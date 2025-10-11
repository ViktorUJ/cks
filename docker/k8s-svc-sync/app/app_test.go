// app_test.go
package main

import (
 "context"
 "testing"

 "github.com/stretchr/testify/assert"
 "github.com/stretchr/testify/require"
 corev1 "k8s.io/api/core/v1"
 metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
 "k8s.io/client-go/kubernetes/fake"
)

func TestSyncService(t *testing.T) {
 ctx := context.Background()
 srcClient := fake.NewSimpleClientset()
 dstClient := fake.NewSimpleClientset()

 // Set test values for global variables
 originalSrcNS := *srcNS
 originalDstNS := *dstNS
 *srcNS = "test-src"
 *dstNS = "test-dst"
 defer func() {
  *srcNS = originalSrcNS
  *dstNS = originalDstNS
 }()

 // Create source namespace
 srcNamespace := &corev1.Namespace{
  ObjectMeta: metav1.ObjectMeta{Name: "test-src"},
 }
 _, err := srcClient.CoreV1().Namespaces().Create(ctx, srcNamespace, metav1.CreateOptions{})
 require.NoError(t, err)

 // Create destination namespace
 dstNamespace := &corev1.Namespace{
  ObjectMeta: metav1.ObjectMeta{Name: "test-dst"},
 }
 _, err = dstClient.CoreV1().Namespaces().Create(ctx, dstNamespace, metav1.CreateOptions{})
 require.NoError(t, err)

 // Create test service in source cluster
 testService := &corev1.Service{
  ObjectMeta: metav1.ObjectMeta{
   Name:      "test-service",
   Namespace: "test-src",
   Labels:    map[string]string{"sync": "true"},
  },
  Spec: corev1.ServiceSpec{
   Ports: []corev1.ServicePort{
    {Name: "http", Port: 80, Protocol: corev1.ProtocolTCP},
   },
  },
 }

 // Create endpoints for the service
 testEndpoints := &corev1.Endpoints{
  ObjectMeta: metav1.ObjectMeta{
   Name:      "test-service",
   Namespace: "test-src",
  },
  Subsets: []corev1.EndpointSubset{
   {
    Addresses: []corev1.EndpointAddress{
     {IP: "10.0.0.1"},
     {IP: "10.0.0.2"},
    },
    Ports: []corev1.EndpointPort{
     {Name: "http", Port: 80, Protocol: corev1.ProtocolTCP},
    },
   },
  },
 }

 // Add to source client
 _, err = srcClient.CoreV1().Services("test-src").Create(ctx, testService, metav1.CreateOptions{})
 require.NoError(t, err)
 _, err = srcClient.CoreV1().Endpoints("test-src").Create(ctx, testEndpoints, metav1.CreateOptions{})
 require.NoError(t, err)

 // Perform synchronization - используем syncServiceWithResult
 result, err := syncServiceWithResult(ctx, srcClient, dstClient, "test-service")
 assert.NoError(t, err)
 assert.True(t, result.ServiceCreated)

 // Verify service was created in destination
 dstSvc, err := dstClient.CoreV1().Services("test-dst").Get(ctx, "test-service", metav1.GetOptions{})
 require.NoError(t, err)
 assert.Equal(t, "true-external", dstSvc.Labels["sync"])
 assert.Equal(t, 1, len(dstSvc.Spec.Ports))
 assert.Equal(t, int32(80), dstSvc.Spec.Ports[0].Port)

 // Verify endpoints were created
 dstEps, err := dstClient.CoreV1().Endpoints("test-dst").Get(ctx, "test-service", metav1.GetOptions{})
 require.NoError(t, err)
 assert.Equal(t, 1, len(dstEps.Subsets))
 assert.Equal(t, 2, len(dstEps.Subsets[0].Addresses))
 assert.Equal(t, "10.0.0.1", dstEps.Subsets[0].Addresses[0].IP)
 assert.Equal(t, "10.0.0.2", dstEps.Subsets[0].Addresses[1].IP)
}

func TestSyncExternalNameService(t *testing.T) {
 ctx := context.Background()
 dstClient := fake.NewSimpleClientset()

 originalDstNS := *dstNS
 *dstNS = "test-dst"
 defer func() {
  *dstNS = originalDstNS
 }()

 // Create namespace
 dstNamespace := &corev1.Namespace{
  ObjectMeta: metav1.ObjectMeta{Name: "test-dst"},
 }
 _, err := dstClient.CoreV1().Namespaces().Create(ctx, dstNamespace, metav1.CreateOptions{})
 require.NoError(t, err)

 // Test ExternalName service
 srcSvc := &corev1.Service{
  ObjectMeta: metav1.ObjectMeta{
   Name:      "external-service",
   Namespace: "test-src",
   Labels:    map[string]string{"sync": "true"},
  },
  Spec: corev1.ServiceSpec{
   Type:         corev1.ServiceTypeExternalName,
   ExternalName: "example.com",
  },
 }

 // Synchronize ExternalName service - используем syncExternalNameServiceWithResult
 result, err := syncExternalNameServiceWithResult(ctx, dstClient, srcSvc, "external-service")
 assert.NoError(t, err)
 assert.True(t, result.ServiceCreated)

 // Verify ExternalName service was created correctly
 dstSvc, err := dstClient.CoreV1().Services("test-dst").Get(ctx, "external-service", metav1.GetOptions{})
 require.NoError(t, err)
 assert.Equal(t, corev1.ServiceTypeExternalName, dstSvc.Spec.Type)
 assert.Equal(t, "example.com", dstSvc.Spec.ExternalName)
 assert.Equal(t, "true-external", dstSvc.Labels["sync"])
}

func TestRemoveService(t *testing.T) {
 ctx := context.Background()
 dstClient := fake.NewSimpleClientset()

 originalDstNS := *dstNS
 *dstNS = "test-dst"
 defer func() {
  *dstNS = originalDstNS
 }()

 // Create namespace
 dstNamespace := &corev1.Namespace{
  ObjectMeta: metav1.ObjectMeta{Name: "test-dst"},
 }
 _, err := dstClient.CoreV1().Namespaces().Create(ctx, dstNamespace, metav1.CreateOptions{})
 require.NoError(t, err)

 // Create service with sync label
 testService := &corev1.Service{
  ObjectMeta: metav1.ObjectMeta{
   Name:      "test-service",
   Namespace: "test-dst",
   Labels:    map[string]string{"sync": "true-external"},
  },
  Spec: corev1.ServiceSpec{
   Ports: []corev1.ServicePort{{Port: 80}},
  },
 }

 testEndpoints := &corev1.Endpoints{
  ObjectMeta: metav1.ObjectMeta{
   Name:      "test-service",
   Namespace: "test-dst",
  },
  Subsets: []corev1.EndpointSubset{{
   Addresses: []corev1.EndpointAddress{{IP: "10.0.0.1"}},
  }},
 }

 _, err = dstClient.CoreV1().Services("test-dst").Create(ctx, testService, metav1.CreateOptions{})
 require.NoError(t, err)
 _, err = dstClient.CoreV1().Endpoints("test-dst").Create(ctx, testEndpoints, metav1.CreateOptions{})
 require.NoError(t, err)

 // Remove service
 err = removeService(ctx, dstClient, "test-service")
 assert.NoError(t, err)

 // Verify service and endpoints are deleted
 _, err = dstClient.CoreV1().Services("test-dst").Get(ctx, "test-service", metav1.GetOptions{})
 assert.Error(t, err)

 _, err = dstClient.CoreV1().Endpoints("test-dst").Get(ctx, "test-service", metav1.GetOptions{})
 assert.Error(t, err)
}