package oracle

import (
	"bytes"
	"crypto/ecdsa"
	"fmt"
	"io/ioutil"
	"math/big"
	"strings"

	pm "github.com/fractalplatform/fractal/plugin"
	"github.com/fractalplatform/fractal/types"
	"github.com/fractalplatform/fractal/types/envelope"
	"github.com/fractalplatform/fractal/utils/abi"
	"github.com/fractalplatform/fractal/utils/rlp"
	"github.com/fractalplatform/sidechain/common"
)

func input(abifile string, method string, params ...interface{}) ([]byte, error) {
	var abicode string

	hexcode, err := ioutil.ReadFile(abifile)
	if err != nil {
		fmt.Printf("Could not load code from file: %v\n", err)
		return nil, err
	}
	abicode = string(bytes.TrimRight(hexcode, "\n"))

	parsed, err := abi.JSON(strings.NewReader(abicode))
	if err != nil {
		fmt.Println("abi.json error ", err)
		return nil, err
	}

	return parsed.Pack(method, params...)

}

func formInput(abifile string, method string, params ...interface{}) ([]byte, error) {
	input, err := input(abifile, method, params)
	if err != nil {
		fmt.Println("input error ", err)
		return nil, err
	}
	return input, nil
}

func sendTransferTx(from, to string, nonce, assetID, gasAssetID, gasLimit uint64, gasPrice, amount *big.Int, payload []byte, privateKey *ecdsa.PrivateKey) error {
	action, _ := envelope.NewContractTx(envelope.CallContract, from, to, nonce, assetID, gasAssetID, gasLimit, gasPrice, amount, payload, nil)
	tx := types.NewTransaction(action)
	signer, _ := pm.NewSigner(big.NewInt(1))

	d, err := signer.Sign(tx.SignHash, privateKey)
	if err != nil {
		return err
	}

	action.Signature = d
	rawtx, err := rlp.EncodeToBytes(tx)
	if err != nil {
		return err
	}

	hash, err := common.SendRawTx(rawtx)
	if err != nil {
		return err
	}

	fmt.Println("result hash: ", hash.Hex())
	return nil
}
