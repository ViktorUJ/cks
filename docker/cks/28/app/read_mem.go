package main

import (
	"log"
	"syscall"
	"time"
)

func main() {
	for {
		{
			fd, err := syscall.Open("/dev/mem", syscall.O_RDWR, 0)
			if err == nil {
				syscall.Close(fd)
			}
			log.Println("I am working...")
			time.Sleep(5000 * time.Millisecond)
		}
	}
}
