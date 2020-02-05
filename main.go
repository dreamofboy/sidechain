package main

import (
	"github.com/fractalplatform/sidechain/config"
	"github.com/fractalplatform/sidechain/oracle"
)

func main() {
	config.InitConfig()
	oracle.StartClient()
}
