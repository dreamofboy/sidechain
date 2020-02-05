package oracle

import (
	"fmt"

	"github.com/Shopify/sarama"
	cluster "github.com/bsm/sarama-cluster"
	"github.com/fractalplatform/sidechain/common"
)

func StartClient() {
	consumer := createConsumer()
	for {
		for msg := range consumer.Messages() {
			fmt.Println("value ", string(msg.Value))
			handleMsg(msg.Value)
			// mark the message as processed
			//todo 异常处理，记录消息队列处理位置，(数据库事务提交，标记消息队列读取位置失败)
			//todo kafka 消息分组
			consumer.MarkOffset(msg, "")
		}
	}
}

func createConsumer() *cluster.Consumer {
	// define our configuration to the cluster
	config := cluster.NewConfig()
	config.Consumer.Return.Errors = false
	config.Group.Return.Notifications = false
	config.Consumer.Offsets.Initial = sarama.OffsetOldest
	//config.Config.Net.SASL.User = ""
	//config.Config.Net.SASL.Password = ""

	// create the consumer
	consumer, err := cluster.NewConsumer([]string{common.KafkaCfg.Address}, common.KafkaCfg.Group, []string{common.KafkaCfg.Topic}, config)
	if err != nil {
		fmt.Println("Unable to connect consumer to kafka cluster")
	}
	fmt.Println("connected")

	go handleErrors(consumer)
	go handleNotifications(consumer)
	return consumer
}

func handleErrors(consumer *cluster.Consumer) {
	for err := range consumer.Errors() {
		fmt.Println("Error: ", err)
	}
}

func handleNotifications(consumer *cluster.Consumer) {
	for ntf := range consumer.Notifications() {
		fmt.Println("Rebalanced: ", ntf)
	}
}
