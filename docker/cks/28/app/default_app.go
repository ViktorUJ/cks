package main

import (
	"log"
	"time"
)

func main() {
	for {
		log.Println("I am working...")
		time.Sleep(5000 * time.Millisecond)
	}
}
