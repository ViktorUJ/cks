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
	"k8s.io/client-go/tools/clientcmd"
	clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
	"k8s.io/client-go/tools/leaderelection"
	"k8s.io/client-go/tools/leaderelection/resourcelock"
)

// -------------------------------------------------------------------------
// Flags
// -------------------------------------------------------------------------
var (
	kubeconfig              = flag.String("kubeconfig", os.Getenv("KUBECONFIG"), "path to kubeconfig; leave empty for default")
	srcCtx                  = flag.String("src-context", "local-cluster", "source kube context")
	dstCtx                  = flag.String("dst-context", "external-cluster", "destination kube context")
	srcNS                   = flag.String("src-ns", "default", "source namespace")
	dstNS                   = flag.String("dst-ns", "prod-test", "destination namespace")
	port                    = flag.Int("port", 8080, "fallback service port if source service has no ports defined")
	syncLabel               = flag.String("sync-label", "sync=true", "label selector for services to sync")
	leaderElectionNamespace = flag.String("leader-election-namespace", "k8s-sync", "namespace for leader election")
	leaderElectionName      = flag.String("leader-election-name", "k8s-svc-sync-leader", "name for leader election")
	podName                 = flag.String("pod-name", os.Getenv("HOSTNAME"), "pod name for leader election")
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
func startLeaderElection(ctx context.Context, leaderClient, srcClient, dstClient *kubernetes.Clientset) {
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
func startSyncOperations(ctx context.Context, srcClient, dstClient *kubernetes.Clientset) {
	logInfo("starting mirror for services with label %s: %s/%s → %s/%s", *syncLabel, *srcCtx, *srcNS, *dstCtx, *dstNS)

	// Initial full sync
	if err := syncAllServices(ctx, srcClient, dstClient); err != nil {
		logErr("initial sync failed: %v", err)
	} else {
		logInfo("initial sync complete")
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

	wg.Wait()
}

// -------------------------------------------------------------------------
// HTTP Server for health and readiness checks
// -------------------------------------------------------------------------
func startHTTPServer(ctx context.Context, srcClient, dstClient *kubernetes.Clientset) {
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
func watchServices(ctx context.Context, src, dst *kubernetes.Clientset) error {
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

func watchEndpoints(ctx context.Context, src, dst *kubernetes.Clientset) error {
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
						logInfo("skipping endpoints sync for %s - service no longer has sync=true label", eps.Name)
						continue
					}

					if err := syncService(ctx, src, dst, eps.Name); err != nil {
						logErr("error syncing endpoints for service %s: %v", eps.Name, err)
					}
				}
			}
		}
	}
}

func handleServiceEvent(ctx context.Context, src, dst *kubernetes.Clientset, svc *corev1.Service, eventType string) {
	shouldSyncNow := svc.Labels["sync"] == "true"
	wasSyncing := isServiceSynced(svc.Name)

	switch {
	case shouldSyncNow && !wasSyncing:
		// Start syncing this service
		setSyncedService(svc.Name, true)
		syncedList := getSyncedServicesList()
		logInfo("started syncing service %s, currently tracking: %v", svc.Name, syncedList)

		if err := performInitialServiceSync(ctx, src, dst, svc.Name); err != nil {
			logErr("initial sync error for %s: %v", svc.Name, err)
		} else {
			logInfo("initial sync completed for service %s", svc.Name)
		}

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
		if err := performInitialServiceSync(ctx, src, dst, svc.Name); err != nil {
			logErr("sync update error for %s: %v", svc.Name, err)
		}

		// Ignore case: !shouldSyncNow && !wasSyncing (service without sync label, not being tracked)
	}
}

// -------------------------------------------------------------------------
// Sync logic
// -------------------------------------------------------------------------
func syncAllServices(ctx context.Context, src, dst *kubernetes.Clientset) error {
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

	var serviceNames []string
	for _, svc := range services.Items {
		serviceNames = append(serviceNames, svc.Name)
	}

	logInfo("found %d services with label %s: %v", len(services.Items), *syncLabel, serviceNames)

	for _, svc := range services.Items {
		setSyncedService(svc.Name, true)
		if err := performInitialServiceSync(ctx, src, dst, svc.Name); err != nil {
			logErr("initial sync error for %s: %v", svc.Name, err)
		}
	}
	return nil
}

func performInitialServiceSync(ctx context.Context, src, dst *kubernetes.Clientset, serviceName string) error {
	srcSvc, err := src.CoreV1().Services(*srcNS).Get(ctx, serviceName, metav1.GetOptions{})
	if err != nil {
		return fmt.Errorf("get source service: %w", err)
	}

	if srcSvc.Spec.Type == corev1.ServiceTypeExternalName {
		return syncExternalNameService(ctx, dst, srcSvc, serviceName)
	}

	eps, err := src.CoreV1().Endpoints(*srcNS).Get(ctx, serviceName, metav1.GetOptions{})
	if err != nil {
		logInfo("no endpoints found for service %s yet, will sync when endpoints appear", serviceName)
		return nil
	}

	ips := readyIPs(eps)
	if len(ips) == 0 {
		logInfo("service %s has no ready addresses yet, will sync when ready addresses appear", serviceName)
		return nil
	}

	return syncService(ctx, src, dst, serviceName)
}

func syncService(ctx context.Context, src, dst *kubernetes.Clientset, serviceName string) error {
	srcSvc, err := src.CoreV1().Services(*srcNS).Get(ctx, serviceName, metav1.GetOptions{})
	if err != nil {
		return fmt.Errorf("get src service: %w", err)
	}

	if srcSvc.Spec.Type == corev1.ServiceTypeExternalName {
		return syncExternalNameService(ctx, dst, srcSvc, serviceName)
	}

	eps, err := src.CoreV1().Endpoints(*srcNS).Get(ctx, serviceName, metav1.GetOptions{})
	if err != nil {
		return fmt.Errorf("get src endpoints: %w", err)
	}
	ips := readyIPs(eps)
	if len(ips) == 0 {
		logInfo("service %s has no ready addresses, skipping", serviceName)
		return nil
	}

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
		servicePorts = []corev1.ServicePort{{Port: int32(*port)}}
		endpointPorts = []corev1.EndpointPort{{Port: int32(*port)}}
	}

	if _, err := dst.CoreV1().Namespaces().Get(ctx, *dstNS, metav1.GetOptions{}); err != nil {
		if _, err := dst.CoreV1().Namespaces().Create(ctx, &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: *dstNS}}, metav1.CreateOptions{}); err != nil {
			return err
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
				// Race condition: service was created between Get and Create
				// Try to get it again and update labels
				existingSvc, getErr := dst.CoreV1().Services(*dstNS).Get(ctx, serviceName, metav1.GetOptions{})
				if getErr != nil {
					return fmt.Errorf("get service after create conflict: %w", getErr)
				}

				// Update labels to mark as managed by sync
				if existingSvc.Labels == nil {
					existingSvc.Labels = make(map[string]string)
				}
				existingSvc.Labels["sync"] = "true-external"
				existingSvc.Spec.Ports = servicePorts

				if _, err := dst.CoreV1().Services(*dstNS).Update(ctx, existingSvc, metav1.UpdateOptions{}); err != nil {
					return fmt.Errorf("update service after create conflict: %w", err)
				}
				logInfo("updated existing service %s/%s with sync label and %d ports", *dstNS, serviceName, len(servicePorts))
			} else {
				return fmt.Errorf("create service: %w", err)
			}
		} else {
			logInfo("created service %s/%s with sync label and %d ports", *dstNS, serviceName, len(servicePorts))
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
				return fmt.Errorf("take ownership of existing service: %w", err)
			}
			logInfo("took ownership of existing service %s/%s and updated with sync label", *dstNS, serviceName)
		}
	}

	desired := &corev1.Endpoints{
		ObjectMeta: metav1.ObjectMeta{Name: serviceName, Namespace: *dstNS},
		Subsets: []corev1.EndpointSubset{{
			Addresses: toEPAddrs(ips),
			Ports:     endpointPorts,
		}},
	}

	cur, err := dst.CoreV1().Endpoints(*dstNS).Get(ctx, serviceName, metav1.GetOptions{})
	if err != nil {
		if _, err := dst.CoreV1().Endpoints(*dstNS).Create(ctx, desired, metav1.CreateOptions{}); err != nil {
			if strings.Contains(err.Error(), "already exists") {
				// Endpoints were created between Get and Create, try to update
				cur, getErr := dst.CoreV1().Endpoints(*dstNS).Get(ctx, serviceName, metav1.GetOptions{})
				if getErr != nil {
					return fmt.Errorf("get endpoints after create conflict: %w", getErr)
				}
				if !sameIPs(cur, ips) {
					desired.ResourceVersion = cur.ResourceVersion
					if _, err := dst.CoreV1().Endpoints(*dstNS).Update(ctx, desired, metav1.UpdateOptions{}); err != nil {
						return fmt.Errorf("update endpoints after create conflict: %w", err)
					}
					logInfo("[%s/%s/%s → %s/%s/%s] updated endpoints after conflict → %d IPs", *srcCtx, *srcNS, serviceName, *dstCtx, *dstNS, serviceName, len(ips))
				}
			} else {
				return fmt.Errorf("create endpoints: %w", err)
			}
		} else {
			logInfo("[%s/%s/%s → %s/%s/%s] created endpoints → %d IPs", *srcCtx, *srcNS, serviceName, *dstCtx, *dstNS, serviceName, len(ips))
		}
		return nil
	}

	if sameIPs(cur, ips) {
		return nil
	}

	desired.ResourceVersion = cur.ResourceVersion
	if _, err := dst.CoreV1().Endpoints(*dstNS).Update(ctx, desired, metav1.UpdateOptions{}); err != nil {
		return fmt.Errorf("update endpoints: %w", err)
	}
	logInfo("[%s/%s/%s → %s/%s/%s] updated endpoints → %d IPs", *srcCtx, *srcNS, serviceName, *dstCtx, *dstNS, serviceName, len(ips))
	return nil
}

func syncExternalNameService(ctx context.Context, dst *kubernetes.Clientset, srcSvc *corev1.Service, serviceName string) error {
	if _, err := dst.CoreV1().Namespaces().Get(ctx, *dstNS, metav1.GetOptions{}); err != nil {
		if _, err := dst.CoreV1().Namespaces().Create(ctx, &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: *dstNS}}, metav1.CreateOptions{}); err != nil {
			return err
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
			return fmt.Errorf("create ExternalName service: %w", err)
		}
		logInfo("created ExternalName service %s/%s → %s", *dstNS, serviceName, srcSvc.Spec.ExternalName)
		return nil
	}

	if existingSvc.Labels["sync"] != "true-external" {
		logInfo("ExternalName service %s/%s exists but not managed by sync (missing sync=true-external label), skipping", *dstNS, serviceName)
		return nil
	}

	if existingSvc.Spec.Type == corev1.ServiceTypeExternalName &&
		existingSvc.Spec.ExternalName == srcSvc.Spec.ExternalName {
		return nil
	}

	existingSvc.Spec.Type = corev1.ServiceTypeExternalName
	existingSvc.Spec.ExternalName = srcSvc.Spec.ExternalName
	existingSvc.Spec.Ports = srcSvc.Spec.Ports
	existingSvc.Spec.ClusterIP = ""

	if _, err := dst.CoreV1().Services(*dstNS).Update(ctx, existingSvc, metav1.UpdateOptions{}); err != nil {
		return fmt.Errorf("update ExternalName service: %w", err)
	}
	logInfo("updated ExternalName service %s/%s → %s", *dstNS, serviceName, srcSvc.Spec.ExternalName)
	return nil
}

func removeService(ctx context.Context, dst *kubernetes.Clientset, serviceName string) error {
	existingSvc, err := dst.CoreV1().Services(*dstNS).Get(ctx, serviceName, metav1.GetOptions{})
	if err != nil {
		logInfo("service %s/%s not found for deletion", *dstNS, serviceName)
		return nil
	}

	if existingSvc.Labels["sync"] != "true-external" {
		logInfo("service %s/%s exists but not managed by sync (missing sync=true-external label), skipping deletion", *dstNS, serviceName)
		return nil
	}

	if existingSvc.Spec.Type != corev1.ServiceTypeExternalName {
		if err := dst.CoreV1().Endpoints(*dstNS).Delete(ctx, serviceName, metav1.DeleteOptions{}); err != nil {
			logErr("failed to delete endpoints %s/%s: %v", *dstNS, serviceName, err)
		} else {
			logInfo("deleted endpoints %s/%s", *dstNS, serviceName)
		}
	}

	if err := dst.CoreV1().Services(*dstNS).Delete(ctx, serviceName, metav1.DeleteOptions{}); err != nil {
		logErr("failed to delete service %s/%s: %v", *dstNS, serviceName, err)
		return err
	}

	syncedList := getSyncedServicesList()
	logInfo("deleted service %s/%s, currently tracking: %v", *dstNS, serviceName, syncedList)

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