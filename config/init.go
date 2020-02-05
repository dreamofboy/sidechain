package config

import (
	"fmt"

	"github.com/fractalplatform/sidechain/common"
	"github.com/spf13/viper"
)

func InitConfig() {
	viper.SetConfigType("yaml")
	viper.SetConfigName("./config")
	viper.AddConfigPath(".")

	readConfig()
}

func readConfig() {
	err := viper.ReadInConfig()
	if err != nil {
		panic(fmt.Errorf("Fatal error config file: %s \n", err))
	}

	common.KafkaCfg = &common.KafkaConfig{
		Address: viper.GetString("sidechain.kafka.address"),
		Group:   viper.GetString("sidechain.kafka.group"),
		Topic:   viper.GetString("sidechain.kafka.topic"),
	}

	common.ContractAddress = viper.GetString("sidechain.contract.address")

	common.Account = &common.AccountConfig{
		Name: viper.GetString("sidechain.oracle.account"),
		Priv: viper.GetString("sidechain.oracle.priv"),
	}

	common.SideChainClient = viper.GetString("sidechain.rpc.host")
}
