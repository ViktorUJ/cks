package main

import (
	"fmt"
	"time"
)

func main() {
	for {
		fmt.Println("I am working")
		time.Sleep(2000 * time.Millisecond)
	}
}
