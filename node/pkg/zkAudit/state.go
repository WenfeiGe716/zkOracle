package zkAudit

import (
	"bytes"
	"errors"
	"fmt"
	"github.com/consensys/gnark-crypto/accumulator/merkletree"
	"github.com/consensys/gnark/frontend"
	"github.com/consensys/gnark/std/accumulator/merkle"
	"hash"
	"math/big"
	"sync"
)

type State struct {
	sync.RWMutex
	hFunc hash.Hash
	data  []byte
	hData []byte
}

func NewState(hFunc hash.Hash, accounts []*Account) (*State, error) {

	data := make([]byte, accountSize*len(accounts))
	hData := make([]byte, hFunc.Size()*len(accounts))

	for i, account := range accounts {

		hFunc.Reset()

		accountData := account.Serialize()
		_, err := hFunc.Write(accountData)
		if err != nil {
			return nil, fmt.Errorf("hash account: %w", err)
		}
		s := hFunc.Sum(nil)

		copy(data[i*accountSize:(i+1)*accountSize], accountData)
		copy(hData[i*hFunc.Size():(i+1)*hFunc.Size()], s)
	}

	return &State{
		hFunc: hFunc,
		data:  data,
		hData: hData,
	}, nil
}

func (s *State) WriteAccount(account Account) error {
	s.Lock()
	defer s.Unlock()

	i := int(account.Index.Int64())
	accountData := account.Serialize()

	copy(s.data[i*accountSize:], accountData)

	s.hFunc.Reset()
	_, err := s.hFunc.Write(accountData)
	if err != nil {
		return fmt.Errorf("hash account: %w", err)
	}
	copy(s.hData[i*s.hFunc.Size():(i+1)*s.hFunc.Size()], s.hFunc.Sum(nil))

	return nil
}

func (s *State) ReadAccount(i uint64) (Account, error) {
	s.RLock()
	defer s.RUnlock()

	var res Account
	res.Deserialize(s.data[int(i)*accountSize : int(i)*accountSize+accountSize])
	return res, nil
}

func (s *State) Root() ([]byte, error) {
	s.RLock()
	defer s.RUnlock()

	var stateBuf bytes.Buffer
	_, err := stateBuf.Write(s.hData)
	if err != nil {
		return nil, fmt.Errorf("%v", err)
	}
	return merkletree.ReaderRoot(&stateBuf, s.hFunc, s.hFunc.Size())
}

func (s *State) MerkleProof(i uint64) ([]byte, [Depth]frontend.Variable, [Depth - 1]frontend.Variable, error) {
	s.RLock()
	defer s.RUnlock()

	var path [Depth]frontend.Variable
	var helper [Depth - 1]frontend.Variable

	var stateBuf bytes.Buffer
	_, err := stateBuf.Write(s.hData)
	if err != nil {
		return nil, path, helper, fmt.Errorf("%v", err)
	}
	root, proof, numLeaves, _ := merkletree.BuildReaderProof(&stateBuf, s.hFunc, s.hFunc.Size(), i)
	proofHelper := merkle.GenerateProofHelper(proof, i, numLeaves)

	if !merkletree.VerifyProof(s.hFunc, root, proof, i, numLeaves) {
		return nil, path, helper, errors.New("invalid merkle proof")
	}

	p := make([]*big.Int, len(proof))
	for i, node := range proof {
		p[i] = big.NewInt(0).SetBytes(node)
	}

	for i := 0; i < len(proof); i++ {
		path[i] = proof[i]
	}

	for i := 0; i < len(proofHelper); i++ {
		helper[i] = proofHelper[i]
	}

	return root, path, helper, nil
}

func (s *State) MerkleProofBytes(i uint64) ([]byte, [Depth]*big.Int, [Depth - 1]*big.Int, error) {
	s.RLock()
	defer s.RUnlock()

	var path [Depth]*big.Int
	var helper [Depth - 1]*big.Int

	var stateBuf bytes.Buffer
	_, err := stateBuf.Write(s.hData)
	if err != nil {
		return nil, path, helper, fmt.Errorf("%v", err)
	}
	root, proof, numLeaves, _ := merkletree.BuildReaderProof(&stateBuf, s.hFunc, s.hFunc.Size(), i)
	proofHelper := merkle.GenerateProofHelper(proof, i, numLeaves)

	if !merkletree.VerifyProof(s.hFunc, root, proof, i, numLeaves) {
		return nil, path, helper, errors.New("invalid merkle proof")
	}

	for i := 0; i < len(proof); i++ {
		path[i] = big.NewInt(0).SetBytes(proof[i])
	}

	for i := 0; i < len(proofHelper); i++ {
		helper[i] = big.NewInt(int64(proofHelper[i]))
	}

	return root, path, helper, nil
}

func (s *State) SetData(data []byte) {
	s.Lock()
	defer s.Unlock()
	s.data = data
}

func (s *State) SetHData(hData []byte) {
	s.Lock()
	defer s.Unlock()
	s.hData = hData
}
