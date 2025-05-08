package main

import (
	"encoding/json"
	"fmt"
	"io"
	"math"
	"math/rand"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"github.com/klauspost/cpuid/v2"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/host"
	"github.com/shirou/gopsutil/v3/mem"
	"github.com/shirou/gopsutil/v3/process"
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
	requestsPerSecond      float64
	requestsPerMinute      float64
	lastRequestTime        time.Time
	requestsCount          uint64
	serverName             string
	serverPort             string
	metricPort             string
	hostName               string
	logPath                string
	enableOutput           string
	enableLoadCpu          string
	enableLoadMemory       string
	memoryProfileStr       string
	memoryProfiles         []MemoryUsageProfile
	enableLogLoadMemory    string
	enableLogLoadCpu       string
	delayStart             string
	enableDefaultHostName  string
	cpuProfiles            []CpuUsageProfile
	cpuProfileStr          string
	cpuMaxProc             int
	parsedDelay            int
	responseDelay          int // in milliseconds
	maxResponseWorker      int
	ResponseWorker         uint64
	additionalResponseSize uint64
	randomBytes            []byte
)

func init() {
	var err error

	hostName = os.Getenv("HOSTNAME")

	enableDefaultHostName = os.Getenv("ENABLE_DEFAULT_HOSTNAME")
	if enableDefaultHostName == "" {
		enableDefaultHostName = "true"
	}

	delayStart = os.Getenv("DELAY_START")
	if delayStart == "" {
		delayStart = "0"
	}
	responseDelayStr := os.Getenv("RESPONSE_DELAY")
	if responseDelayStr == "" {
		responseDelayStr = "0"
	}
	responseDelay, err = strconv.Atoi(responseDelayStr)

	maxResponseWorkerStr := os.Getenv("MAX_RESPONSE_WORKER")
	if maxResponseWorkerStr == "" {
		maxResponseWorkerStr = "65535"
	}
	maxResponseWorker, err = strconv.Atoi(maxResponseWorkerStr)

	additionalResponseSizeStr := os.Getenv("ADDITIONAL_RESPONSE_SIZE")
	if additionalResponseSizeStr == "" {
		additionalResponseSizeStr = "0"
	}
	additionalResponseSize, err = strconv.ParseUint(additionalResponseSizeStr, 10, 64)

	parsedDelay, err = strconv.Atoi(delayStart)
	if err != nil {
		parsedDelay = 0
	}

	if hostName == "" || enableDefaultHostName == "true" {
		hostName = "ping_pong_server"
	}

	serverName = os.Getenv("SERVER_NAME")
	if serverName == "" {
		serverName = hostName
	}
	serverPort = os.Getenv("SRV_PORT")
	if serverPort == "" {
		serverPort = "8080"
	}
	metricPort = os.Getenv("METRIC_PORT")
	if metricPort == "" {
		metricPort = "9090"
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

	memoryProfileStr = os.Getenv("MEMORY_USAGE_PROFILE")
	if memoryProfileStr == "" {
		memoryProfileStr = "1=10 2=30"
	}

	enableLogLoadCpu = os.Getenv("ENABLE_LOG_LOAD_CPU")
	if enableLogLoadCpu == "" {
		enableLogLoadCpu = "false"
	}
	cpuProfileStr = os.Getenv("CPU_USAGE_PROFILE")
	if cpuProfileStr == "" {
		cpuProfileStr = "10=1=1=30"
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
	// init
	runtime.GOMAXPROCS(cpuMaxProc)
}
func cpuUsage() {
	var enableLoadCpuOld string
	var cpuProfileStrOld string
	for {
		if enableLoadCpuOld != enableLoadCpu {
			sendLog("enableLoadCpu  changed =>  " + enableLoadCpu)
			enableLoadCpuOld = enableLoadCpu
		}
		if cpuProfileStrOld != cpuProfileStr {
			sendLog("cpuProfileStr  changed =>  " + cpuProfileStr)
			cpuProfileStrOld = cpuProfileStr
		}

		if enableLoadCpu == "true" {
			sendLog(fmt.Sprintf("enableLoadCpu: %v, cpuMaxProc: %d", enableLoadCpu, cpuMaxProc))
			profiles := strings.Split(cpuProfileStr, " ")
			var tempProfiles []CpuUsageProfile
			for _, p := range profiles {
				if enableLoadCpu != "true" {
					break
				}
				parts := strings.Split(p, "=")
				if len(parts) == 4 {
					iterationsMillion, err1 := strconv.Atoi(parts[0])
					waitMilliseconds, err2 := strconv.Atoi(parts[1])
					goroutines, err3 := strconv.Atoi(parts[2])
					timeSeconds, err4 := strconv.Atoi(parts[3])

					if err1 == nil && err2 == nil && err3 == nil && err4 == nil {
						tempProfiles = append(tempProfiles, CpuUsageProfile{
							IterationsMillion: iterationsMillion,
							WaitMilliseconds:  waitMilliseconds,
							Goroutines:        goroutines,
							TimeSeconds:       timeSeconds,
						})
					}
				}
			}

			for _, profile := range tempProfiles {
				if enableLogLoadCpu == "true" {
					sendLog(fmt.Sprintf("LoadCpu => IterationsMillion: %d, WaitMilliseconds: %d, Goroutines: %d, TimeSeconds: %d, cpuMaxProc: %d\n",
						profile.IterationsMillion, profile.WaitMilliseconds, profile.Goroutines, profile.TimeSeconds, cpuMaxProc))
				}

				for i := 0; i < profile.Goroutines && enableLoadCpu == "true"; i++ {
					if enableLoadCpu != "true" {
						break
					}
					go cpuLoad(profile.IterationsMillion, profile.WaitMilliseconds, profile.TimeSeconds)
				}
				time.Sleep(time.Duration(profile.TimeSeconds) * time.Second)
			}
		} else {
			time.Sleep(1 * time.Second)
		}
	}
}

func cpuLoad(iterationsMillion int, waitMilliseconds int, timeSeconds int) {
	totalIterations := iterationsMillion * 1000000
	var sum int

	deadline := time.Now().Add(time.Duration(timeSeconds) * time.Second)

	for time.Now().Before(deadline) && enableLoadCpu == "true" {
		if enableLoadCpu != "true" {
			break
		}
		for i := 0; i < totalIterations && enableLoadCpu == "true"; i++ {
			sum += rand.Intn(256)
			if enableLoadCpu != "true" {
				break
			}
		}

		if time.Now().Add(time.Duration(waitMilliseconds) * time.Millisecond).Before(deadline) {
			time.Sleep(time.Duration(waitMilliseconds) * time.Millisecond)
		}
	}
}

func memoryUsage() {
	var enableLoadMemoryOld string
	var memoryProfileStrOld string
	for {
		memoryProfiles = nil
		if enableLoadMemoryOld != enableLoadMemory {
			sendLog("enableLoadMemory  changed =>  " + enableLoadMemory)
			enableLoadMemoryOld = enableLoadMemory
		}
		if memoryProfileStrOld != memoryProfileStr {
			sendLog("memoryProfileStr  changed =>  " + memoryProfileStr)
			memoryProfileStrOld = memoryProfileStr
		}

		if enableLoadMemory == "true" {

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
				memoryLoad(profile.Megabytes*1024*1024, profile.Seconds)
				runtime.GC()

			}

		} else {
			time.Sleep(1 * time.Second)
		}

	}
}

func memoryLoad(size int, sec int) {
	slice := make([]byte, size)
	for i := range slice {
		slice[i] = 0xFF
	}
	for i := 0; i < sec; i++ {
		if enableLoadMemory != "true" {
			break
		}
		time.Sleep(1 * time.Second)
	}
}

func requestHandler(w http.ResponseWriter, r *http.Request) {
	var response strings.Builder
	var totalSize int
	var bodySize int

	if atomic.LoadUint64(&ResponseWorker) >= uint64(maxResponseWorker) {
		w.WriteHeader(http.StatusServiceUnavailable)
		fmt.Fprintf(w, "Server is overloaded. Current workers: %d, Max allowed: %d\n", ResponseWorker, maxResponseWorker)
		return
	}
	atomic.AddUint64(&ResponseWorker, 1)
	defer atomic.AddUint64(&ResponseWorker, ^uint64(0))
	if responseDelay > 0 {
		time.Sleep(time.Duration(responseDelay) * time.Millisecond)
	}
	response.WriteString(fmt.Sprintf("Server Name: %s\n", serverName))
	response.WriteString(fmt.Sprintf("URL: http://%s%s\n", r.Host, r.URL.String()))
	response.WriteString(fmt.Sprintf("Client IP: %s\n", getIP(r)))
	response.WriteString(fmt.Sprintf("Method: %s\n", r.Method))
	response.WriteString(fmt.Sprintf("Protocol: %s\n", r.Proto))
	response.WriteString(fmt.Sprintf("responseDelay: %s\n", strconv.Itoa(responseDelay)))
	response.WriteString(fmt.Sprintf("maxResponseWorker: %s\n", strconv.Itoa(maxResponseWorker)))
	response.WriteString(fmt.Sprintf("ResponseWorker: %d\n", ResponseWorker))
	response.WriteString(fmt.Sprintf("additionalResponseSize: %d Kb \n", additionalResponseSize))
	response.WriteString(fmt.Sprintf("--------------- \n"))
	response.WriteString(fmt.Sprintf(" \n"))
	response.WriteString("Headers:\n")
	response.WriteString(fmt.Sprintf(" \n"))

	for name, headers := range r.Header {
		for _, h := range headers {
			response.WriteString(fmt.Sprintf("%v: %v\n", name, h))
		}
	}

	response.WriteString(fmt.Sprintf("--------------- \n"))
	response.WriteString(fmt.Sprintf(" \n"))
	response.WriteString("Headers size : \n")
	response.WriteString(fmt.Sprintf(" \n"))
	for name, headers := range r.Header {
		for _, h := range headers {
			totalSize += len(h)
			response.WriteString(fmt.Sprintf("%v:  %d byte  \n", name, len(h)))
		}
	}
	response.WriteString(fmt.Sprintf("--------------- \n"))
	response.WriteString(fmt.Sprintf("total size of headers: %d byte  \n", totalSize))
	response.WriteString(fmt.Sprintf("--------------- \n"))

	if r.Method == http.MethodPost || r.Method == http.MethodPut {
		body, err := io.ReadAll(r.Body)
		if err == nil {
			response.WriteString("Request Body:\n")
			response.Write(body)
			response.WriteString(fmt.Sprintf("\n--------------- \n"))
			response.WriteString(fmt.Sprintf("size of Body : %d byte \n", len(body)))
		} else {
			response.WriteString(fmt.Sprintf("Failed to read request body: %v\n", err))
		}
	}

	if r.Body != nil {
		bodyBytes, err := io.ReadAll(r.Body)
		if err == nil {
			bodySize = len(bodyBytes)
		}
	}

	requestLine := fmt.Sprintf("%s %s %s\r\n", r.Method, r.RequestURI, r.Proto)
	requestLineSize := len(requestLine)
	blankLineSize := len("\r\n")
	totalSizeRaw := requestLineSize + totalSize + blankLineSize + bodySize
	response.WriteString(fmt.Sprintf("total request size  : %d byte \n", totalSizeRaw))

	for i := uint64(0); i < additionalResponseSize; i++ {
		block := strings.Repeat("*", 1024)
		htmlBlock := fmt.Sprintf("%s", block)
		response.WriteString(htmlBlock)
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
		"serverName":             serverName,
		"hostName":               hostName,
		"logPath":                logPath,
		"enableOutput":           enableOutput,
		"enableLoadCpu":          enableLoadCpu,
		"enableLoadMemory":       enableLoadMemory,
		"enableLogLoadMemory":    enableLogLoadMemory,
		"enableLogLoadCpu":       enableLogLoadCpu,
		"delayStart":             parsedDelay,
		"enableDefaultHostName":  enableDefaultHostName,
		"cpuMaxProc":             cpuMaxProc,
		"memoryProfileStr":       memoryProfileStr,
		"cpuProfileStr":          cpuProfileStr,
		"responseDelay":          responseDelay,
		"maxResponseWorker":      maxResponseWorker,
		"ResponseWorker":         ResponseWorker,
		"additionalResponseSize": additionalResponseSize,
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

func panicHandler(w http.ResponseWriter, r *http.Request) {
	defer func() {
		if err := recover(); err != nil {
			fmt.Println("Panic occurred:", err)
			os.Exit(1)
		}
	}()
	panic("Test panic")
}

func setVarHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
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
	// cpuProfileStr
	if val, ok := updates["cpuProfileStr"]; ok {
		if s, ok := val.(string); ok && s != cpuProfileStr {
			changes["cpuProfileStr"] = map[string]string{"old": cpuProfileStr, "new": s}
			cpuProfileStr = s
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
	// memoryProfileStr
	if val, ok := updates["memoryProfileStr"]; ok {
		if s, ok := val.(string); ok && s != memoryProfileStr {
			changes["memoryProfileStr"] = map[string]string{"old": memoryProfileStr, "new": s}
			memoryProfileStr = s
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

	// enableDefaultHostName
	if val, ok := updates["enableDefaultHostName"]; ok {
		if s, ok := val.(string); ok && s != enableDefaultHostName {
			changes["enableDefaultHostName"] = map[string]string{"old": enableDefaultHostName, "new": s}
			enableDefaultHostName = s
			changed = true
		}
	}

	// responseDelay
	if val, ok := updates["responseDelay"]; ok {
		switch v := val.(type) {
		case float64:
			intVal := int(v)
			if intVal != responseDelay {
				changes["responseDelay"] = map[string]string{
					"old": strconv.Itoa(responseDelay),
					"new": strconv.Itoa(intVal),
				}
				responseDelay = intVal
				changed = true
			}
		case string:
			intVal, err := strconv.Atoi(v)
			if err == nil && intVal != responseDelay {
				changes["responseDelay"] = map[string]string{
					"old": strconv.Itoa(responseDelay),
					"new": v,
				}
				responseDelay = intVal
				changed = true
			}
		}
	}

	// maxResponseWorker
	if val, ok := updates["maxResponseWorker"]; ok {
		switch v := val.(type) {
		case float64:
			intVal := int(v)
			if intVal != maxResponseWorker {
				changes["maxResponseWorker"] = map[string]string{
					"old": strconv.Itoa(maxResponseWorker),
					"new": strconv.Itoa(intVal),
				}
				maxResponseWorker = intVal
				changed = true
			}
		case string:
			intVal, err := strconv.Atoi(v)
			if err == nil && intVal != maxResponseWorker {
				changes["maxResponseWorker"] = map[string]string{
					"old": strconv.Itoa(maxResponseWorker),
					"new": v,
				}
				maxResponseWorker = intVal
				changed = true
			}
		}
	}

	// additionalResponseSize
	if val, ok := updates["additionalResponseSize"]; ok {
		switch v := val.(type) {
		case float64:
			// Convert float64 to uint64
			newSize := uint64(v)
			if newSize != additionalResponseSize {
				changes["additionalResponseSize"] = map[string]string{
					"old": strconv.FormatUint(additionalResponseSize, 10),
					"new": strconv.FormatUint(newSize, 10),
				}
				additionalResponseSize = newSize
				changed = true
			}

		case string:
			// Parse string directly into uint64
			parsed, err := strconv.ParseUint(v, 10, 64)
			if err == nil && parsed != additionalResponseSize {
				changes["additionalResponseSize"] = map[string]string{
					"old": strconv.FormatUint(additionalResponseSize, 10),
					"new": v,
				}
				additionalResponseSize = parsed
				changed = true
			}
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
		runtime.GOMAXPROCS(cpuMaxProc)
	}

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

// roundToOneDecimal rounds a float to 1 decimal place
func roundToOneDecimal(value float64) float64 {
	return math.Round(value*10) / 10
}

func roundFloat(value float64, precision int) float64 {
	multiplier := math.Pow(10, float64(precision))
	return math.Round(value*multiplier) / multiplier
}

func getTopProcesses() (topCPU, topMemory []map[string]interface{}) {
	processes, err := process.Processes()
	if err != nil {
		fmt.Println("Error retrieving processes:", err)
		return nil, nil
	}

	var cpuList, memList []map[string]interface{}

	for _, p := range processes {
		name, err := p.Name()
		if err != nil {
			continue // Skip process if we can't retrieve its name
		}

		cpuPercent, err := p.CPUPercent()
		if err != nil {
			continue // Skip process if we can't retrieve CPU usage
		}

		memInfo, err := p.MemoryInfo()
		if err != nil || memInfo == nil {
			continue // Skip process if memory info is not available
		}

		cpuList = append(cpuList, map[string]interface{}{
			"name":      name,
			"cpu_usage": roundFloat(cpuPercent, 1),
			"unit":      "percentage",
		})

		memList = append(memList, map[string]interface{}{
			"name":         name,
			"memory_usage": roundFloat(float64(memInfo.RSS)/1024/1024, 1),
			"unit":         "MB",
		})
	}

	// Sort by highest CPU and memory usage
	sort.Slice(cpuList, func(i, j int) bool {
		return cpuList[i]["cpu_usage"].(float64) > cpuList[j]["cpu_usage"].(float64)
	})
	sort.Slice(memList, func(i, j int) bool {
		return memList[i]["memory_usage"].(float64) > memList[j]["memory_usage"].(float64)
	})

	// Keep only top 5 processes
	if len(cpuList) > 5 {
		cpuList = cpuList[:5]
	}
	if len(memList) > 5 {
		memList = memList[:5]
	}

	return cpuList, memList
}

// getNetworkInterfaces retrieves details of available network interfaces and returns a map with interface names as keys
func getNetworkInterfaces() map[string]map[string]interface{} {
	interfaces, _ := net.Interfaces() // Uses Go's standard net package
	networkInfo := make(map[string]map[string]interface{})

	for _, iface := range interfaces {
		ipv4 := []string{}
		ipv6 := []string{}

		// Retrieve IP addresses
		addrs, err := iface.Addrs()
		if err == nil {
			for _, addr := range addrs {
				ip, _, err := net.ParseCIDR(addr.String())
				if err != nil {
					continue
				}
				if ip.To4() != nil {
					ipv4 = append(ipv4, ip.String()) // Store IPv4 addresses
				} else {
					ipv6 = append(ipv6, ip.String()) // Store IPv6 addresses
				}
			}
		}

		// Store data in a map where the key is the interface name
		networkInfo[iface.Name] = map[string]interface{}{
			"mac_address": iface.HardwareAddr.String(), // MAC address
			"status":      iface.Flags.String(),        // Interface status
			"ipv4":        ipv4,                        // List of IPv4 addresses
			"ipv6":        ipv6,                        // List of IPv6 addresses
		}
	}

	return networkInfo
}

// getGPUInfo retrieves details about available GPUs using CPU and system info
func getGPUInfo() []map[string]interface{} {
	gpuList := []map[string]interface{}{}

	// Try to get GPU information from CPU Vendor (for integrated GPUs)
	if cpuid.CPU.VendorString != "" {
		gpuList = append(gpuList, map[string]interface{}{
			"name":   "Integrated GPU",
			"vendor": cpuid.CPU.VendorString,
			"memory": "N/A",
		})
	}

	// If there is no detected GPU, provide a fallback
	if len(gpuList) == 0 {
		gpuList = append(gpuList, map[string]interface{}{
			"name":   "Unknown GPU",
			"vendor": "Unknown Vendor",
			"memory": "N/A",
		})
	}

	return gpuList
}

func osInfoHandler(w http.ResponseWriter, r *http.Request) {
	// Get CPU information
	cpuUsage, _ := cpu.Percent(0, false)
	cpuPerCore, _ := cpu.Percent(0, true)

	// Get memory information
	memStats, _ := mem.VirtualMemory()

	// Get OS version
	hostInfo, _ := host.Info()

	// Get Go runtime information
	goInfo := map[string]interface{}{
		"version":       runtime.Version(),
		"gomaxprocs":    runtime.GOMAXPROCS(0),
		"num_goroutine": runtime.NumGoroutine(),
		"num_cpu":       runtime.NumCPU(),
	}

	// Get architecture details
	archInfo := map[string]interface{}{
		"architecture": runtime.GOARCH,
		"goamd64":      os.Getenv("GOAMD64"),
		"goarm":        os.Getenv("GOARM"),
	}

	// Get disk partitions (logical disks)
	partitions, _ := disk.Partitions(false)
	logicalDisks := []map[string]interface{}{}

	for _, p := range partitions {
		usage, err := disk.Usage(p.Mountpoint)
		if err == nil {
			logicalDisks = append(logicalDisks, map[string]interface{}{
				"device": p.Device,
				"mount":  p.Mountpoint,
				"total": map[string]interface{}{
					"value": usage.Total / 1024 / 1024 / 1024,
					"unit":  "GB",
				},
				"used": map[string]interface{}{
					"value": usage.Used / 1024 / 1024 / 1024,
					"unit":  "GB",
				},
				"free": map[string]interface{}{
					"value": usage.Free / 1024 / 1024 / 1024,
					"unit":  "GB",
				},
				"usage": map[string]interface{}{
					"value": roundFloat(usage.UsedPercent, 1),
					"unit":  "percentage",
				},
			})
		}
	}

	// Get physical disk I/O statistics
	physicalDisks, _ := disk.IOCounters()
	physicalDiskInfo := []map[string]interface{}{}

	for name, stats := range physicalDisks {
		physicalDiskInfo = append(physicalDiskInfo, map[string]interface{}{
			"name":        name,
			"read_bytes":  stats.ReadBytes,
			"write_bytes": stats.WriteBytes,
			"read_count":  stats.ReadCount,
			"write_count": stats.WriteCount,
		})
	}

	// Get top processes
	topCPU, topMemory := getTopProcesses()

	// Get network interfaces
	networkInfo := getNetworkInterfaces()

	// Get GPU info
	gpuInfo := getGPUInfo()

	// Prepare CPU core usage details
	cpuCores := []map[string]interface{}{}
	for i, usage := range cpuPerCore {
		cpuCores = append(cpuCores, map[string]interface{}{
			"core":  i + 1,
			"usage": roundFloat(usage, 1),
			"unit":  "percentage",
		})
	}

	// Prepare JSON response
	info := map[string]interface{}{
		"os": map[string]interface{}{
			"name":    runtime.GOOS,
			"version": hostInfo.PlatformVersion,
		},
		"cpu": map[string]interface{}{
			"usage_total": map[string]interface{}{
				"value": roundFloat(cpuUsage[0], 1),
				"unit":  "percentage",
			},
			"cores": cpuCores,
		},
		"memory": map[string]interface{}{
			"total": map[string]interface{}{
				"value": memStats.Total / 1024 / 1024,
				"unit":  "MB",
			},
			"used": map[string]interface{}{
				"value": memStats.Used / 1024 / 1024,
				"unit":  "MB",
			},
			"free": map[string]interface{}{
				"value": memStats.Available / 1024 / 1024,
				"unit":  "MB",
			},
		},
		"architecture":   archInfo,
		"network":        networkInfo,
		"logical_disks":  logicalDisks,
		"physical_disks": physicalDiskInfo,
		"top_processes": map[string]interface{}{
			"cpu":    topCPU,
			"memory": topMemory,
		},
		"go":  goInfo,
		"gpu": gpuInfo,
	}

	// Send response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(info)
}

func main() {
	var err error

	sendLog(fmt.Sprintf("DELAY START %v  , second", parsedDelay))
	time.Sleep(time.Duration(parsedDelay) * time.Second)

	sendLog("path: /metrics start metrics on port: " + metricPort)

	go metricsHandler()
	go memoryUsage()
	go cpuUsage()

	http.HandleFunc("/", requestHandler)
	http.HandleFunc("/ping-pong-api/getVar", getVarHandler)
	http.HandleFunc("/ping-pong-api/getMetric", getMetricHandler)
	http.HandleFunc("/ping-pong-api/setVar", setVarHandler)
	http.HandleFunc("/ping-pong-api/panic", panicHandler)
	http.HandleFunc("/ping-pong-api/osInfo", osInfoHandler)
	sendLog("additionalResponseSize: " + strconv.FormatUint(additionalResponseSize, 10))
	sendLog("start server on port: " + serverPort)

	err = http.ListenAndServe(":"+serverPort, nil)
	if err != nil {
		sendLog(fmt.Sprintf("Server failed: %v", err))
	}

}
