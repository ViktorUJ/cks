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
		}
		time.Sleep(2000 * time.Millisecond)
	}
}
