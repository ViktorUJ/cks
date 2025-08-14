package main

import (
	"context"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"sort"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	coordinationv1 "k8s.io/client-go/kubernetes/typed/coordination/v1"
	corev1client "k8s.io/client-go/kubernetes/typed/core/v1"
	"k8s.io/client-go/tools/clientcmd"
	clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
	"k8s.io/client-go/tools/leaderelection"
	"k8s.io/client-go/tools/leaderelection/resourcelock"
)

// -------------------------------------------------------------------------
// Interface for testability
// -------------------------------------------------------------------------
type KubernetesClient interface {
	CoreV1() corev1client.CoreV1Interface
	CoordinationV1() coordinationv1.CoordinationV1Interface
}

// Ensure *kubernetes.Clientset implements KubernetesClient
var _ KubernetesClient = (*kubernetes.Clientset)(nil)

// -------------------------------------------------------------------------
// Flags
// -------------------------------------------------------------------------
var (
	kubeconfig              = flag.String("kubeconfig", os.Getenv("KUBECONFIG"), "path to kubeconfig; leave empty for default")
	srcCtx                  = flag.String("src-context", "local-cluster", "source kube context")
	dstCtx                  = flag.String("dst-context", "external-cluster", "destination kube context")
	srcNS                   = flag.String("src-ns", "default", "source namespace")
	dstNS                   = flag.String("dst-ns", "prod-test", "destination namespace")
	syncLabel               = flag.String("sync-label", "sync=true", "label selector for services to sync")
	leaderElectionNamespace = flag.String("leader-election-namespace", "k8s-sync", "namespace for leader election")
	leaderElectionName      = flag.String("leader-election-name", "k8s-svc-sync-leader", "name for leader election")
	podName                 = flag.String("pod-name", os.Getenv("HOSTNAME"), "pod name for leader election")
	syncInterval            = flag.Duration("sync-interval", 3*time.Minute, "interval for periodic full sync")
)

// Track which services are currently being synced
var (
	syncedServices = make(map[string]bool)
	syncMutex      = sync.RWMutex{}
	isLeader       = false
	leaderMutex    = sync.RWMutex{}
)

func main() {
	flag.Parse()

	logInfo("using sync interval: %v", *syncInterval)

	if *podName == "" {
		*podName = "k8s-svc-sync-" + strconv.FormatInt(time.Now().Unix(), 10)
		logInfo("pod name not set, using generated name: %s", *podName)
	}

	srcClient, err := clientFor(*kubeconfig, *srcCtx)
	must(err)
	dstClient, err := clientFor(*kubeconfig, *dstCtx)
	must(err)

	// For leader election, we'll use the source cluster client (local cluster)
	leaderElectionClient, err := clientFor(*kubeconfig, *srcCtx)
	must(err)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	logInfo("starting k8s-svc-sync pod %s", *podName)

	// Start HTTP server for health and readiness checks
	go startHTTPServer(ctx, srcClient, dstClient)

	// Start leader election
	startLeaderElection(ctx, leaderElectionClient, srcClient, dstClient)
}

// -------------------------------------------------------------------------
// Leader Election
// -------------------------------------------------------------------------
func startLeaderElection(ctx context.Context, leaderClient, srcClient, dstClient KubernetesClient) {
	lock := &resourcelock.LeaseLock{
		LeaseMeta: metav1.ObjectMeta{
			Name:      *leaderElectionName,
			Namespace: *leaderElectionNamespace,
		},
		Client: leaderClient.CoordinationV1(),
		LockConfig: resourcelock.ResourceLockConfig{
			Identity: *podName,
		},
	}

	leaderElectionConfig := leaderelection.LeaderElectionConfig{
		Lock:            lock,
		ReleaseOnCancel: true,
		LeaseDuration:   6 * time.Second,
		RenewDeadline:   4 * time.Second,
		RetryPeriod:     1 * time.Second,
		Callbacks: leaderelection.LeaderCallbacks{
			OnStartedLeading: func(ctx context.Context) {
				logInfo("became leader, starting sync operations")
				setLeaderStatus(true)
				startSyncOperations(ctx, srcClient, dstClient)
			},
			OnStoppedLeading: func() {
				logInfo("stopped leading")
				setLeaderStatus(false)
			},
			OnNewLeader: func(identity string) {
				if identity == *podName {
					return
				}
				logInfo("new leader elected: %s", identity)
			},
		},
	}

	leaderelection.RunOrDie(ctx, leaderElectionConfig)
}

func setLeaderStatus(leader bool) {
	leaderMutex.Lock()
	defer leaderMutex.Unlock()
	isLeader = leader
}

func getLeaderStatus() bool {
	leaderMutex.RLock()
	defer leaderMutex.RUnlock()
	return isLeader
}

// -------------------------------------------------------------------------
// Sync Operations (only runs on leader)
// -------------------------------------------------------------------------
func startSyncOperations(ctx context.Context, srcClient, dstClient KubernetesClient) {
	logInfo("starting mirror for services with label %s: %s/%s → %s/%s", *syncLabel, *srcCtx, *srcNS, *dstCtx, *dstNS)

	// Initial full sync
	if err := syncAllServices(ctx, srcClient, dstClient); err != nil {
		logErr("initial sync failed: %v", err)
	} else {
		syncedList := getSyncedServicesList()
		if len(syncedList) > 0 {
			logInfo("initial sync complete, synchronized services: %v", syncedList)
		} else {
			logInfo("initial sync complete, no services synchronized")
		}
	}

	// Start watching both services and endpoints concurrently
	var wg sync.WaitGroup

	wg.Add(1)
	go func() {
		defer wg.Done()
		for {
			if !getLeaderStatus() {
				logInfo("no longer leader, stopping service watcher")
				return
			}
			if err := watchServices(ctx, srcClient, dstClient); err != nil {
				logErr("service watcher error: %v", err)
				time.Sleep(5 * time.Second)
			} else {
				logInfo("service watcher stopped cleanly")
				return
			}
		}
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		for {
			if !getLeaderStatus() {
				logInfo("no longer leader, stopping endpoints watcher")
				return
			}
			if err := watchEndpoints(ctx, srcClient, dstClient); err != nil {
				logErr("endpoints watcher error: %v", err)
				time.Sleep(5 * time.Second)
			} else {
				logInfo("endpoints watcher stopped cleanly")
				return
			}
		}
	}()

	// Start periodic full sync
	wg.Add(1)
	go func() {
		defer wg.Done()

		// Wait for the first interval before starting periodic sync
		timer := time.NewTimer(*syncInterval)
		defer timer.Stop()

		logInfo("next periodic sync scheduled in %v", *syncInterval)

		select {
		case <-ctx.Done():
			return
		case <-timer.C:
			// First sync after interval
		}

		// Check if still leader before first sync
		if !getLeaderStatus() {
			return
		}

		logInfo("performing periodic full sync")
		result, err := syncAllServicesWithResult(ctx, srcClient, dstClient)
		if err != nil {
			logErr("periodic sync failed: %v", err)
		} else {
			if result.hasChanges() {
				logInfo("periodic sync completed - created: %d, updated: %d, deleted: %d, endpoints: %d",
					result.ServicesCreated, result.ServicesUpdated, result.ServicesDeleted, result.EndpointsUpdated)
			} else {
				logInfo("periodic sync completed - no changes")
			}
		}

		// Now start regular ticker for subsequent syncs
		ticker := time.NewTicker(*syncInterval)
		defer ticker.Stop()

		logInfo("next periodic sync scheduled in %v", *syncInterval)

		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				if !getLeaderStatus() {
					return
				}

				logInfo("performing periodic full sync")
				result, err := syncAllServicesWithResult(ctx, srcClient, dstClient)
				if err != nil {
					logErr("periodic sync failed: %v", err)
				} else {
					if result.hasChanges() {
						logInfo("periodic sync completed - created: %d, updated: %d, deleted: %d, endpoints: %d",
							result.ServicesCreated, result.ServicesUpdated, result.ServicesDeleted, result.EndpointsUpdated)
					} else {
						logInfo("periodic sync completed - no changes")
					}
				}

				logInfo("next periodic sync scheduled in %v", *syncInterval)
			}
		}
	}()

	wg.Wait()
}

// -------------------------------------------------------------------------
// HTTP Server for health and readiness checks
// -------------------------------------------------------------------------
func startHTTPServer(ctx context.Context, srcClient, dstClient KubernetesClient) {
	httpPort := 8080
	mux := http.NewServeMux()

	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	mux.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
		_, srcErr := srcClient.CoreV1().Namespaces().Get(ctx, *srcNS, metav1.GetOptions{})
		_, dstErr := dstClient.CoreV1().Namespaces().Get(ctx, *dstNS, metav1.GetOptions{})

		if srcErr != nil || dstErr != nil {
			w.WriteHeader(http.StatusServiceUnavailable)
			if srcErr != nil {
				w.Write([]byte("Source cluster connection failed: " + srcErr.Error() + "\n"))
			}
			if dstErr != nil {
				w.Write([]byte("Destination cluster connection failed: " + dstErr.Error() + "\n"))
			}
			return
		}

		w.WriteHeader(http.StatusOK)
		w.Write([]byte("Clusters connected"))
	})

	mux.HandleFunc("/leader", func(w http.ResponseWriter, r *http.Request) {
		if getLeaderStatus() {
			w.WriteHeader(http.StatusOK)
			w.Write([]byte(fmt.Sprintf("Leader: %s", *podName)))
		} else {
			w.WriteHeader(http.StatusOK)
			w.Write([]byte("Follower"))
		}
	})

	server := &http.Server{
		Addr:    ":" + strconv.Itoa(httpPort),
		Handler: mux,
	}

	logInfo("starting HTTP server on port %d with endpoints: /health, /ready, /leader", httpPort)

	go func() {
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logErr("HTTP server error: %v", err)
		}
	}()

	go func() {
		<-ctx.Done()
		logInfo("shutting down HTTP server")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := server.Shutdown(shutdownCtx); err != nil {
			logErr("HTTP server shutdown error: %v", err)
		}
	}()
}

// -------------------------------------------------------------------------
// Watchers
// -------------------------------------------------------------------------
func watchServices(ctx context.Context, src, dst KubernetesClient) error {
	w, err := src.CoreV1().Services(*srcNS).Watch(ctx, metav1.ListOptions{
		Watch: true,
	})
	if err != nil {
		return err
	}
	defer w.Stop()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case ev, ok := <-w.ResultChan():
			if !ok {
				return fmt.Errorf("service watch channel closed")
			}
			if !getLeaderStatus() {
				return fmt.Errorf("no longer leader")
			}
			if svc, ok := ev.Object.(*corev1.Service); ok {
				handleServiceEvent(ctx, src, dst, svc, string(ev.Type))
			}
		}
	}
}

func watchEndpoints(ctx context.Context, src, dst KubernetesClient) error {
 w, err := src.CoreV1().Endpoints(*srcNS).Watch(ctx, metav1.ListOptions{
  Watch: true,
 })
 if err != nil {
  return err
 }
 defer w.Stop()

 for {
  select {
  case <-ctx.Done():
   return ctx.Err()
  case ev, ok := <-w.ResultChan():
   if !ok {
    return fmt.Errorf("endpoints watch channel closed")
   }
   if !getLeaderStatus() {
    return fmt.Errorf("no longer leader")
   }
   if eps, ok := ev.Object.(*corev1.Endpoints); ok {
    // Only process endpoints for services that are currently being synced
    if isServiceSynced(eps.Name) {
     // Additional check: verify the source service still has sync=true label
     srcSvc, err := src.CoreV1().Services(*srcNS).Get(ctx, eps.Name, metav1.GetOptions{})
     if err != nil {
      logErr("error getting source service %s for endpoints sync: %v", eps.Name, err)
      continue
     }

     // Skip if service no longer has sync=true label
     if srcSvc.Labels["sync"] != "true" {
      continue
     }

     // Get OLD state from destination BEFORE sync
     oldIPs := []string{}
     if dstEps, err := dst.CoreV1().Endpoints(*dstNS).Get(ctx, eps.Name, metav1.GetOptions{}); err == nil {
      oldIPs = readyIPs(dstEps)
     }

     result, err := syncServiceWithResult(ctx, src, dst, eps.Name)
     if err != nil {
      logErr("error syncing endpoints for service %s: %v", eps.Name, err)
     } else if result.EndpointsUpdated {
      // Get ACTUAL final state from destination AFTER sync
      actualFinalIPs := []string{}
      if dstEps, err := dst.CoreV1().Endpoints(*dstNS).Get(ctx, eps.Name, metav1.GetOptions{}); err == nil {
       actualFinalIPs = readyIPs(dstEps)
      }

      sort.Strings(oldIPs)
      sort.Strings(actualFinalIPs)

      // Calculate added and removed IPs based on actual final state
      added, removed := calculateIPChanges(oldIPs, actualFinalIPs)

      if len(added) > 0 || len(removed) > 0 {
       var changeInfo strings.Builder
       if len(added) > 0 {
        changeInfo.WriteString(fmt.Sprintf(" added: %v (%d)", added, len(added)))
       }
       if len(removed) > 0 {
        if changeInfo.Len() > 0 {
         changeInfo.WriteString(",")
        }
        changeInfo.WriteString(fmt.Sprintf(" removed: %v (%d)", removed, len(removed)))
       }

       logInfo("endpoints updated for service %s: %v -> %v%s", eps.Name, oldIPs, actualFinalIPs, changeInfo.String())
      } else {
       logInfo("endpoints updated for service %s: %v -> %v", eps.Name, oldIPs, actualFinalIPs)
      }
     }
    }
   }
  }
 }
}

func calculateIPChanges(oldIPs, newIPs []string) (added []string, removed []string) {
 oldSet := make(map[string]bool)
 newSet := make(map[string]bool)

 for _, ip := range oldIPs {
  oldSet[ip] = true
 }

 for _, ip := range newIPs {
  newSet[ip] = true
 }

 // Find added IPs (in new but not in old)
 for _, ip := range newIPs {
  if !oldSet[ip] {
   added = append(added, ip)
  }
 }

 // Find removed IPs (in old but not in new)
 for _, ip := range oldIPs {
  if !newSet[ip] {
   removed = append(removed, ip)
  }
 }

 sort.Strings(added)
 sort.Strings(removed)

 return added, removed
}

func handleServiceEvent(ctx context.Context, src, dst KubernetesClient, svc *corev1.Service, eventType string) {
	shouldSyncNow := svc.Labels["sync"] == "true"
	wasSyncing := isServiceSynced(svc.Name)

	switch {
	case shouldSyncNow && !wasSyncing:
		// Start syncing this service
		setSyncedService(svc.Name, true)
		syncedList := getSyncedServicesList()
		logInfo("started syncing service %s, currently tracking: %v", svc.Name, syncedList)

		result, err := performInitialServiceSyncWithResult(ctx, src, dst, svc.Name)
		if err != nil {
			logErr("initial sync error for %s: %v", svc.Name, err)
		} else {
			logInfo("initial sync completed for service %s", svc.Name)
		}
		_ = result // use result variable to avoid unused variable warning

	case !shouldSyncNow && wasSyncing:
		// FIRST remove from tracking to prevent race conditions with endpoints watcher
		setSyncedService(svc.Name, false)

		// THEN delete the service
		if err := removeService(ctx, dst, svc.Name); err != nil {
			logErr("error removing service %s: %v", svc.Name, err)
		} else {
			syncedList := getSyncedServicesList()
			logInfo("stopped syncing service %s, currently tracking: %v", svc.Name, syncedList)
		}

	case eventType == "DELETED" && wasSyncing:
		// FIRST remove from tracking
		setSyncedService(svc.Name, false)

		// THEN delete the service
		if err := removeService(ctx, dst, svc.Name); err != nil {
			logErr("error removing service %s: %v", svc.Name, err)
		} else {
			syncedList := getSyncedServicesList()
			logInfo("service %s was deleted, stopped tracking, currently tracking: %v", svc.Name, syncedList)
		}

	case shouldSyncNow && wasSyncing:
		// Service is being synced and still should be synced - check for updates
		result, err := performInitialServiceSyncWithResult(ctx, src, dst, svc.Name)
		if err != nil {
			logErr("sync update error for %s: %v", svc.Name, err)
		}
		_ = result // use result variable to avoid unused variable warning

		// Ignore case: !shouldSyncNow && !wasSyncing (service without sync label, not being tracked)
	}
}

// -------------------------------------------------------------------------
// Sync logic - Updated to use interface
// -------------------------------------------------------------------------
func syncAllServices(ctx context.Context, src, dst KubernetesClient) error {
	services, err := src.CoreV1().Services(*srcNS).List(ctx, metav1.ListOptions{
		LabelSelector: *syncLabel,
	})
	if err != nil {
		return fmt.Errorf("list services: %w", err)
	}

	if len(services.Items) == 0 {
		logInfo("no services found with label %s", *syncLabel)
		return nil
	}

	// Check for services that should be deleted (exist in dst but not in src with sync label)
	dstServices, err := dst.CoreV1().Services(*dstNS).List(ctx, metav1.ListOptions{
		LabelSelector: "sync=true-external",
	})
	if err != nil {
		return fmt.Errorf("list destination services: %w", err)
	}

	srcServiceNames := make(map[string]bool)
	for _, svc := range services.Items {
		srcServiceNames[svc.Name] = true
	}

	// Delete services that no longer exist in source
	for _, dstSvc := range dstServices.Items {
		if !srcServiceNames[dstSvc.Name] {
			setSyncedService(dstSvc.Name, false)
			if err := removeService(ctx, dst, dstSvc.Name); err != nil {
				logErr("error removing obsolete service %s: %v", dstSvc.Name, err)
			}
		}
	}

	syncedServicesCount := 0
	for _, svc := range services.Items {
		setSyncedService(svc.Name, true)
		syncedServicesCount++

		result, err := performInitialServiceSyncWithResult(ctx, src, dst, svc.Name)
		if err != nil {
			logErr("sync error for %s: %v", svc.Name, err)
			continue
		}
		_ = result // use result variable to avoid unused variable warning
	}

	if syncedServicesCount > 0 {
		logInfo("synchronized %d services with label %s", syncedServicesCount, *syncLabel)
	}

	return nil
}

// Sync result structure
type SyncResult struct {
	ServicesCreated  int
	ServicesUpdated  int
	ServicesDeleted  int
	EndpointsUpdated int
}

func (r SyncResult) hasChanges() bool {
	return r.ServicesCreated > 0 || r.ServicesUpdated > 0 || r.ServicesDeleted > 0 || r.EndpointsUpdated > 0
}

func syncAllServicesWithResult(ctx context.Context, src, dst KubernetesClient) (SyncResult, error) {
	var result SyncResult

	services, err := src.CoreV1().Services(*srcNS).List(ctx, metav1.ListOptions{
		LabelSelector: *syncLabel,
	})
	if err != nil {
		return result, fmt.Errorf("list services: %w", err)
	}

	if len(services.Items) == 0 {
		return result, nil
	}

	// Check for services that should be deleted (exist in dst but not in src with sync label)
	dstServices, err := dst.CoreV1().Services(*dstNS).List(ctx, metav1.ListOptions{
		LabelSelector: "sync=true-external",
	})
	if err != nil {
		return result, fmt.Errorf("list destination services: %w", err)
	}

	srcServiceNames := make(map[string]bool)
	for _, svc := range services.Items {
		srcServiceNames[svc.Name] = true
	}

	// Delete services that no longer exist in source
	for _, dstSvc := range dstServices.Items {
		if !srcServiceNames[dstSvc.Name] {
			setSyncedService(dstSvc.Name, false)
			if err := removeService(ctx, dst, dstSvc.Name); err != nil {
				logErr("error removing obsolete service %s: %v", dstSvc.Name, err)
			} else {
				result.ServicesDeleted++
			}
		}
	}

	// Track service names for logging
	var syncedServiceNames []string

	for _, svc := range services.Items {
		setSyncedService(svc.Name, true)
		syncedServiceNames = append(syncedServiceNames, svc.Name)

		syncResult, err := performInitialServiceSyncWithResult(ctx, src, dst, svc.Name)
		if err != nil {
			logErr("sync error for %s: %v", svc.Name, err)
			continue
		}

		if syncResult.ServiceCreated {
			result.ServicesCreated++
		} else if syncResult.ServiceUpdated {
			result.ServicesUpdated++
		}

		if syncResult.EndpointsUpdated {
			result.EndpointsUpdated++
		}
	}

	if len(syncedServiceNames) > 0 {
		sort.Strings(syncedServiceNames)
		logInfo("synchronized services: %v", syncedServiceNames)
	}

	return result, nil
}

// ServiceSyncResult represents the result of syncing a single service
type ServiceSyncResult struct {
	ServiceCreated   bool
	ServiceUpdated   bool
	EndpointsUpdated bool
}

func performInitialServiceSyncWithResult(ctx context.Context, src, dst KubernetesClient, serviceName string) (ServiceSyncResult, error) {
	var result ServiceSyncResult

	srcSvc, err := src.CoreV1().Services(*srcNS).Get(ctx, serviceName, metav1.GetOptions{})
	if err != nil {
		return result, fmt.Errorf("get source service: %w", err)
	}

	if srcSvc.Spec.Type == corev1.ServiceTypeExternalName {
		syncResult, err := syncExternalNameServiceWithResult(ctx, dst, srcSvc, serviceName)
		return syncResult, err
	}

	eps, err := src.CoreV1().Endpoints(*srcNS).Get(ctx, serviceName, metav1.GetOptions{})
	if err != nil {
		return result, nil // No endpoints yet
	}

	ips := readyIPs(eps)
	if len(ips) == 0 {
		return result, nil // No ready addresses yet
	}

	return syncServiceWithResult(ctx, src, dst, serviceName)
}

func syncExternalNameServiceWithResult(ctx context.Context, dst KubernetesClient, srcSvc *corev1.Service, serviceName string) (ServiceSyncResult, error) {
	var result ServiceSyncResult

	if _, err := dst.CoreV1().Namespaces().Get(ctx, *dstNS, metav1.GetOptions{}); err != nil {
		if _, err := dst.CoreV1().Namespaces().Create(ctx, &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: *dstNS}}, metav1.CreateOptions{}); err != nil {
			return result, err
		}
	}

	existingSvc, err := dst.CoreV1().Services(*dstNS).Get(ctx, serviceName, metav1.GetOptions{})
	if err != nil {
		svc := &corev1.Service{
			ObjectMeta: metav1.ObjectMeta{
				Name:      serviceName,
				Namespace: *dstNS,
				Labels:    map[string]string{"sync": "true-external"},
			},
			Spec: corev1.ServiceSpec{
				Type:         corev1.ServiceTypeExternalName,
				ExternalName: srcSvc.Spec.ExternalName,
				Ports:        srcSvc.Spec.Ports,
			},
		}
		if _, err := dst.CoreV1().Services(*dstNS).Create(ctx, svc, metav1.CreateOptions{}); err != nil {
			return result, fmt.Errorf("create ExternalName service: %w", err)
		}
		result.ServiceCreated = true
		return result, nil
	}

	if existingSvc.Labels["sync"] != "true-external" {
		return result, nil
	}

	if existingSvc.Spec.Type == corev1.ServiceTypeExternalName &&
		existingSvc.Spec.ExternalName == srcSvc.Spec.ExternalName {
		return result, nil
	}

	existingSvc.Spec.Type = corev1.ServiceTypeExternalName
	existingSvc.Spec.ExternalName = srcSvc.Spec.ExternalName
	existingSvc.Spec.Ports = srcSvc.Spec.Ports
	existingSvc.Spec.ClusterIP = ""

	if _, err := dst.CoreV1().Services(*dstNS).Update(ctx, existingSvc, metav1.UpdateOptions{}); err != nil {
		return result, fmt.Errorf("update ExternalName service: %w", err)
	}
	result.ServiceUpdated = true
	return result, nil
}

func syncServiceWithResult(ctx context.Context, src, dst KubernetesClient, serviceName string) (ServiceSyncResult, error) {
 var result ServiceSyncResult

 srcSvc, err := src.CoreV1().Services(*srcNS).Get(ctx, serviceName, metav1.GetOptions{})
 if err != nil {
  return result, fmt.Errorf("get src service: %w", err)
 }

 if srcSvc.Spec.Type == corev1.ServiceTypeExternalName {
  return syncExternalNameServiceWithResult(ctx, dst, srcSvc, serviceName)
 }

 eps, err := src.CoreV1().Endpoints(*srcNS).Get(ctx, serviceName, metav1.GetOptions{})
 if err != nil {
  return result, fmt.Errorf("get src endpoints: %w", err)
 }
 ips := readyIPs(eps)

 var servicePorts []corev1.ServicePort
 var endpointPorts []corev1.EndpointPort

 if len(srcSvc.Spec.Ports) > 0 {
  servicePorts = make([]corev1.ServicePort, len(srcSvc.Spec.Ports))
  endpointPorts = make([]corev1.EndpointPort, len(srcSvc.Spec.Ports))

  for i, port := range srcSvc.Spec.Ports {
   servicePorts[i] = corev1.ServicePort{
    Name:       port.Name,
    Protocol:   port.Protocol,
    Port:       port.Port,
    TargetPort: port.TargetPort,
   }
   endpointPorts[i] = corev1.EndpointPort{
    Name:     port.Name,
    Port:     port.Port,
    Protocol: port.Protocol,
   }
  }
 } else {
  return result, nil
 }

 if _, err := dst.CoreV1().Namespaces().Get(ctx, *dstNS, metav1.GetOptions{}); err != nil {
  if _, err := dst.CoreV1().Namespaces().Create(ctx, &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: *dstNS}}, metav1.CreateOptions{}); err != nil {
   return result, err
  }
 }

 existingSvc, err := dst.CoreV1().Services(*dstNS).Get(ctx, serviceName, metav1.GetOptions{})
 if err != nil {
  // Service doesn't exist, create new one
  svc := &corev1.Service{
   ObjectMeta: metav1.ObjectMeta{
    Name:      serviceName,
    Namespace: *dstNS,
    Labels:    map[string]string{"sync": "true-external"},
   },
   Spec: corev1.ServiceSpec{
    Type:  corev1.ServiceTypeClusterIP,
    Ports: servicePorts,
   },
  }
  if _, err := dst.CoreV1().Services(*dstNS).Create(ctx, svc, metav1.CreateOptions{}); err != nil {
   if strings.Contains(err.Error(), "already exists") {
    result.ServiceUpdated = true
   } else {
    return result, fmt.Errorf("create service: %w", err)
   }
  } else {
   result.ServiceCreated = true
  }
 } else {
  // Service exists, check if it's managed by sync
  if existingSvc.Labels["sync"] != "true-external" {
   // Take ownership of existing service
   if existingSvc.Labels == nil {
    existingSvc.Labels = make(map[string]string)
   }
   existingSvc.Labels["sync"] = "true-external"
   existingSvc.Spec.Ports = servicePorts

   if _, err := dst.CoreV1().Services(*dstNS).Update(ctx, existingSvc, metav1.UpdateOptions{}); err != nil {
    return result, fmt.Errorf("take ownership of existing service: %w", err)
   }
   result.ServiceUpdated = true
  }
 }

 // Handle endpoints - create/update/clear based on source IPs
 cur, err := dst.CoreV1().Endpoints(*dstNS).Get(ctx, serviceName, metav1.GetOptions{})
 if err != nil {
  // Endpoints don't exist
  if len(ips) > 0 {
   // Create endpoints with IPs
   desired := &corev1.Endpoints{
    ObjectMeta: metav1.ObjectMeta{Name: serviceName, Namespace: *dstNS},
    Subsets: []corev1.EndpointSubset{{
     Addresses: toEPAddrs(ips),
     Ports:     endpointPorts,
    }},
   }
   if _, err := dst.CoreV1().Endpoints(*dstNS).Create(ctx, desired, metav1.CreateOptions{}); err != nil {
    if strings.Contains(err.Error(), "already exists") {
     result.EndpointsUpdated = true
    } else {
     return result, fmt.Errorf("create endpoints: %w", err)
    }
   } else {
    result.EndpointsUpdated = true
   }
  } else {
   // Create empty endpoints
   desired := &corev1.Endpoints{
    ObjectMeta: metav1.ObjectMeta{Name: serviceName, Namespace: *dstNS},
    Subsets:    []corev1.EndpointSubset{},
   }
   if _, err := dst.CoreV1().Endpoints(*dstNS).Create(ctx, desired, metav1.CreateOptions{}); err != nil {
    if !strings.Contains(err.Error(), "already exists") {
     return result, fmt.Errorf("create empty endpoints: %w", err)
    }
   } else {
    result.EndpointsUpdated = true
   }
  }
  return result, nil
 }

 // Endpoints exist - check if update is needed
 currentIPs := readyIPs(cur)

 if len(ips) == 0 {
  // Source has no ready IPs - clear destination endpoints
  if len(currentIPs) > 0 {
   desired := &corev1.Endpoints{
    ObjectMeta: metav1.ObjectMeta{
     Name:            serviceName,
     Namespace:       *dstNS,
     ResourceVersion: cur.ResourceVersion,
    },
    Subsets: []corev1.EndpointSubset{},
   }
   if _, err := dst.CoreV1().Endpoints(*dstNS).Update(ctx, desired, metav1.UpdateOptions{}); err != nil {
    return result, fmt.Errorf("clear endpoints: %w", err)
   }
   result.EndpointsUpdated = true
  }
 } else {
  // Source has ready IPs - sync them
  if !sameIPs(cur, ips) {
   desired := &corev1.Endpoints{
    ObjectMeta: metav1.ObjectMeta{
     Name:            serviceName,
     Namespace:       *dstNS,
     ResourceVersion: cur.ResourceVersion,
    },
    Subsets: []corev1.EndpointSubset{{
     Addresses: toEPAddrs(ips),
     Ports:     endpointPorts,
    }},
   }
   if _, err := dst.CoreV1().Endpoints(*dstNS).Update(ctx, desired, metav1.UpdateOptions{}); err != nil {
    return result, fmt.Errorf("update endpoints: %w", err)
   }
   result.EndpointsUpdated = true
  }
 }

 return result, nil
}

func removeService(ctx context.Context, dst KubernetesClient, serviceName string) error {
	if err := dst.CoreV1().Services(*dstNS).Delete(ctx, serviceName, metav1.DeleteOptions{}); err != nil {
		if !strings.Contains(err.Error(), "not found") {
			return fmt.Errorf("delete service: %w", err)
		}
	}

	if err := dst.CoreV1().Endpoints(*dstNS).Delete(ctx, serviceName, metav1.DeleteOptions{}); err != nil {
		if !strings.Contains(err.Error(), "not found") {
			return fmt.Errorf("delete endpoints: %w", err)
		}
	}

	return nil
}

// -------------------------------------------------------------------------
// Service tracking helpers
// -------------------------------------------------------------------------
func isServiceSynced(serviceName string) bool {
	syncMutex.RLock()
	defer syncMutex.RUnlock()
	return syncedServices[serviceName]
}

func setSyncedService(serviceName string, synced bool) {
	syncMutex.Lock()
	defer syncMutex.Unlock()
	if synced {
		syncedServices[serviceName] = true
	} else {
		delete(syncedServices, serviceName)
	}
}

func getSyncedServicesList() []string {
	syncMutex.RLock()
	defer syncMutex.RUnlock()

	var services []string
	for serviceName := range syncedServices {
		services = append(services, serviceName)
	}
	sort.Strings(services)
	return services
}

// -------------------------------------------------------------------------
// Helpers
// -------------------------------------------------------------------------
func readyIPs(eps *corev1.Endpoints) []string {
	var ips []string
	for _, ss := range eps.Subsets {
		for _, a := range ss.Addresses {
			ips = append(ips, a.IP)
		}
	}
	// Ensure we always return an initialized slice, never nil
	if ips == nil {
		return []string{}
	}
	return ips
}

func sameIPs(eps *corev1.Endpoints, ips []string) bool {
	if len(eps.Subsets) == 0 || len(eps.Subsets[0].Addresses) != len(ips) {
		return false
	}
	set := make(map[string]struct{}, len(ips))
	for _, ip := range ips {
		set[ip] = struct{}{}
	}
	for _, a := range eps.Subsets[0].Addresses {
		if _, ok := set[a.IP]; !ok {
			return false
		}
	}
	return true
}

func toEPAddrs(ips []string) []corev1.EndpointAddress {
	out := make([]corev1.EndpointAddress, len(ips))
	for i, ip := range ips {
		out[i] = corev1.EndpointAddress{IP: ip}
	}
	return out
}

// -------------------------------------------------------------------------
// Logging
// -------------------------------------------------------------------------
func logInfo(format string, a ...interface{}) {
	fmt.Printf("%s [%s] "+format+"\n", append([]interface{}{time.Now().Format("2006-01-02 15:04:05"), *podName}, a...)...)
}

func logErr(format string, a ...interface{}) {
	fmt.Fprintf(os.Stderr, "%s [%s] "+format+"\n", append([]interface{}{time.Now().Format("2006-01-02 15:04:05"), *podName}, a...)...)
}

// -------------------------------------------------------------------------
// Misc helpers
// -------------------------------------------------------------------------
func clientFor(kubeconfig, ctxName string) (*kubernetes.Clientset, error) {
	rules := clientcmd.NewDefaultClientConfigLoadingRules()
	if kubeconfig != "" {
		rules.ExplicitPath = kubeconfig
	}
	cfg, err := clientcmd.NewNonInteractiveDeferredLoadingClientConfig(rules, &clientcmd.ConfigOverrides{CurrentContext: ctxName, ClusterInfo: clientcmdapi.Cluster{}}).ClientConfig()
	if err != nil {
		return nil, err
	}
	return kubernetes.NewForConfig(cfg)
}

func must(err error) {
	if err != nil {
		logErr("fatal: %v", err)
		os.Exit(1)
	}
}
