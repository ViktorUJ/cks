package main

import (
	"fmt"
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
	requestsCount     uint64  // Add this line
)

// requestHandler handles all incoming HTTP requests and returns the request details as the response.
func requestHandler(w http.ResponseWriter, r *http.Request) {
	var response strings.Builder
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

// metricsHandler sets up the Prometheus metrics and starts the metrics server.
func metricsHandler() {
	requests := prometheus.NewCounterFunc(
		prometheus.CounterOpts{
			Name: "requests_total",
			Help: "Total number of requests.",
		},
		func() float64 {
			return float64(atomic.LoadUint64(&requestsCount))
		},
	)

	rps := prometheus.NewGaugeFunc(
		prometheus.GaugeOpts{
			Name: "requests_per_second",
			Help: "Requests per second.",
		},
		func() float64 {
			return requestsPerSecond
		},
	)

	rpm := prometheus.NewGaugeFunc(
		prometheus.GaugeOpts{
			Name: "requests_per_minute",
			Help: "Requests per minute.",
		},
		func() float64 {
			return requestsPerMinute
		},
	)

	goroutines := prometheus.NewGaugeFunc(
		prometheus.GaugeOpts{
			Name: "goroutines",
			Help: "Current number of goroutines.",
		},
		func() float64 {
			return float64(runtime.NumGoroutine())
		},
	)

	prometheus.MustRegister(requests, rps, rpm, goroutines)

	metricPort := os.Getenv("METRIC_PORT")
	if metricPort == "" {
		metricPort = "9090"  // Default port for Prometheus metrics
	}

	http.Handle("/metrics", promhttp.Handler())
	http.ListenAndServe(":" + metricPort, nil)
}

// main function sets up the main HTTP server and the metrics server.
func main() {
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
