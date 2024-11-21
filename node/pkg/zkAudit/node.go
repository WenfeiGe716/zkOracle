package zkAudit

import (
	"context"
	"crypto/ecdsa"
	"encoding/hex"
	"fmt"
	"github.com/consensys/gnark-crypto/ecc"
	"github.com/consensys/gnark-crypto/ecc/bn254/fr/mimc"
	"github.com/consensys/gnark-crypto/ecc/bn254/twistededwards/eddsa"
	"github.com/consensys/gnark/backend/groth16"
	"github.com/consensys/gnark/frontend"
	"github.com/consensys/gnark/frontend/cs/r1cs"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/spf13/viper"
	"google.golang.org/grpc"
	"math/big"
	"net"
	"os"
)

type Node struct {
	UnimplementedOracleNodeServer
	config          Config
	viper           *viper.Viper
	chainID         *big.Int
	ethClient       *ethclient.Client
	ecdsaPrivateKey *ecdsa.PrivateKey
	eddsaPrivateKey *eddsa.PrivateKey
	contract        *ZKOracleContract
	aggregator      *Aggregator
	validator       *Validator
	votePool        *VotePool
	state           *State
	stateSync       *StateSync
	server          *grpc.Server
}

func NewNode(v *viper.Viper) (*Node, error) {

	var config Config
	err := viper.Unmarshal(&config)
	if err != nil {
		panic(err)
	}

	ethClient, err := ethclient.Dial(config.Ethereum.TargetAddress)
	if err != nil {
		return nil, fmt.Errorf("dial eth: %w", err)
	}

	chainID, err := ethClient.ChainID(context.Background())
	if err != nil {
		return nil, fmt.Errorf("chain id: %w", err)
	}

	ecdsaPrivateKey, err := crypto.HexToECDSA(config.Ethereum.PrivateKey)
	if err != nil {
		return nil, fmt.Errorf("ecdsa private key: %w", err)
	}

	contract, err := NewZKOracleContract(common.HexToAddress(config.ContractAddress), ethClient)
	if err != nil {
		return nil, fmt.Errorf("oracle contract: %w", err)
	}

	b, err := hex.DecodeString(config.PrivateKey)
	if err != nil {
		return nil, fmt.Errorf("eddsa private key to bytes: %w", err)
	}

	eddsaPrivateKey := new(eddsa.PrivateKey)
	_, err = eddsaPrivateKey.SetBytes(b)
	if err != nil {
		return nil, fmt.Errorf("eddsa private key from bytes: %w", err)
	}

	validator := NewValidator(config.Index, ethClient, contract, eddsaPrivateKey)

	var circuit AggregationCircuit
	constraintSystem, err := frontend.Compile(ecc.BN254, r1cs.NewBuilder, &circuit)
	if err != nil {
		return nil, fmt.Errorf("compile: %w", err)
	}

	pkFile, err := os.Open(config.ZKP.ProvingKey)
	if err != nil {
		return nil, fmt.Errorf("open pk file: %w", err)
	}

	pk := groth16.NewProvingKey(ecc.BN254)
	_, err = pk.ReadFrom(pkFile)
	if err != nil {
		return nil, fmt.Errorf("read from pk file: %w", err)
	}

	vkFile, err := os.Open(config.ZKP.VerifyingKey)
	if err != nil {
		return nil, fmt.Errorf("open vk file: %w", err)
	}

	vk := groth16.NewVerifyingKey(ecc.BN254)
	_, err = vk.ReadFrom(vkFile)
	if err != nil {
		return nil, fmt.Errorf("read from vk file: %w", err)
	}

	state, err := NewState(mimc.NewMiMC(), nil)
	if err != nil {
		return nil, fmt.Errorf("create state: %w", err)
	}

	votePool := NewVotePool()
	aggregator := NewAggregator(
		config.Index,
		eddsaPrivateKey,
		state,
		votePool,
		constraintSystem,
		pk,
		vk,
		contract,
		chainID,
		ecdsaPrivateKey,
		ethClient,
	)

	stateSync := NewStateSync(config.Index, state, contract, common.HexToAddress(config.ContractAddress), ethClient)

	server := grpc.NewServer()

	node := &Node{
		config:          config,
		viper:           v,
		server:          server,
		contract:        contract,
		validator:       validator,
		aggregator:      aggregator,
		chainID:         chainID,
		ecdsaPrivateKey: ecdsaPrivateKey,
		eddsaPrivateKey: eddsaPrivateKey,
		ethClient:       ethClient,
		state:           state,
		stateSync:       stateSync,
		votePool:        votePool,
	}
	RegisterOracleNodeServer(server, node)

	return node, nil
}

func (n *Node) Register(ipAddr string) error {

	auth, err := bind.NewKeyedTransactorWithChainID(n.ecdsaPrivateKey, n.chainID)
	if err != nil {
		return fmt.Errorf("new transactor: %w", err)
	}
	auth.GasPrice = big.NewInt(20000000000)

	x := new(big.Int)
	y := new(big.Int)

	n.eddsaPrivateKey.PublicKey.A.X.ToBigIntRegular(x)
	n.eddsaPrivateKey.PublicKey.A.Y.ToBigIntRegular(y)

	logger.Info().
		Str("pubKeyX", x.String()).
		Str("pubKeyY", y.String()).
		Str("ipAddr", ipAddr).
		Msg("register")

	eventChan := make(chan *ZKOracleContractRegistered)
	go func() {
		e, err := WaitEvent(context.Background(), n.contract.WatchRegistered)
		if err != nil {
			logger.Error().Err(err).Msg("wait registered event")
		}
		eventChan <- e
	}()

	_, err = n.contract.Register(auth, ZKOraclePublicKey{
		X: x,
		Y: y,
	}, ipAddr)
	if err != nil {
		return fmt.Errorf("register: %w", err)
	}

	registeredEvent := <-eventChan
	viper.Set("registered", true)
	viper.Set("index", registeredEvent.Index.Uint64())

	err = n.viper.WriteConfig()
	if err != nil {
		return fmt.Errorf("write config: %w", err)
	}

	return nil
}

func (n *Node) Run() error {

	go func() {
		if err := n.stateSync.Synchronize(); err != nil {
			logger.Err(err).Msg("synchronize")
		}
	}()

	if !n.config.Registered {
		err := n.Register(n.config.BindAddress)
		if err != nil {
			return fmt.Errorf("register: %w", err)
		}
	}

	go func() {
		err := n.aggregator.Aggregate(context.Background())
		if err != nil {
			logger.Err(err).Msg("aggregate")
		}
	}()

	go func() {
		err := n.validator.Validate(context.Background())
		if err != nil {
			logger.Err(err).Msg("validate")
		}
	}()

	listener, err := net.Listen("tcp", n.config.BindAddress)
	if err != nil {
		return fmt.Errorf("listen tcp: %w", err)
	}

	return n.server.Serve(listener)
}

func (n *Node) Stop() {
	n.server.Stop()
}
