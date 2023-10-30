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
	requestsPerSecond int64
	requestsPerMinute int64
)

func requestHandler(w http.ResponseWriter, r *http.Request) {
	atomic.AddInt64(&requestsPerSecond, 1)
	atomic.AddInt64(&requestsPerMinute, 1)

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

	// Вывод всех заголовков и метаинформации в ответ
	fmt.Fprint(w, response.String())
}

func recordMetrics() {
	tickerSecond := time.NewTicker(time.Second)
	tickerMinute := time.NewTicker(time.Minute)
	for {
		select {
		case <-tickerSecond.C:
			atomic.StoreInt64(&requestsPerSecond, 0)
		case <-tickerMinute.C:
			atomic.StoreInt64(&requestsPerMinute, 0)
		}
	}
}

func main() {
	go recordMetrics()

	http.HandleFunc("/", requestHandler)

	http.Handle("/metrics", promhttp.HandlerFor(
		prometheus.DefaultGatherer,
		promhttp.HandlerOpts{},
	))

	port := os.Getenv("SRV_PORT")
	if port == "" {
		fmt.Println("SRV_PORT is not set, defaulting to 8080")
		port = "8080"
	}

	metricPort := os.Getenv("METRIC_PORT")
	if metricPort == "" {
		fmt.Println("METRIC_PORT is not set, defaulting to 9090")
		metricPort = "9090"
	}

	go func() {
		err := http.ListenAndServe(":"+port, nil)
		if err != nil {
			fmt.Println("Server failed:", err)
		}
	}()

	err := http.ListenAndServe(":"+metricPort, nil)
	if err != nil {
		fmt.Println("Metric server failed:", err)
	}
}
