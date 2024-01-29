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
	"strconv"
	"math/rand"

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
	requestsPerSecond float64
	requestsPerMinute float64
	lastRequestTime   time.Time
	requestsCount     uint64
	serverName        string
	logPath       string
	enableOutput  string
    enableLoadCpu string
    enableLoadMemory string
    enableLogLoadMemory string
    memoryProfiles []MemoryUsageProfile
    cpuProfiles []CpuUsageProfile
//    memoryUsageIncreaseStepsWait int
//    memoryUsageIncreaseLoopWait int
//    cpuMaxProc int
//    cpuPiIterations int

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
	enableLogLoadMemory = os.Getenv("ENABLE_LOG_LOAD_MEMORY")
	if enableLogLoadMemory == "" {
		enableLogLoadMemory = "false"
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


}
func cpuUsage () {

    cpuProfileStr := os.Getenv("CPU_USAGE_PROFILE")
    sendLog(" *** cpu load enable ")
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
        fmt.Printf("IterationsMillion: %d, WaitMilliseconds: %d, Goroutines: %d, TimeSeconds: %d\n",
            profile.IterationsMillion, profile.WaitMilliseconds, profile.Goroutines, profile.TimeSeconds)
             go cpuLoad(profile.IterationsMillion, profile.WaitMilliseconds, profile.TimeSeconds)
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

func memoryUsage () {
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
           sendLog(fmt.Sprintf("Megabytes: %d, Seconds: %d\n", profile.Megabytes, profile.Seconds))
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
	sendLog(fmt.Sprintf("enableLoadCpu: %v", enableLoadCpu))
	if enableLoadMemory == "true" { go memoryUsage() }
	if enableLoadCpu == "true" { go cpuUsage() }
	port := os.Getenv("SRV_PORT")
	if port == "" {
		sendLog("SRV_PORT is not set, default port :  8080")
		port = "8080"
	}

	err := http.ListenAndServe(":" + port, nil)
	if err != nil {
		sendLog(fmt.Sprintf("Server failed: %v", err))
	}
}
