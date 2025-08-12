package main

import (
	"context"
	"strconv"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes/fake"
)

func BenchmarkSyncService(b *testing.B) {
	ctx := context.Background()
	srcClient := fake.NewSimpleClientset()
	dstClient := fake.NewSimpleClientset()

	*srcNS = "test-src"
	*dstNS = "test-dst"

	// Create destination namespace
	dstNamespace := &corev1.Namespace{
		ObjectMeta: metav1.ObjectMeta{Name: "test-dst"},
	}
	_, err := dstClient.CoreV1().Namespaces().Create(ctx, dstNamespace, metav1.CreateOptions{})
	require.NoError(b, err)

	// Create test service with many endpoints
	testService := &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "bench-service",
			Namespace: "test-src",
			Labels:    map[string]string{"sync": "true"},
		},
		Spec: corev1.ServiceSpec{
			Ports: []corev1.ServicePort{{Port: 80}},
		},
	}

	// Create endpoints with multiple IPs for performance testing
	ips := make([]corev1.EndpointAddress, 100)
	for i := 0; i < 100; i++ {
		ips[i] = corev1.EndpointAddress{IP: "10.0.0." + strconv.Itoa(i+1)}
	}

	testEndpoints := &corev1.Endpoints{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "bench-service",
			Namespace: "test-src",
		},
		Subsets: []corev1.EndpointSubset{{
			Addresses: ips,
			Ports:     []corev1.EndpointPort{{Port: 80}},
		}},
	}

	_, err = srcClient.CoreV1().Services("test-src").Create(ctx, testService, metav1.CreateOptions{})
	require.NoError(b, err)
	_, err = srcClient.CoreV1().Endpoints("test-src").Create(ctx, testEndpoints, metav1.CreateOptions{})
	require.NoError(b, err)

	b.ResetTimer()

	// Benchmark service synchronization
	for i := 0; i < b.N; i++ {
		err := syncService(ctx, srcClient, dstClient, "bench-service")
		require.NoError(b, err)
	}
}

func TestConcurrentServiceTracking(t *testing.T) {
	// Clear state before test
	syncMutex.Lock()
	syncedServices = make(map[string]bool)
	syncMutex.Unlock()

	// Test concurrent access to service tracking
	done := make(chan bool)

	// Goroutine 1: Adding services concurrently
	go func() {
		for i := 0; i < 100; i++ {
			setSyncedService("service-"+strconv.Itoa(i), true)
			time.Sleep(1 * time.Millisecond)
		}
		done <- true
	}()

	// Goroutine 2: Removing services concurrently
	go func() {
		for i := 0; i < 50; i++ {
			setSyncedService("service-"+strconv.Itoa(i), false)
			time.Sleep(2 * time.Millisecond)
		}
		done <- true
	}()

	// Goroutine 3: Reading service list concurrently
	go func() {
		for i := 0; i < 50; i++ {
			getSyncedServicesList()
			time.Sleep(1 * time.Millisecond)
		}
		done <- true
	}()

	// Wait for all goroutines to complete
	for i := 0; i < 3; i++ {
		<-done
	}

	// Verify final state is consistent
	services := getSyncedServicesList()
	require.True(t, len(services) >= 50) // At least 50 services should remain
}