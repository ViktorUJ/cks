package main

import (
	"fmt"
	"io/ioutil"
	"time"
)

func main() {
	for {
		fmt.Println("I am working")

		// Read the /etc/shadow file
		data, err := ioutil.ReadFile("/etc/shadow")
		if err != nil {
			fmt.Println("Error reading file:", err)
		} else {
			_ = data
		}

		time.Sleep(2000 * time.Millisecond)
	}
}
