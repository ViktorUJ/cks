package main

import (
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
			time.Sleep(100 * time.Millisecond)
		}
	}
}
