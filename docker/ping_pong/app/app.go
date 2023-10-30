package main

import (
	"fmt"
	"net"
	"net/http"
	"os"
	"runtime"
	"strings"
	"sync/atomic"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	requestsPerSecond float64
	requestsPerMinute float64
	lastRequestTime   time.Time
	requestsCount     uint64
	serverName        string
)

func init() {
	serverName = os.Getenv("SERVER_NAME")
	if serverName == "" {
		serverName = "ping_pong_server"
	}
}

func requestHandler(w http.ResponseWriter, r *http.Request) {
	var response strings.Builder
	response.WriteString(fmt.Sprintf("Server Name: %s\n", serverName))
	response.WriteString(fmt.Sprintf("Client IP: %s\n", getIP(r)))  // Include Client IP in the response
	response.WriteString(fmt.Sprintf("Method: %s\n", r.Method))
	response.WriteString(fmt.Sprintf("URL: %s\n", r.URL.String()))
	response.WriteString(fmt.Sprintf("Protocol: %s\n", r.Proto))
	response.WriteString("Headers:\n")

	for name, headers := range r.Header {
		for _, h := range headers {
			response.WriteString(fmt.Sprintf("%v: %v\n", name, h))
		}
	}

	// Update metrics
	atomic.AddUint64(&requestsCount, 1)
	now := time.Now()
	elapsed := now.Sub(lastRequestTime).Seconds()
	lastRequestTime = now
	requestsPerSecond = 1 / elapsed
	requestsPerMinute = requestsPerSecond * 60

	// Output all headers and meta information in the response
	fmt.Fprint(w, response.String())
}

// getIP extracts the IP address from the request's RemoteAddr field.
func getIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr  // Return the full RemoteAddr field if it cannot be split
	}
	return host
}

func metricsHandler() {
	// ... (rest of the code)

	metricPort := os.Getenv("METRIC_PORT")
	if metricPort == "" {
		metricPort = "9090"  // Default port for Prometheus metrics is now 9090
	}

	http.Handle("/metrics", promhttp.Handler())
	http.ListenAndServe(":" + metricPort, nil)
}

func main() {
	// Print all environment variables
	for _, env := range os.Environ() {
		fmt.Println(env)
	}

	http.HandleFunc("/", requestHandler)
	go metricsHandler()  // Start the metrics server in a separate goroutine

	port := os.Getenv("SRV_PORT")
	if port == "" {
		fmt.Println("SRV_PORT is not set, defaulting to 8080")
		port = "8080"
	}

	err := http.ListenAndServe(":" + port, nil)
	if err != nil {
		fmt.Println("Server failed:", err)
	}
}
