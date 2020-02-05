package common

var KafkaCfg *KafkaConfig

type KafkaConfig struct {
	Address string
	Group   string
	Topic   string
}

var ContractAddress string

var Account *AccountConfig

type AccountConfig struct {
	Name string
	Priv string
}

var SideChainClient string
