package main

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type MemoryUsageProfile struct {
	Megabytes int
	Seconds   int
}

type CpuUsageProfile struct {
	IterationsMillion int
	WaitMilliseconds  int
	Goroutines        int
	TimeSeconds       int
}

var (
	requestsPerSecond     float64
	requestsPerMinute     float64
	lastRequestTime       time.Time
	requestsCount         uint64
	serverName            string
	hostName              string
	logPath               string
	enableOutput          string
	enableLoadCpu         string
	enableLoadMemory      string
	enableLogLoadMemory   string
	enableLogLoadCpu      string
	delayStart            string
	enableDefaultHostName string
	memoryProfiles        []MemoryUsageProfile
	cpuProfiles           []CpuUsageProfile
	cpuMaxProc            int
)

func init() {
	hostName = os.Getenv("HOSTNAME")

	enableDefaultHostName = os.Getenv("ENABLE_DEFAULT_HOSTNAME")
	if enableDefaultHostName == "" {
		enableDefaultHostName = "true"
	}

	delayStart = os.Getenv("DELAY_START")
	if delayStart == "" {
		delayStart = "0"
	}

	if hostName == "" || enableDefaultHostName == "true" {
		hostName = "ping_pong_server"
	}

	serverName = os.Getenv("SERVER_NAME")
	if serverName == "" {
		serverName = hostName
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
	enableLogLoadMemory = os.Getenv("ENABLE_LOG_LOAD_MEMORY")
	if enableLogLoadMemory == "" {
		enableLogLoadMemory = "false"
	}

	enableLogLoadCpu = os.Getenv("ENABLE_LOG_LOAD_CPU")
	if enableLogLoadCpu == "" {
		enableLogLoadCpu = "false"
	}

	cpuMaxProc = func() int {
		if value, err := strconv.Atoi(os.Getenv("CPU_MAXPROC")); err == nil && value > 0 {
			return value
		}
		return 1
	}()

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

}
func cpuUsage() {

	cpuProfileStr := os.Getenv("CPU_USAGE_PROFILE")
	profiles := strings.Split(cpuProfileStr, " ")
	for _, p := range profiles {
		parts := strings.Split(p, "=")
		if len(parts) == 4 {
			iterationsMillion, err1 := strconv.Atoi(parts[0])
			waitMilliseconds, err2 := strconv.Atoi(parts[1])
			goroutines, err3 := strconv.Atoi(parts[2])
			timeSeconds, err4 := strconv.Atoi(parts[3])

			if err1 == nil && err2 == nil && err3 == nil && err4 == nil {
				cpuProfiles = append(cpuProfiles, CpuUsageProfile{
					IterationsMillion: iterationsMillion,
					WaitMilliseconds:  waitMilliseconds,
					Goroutines:        goroutines,
					TimeSeconds:       timeSeconds,
				})
			}
		}
	}

	for {
		for _, profile := range cpuProfiles {
			if enableLogLoadCpu == "true" {
				sendLog(fmt.Sprintf("LoadCpu =>  IterationsMillion: %d, WaitMilliseconds: %d, Goroutines: %d, TimeSeconds: %d, cpuMaxProc:%d\n ",
					profile.IterationsMillion, profile.WaitMilliseconds, profile.Goroutines, profile.TimeSeconds, cpuMaxProc))
			}

			for i := 0; i < profile.Goroutines; i++ {
				go cpuLoad(profile.IterationsMillion, profile.WaitMilliseconds, profile.TimeSeconds)
			}
			time.Sleep(time.Duration(profile.TimeSeconds) * time.Second)
		}

	}
}

func cpuLoad(iterationsMillion int, waitMilliseconds int, timeSeconds int) {
	totalIterations := iterationsMillion * 1000000
	var sum int

	deadline := time.Now().Add(time.Duration(timeSeconds) * time.Second)

	for time.Now().Before(deadline) {
		for i := 0; i < totalIterations; i++ {
			sum += rand.Intn(256)
		}

		if time.Now().Add(time.Duration(waitMilliseconds) * time.Millisecond).Before(deadline) {
			time.Sleep(time.Duration(waitMilliseconds) * time.Millisecond)
		}
	}
}

func memoryUsage() {
	for {
		memoryProfileStr := os.Getenv("MEMORY_USAGE_PROFILE")

		if memoryProfileStr != "" {
			// split  "Mb=sec"
			memoryProfilePairs := strings.Split(memoryProfileStr, " ")

			for _, pair := range memoryProfilePairs {
				parts := strings.Split(pair, "=")
				if len(parts) == 2 {
					mb, errMb := strconv.Atoi(parts[0])
					sec, errSec := strconv.Atoi(parts[1])
					if errMb == nil && errSec == nil {
						memoryProfiles = append(memoryProfiles, MemoryUsageProfile{
							Megabytes: mb,
							Seconds:   sec,
						})
					}
				}
			}
		}

		for _, profile := range memoryProfiles {
			if enableLogLoadMemory == "true" {
				sendLog(fmt.Sprintf("LoadMemory => Megabytes: %d, Seconds: %d\n", profile.Megabytes, profile.Seconds))
			}
			size := profile.Megabytes * 1024 * 1024
			slice := make([]byte, size)

			for i := range slice {
				slice[i] = 0xFF
			}
			time.Sleep(time.Duration(profile.Seconds) * time.Second)
			slice = nil
			runtime.GC()
			time.Sleep(20 * time.Second) // wait GCC

		}

	}

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
	http.ListenAndServe(":"+metricPort, nil)
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

// getVar in JSON fromat
func getVarHandler(w http.ResponseWriter, r *http.Request) {
	vars := map[string]interface{}{
		"requestsPerSecond":     requestsPerSecond,
		"requestsPerMinute":     requestsPerMinute,
		"lastRequestTime":       lastRequestTime.Format(time.RFC3339),
		"requestsCount":         atomic.LoadUint64(&requestsCount),
		"serverName":            serverName,
		"hostName":              hostName,
		"logPath":               logPath,
		"enableOutput":          enableOutput,
		"enableLoadCpu":         enableLoadCpu,
		"enableLoadMemory":      enableLoadMemory,
		"enableLogLoadMemory":   enableLogLoadMemory,
		"enableLogLoadCpu":      enableLogLoadCpu,
		"delayStart":            delayStart,
		"enableDefaultHostName": enableDefaultHostName,
		"cpuMaxProc":            cpuMaxProc,
		"memoryProfiles":        memoryProfiles,
		"cpuProfiles":           cpuProfiles,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(vars)
}

// Metric API  JSON
func getMetricHandler(w http.ResponseWriter, r *http.Request) {
	metrics := map[string]interface{}{
		"requests_total":      atomic.LoadUint64(&requestsCount),
		"requests_per_second": requestsPerSecond,
		"requests_per_minute": requestsPerMinute,
		"goroutines":          runtime.NumGoroutine(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(metrics)
}

func setVarHandler(w http.ResponseWriter, r *http.Request) {
	// Метод запроса должен быть POST
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	// Декодируем входной JSON в мапу
	var updates map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&updates); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	changed := false
	changes := make(map[string]map[string]string)

	// serverName
	if val, ok := updates["serverName"]; ok {
		if s, ok := val.(string); ok && s != serverName {
			changes["serverName"] = map[string]string{"old": serverName, "new": s}
			serverName = s
			changed = true
		}
	}
	// hostName
	if val, ok := updates["hostName"]; ok {
		if s, ok := val.(string); ok && s != hostName {
			changes["hostName"] = map[string]string{"old": hostName, "new": s}
			hostName = s
			changed = true
		}
	}
	// logPath
	if val, ok := updates["logPath"]; ok {
		if s, ok := val.(string); ok && s != logPath {
			changes["logPath"] = map[string]string{"old": logPath, "new": s}
			logPath = s
			changed = true
		}
	}
	// enableOutput
	if val, ok := updates["enableOutput"]; ok {
		if s, ok := val.(string); ok && s != enableOutput {
			changes["enableOutput"] = map[string]string{"old": enableOutput, "new": s}
			enableOutput = s
			changed = true
		}
	}
	// enableLoadCpu
	if val, ok := updates["enableLoadCpu"]; ok {
		if s, ok := val.(string); ok && s != enableLoadCpu {
			changes["enableLoadCpu"] = map[string]string{"old": enableLoadCpu, "new": s}
			enableLoadCpu = s
			changed = true
		}
	}
	// enableLoadMemory
	if val, ok := updates["enableLoadMemory"]; ok {
		if s, ok := val.(string); ok && s != enableLoadMemory {
			changes["enableLoadMemory"] = map[string]string{"old": enableLoadMemory, "new": s}
			enableLoadMemory = s
			changed = true
		}
	}
	// enableLogLoadMemory
	if val, ok := updates["enableLogLoadMemory"]; ok {
		if s, ok := val.(string); ok && s != enableLogLoadMemory {
			changes["enableLogLoadMemory"] = map[string]string{"old": enableLogLoadMemory, "new": s}
			enableLogLoadMemory = s
			changed = true
		}
	}
	// enableLogLoadCpu
	if val, ok := updates["enableLogLoadCpu"]; ok {
		if s, ok := val.(string); ok && s != enableLogLoadCpu {
			changes["enableLogLoadCpu"] = map[string]string{"old": enableLogLoadCpu, "new": s}
			enableLogLoadCpu = s
			changed = true
		}
	}
	// delayStart
	if val, ok := updates["delayStart"]; ok {
		if s, ok := val.(string); ok && s != delayStart {
			changes["delayStart"] = map[string]string{"old": delayStart, "new": s}
			delayStart = s
			changed = true
		}
	}
	// enableDefaultHostName
	if val, ok := updates["enableDefaultHostName"]; ok {
		if s, ok := val.(string); ok && s != enableDefaultHostName {
			changes["enableDefaultHostName"] = map[string]string{"old": enableDefaultHostName, "new": s}
			enableDefaultHostName = s
			changed = true
		}
	}
	// cpuMaxProc
	if val, ok := updates["cpuMaxProc"]; ok {
		switch v := val.(type) {
		case float64:
			intVal := int(v)
			if intVal != cpuMaxProc {
				changes["cpuMaxProc"] = map[string]string{
					"old": strconv.Itoa(cpuMaxProc),
					"new": strconv.Itoa(intVal),
				}
				cpuMaxProc = intVal
				changed = true
			}
		case string:
			intVal, err := strconv.Atoi(v)
			if err == nil && intVal != cpuMaxProc {
				changes["cpuMaxProc"] = map[string]string{
					"old": strconv.Itoa(cpuMaxProc),
					"new": v,
				}
				cpuMaxProc = intVal
				changed = true
			}
		}
	}

	// Возвращаем ответ в JSON
	w.Header().Set("Content-Type", "application/json")
	if changed {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":  "Variables updated. Handlers reloaded.",
			"changes": changes,
		})
	} else {
		json.NewEncoder(w).Encode(map[string]string{"status": "No changes detected."})
	}
}

func main() {
	parsedDelay, err := strconv.Atoi(delayStart)
	if err != nil {
		parsedDelay = 0
	}
	sendLog(fmt.Sprintf("DELAY START %v  , second", delayStart))
	time.Sleep(time.Duration(parsedDelay) * time.Second)

	for _, env := range os.Environ() {
		sendLog(env)
	}
	http.HandleFunc("/", requestHandler)
	go metricsHandler()
	sendLog(fmt.Sprintf("enableLoadCpu: %v, cpuMaxProc: %d", enableLoadCpu, cpuMaxProc))
	runtime.GOMAXPROCS(cpuMaxProc)
	if enableLoadMemory == "true" {
		go memoryUsage()
	}
	if enableLoadCpu == "true" {
		go cpuUsage()
	}
	http.HandleFunc("/ping-pong-api/getVar", getVarHandler)
	http.HandleFunc("/ping-pong-api/getMetric", getMetricHandler)
	http.HandleFunc("/ping-pong-api/setVar", setVarHandler)
	port := os.Getenv("SRV_PORT")
	if port == "" {
		sendLog("SRV_PORT is not set, default port :  8080")
		port = "8080"
	}

	err = http.ListenAndServe(":"+port, nil)
	if err != nil {
		sendLog(fmt.Sprintf("Server failed: %v", err))
	}
}
