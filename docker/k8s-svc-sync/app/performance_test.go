package main

import (
 "context"
 "testing"
 "time"
 "fmt"

 "github.com/stretchr/testify/assert"
 "github.com/stretchr/testify/require"
 corev1 "k8s.io/api/core/v1"
 metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
 "k8s.io/client-go/kubernetes/fake"
)

func BenchmarkServiceSync(b *testing.B) {
 ctx := context.Background()
 srcClient := fake.NewSimpleClientset()
 dstClient := fake.NewSimpleClientset()

 originalSrcNS := *srcNS
 originalDstNS := *dstNS
 originalPodName := *podName
 *srcNS = "bench-src"
 *dstNS = "bench-dst"
 *podName = "bench-pod"
 defer func() {
  *srcNS = originalSrcNS
  *dstNS = originalDstNS
  *podName = originalPodName
 }()

 // Create namespaces
 srcNamespace := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "bench-src"}}
 dstNamespace := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "bench-dst"}}
 _, err := srcClient.CoreV1().Namespaces().Create(ctx, srcNamespace, metav1.CreateOptions{})
 require.NoError(b, err)
 _, err = dstClient.CoreV1().Namespaces().Create(ctx, dstNamespace, metav1.CreateOptions{})
 require.NoError(b, err)

 // Create test service and endpoints
 service := &corev1.Service{
  ObjectMeta: metav1.ObjectMeta{
   Name:      "bench-service",
   Namespace: "bench-src",
   Labels:    map[string]string{"sync": "true"},
  },
  Spec: corev1.ServiceSpec{
   Type: corev1.ServiceTypeClusterIP,
   Ports: []corev1.ServicePort{{
    Name:     "http",
    Protocol: corev1.ProtocolTCP,
    Port:     80,
   }},
  },
 }

 endpoints := &corev1.Endpoints{
  ObjectMeta: metav1.ObjectMeta{
   Name:      "bench-service",
   Namespace: "bench-src",
  },
  Subsets: []corev1.EndpointSubset{{
   Addresses: []corev1.EndpointAddress{{IP: "10.0.0.1"}},
   Ports:     []corev1.EndpointPort{{Name: "http", Port: 80, Protocol: corev1.ProtocolTCP}},
  }},
 }

 _, err = srcClient.CoreV1().Services("bench-src").Create(ctx, service, metav1.CreateOptions{})
 require.NoError(b, err)
 _, err = srcClient.CoreV1().Endpoints("bench-src").Create(ctx, endpoints, metav1.CreateOptions{})
 require.NoError(b, err)

 b.ResetTimer()

 for i := 0; i < b.N; i++ {
  _, err := syncServiceWithResult(ctx, srcClient, dstClient, "bench-service")
  if err != nil {
   b.Fatal(err)
  }
 }
}

func TestPerformanceMultipleServices(t *testing.T) {
 ctx := context.Background()
 srcClient := fake.NewSimpleClientset()
 dstClient := fake.NewSimpleClientset()

 originalSrcNS := *srcNS
 originalDstNS := *dstNS
 originalPodName := *podName
 *srcNS = "perf-src"
 *dstNS = "perf-dst"
 *podName = "perf-pod"
 defer func() {
  *srcNS = originalSrcNS
  *dstNS = originalDstNS
  *podName = originalPodName
 }()

 // Create namespaces
 srcNamespace := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "perf-src"}}
 dstNamespace := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "perf-dst"}}
 _, err := srcClient.CoreV1().Namespaces().Create(ctx, srcNamespace, metav1.CreateOptions{})
 require.NoError(t, err)
 _, err = dstClient.CoreV1().Namespaces().Create(ctx, dstNamespace, metav1.CreateOptions{})
 require.NoError(t, err)

 // Create multiple services
 serviceCount := 100
 for i := 0; i < serviceCount; i++ {
  serviceName := fmt.Sprintf("service-%d", i)

  service := &corev1.Service{
   ObjectMeta: metav1.ObjectMeta{
    Name:      serviceName,
    Namespace: "perf-src",
    Labels:    map[string]string{"sync": "true"},
   },
   Spec: corev1.ServiceSpec{
    Type: corev1.ServiceTypeClusterIP,
    Ports: []corev1.ServicePort{{
     Name:     "http",
     Protocol: corev1.ProtocolTCP,
     Port:     80,
    }},
   },
  }

  endpoints := &corev1.Endpoints{
   ObjectMeta: metav1.ObjectMeta{
    Name:      serviceName,
    Namespace: "perf-src",
   },
   Subsets: []corev1.EndpointSubset{{
    Addresses: []corev1.EndpointAddress{{IP: fmt.Sprintf("10.0.0.%d", i+1)}},
    Ports:     []corev1.EndpointPort{{Name: "http", Port: 80, Protocol: corev1.ProtocolTCP}},
   }},
  }

  _, err = srcClient.CoreV1().Services("perf-src").Create(ctx, service, metav1.CreateOptions{})
  require.NoError(t, err)
  _, err = srcClient.CoreV1().Endpoints("perf-src").Create(ctx, endpoints, metav1.CreateOptions{})
  require.NoError(t, err)
 }

 start := time.Now()

 for i := 0; i < serviceCount; i++ {
  serviceName := fmt.Sprintf("service-%d", i)
  _, err := syncServiceWithResult(ctx, srcClient, dstClient, serviceName)
  assert.NoError(t, err)
 }

 duration := time.Since(start)
 t.Logf("Synced %d services in %v (%.2f ms per service)", serviceCount, duration, float64(duration.Nanoseconds())/float64(serviceCount)/1000000)
}