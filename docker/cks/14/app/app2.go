package main

import (
	"syscall"
	"time"
)

func main() {
	for {
		println("I am working ")
		syscall.Kill(666, syscall.SIGTERM)
		time.Sleep(500 * time.Millisecond)
	}
}
