package simulator

import (
	"fmt"
	"github.com/consensys/gnark-crypto/ecc/bn254/twistededwards/eddsa"
	"github.com/stretchr/testify/require"
	"math/big"
	"math/rand"
	"node/pkg/zkAudit"
	"testing"
	"time"
)

func TestAccounts(t *testing.T) {
	t.Run("生成账户", testAccount)
}

func testGeneratePrivateKeys(t *testing.T) (*eddsa.PrivateKey, error) {
	r := rand.New(rand.NewSource(time.Now().UnixNano()))
	privateKey, err := eddsa.GenerateKey(r)
	if err != nil {
		return nil, fmt.Errorf("eddsa generate key: %w", err)
	}
	return privateKey, nil
}

func testAccount(t *testing.T) {
	privateKey, err := testGeneratePrivateKeys(t)
	require.Nil(t, err, "生成私钥失败！")
	account := &zkAudit.Account{
		Index:     big.NewInt(int64(1)),
		PublicKey: &privateKey.PublicKey,
		Balance:   big.NewInt(0),
	}
	fmt.Printf("X:%s\n", privateKey.PublicKey.A.X.String())
	fmt.Printf("Y:%s\n", privateKey.PublicKey.A.Y.String())
	fmt.Printf("Account:%v\n", account)
}
