package main

import (
	"encoding/json"
	"log"
	"math/rand"
	"net/http"
	"os"
	"time"
)

type Response struct {
	PodName     string `json:"pod_name"`
	Version     string `json:"version"`
	Namespace   string `json:"namespace"`
	SpaceObject string `json:"space_object,omitempty"`
}

var blackholeCounter int

func invincibleHandler(w http.ResponseWriter, r *http.Request) {
	log.Printf("[%s] %s %s from %s", os.Getenv("VERSION"), r.Method, r.URL.Path, r.RemoteAddr)

	// 50% chance of 5 second delay
	if rand.Intn(100) < 50 {
		log.Println("Invincible: Simulating slow response (5s delay)")
		time.Sleep(5 * time.Second)
	}

	podName := os.Getenv("POD_NAME")
	version := os.Getenv("VERSION")
	namespace := os.Getenv("NAMESPACE")

	if version == "" {
		version = "unknown"
	}
	if podName == "" {
		podName = "unknown"
	}
	if namespace == "" {
		namespace = "unknown"
	}

	response := Response{
		PodName:     podName,
		Version:     version,
		Namespace:   namespace,
		SpaceObject: "Invincible",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func blackholeHandler(w http.ResponseWriter, r *http.Request) {
	log.Printf("[%s] %s %s from %s", os.Getenv("VERSION"), r.Method, r.URL.Path, r.RemoteAddr)

	blackholeCounter++

	// Return 500 for first 2 requests
	if blackholeCounter <= 2 {
		w.WriteHeader(http.StatusInternalServerError)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"error":   "Internal Server Error",
			"message": "Blackhole encountered",
			"attempt": blackholeCounter,
		})
		return
	}

	// After 2 failures, return success
	podName := os.Getenv("POD_NAME")
	version := os.Getenv("VERSION")
	namespace := os.Getenv("NAMESPACE")

	if version == "" {
		version = "unknown"
	}
	if podName == "" {
		podName = "unknown"
	}
	if namespace == "" {
		namespace = "unknown"
	}

	response := Response{
		PodName:     podName,
		Version:     version,
		Namespace:   namespace,
		SpaceObject: "Gargantua",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func normandyHandler(w http.ResponseWriter, r *http.Request) {
	log.Printf("[%s] %s %s from %s", os.Getenv("VERSION"), r.Method, r.URL.Path, r.RemoteAddr)

	version := os.Getenv("VERSION")

	// v1 with commander: shepard header
	if version == "v1" && r.Header.Get("commander") == "shepard" {
		w.Header().Set("Content-Type", "text/plain")
		w.Write([]byte("welcome aboard capitan"))
		return
	}
	if version == "v1" {
		w.Header().Set("Content-Type", "text/plain")
		w.Write([]byte("Normandy SR1"))
		return
	}

	// v2 always returns text
	if version == "v2" {
		w.Header().Set("Content-Type", "text/plain")
		w.Write([]byte("Normandy SR2"))
		return
	}

	// v1 without header - Normal JSON response
	podName := os.Getenv("POD_NAME")
	namespace := os.Getenv("NAMESPACE")

	if version == "" {
		version = "unknown"
	}
	if podName == "" {
		podName = "unknown"
	}
	if namespace == "" {
		namespace = "unknown"
	}

	response := Response{
		PodName:     podName,
		Version:     version,
		Namespace:   namespace,
		SpaceObject: "Normandy",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	log.Printf("[%s] %s %s from %s", os.Getenv("VERSION"), r.Method, r.URL.Path, r.RemoteAddr)

	podName := os.Getenv("POD_NAME")
	version := os.Getenv("VERSION")
	namespace := os.Getenv("NAMESPACE")

	if version == "" {
		version = "unknown"
	}
	if podName == "" {
		podName = "unknown"
	}
	if namespace == "" {
		namespace = "unknown"
	}

	// Determine space object from path
	spaceObject := ""
	switch r.URL.Path {
	case "/pluto":
		spaceObject = "Pluto"
	case "/moon":
		spaceObject = "Moon"
	case "/mars":
		spaceObject = "Mars"
	}

	response := Response{
		PodName:     podName,
		Version:     version,
		Namespace:   namespace,
		SpaceObject: spaceObject,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func main() {
	// Seed random number generator
	rand.Seed(time.Now().UnixNano())

	http.HandleFunc("/", healthHandler)
	http.HandleFunc("/pluto", healthHandler)
	http.HandleFunc("/moon", healthHandler)
	http.HandleFunc("/mars", healthHandler)
	http.HandleFunc("/blackhole", blackholeHandler)
	http.HandleFunc("/invincible", invincibleHandler)
	http.HandleFunc("/normandy", normandyHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Starting server on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}
