// helpers_test.go
package main

import (
 "testing"

 "github.com/stretchr/testify/assert"
 corev1 "k8s.io/api/core/v1"

)

func TestReadyIPs(t *testing.T) {
 tests := []struct {
  name     string
  input    *corev1.Endpoints
  expected []string
 }{
  {
   name: "multiple ready IPs",
   input: &corev1.Endpoints{
    Subsets: []corev1.EndpointSubset{
     {
      Addresses: []corev1.EndpointAddress{
       {IP: "10.0.0.1"},
       {IP: "10.0.0.2"},
      },
     },
    },
   },
   expected: []string{"10.0.0.1", "10.0.0.2"},
  },
  {
   name: "empty endpoints",
   input: &corev1.Endpoints{
    Subsets: []corev1.EndpointSubset{},
   },
   expected: []string{},
  },
 }

 for _, tt := range tests {
  t.Run(tt.name, func(t *testing.T) {
   result := readyIPs(tt.input)
   assert.Equal(t, tt.expected, result)
  })
 }
}

func TestSameIPs(t *testing.T) {
 tests := []struct {
  name     string
  eps      *corev1.Endpoints
  ips      []string
  expected bool
 }{
  {
   name: "same IPs",
   eps: &corev1.Endpoints{
    Subsets: []corev1.EndpointSubset{
     {
      Addresses: []corev1.EndpointAddress{
       {IP: "10.0.0.1"},
       {IP: "10.0.0.2"},
      },
     },
    },
   },
   ips:      []string{"10.0.0.1", "10.0.0.2"},
   expected: true,
  },
  {
   name: "different IPs",
   eps: &corev1.Endpoints{
    Subsets: []corev1.EndpointSubset{
     {
      Addresses: []corev1.EndpointAddress{
       {IP: "10.0.0.1"},
      },
     },
    },
   },
   ips:      []string{"10.0.0.2"},
   expected: false,
  },
 }

 for _, tt := range tests {
  t.Run(tt.name, func(t *testing.T) {
   result := sameIPs(tt.eps, tt.ips)
   assert.Equal(t, tt.expected, result)
  })
 }
}

func TestServiceTracking(t *testing.T) {
 // Clear state before test
 syncMutex.Lock()
 syncedServices = make(map[string]bool)
 syncMutex.Unlock()

 // Test adding service to tracking
 setSyncedService("test-service", true)
 assert.True(t, isServiceSynced("test-service"))
 assert.False(t, isServiceSynced("non-existent"))

 // Test getting list of synced services
 setSyncedService("service-1", true)
 setSyncedService("service-2", true)

 services := getSyncedServicesList()
 assert.Len(t, services, 3)
 assert.Contains(t, services, "test-service")
 assert.Contains(t, services, "service-1")
 assert.Contains(t, services, "service-2")

 // Test removing service from tracking
 setSyncedService("service-1", false)
 assert.False(t, isServiceSynced("service-1"))

 services = getSyncedServicesList()
 assert.Len(t, services, 2)
 assert.NotContains(t, services, "service-1")
}

func TestLeaderStatus(t *testing.T) {
 // Test setting leader status
 setLeaderStatus(true)
 assert.True(t, getLeaderStatus())

 setLeaderStatus(false)
 assert.False(t, getLeaderStatus())
}