package main
import (
  "time"
   "syscall"
)
func main() {
    for {
    println("I am working ")
    syscall.Kill(666, syscall.SIGTERM)
    time.Sleep(5000 * time.Millisecond)
}
}
