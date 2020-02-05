package oracle

import (
	"fmt"

	"github.com/Jeffail/gabs"
)

func handleMsg(msg []byte) {
	container, _ := gabs.ParseJSON(msg)
	switch container.Path("eventName").Data().(string) {
	case "TRXReceived":
		from := container.Path("dataMap.from").String()
		to := container.Path("dataMap.to").String()
		value := container.Path("dataMap.value").String()
		nonce := container.Path("dataMap.nonce").String()
		fmt.Println("f t v n", from, to, value, nonce)
	}
}
