package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

var (
	serverPort     string
	backendURL     string
	enableOutput   string
	backendTimeout time.Duration
)

func init() {
	serverPort = os.Getenv("SRV_PORT")
	if serverPort == "" {
		serverPort = "8080"
	}

	backendURL = os.Getenv("BACKEND_URL")
	if backendURL == "" {
		backendURL = "http://localhost:8081"
	}
	// trim trailing slash
	backendURL = strings.TrimRight(backendURL, "/")

	enableOutput = os.Getenv("ENABLE_OUTPUT")
	if enableOutput == "" {
		enableOutput = "true"
	}

	backendTimeoutStr := os.Getenv("BACKEND_TIMEOUT")
	if backendTimeoutStr == "" {
		backendTimeoutStr = "5s"
	}
	var err error
	backendTimeout, err = time.ParseDuration(backendTimeoutStr)
	if err != nil {
		fmt.Printf("invalid BACKEND_TIMEOUT %q, using 5s\n", backendTimeoutStr)
		backendTimeout = 5 * time.Second
	}
}

func sendLog(msg string) {
	if enableOutput == "true" {
		fmt.Println(msg)
	}
}

func proxyHandler(w http.ResponseWriter, r *http.Request) {
	// Build target URL: backend + original path + query
	targetURL := backendURL + r.URL.RequestURI()

	// Read original body
	bodyBytes, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, fmt.Sprintf("failed to read request body: %v", err), http.StatusInternalServerError)
		return
	}
	defer r.Body.Close()

	// Pass nil body for methods that don't have a body (GET, HEAD, DELETE, etc.)
	var reqBody io.Reader
	if len(bodyBytes) > 0 {
		reqBody = strings.NewReader(string(bodyBytes))
	}

	// Create upstream request
	req, err := http.NewRequest(r.Method, targetURL, reqBody)
	if err != nil {
		http.Error(w, fmt.Sprintf("failed to create upstream request: %v", err), http.StatusInternalServerError)
		return
	}

	// Copy all headers from original request
	for name, values := range r.Header {
		for _, v := range values {
			req.Header.Add(name, v)
		}
	}

	// Forward real client IP
	req.Header.Set("X-Forwarded-For", r.RemoteAddr)
	req.Header.Set("X-Original-Method", r.Method)

	client := &http.Client{Timeout: backendTimeout}

	start := time.Now()
	resp, err := client.Do(req)
	elapsed := time.Since(start)

	if err != nil {
		http.Error(w, fmt.Sprintf("backend error: %v", err), http.StatusBadGateway)
		sendLog(fmt.Sprintf("ERROR backend=%s elapsed=%s err=%v", targetURL, elapsed, err))
		return
	}
	defer resp.Body.Close()

	// Read backend response body
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		http.Error(w, fmt.Sprintf("failed to read backend response: %v", err), http.StatusInternalServerError)
		return
	}

	// Copy backend response headers to client
	for name, values := range resp.Header {
		for _, v := range values {
			w.Header().Add(name, v)
		}
	}

	// Add proxy meta headers
	w.Header().Set("X-Backend-Status-Code", fmt.Sprintf("%d", resp.StatusCode))
	w.Header().Set("X-Backend-Response-Time", elapsed.String())

	// Write status code from backend
	w.WriteHeader(resp.StatusCode)

	// Build response: proxy info block + backend body
	var out strings.Builder
	out.WriteString(fmt.Sprintf("--- Proxy Info ---\n"))
	out.WriteString(fmt.Sprintf("Backend URL      : %s\n", targetURL))
	out.WriteString(fmt.Sprintf("Backend Status   : %d\n", resp.StatusCode))
	out.WriteString(fmt.Sprintf("Backend Response Time: %s\n", elapsed))
	out.WriteString(fmt.Sprintf("--- Backend Response ---\n"))
	out.Write(respBody)

	fmt.Fprint(w, out.String())

	sendLog(fmt.Sprintf("proxied method=%s url=%s backend_status=%d elapsed=%s",
		r.Method, targetURL, resp.StatusCode, elapsed))
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprint(w, "ok")
}

func main() {
	sendLog(fmt.Sprintf("ping_pong_front starting on port %s, backend=%s", serverPort, backendURL))

	http.HandleFunc("/healthz", healthHandler)
	http.HandleFunc("/", proxyHandler)

	if err := http.ListenAndServe(":"+serverPort, nil); err != nil {
		sendLog(fmt.Sprintf("server failed: %v", err))
		os.Exit(1)
	}
}
