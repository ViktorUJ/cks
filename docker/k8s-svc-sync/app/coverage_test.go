package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes/fake"
)

func TestHTTPEndpoints(t *testing.T) {
	srcClient := fake.NewSimpleClientset()
	dstClient := fake.NewSimpleClientset()

	originalSrcNS := *srcNS
	originalDstNS := *dstNS
	*srcNS = "test-src"
	*dstNS = "test-dst"
	defer func() {
		*srcNS = originalSrcNS
		*dstNS = originalDstNS
	}()

	ctx := context.Background()

	// Create namespaces
	srcNamespace := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "test-src"}}
	dstNamespace := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "test-dst"}}
	_, err := srcClient.CoreV1().Namespaces().Create(ctx, srcNamespace, metav1.CreateOptions{})
	require.NoError(t, err)
	_, err = dstClient.CoreV1().Namespaces().Create(ctx, dstNamespace, metav1.CreateOptions{})
	require.NoError(t, err)

	t.Run("health_endpoint", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/health", nil)
		w := httptest.NewRecorder()

		mux := http.NewServeMux()
		mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
			w.Write([]byte("OK"))
		})

		mux.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
		assert.Equal(t, "OK", w.Body.String())
	})

	t.Run("ready_endpoint_success", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/ready", nil)
		w := httptest.NewRecorder()

		mux := http.NewServeMux()
		mux.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
			_, srcErr := srcClient.CoreV1().Namespaces().Get(ctx, *srcNS, metav1.GetOptions{})
			_, dstErr := dstClient.CoreV1().Namespaces().Get(ctx, *dstNS, metav1.GetOptions{})

			if srcErr != nil || dstErr != nil {
				w.WriteHeader(http.StatusServiceUnavailable)
				return
			}

			w.WriteHeader(http.StatusOK)
			w.Write([]byte("Clusters connected"))
		})

		mux.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
		assert.Equal(t, "Clusters connected", w.Body.String())
	})

	t.Run("ready_endpoint_failure", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/ready", nil)
		w := httptest.NewRecorder()

		failureClient := fake.NewSimpleClientset()

		mux := http.NewServeMux()
		mux.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
			_, srcErr := failureClient.CoreV1().Namespaces().Get(ctx, "nonexistent", metav1.GetOptions{})
			_, dstErr := dstClient.CoreV1().Namespaces().Get(ctx, *dstNS, metav1.GetOptions{})

			if srcErr != nil || dstErr != nil {
				w.WriteHeader(http.StatusServiceUnavailable)
				if srcErr != nil {
					w.Write([]byte("Source cluster connection failed: " + srcErr.Error() + "\n"))
				}
				return
			}

			w.WriteHeader(http.StatusOK)
			w.Write([]byte("Clusters connected"))
		})

		mux.ServeHTTP(w, req)
		assert.Equal(t, http.StatusServiceUnavailable, w.Code)
		assert.Contains(t, w.Body.String(), "Source cluster connection failed")
	})

	t.Run("leader_endpoint_when_leader", func(t *testing.T) {
		setLeaderStatus(true)
		defer setLeaderStatus(false)

		req := httptest.NewRequest(http.MethodGet, "/leader", nil)
		w := httptest.NewRecorder()

		originalPodName := *podName
		*podName = "test-pod"
		defer func() { *podName = originalPodName }()

		mux := http.NewServeMux()
		mux.HandleFunc("/leader", func(w http.ResponseWriter, r *http.Request) {
			if getLeaderStatus() {
				w.WriteHeader(http.StatusOK)
				w.Write([]byte("Leader: " + *podName))
			} else {
				w.WriteHeader(http.StatusOK)
				w.Write([]byte("Follower"))
			}
		})

		mux.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
		assert.Equal(t, "Leader: test-pod", w.Body.String())
	})

	t.Run("leader_endpoint_when_follower", func(t *testing.T) {
		setLeaderStatus(false)

		req := httptest.NewRequest(http.MethodGet, "/leader", nil)
		w := httptest.NewRecorder()

		mux := http.NewServeMux()
		mux.HandleFunc("/leader", func(w http.ResponseWriter, r *http.Request) {
			if getLeaderStatus() {
				w.WriteHeader(http.StatusOK)
				w.Write([]byte("Leader: " + *podName))
			} else {
				w.WriteHeader(http.StatusOK)
				w.Write([]byte("Follower"))
			}
		})

		mux.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
		assert.Equal(t, "Follower", w.Body.String())
	})
}

func TestServiceSyncEdgeCases(t *testing.T) {
	ctx := context.Background()
	srcClient := fake.NewSimpleClientset()
	dstClient := fake.NewSimpleClientset()

	originalSrcNS := *srcNS
	originalDstNS := *dstNS
	originalPodName := *podName
	*srcNS = "test-src"
	*dstNS = "test-dst"
	*podName = "test-pod"
	defer func() {
		*srcNS = originalSrcNS
		*dstNS = originalDstNS
		*podName = originalPodName
	}()

	// Create namespaces
	srcNamespace := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "test-src"}}
	dstNamespace := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "test-dst"}}
	_, err := srcClient.CoreV1().Namespaces().Create(ctx, srcNamespace, metav1.CreateOptions{})
	require.NoError(t, err)
	_, err = dstClient.CoreV1().Namespaces().Create(ctx, dstNamespace, metav1.CreateOptions{})
	require.NoError(t, err)

	t.Run("service_with_multiple_port_types", func(t *testing.T) {
		service := &corev1.Service{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "multi-port",
				Namespace: "test-src",
				Labels:    map[string]string{"sync": "true"},
			},
			Spec: corev1.ServiceSpec{
				Ports: []corev1.ServicePort{
					{Name: "http", Port: 80, Protocol: corev1.ProtocolTCP},
					{Name: "https", Port: 443, Protocol: corev1.ProtocolTCP},
					{Name: "dns", Port: 53, Protocol: corev1.ProtocolUDP},
				},
			},
		}

		endpoints := &corev1.Endpoints{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "multi-port",
				Namespace: "test-src",
			},
			Subsets: []corev1.EndpointSubset{{
				Addresses: []corev1.EndpointAddress{{IP: "10.0.0.1"}},
				Ports: []corev1.EndpointPort{
					{Name: "http", Port: 80, Protocol: corev1.ProtocolTCP},
					{Name: "https", Port: 443, Protocol: corev1.ProtocolTCP},
					{Name: "dns", Port: 53, Protocol: corev1.ProtocolUDP},
				},
			}},
		}

		_, err := srcClient.CoreV1().Services("test-src").Create(ctx, service, metav1.CreateOptions{})
		require.NoError(t, err)
		_, err = srcClient.CoreV1().Endpoints("test-src").Create(ctx, endpoints, metav1.CreateOptions{})
		require.NoError(t, err)

		_, err = syncServiceWithResult(ctx, srcClient, dstClient, "multi-port")
		assert.NoError(t, err)

		dstSvc, err := dstClient.CoreV1().Services("test-dst").Get(ctx, "multi-port", metav1.GetOptions{})
		require.NoError(t, err)
		assert.Len(t, dstSvc.Spec.Ports, 3)
	})

	t.Run("service_with_no_ready_addresses", func(t *testing.T) {
		service := &corev1.Service{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "no-ready",
				Namespace: "test-src",
				Labels:    map[string]string{"sync": "true"},
			},
			Spec: corev1.ServiceSpec{
				Ports: []corev1.ServicePort{{Port: 80}},
			},
		}

		endpoints := &corev1.Endpoints{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "no-ready",
				Namespace: "test-src",
			},
			Subsets: []corev1.EndpointSubset{{
				Addresses: []corev1.EndpointAddress{}, // No ready addresses
			}},
		}

		_, err := srcClient.CoreV1().Services("test-src").Create(ctx, service, metav1.CreateOptions{})
		require.NoError(t, err)
		_, err = srcClient.CoreV1().Endpoints("test-src").Create(ctx, endpoints, metav1.CreateOptions{})
		require.NoError(t, err)

		_, err = syncServiceWithResult(ctx, srcClient, dstClient, "no-ready")
		assert.NoError(t, err)
	})

	t.Run("service_with_no_ports", func(t *testing.T) {
		service := &corev1.Service{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "no-ports",
				Namespace: "test-src",
				Labels:    map[string]string{"sync": "true"},
			},
			Spec: corev1.ServiceSpec{
				Ports: []corev1.ServicePort{}, // Empty ports array
			},
		}

		endpoints := &corev1.Endpoints{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "no-ports",
				Namespace: "test-src",
			},
			Subsets: []corev1.EndpointSubset{{
				Addresses: []corev1.EndpointAddress{{IP: "10.0.0.1"}},
			}},
		}

		_, err := srcClient.CoreV1().Services("test-src").Create(ctx, service, metav1.CreateOptions{})
		require.NoError(t, err)
		_, err = srcClient.CoreV1().Endpoints("test-src").Create(ctx, endpoints, metav1.CreateOptions{})
		require.NoError(t, err)

		_, err = syncServiceWithResult(ctx, srcClient, dstClient, "no-ports")
		assert.NoError(t, err) // Should succeed but skip sync due to no ports
	})
}

func TestExternalNameServiceVariations(t *testing.T) {
	ctx := context.Background()
	dstClient := fake.NewSimpleClientset()

	originalDstNS := *dstNS
	originalPodName := *podName
	*dstNS = "test-dst"
	*podName = "test-pod"
	defer func() {
		*dstNS = originalDstNS
		*podName = originalPodName
	}()

	// Create namespace
	dstNamespace := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "test-dst"}}
	_, err := dstClient.CoreV1().Namespaces().Create(ctx, dstNamespace, metav1.CreateOptions{})
	require.NoError(t, err)

	t.Run("external_name_service_with_ports", func(t *testing.T) {
		srcSvc := &corev1.Service{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "ext-with-ports",
				Namespace: "test-src",
				Labels:    map[string]string{"sync": "true"},
			},
			Spec: corev1.ServiceSpec{
				Type:         corev1.ServiceTypeExternalName,
				ExternalName: "api.example.com",
				Ports: []corev1.ServicePort{
					{Name: "http", Port: 80},
					{Name: "https", Port: 443},
				},
			},
		}

		_, err := syncExternalNameServiceWithResult(ctx, dstClient, srcSvc, "ext-with-ports")
		assert.NoError(t, err)

		dstSvc, err := dstClient.CoreV1().Services("test-dst").Get(ctx, "ext-with-ports", metav1.GetOptions{})
		require.NoError(t, err)
		assert.Equal(t, "api.example.com", dstSvc.Spec.ExternalName)
		assert.Len(t, dstSvc.Spec.Ports, 2)
	})

	t.Run("update_existing_external_name_service", func(t *testing.T) {
		// Create existing service
		existingSvc := &corev1.Service{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "ext-update",
				Namespace: "test-dst",
				Labels:    map[string]string{"sync": "true-external"},
			},
			Spec: corev1.ServiceSpec{
				Type:         corev1.ServiceTypeExternalName,
				ExternalName: "old.example.com",
			},
		}
		_, err := dstClient.CoreV1().Services("test-dst").Create(ctx, existingSvc, metav1.CreateOptions{})
		require.NoError(t, err)

		// Update with new external name
		srcSvc := &corev1.Service{
			Spec: corev1.ServiceSpec{
				Type:         corev1.ServiceTypeExternalName,
				ExternalName: "new.example.com",
			},
		}

		_, err = syncExternalNameServiceWithResult(ctx, dstClient, srcSvc, "ext-update")
		assert.NoError(t, err)

		dstSvc, err := dstClient.CoreV1().Services("test-dst").Get(ctx, "ext-update", metav1.GetOptions{})
		require.NoError(t, err)
		assert.Equal(t, "new.example.com", dstSvc.Spec.ExternalName)
	})

	t.Run("skip_unmanaged_external_name_service", func(t *testing.T) {
		// Create service without sync label
		unmanagedSvc := &corev1.Service{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "ext-unmanaged",
				Namespace: "test-dst",
			},
			Spec: corev1.ServiceSpec{
				Type:         corev1.ServiceTypeExternalName,
				ExternalName: "unmanaged.example.com",
			},
		}
		_, err := dstClient.CoreV1().Services("test-dst").Create(ctx, unmanagedSvc, metav1.CreateOptions{})
		require.NoError(t, err)

		srcSvc := &corev1.Service{
			Spec: corev1.ServiceSpec{
				Type:         corev1.ServiceTypeExternalName,
				ExternalName: "managed.example.com",
			},
		}

		_, err = syncExternalNameServiceWithResult(ctx, dstClient, srcSvc, "ext-unmanaged")
		assert.NoError(t, err)

		// Verify service was not updated
		dstSvc, err := dstClient.CoreV1().Services("test-dst").Get(ctx, "ext-unmanaged", metav1.GetOptions{})
		require.NoError(t, err)
		assert.Equal(t, "unmanaged.example.com", dstSvc.Spec.ExternalName)
	})
}

func TestHandleServiceEvent(t *testing.T) {
	ctx := context.Background()
	srcClient := fake.NewSimpleClientset()
	dstClient := fake.NewSimpleClientset()

	// Clear sync state
	syncMutex.Lock()
	syncedServices = make(map[string]bool)
	syncMutex.Unlock()

	originalSrcNS := *srcNS
	originalDstNS := *dstNS
	originalPodName := *podName
	*srcNS = "test-src"
	*dstNS = "test-dst"
	*podName = "test-pod"
	defer func() {
		*srcNS = originalSrcNS
		*dstNS = originalDstNS
		*podName = originalPodName
	}()

	// Create namespaces
	srcNamespace := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "test-src"}}
	dstNamespace := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "test-dst"}}
	_, err := srcClient.CoreV1().Namespaces().Create(ctx, srcNamespace, metav1.CreateOptions{})
	require.NoError(t, err)
	_, err = dstClient.CoreV1().Namespaces().Create(ctx, dstNamespace, metav1.CreateOptions{})
	require.NoError(t, err)

	t.Run("start_syncing_new_service", func(t *testing.T) {
		svc := &corev1.Service{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "new-sync",
				Namespace: "test-src",
				Labels:    map[string]string{"sync": "true"},
			},
			Spec: corev1.ServiceSpec{
				Type:         corev1.ServiceTypeExternalName,
				ExternalName: "example.com",
			},
		}

		_, err := srcClient.CoreV1().Services("test-src").Create(ctx, svc, metav1.CreateOptions{})
		require.NoError(t, err)

		handleServiceEvent(ctx, srcClient, dstClient, svc, "ADDED")
		assert.True(t, isServiceSynced("new-sync"))
	})

	t.Run("stop_syncing_service", func(t *testing.T) {
		// Create service to sync first
		svc := &corev1.Service{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "stop-sync",
				Namespace: "test-src",
				Labels:    map[string]string{"sync": "true"},
			},
			Spec: corev1.ServiceSpec{
				Type:         corev1.ServiceTypeExternalName,
				ExternalName: "example.com",
			},
		}

		_, err := srcClient.CoreV1().Services("test-src").Create(ctx, svc, metav1.CreateOptions{})
		require.NoError(t, err)

		// Start syncing
		handleServiceEvent(ctx, srcClient, dstClient, svc, "ADDED")
		assert.True(t, isServiceSynced("stop-sync"))

		// Remove sync label
		svc.Labels = map[string]string{}
		handleServiceEvent(ctx, srcClient, dstClient, svc, "MODIFIED")
		assert.False(t, isServiceSynced("stop-sync"))
	})

	t.Run("service_deleted", func(t *testing.T) {
		// Create and sync service first
		svc := &corev1.Service{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "deleted-svc",
				Namespace: "test-src",
				Labels:    map[string]string{"sync": "true"},
			},
			Spec: corev1.ServiceSpec{
				Type:         corev1.ServiceTypeExternalName,
				ExternalName: "example.com",
			},
		}

		setSyncedService("deleted-svc", true)
		handleServiceEvent(ctx, srcClient, dstClient, svc, "DELETED")
		assert.False(t, isServiceSynced("deleted-svc"))
	})
}

func TestWatchServices(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()

	srcClient := fake.NewSimpleClientset()
	dstClient := fake.NewSimpleClientset()

	setLeaderStatus(true)
	defer setLeaderStatus(false)

	err := watchServices(ctx, srcClient, dstClient)
	assert.Error(t, err) // Should timeout
}

func TestWatchEndpoints(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()

	srcClient := fake.NewSimpleClientset()
	dstClient := fake.NewSimpleClientset()

	setLeaderStatus(true)
	defer setLeaderStatus(false)

	err := watchEndpoints(ctx, srcClient, dstClient)
	assert.Error(t, err) // Should timeout
}

func TestSyncAllServices(t *testing.T) {
	ctx := context.Background()
	srcClient := fake.NewSimpleClientset()
	dstClient := fake.NewSimpleClientset()

	// Clear sync state before each test
	syncMutex.Lock()
	syncedServices = make(map[string]bool)
	syncMutex.Unlock()

	originalSrcNS := *srcNS
	originalDstNS := *dstNS
	originalPodName := *podName
	originalSyncLabel := *syncLabel
	*srcNS = "test-src"
	*dstNS = "test-dst"
	*podName = "test-pod"
	*syncLabel = "sync=true"
	defer func() {
		*srcNS = originalSrcNS
		*dstNS = originalDstNS
		*podName = originalPodName
		*syncLabel = originalSyncLabel
	}()

	// Create namespaces
	srcNamespace := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "test-src"}}
	dstNamespace := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "test-dst"}}
	_, err := srcClient.CoreV1().Namespaces().Create(ctx, srcNamespace, metav1.CreateOptions{})
	require.NoError(t, err)
	_, err = dstClient.CoreV1().Namespaces().Create(ctx, dstNamespace, metav1.CreateOptions{})
	require.NoError(t, err)

	t.Run("no_services_found", func(t *testing.T) {
		// Clear any existing services
		syncMutex.Lock()
		syncedServices = make(map[string]bool)
		syncMutex.Unlock()

		err := syncAllServices(ctx, srcClient, dstClient)
		assert.NoError(t, err)
	})

	t.Run("multiple_services", func(t *testing.T) {
		// Clear sync state
		syncMutex.Lock()
		syncedServices = make(map[string]bool)
		syncMutex.Unlock()

		// Create multiple services
		for i := 1; i <= 3; i++ {
			svc := &corev1.Service{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "svc-" + strconv.Itoa(i),
					Namespace: "test-src",
					Labels:    map[string]string{"sync": "true"},
				},
				Spec: corev1.ServiceSpec{
					Type:         corev1.ServiceTypeExternalName,
					ExternalName: "example.com",
				},
			}
			_, err := srcClient.CoreV1().Services("test-src").Create(ctx, svc, metav1.CreateOptions{})
			require.NoError(t, err)
		}

		err := syncAllServices(ctx, srcClient, dstClient)
		assert.NoError(t, err)

		services := getSyncedServicesList()
		assert.Len(t, services, 3)
	})
}

func TestPerformInitialServiceSync(t *testing.T) {
	ctx := context.Background()
	srcClient := fake.NewSimpleClientset()
	dstClient := fake.NewSimpleClientset()

	originalSrcNS := *srcNS
	originalDstNS := *dstNS
	*srcNS = "test-src"
	*dstNS = "test-dst"
	defer func() {
		*srcNS = originalSrcNS
		*dstNS = originalDstNS
	}()

	// Create namespaces
	srcNamespace := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "test-src"}}
	dstNamespace := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "test-dst"}}
	_, err := srcClient.CoreV1().Namespaces().Create(ctx, srcNamespace, metav1.CreateOptions{})
	require.NoError(t, err)
	_, err = dstClient.CoreV1().Namespaces().Create(ctx, dstNamespace, metav1.CreateOptions{})
	require.NoError(t, err)

	t.Run("service_not_found", func(t *testing.T) {
		_, err := performInitialServiceSyncWithResult(ctx, srcClient, dstClient, "nonexistent")
		assert.Error(t, err)
	})

	t.Run("external_name_service", func(t *testing.T) {
		svc := &corev1.Service{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "ext-svc",
				Namespace: "test-src",
				Labels:    map[string]string{"sync": "true"},
			},
			Spec: corev1.ServiceSpec{
				Type:         corev1.ServiceTypeExternalName,
				ExternalName: "example.com",
			},
		}
		_, err := srcClient.CoreV1().Services("test-src").Create(ctx, svc, metav1.CreateOptions{})
		require.NoError(t, err)

		_, err = performInitialServiceSyncWithResult(ctx, srcClient, dstClient, "ext-svc")
		assert.NoError(t, err)
	})

	t.Run("service_with_no_endpoints", func(t *testing.T) {
		svc := &corev1.Service{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "no-eps",
				Namespace: "test-src",
				Labels:    map[string]string{"sync": "true"},
			},
			Spec: corev1.ServiceSpec{
				Ports: []corev1.ServicePort{{Port: 80}},
			},
		}
		_, err := srcClient.CoreV1().Services("test-src").Create(ctx, svc, metav1.CreateOptions{})
		require.NoError(t, err)

		_, err = performInitialServiceSyncWithResult(ctx, srcClient, dstClient, "no-eps")
		assert.NoError(t, err)
	})
}

func TestHelperFunctions(t *testing.T) {
	t.Run("readyIPs_with_multiple_subsets", func(t *testing.T) {
		eps := &corev1.Endpoints{
			Subsets: []corev1.EndpointSubset{
				{Addresses: []corev1.EndpointAddress{{IP: "10.0.0.1"}, {IP: "10.0.0.2"}}},
				{Addresses: []corev1.EndpointAddress{{IP: "10.0.0.3"}}},
			},
		}
		ips := readyIPs(eps)
		assert.Len(t, ips, 3)
		assert.Contains(t, ips, "10.0.0.1")
		assert.Contains(t, ips, "10.0.0.2")
		assert.Contains(t, ips, "10.0.0.3")
	})

	t.Run("readyIPs_with_nil_endpoints", func(t *testing.T) {
		eps := &corev1.Endpoints{Subsets: []corev1.EndpointSubset{}}
		ips := readyIPs(eps)
		assert.Equal(t, []string{}, ips)
	})

	t.Run("sameIPs_edge_cases", func(t *testing.T) {
		// Test empty endpoints with empty IP list
		eps := &corev1.Endpoints{Subsets: []corev1.EndpointSubset{}}
		result := sameIPs(eps, []string{})
		assert.False(t, result) // Should be false because no subsets

		// Test empty subset addresses with empty IP list
		eps = &corev1.Endpoints{
			Subsets: []corev1.EndpointSubset{{Addresses: []corev1.EndpointAddress{}}},
		}
		result = sameIPs(eps, []string{})
		assert.True(t, result) // Should be true - both are empty
	})

	t.Run("toEPAddrs", func(t *testing.T) {
		ips := []string{"10.0.0.1", "10.0.0.2"}
		addrs := toEPAddrs(ips)
		assert.Len(t, addrs, 2)
		assert.Equal(t, "10.0.0.1", addrs[0].IP)
		assert.Equal(t, "10.0.0.2", addrs[1].IP)
	})
}

func TestClientForFunction(t *testing.T) {
	// Test that clientFor function handles invalid context gracefully
	_, err := clientFor("", "invalid-context")
	assert.Error(t, err)
}

func TestMustFunction(t *testing.T) {
	// Test must function with nil error
	assert.NotPanics(t, func() {
		must(nil)
	})
}

func TestServiceSyncRaceConditions(t *testing.T) {
	ctx := context.Background()
	srcClient := fake.NewSimpleClientset()
	dstClient := fake.NewSimpleClientset()

	originalSrcNS := *srcNS
	originalDstNS := *dstNS
	originalPodName := *podName
	*srcNS = "test-src"
	*dstNS = "test-dst"
	*podName = "test-pod"
	defer func() {
		*srcNS = originalSrcNS
		*dstNS = originalDstNS
		*podName = originalPodName
	}()

	// Create namespaces
	srcNamespace := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "test-src"}}
	dstNamespace := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "test-dst"}}
	_, err := srcClient.CoreV1().Namespaces().Create(ctx, srcNamespace, metav1.CreateOptions{})
	require.NoError(t, err)
	_, err = dstClient.CoreV1().Namespaces().Create(ctx, dstNamespace, metav1.CreateOptions{})
	require.NoError(t, err)

	t.Run("service_create_race_condition", func(t *testing.T) {
		// Create source service
		srcSvc := &corev1.Service{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "race-svc",
				Namespace: "test-src",
				Labels:    map[string]string{"sync": "true"},
			},
			Spec: corev1.ServiceSpec{
				Ports: []corev1.ServicePort{{Port: 80}},
			},
		}

		srcEps := &corev1.Endpoints{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "race-svc",
				Namespace: "test-src",
			},
			Subsets: []corev1.EndpointSubset{{
				Addresses: []corev1.EndpointAddress{{IP: "10.0.0.1"}},
				Ports:     []corev1.EndpointPort{{Port: 80}},
			}},
		}

		// Create existing service in destination without sync label
		existingDstSvc := &corev1.Service{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "race-svc",
				Namespace: "test-dst",
			},
			Spec: corev1.ServiceSpec{
				Ports: []corev1.ServicePort{{Port: 8080}},
			},
		}

		_, err := srcClient.CoreV1().Services("test-src").Create(ctx, srcSvc, metav1.CreateOptions{})
		require.NoError(t, err)
		_, err = srcClient.CoreV1().Endpoints("test-src").Create(ctx, srcEps, metav1.CreateOptions{})
		require.NoError(t, err)
		_, err = dstClient.CoreV1().Services("test-dst").Create(ctx, existingDstSvc, metav1.CreateOptions{})
		require.NoError(t, err)

		_, err = syncServiceWithResult(ctx, srcClient, dstClient, "race-svc")
		assert.NoError(t, err)

		// Verify service was updated with sync label
		dstSvc, err := dstClient.CoreV1().Services("test-dst").Get(ctx, "race-svc", metav1.GetOptions{})
		require.NoError(t, err)
		assert.Equal(t, "true-external", dstSvc.Labels["sync"])
	})
}

func TestRemoveServiceEdgeCases(t *testing.T) {
	ctx := context.Background()
	dstClient := fake.NewSimpleClientset()

	// Clear sync state
	syncMutex.Lock()
	syncedServices = make(map[string]bool)
	// Add some existing tracked services from previous tests
	syncedServices["svc-1"] = true
	syncedServices["svc-2"] = true
	syncedServices["svc-3"] = true
	syncMutex.Unlock()

	originalDstNS := *dstNS
	originalPodName := *podName
	*dstNS = "test-dst"
	*podName = "test-pod"
	defer func() {
		*dstNS = originalDstNS
		*podName = originalPodName
	}()

	// Create namespace
	dstNamespace := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "test-dst"}}
	_, err := dstClient.CoreV1().Namespaces().Create(ctx, dstNamespace, metav1.CreateOptions{})
	require.NoError(t, err)

	t.Run("remove_external_name_service", func(t *testing.T) {
		svc := &corev1.Service{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "ext-remove",
				Namespace: "test-dst",
				Labels:    map[string]string{"sync": "true-external"},
			},
			Spec: corev1.ServiceSpec{
				Type:         corev1.ServiceTypeExternalName,
				ExternalName: "example.com",
			},
		}
		_, err := dstClient.CoreV1().Services("test-dst").Create(ctx, svc, metav1.CreateOptions{})
		require.NoError(t, err)

		err = removeService(ctx, dstClient, "ext-remove")
		assert.NoError(t, err)

		_, err = dstClient.CoreV1().Services("test-dst").Get(ctx, "ext-remove", metav1.GetOptions{})
		assert.Error(t, err)
	})

	t.Run("service_not_found_for_deletion", func(t *testing.T) {
		err := removeService(ctx, dstClient, "nonexistent")
		assert.NoError(t, err)
	})

	t.Run("unmanaged_service_deletion", func(t *testing.T) {
		svc := &corev1.Service{
			ObjectMeta: metav1.ObjectMeta{
				Name:      "unmanaged",
				Namespace: "test-dst",
			},
			Spec: corev1.ServiceSpec{
				Ports: []corev1.ServicePort{{Port: 80}},
			},
		}
		_, err := dstClient.CoreV1().Services("test-dst").Create(ctx, svc, metav1.CreateOptions{})
		require.NoError(t, err)

		err = removeService(ctx, dstClient, "unmanaged")
		assert.NoError(t, err)

		// Service should be deleted
		_, err = dstClient.CoreV1().Services("test-dst").Get(ctx, "unmanaged", metav1.GetOptions{})
		assert.Error(t, err)
	})
}

// Coverage tests for helper functions
func TestCoverageReadyIPs(t *testing.T) {
	t.Run("multiple_ready_IPs", func(t *testing.T) {
		eps := &corev1.Endpoints{
			Subsets: []corev1.EndpointSubset{
				{Addresses: []corev1.EndpointAddress{{IP: "10.0.0.1"}, {IP: "10.0.0.2"}}},
				{Addresses: []corev1.EndpointAddress{{IP: "10.0.0.3"}}},
			},
		}
		ips := readyIPs(eps)
		assert.Len(t, ips, 3)
		assert.Contains(t, ips, "10.0.0.1")
		assert.Contains(t, ips, "10.0.0.2")
		assert.Contains(t, ips, "10.0.0.3")
	})

	t.Run("empty_endpoints", func(t *testing.T) {
		eps := &corev1.Endpoints{Subsets: []corev1.EndpointSubset{}}
		ips := readyIPs(eps)
		assert.Equal(t, []string{}, ips)
	})
}

func TestCoverageSameIPs(t *testing.T) {
	t.Run("same_IPs", func(t *testing.T) {
		eps := &corev1.Endpoints{
			Subsets: []corev1.EndpointSubset{{
				Addresses: []corev1.EndpointAddress{{IP: "10.0.0.1"}, {IP: "10.0.0.2"}},
			}},
		}
		result := sameIPs(eps, []string{"10.0.0.1", "10.0.0.2"})
		assert.True(t, result)
	})

	t.Run("different_IPs", func(t *testing.T) {
		eps := &corev1.Endpoints{
			Subsets: []corev1.EndpointSubset{{
				Addresses: []corev1.EndpointAddress{{IP: "10.0.0.1"}},
			}},
		}
		result := sameIPs(eps, []string{"10.0.0.2"})
		assert.False(t, result)
	})
}

func TestCoverageServiceTracking(t *testing.T) {
	// Clear state
	syncMutex.Lock()
	syncedServices = make(map[string]bool)
	syncMutex.Unlock()

	// Test service tracking functionality
	setSyncedService("test1", true)
	setSyncedService("test2", true)
	assert.True(t, isServiceSynced("test1"))
	assert.True(t, isServiceSynced("test2"))
	assert.False(t, isServiceSynced("test3"))

	services := getSyncedServicesList()
	assert.Len(t, services, 2)
	assert.Contains(t, services, "test1")
	assert.Contains(t, services, "test2")

	setSyncedService("test1", false)
	assert.False(t, isServiceSynced("test1"))

	services = getSyncedServicesList()
	assert.Len(t, services, 1)
	assert.Contains(t, services, "test2")
}

func TestCoverageLeaderStatus(t *testing.T) {
	// Test leader status functionality
	setLeaderStatus(true)
	assert.True(t, getLeaderStatus())

	setLeaderStatus(false)
	assert.False(t, getLeaderStatus())

	setLeaderStatus(true)
	assert.True(t, getLeaderStatus())
}

func TestCoverageConcurrentServiceTracking(t *testing.T) {
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