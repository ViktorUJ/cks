package main

import (
	"fmt"
	"net"
	"net/http"
	"os"
    "path/filepath"
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
	logPath       string
	enableOutput  string
)

func init() {
	serverName = os.Getenv("SERVER_NAME")
	if serverName == "" {
		serverName = "ping_pong_server"
	}
	logPath = os.Getenv("LOG_PATH")

	enableOutput = os.Getenv("ENABLE_OUTPUT")
	if enableOutput == "" {
		enableOutput = "true"
	}

	enableLoadCpu = os.Getenv("ENABLE_LOAD_CPU")
	if enableLoadCpu == "" {
		enableLoadCpu = "false"
	}

	enableLoadMemory = os.Getenv("ENABLE_LOAD_MEMORY")
	if enableLoadMemory == "" {
		enableLoadMemory = "false"
	}

	memoryUsageMin = os.Getenv("MEMORY_USAGE_MIN")
	if memoryUsageMin == "" {
		memoryUsageMin = "1"
	}

	memoryUsageMax = os.Getenv("MEMORY_USAGE_MAX")
	if memoryUsageMax == "" {
		memoryUsageMax = "1"
	}

	memoryUsageIncreaseSteps = os.Getenv("MEMORY_USAGE_INCREASE_STEPS")
	if memoryUsageIncreaseSteps == "" {
		memoryUsageIncreaseSteps = "1"
	}

	memoryUsageIncreaseStepsWait = os.Getenv("MEMORY_USAGE_INCREASE_STEPS_WAIT")
	if memoryUsageIncreaseStepsWait == "" {
		memoryUsageIncreaseStepsWait = "1"
	}

	memoryUsageIncreaseLoopWait = os.Getenv("MEMORY_USAGE_INCREASE_LOOP_WAIT")
	if memoryUsageIncreaseLoopWait == "" {
		memoryUsageIncreaseLoopWait = "1"
	}

	cpuMaxProc = os.Getenv("CPU_MAXPROC")
	if cpuMaxProc == "" {
		cpuMaxProc = "1"
	}

	cpuPiIterations = os.Getenv("CPU_PI_ITERATIONS")
	if cpuPiIterations == "" {
		cpuPiIterations = "1"
	}

	if logPath != "" {
		dir := filepath.Dir(logPath)
		if _, err := os.Stat(dir); os.IsNotExist(err) {
			err := os.MkdirAll(dir, os.ModePerm)
			if err != nil {
				fmt.Println("Failed to create log directory: %v", err)
			}
		}

		file, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
		if err != nil {
			fmt.Println("Failed to open log file: %v", err)
		}
		file.Close()
	}

    size := memoryUsageMin * 1024 * 1024
    slice := make([]byte, size)

}

func requestHandler(w http.ResponseWriter, r *http.Request) {
	var response strings.Builder
	response.WriteString(fmt.Sprintf("Server Name: %s\n", serverName))
    response.WriteString(fmt.Sprintf("URL: http://%s%s\n", r.Host, r.URL.String()))
	response.WriteString(fmt.Sprintf("Client IP: %s\n", getIP(r)))
	response.WriteString(fmt.Sprintf("Method: %s\n", r.Method))
	response.WriteString(fmt.Sprintf("Protocol: %s\n", r.Proto))
	response.WriteString("Headers:\n")

	for name, headers := range r.Header {
		for _, h := range headers {
			response.WriteString(fmt.Sprintf("%v: %v\n", name, h))
		}
	}

	atomic.AddUint64(&requestsCount, 1)
	now := time.Now()
	elapsed := now.Sub(lastRequestTime).Seconds()
	lastRequestTime = now
	requestsPerSecond = 1 / elapsed
	requestsPerMinute = requestsPerSecond * 60

	fmt.Fprint(w, response.String())
	sendLog(response.String())
}

func getIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

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
		metricPort = "9090"
	}

	http.Handle("/metrics", promhttp.Handler())
	http.ListenAndServe(":" + metricPort, nil)
}

func sendLog(message string) {
	if enableOutput == "true" {
		fmt.Println(message)
	}

	if logPath != "" {
		file, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
		if err != nil {
			fmt.Println("Failed to open log file:", err)
			return
		}
		defer file.Close()

		if _, err := file.WriteString(message + "\n"); err != nil {
			fmt.Println("Failed to write to log file:", err)
		}
	}
}

func main() {
	for _, env := range os.Environ() {
		sendLog(env)
	}
    fmt.Println(enableLoadCpu)
	http.HandleFunc("/", requestHandler)
	go metricsHandler()

	port := os.Getenv("SRV_PORT")
	if port == "" {
		sendLog("SRV_PORT is not set, defaulting to 8080")
		port = "8080"
	}

	err := http.ListenAndServe(":" + port, nil)
	if err != nil {
		sendLog(fmt.Sprintf("Server failed: %v", err))
	}
}
