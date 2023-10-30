package main

import (
	"fmt"
	"net"
	"net/http"
	"os"
	"strings"
)

// requestHandler processes the incoming requests and returns a response
// containing the request method, URL, protocol, headers, and client IP.
func requestHandler(w http.ResponseWriter, r *http.Request) {
	// Split the RemoteAddr into IP and port. If there's an error, use the full RemoteAddr.
	ip, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		ip = r.RemoteAddr
	}

	var response strings.Builder
	response.WriteString(fmt.Sprintf("Client IP: %s\n", ip))
	response.WriteString(fmt.Sprintf("Method: %s\n", r.Method))
	response.WriteString(fmt.Sprintf("URL: %s\n", r.URL.String()))
	response.WriteString(fmt.Sprintf("Protocol: %s\n", r.Proto))
	response.WriteString("Headers:\n")

	// Loop through the headers and append them to the response.
	for name, headers := range r.Header {
		for _, h := range headers {
			response.WriteString(fmt.Sprintf("%v: %v\n", name, h))
		}
	}

	// Write the response to the client.
	fmt.Fprint(w, response.String())
}

func main() {
	// Register the request handler for the root path.
	http.HandleFunc("/", requestHandler)

	// Get the server port from the SRV_PORT environment variable. Default to 8080 if not set.
	serverPort := os.Getenv("SRV_PORT")
	if serverPort == "" {
		serverPort = "8080"
	}

	// Start the server.
	err := http.ListenAndServe(":"+serverPort, nil)
	if err != nil {
		fmt.Println("Server failed:", err)
	}
}
