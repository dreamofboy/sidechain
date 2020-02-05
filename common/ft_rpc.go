package common

import (
	"context"
	"math/big"
	"os"
	"os/user"
	"path/filepath"
	"runtime"
	"strings"
	"sync"

	"github.com/fractalplatform/fractal/common"
	"github.com/fractalplatform/fractal/common/hexutil"
	"github.com/fractalplatform/fractal/rpc"
	jww "github.com/spf13/jwalterweatherman"
)

var (
	once           sync.Once
	clientInstance *rpc.Client
	defaultRPCPath = "ft.ipc"
)

// DefultURL default rpc url
func DefultURL() string {
	if strings.HasPrefix(defaultRPCPath, "http://") {
		return defaultRPCPath
	}
	if runtime.GOOS == "windows" {
		return `\\.\pipe\` + defaultRPCPath
	}
	return filepath.Join(defaultDataDir(), defaultRPCPath)
}

func SetDefultURL(rpchost string) {
	defaultRPCPath = rpchost
}

// MustRPCClient Wraper rpc's client
func MustRPCClient() *rpc.Client {
	once.Do(func() {
		client, err := rpc.Dial(DefultURL())
		if err != nil {
			jww.ERROR.Fatalln(err)
			os.Exit(1)
		}
		clientInstance = client
	})

	return clientInstance
}

// ClientCall Wrapper rpc call api.
func ClientCall(method string, result interface{}, args ...interface{}) error {
	client := MustRPCClient()
	err := client.CallContext(context.Background(), result, method, args...)
	return err
}

//SendRawTx send raw transaction
func SendRawTx(rawTx []byte) (common.Hash, error) {
	hash := new(common.Hash)
	err := ClientCall("ft_sendRawTransaction", hash, hexutil.Bytes(rawTx))
	return *hash, err
}

// GasPrice suggest gas price
func GasPrice() (*big.Int, error) {
	gp := big.NewInt(0)
	err := ClientCall("ft_gasPrice", gp)
	return gp, err
}

// GetNonce get nonce by name and block number.
func GetNonce(accountName string) (uint64, error) {
	nonce := new(uint64)
	err := ClientCall("account_getNonce", nonce, accountName)
	return *nonce, err
}

// defaultDataDir is the default data directory to use for the databases and other
// persistence requirements.
func defaultDataDir() string {
	// Try to place the data folder in the user's home dir
	home := homeDir()
	if home != "" {
		if runtime.GOOS == "darwin" {
			return filepath.Join(home, "Library", "ft_ledger")
		} else if runtime.GOOS == "windows" {
			return filepath.Join(home, "AppData", "Roaming", "ft_ledger")
		} else {
			return filepath.Join(home, ".ft_ledger")
		}
	}
	// As we cannot guess a stable location, return empty and handle later
	return ""
}

func homeDir() string {
	if home := os.Getenv("HOME"); home != "" {
		return home
	}
	if usr, err := user.Current(); err == nil {
		return usr.HomeDir
	}
	return ""
}
