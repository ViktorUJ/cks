// Build & run:
//   go mod tidy && go build -o mirror .
//   ./mirror -src-context israel-production -dst-context prod-madlan -port 8080
package main

import (
    "context"
    "flag"
    "fmt"
    "net/http"
    "os"
    "os/signal"
    "strconv"
    "sync"
    "syscall"
    "time"

    corev1 "k8s.io/api/core/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/tools/clientcmd"
    clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
)

// -------------------------------------------------------------------------
// Flags
// -------------------------------------------------------------------------
var (
    kubeconfig = flag.String("kubeconfig", os.Getenv("KUBECONFIG"), "path to kubeconfig; leave empty for default")
    srcCtx     = flag.String("src-context", "local-cluster", "source kube context")
    dstCtx     = flag.String("dst-context", "external-cluster", "destination kube context")
    srcNS      = flag.String("src-ns", "default", "source namespace")
    dstNS      = flag.String("dst-ns", "prod-test", "destination namespace")
    port       = flag.Int("port", 8080, "fallback service port if source service has no ports defined")
    syncLabel  = flag.String("sync-label", "sync=true", "label selector for services to sync")
)

// Track which services are currently being synced
var (
    syncedServices = make(map[string]bool)
    syncMutex      = sync.RWMutex{}
)

func main() {
    flag.Parse()

    srcClient, err := clientFor(*kubeconfig, *srcCtx)
    must(err)
    dstClient, err := clientFor(*kubeconfig, *dstCtx)
    must(err)

    ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
    defer stop()

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
            if err := watchServices(ctx, srcClient, dstClient); err != nil {
                logErr("service watch error: %v – retrying in 5s", err)
                select {
                case <-time.After(5 * time.Second):
                case <-ctx.Done():
                    return
                }
            } else {
                return
            }
        }
    }()

    wg.Add(1)
    go func() {
        defer wg.Done()
        for {
            if err := watchEndpoints(ctx, srcClient, dstClient); err != nil {
                logErr("endpoints watch error: %v – retrying in 5s", err)
                select {
                case <-time.After(5 * time.Second):
                case <-ctx.Done():
                    return
                }
            } else {
                return
            }
        }
    }()

    // Start HTTP server for health and readiness checks
    startHTTPServer(ctx, srcClient, dstClient)

    wg.Wait()
}

// -------------------------------------------------------------------------
// HTTP Server for health and readiness checks
// -------------------------------------------------------------------------
func startHTTPServer(ctx context.Context, srcClient, dstClient *kubernetes.Clientset) {
    httpPort := 8080
    mux := http.NewServeMux()

    // Health check endpoint - returns 200 OK if the process is running
    mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        w.Write([]byte("OK"))
    })

    // Readiness check endpoint - verifies connections to both Kubernetes clusters
    mux.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
        // Check source cluster connection
        _, srcErr := srcClient.CoreV1().Namespaces().Get(ctx, *srcNS, metav1.GetOptions{})

        // Check destination cluster connection
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

    server := &http.Server{
        Addr:    ":" + strconv.Itoa(httpPort),
        Handler: mux,
    }

    logInfo("starting HTTP server on port %d with endpoints: /health, /ready", httpPort)

    // Start HTTP server in its own goroutine
    go func() {
        if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            logErr("HTTP server error: %v", err)
        }
    }()

    // Ensure server gracefully shuts down when context is done
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
            if eps, ok := ev.Object.(*corev1.Endpoints); ok {
                // Only sync if service is being tracked
                if isServiceSynced(eps.Name) {
                    if err := syncService(ctx, src, dst, eps.Name); err != nil {
                        logErr("sync error for %s: %v", eps.Name, err)
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
        logInfo("started syncing service %s", svc.Name)

        // Immediately perform initial sync for this service
        if err := performInitialServiceSync(ctx, src, dst, svc.Name); err != nil {
            logErr("initial sync error for %s: %v", svc.Name, err)
        } else {
            logInfo("initial sync completed for service %s", svc.Name)
        }

    case !shouldSyncNow && wasSyncing:
        // Stop syncing this service
        setSyncedService(svc.Name, false)
        logInfo("stopped syncing service %s", svc.Name)
        if err := removeService(ctx, dst, svc.Name); err != nil {
            logErr("error removing service %s: %v", svc.Name, err)
        }

    case eventType == "DELETED" && wasSyncing:
        // Service was deleted, clean up
        setSyncedService(svc.Name, false)
        logInfo("service %s deleted, cleaning up", svc.Name)
        if err := removeService(ctx, dst, svc.Name); err != nil {
            logErr("error removing service %s: %v", svc.Name, err)
        }
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

    logInfo("found %d services with label %s", len(services.Items), *syncLabel)
    for _, svc := range services.Items {
        setSyncedService(svc.Name, true)
        if err := performInitialServiceSync(ctx, src, dst, svc.Name); err != nil {
            logErr("initial sync error for %s: %v", svc.Name, err)
        }
    }
    return nil
}

func performInitialServiceSync(ctx context.Context, src, dst *kubernetes.Clientset, serviceName string) error {
    // Get the service to check if it exists
    _, err := src.CoreV1().Services(*srcNS).Get(ctx, serviceName, metav1.GetOptions{})
    if err != nil {
        return fmt.Errorf("get source service: %w", err)
    }

    // Check if endpoints exist for this service
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

    // Always perform the sync - syncService will handle existing endpoints
    return syncService(ctx, src, dst, serviceName)
}

func syncService(ctx context.Context, src, dst *kubernetes.Clientset, serviceName string) error {
    // Get source service to extract port information
    srcSvc, err := src.CoreV1().Services(*srcNS).Get(ctx, serviceName, metav1.GetOptions{})
    if err != nil {
        return fmt.Errorf("get src service: %w", err)
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

    // Extract ports from source service
    var servicePorts []corev1.ServicePort
    var endpointPorts []corev1.EndpointPort

    if len(srcSvc.Spec.Ports) > 0 {
        servicePorts = make([]corev1.ServicePort, len(srcSvc.Spec.Ports))
        endpointPorts = make([]corev1.EndpointPort, len(srcSvc.Spec.Ports))

        for i, port := range srcSvc.Spec.Ports {
            servicePorts[i] = corev1.ServicePort{
                Name:       port.Name,
                Port:       port.Port,
                Protocol:   port.Protocol,
                TargetPort: port.TargetPort,
            }
            endpointPorts[i] = corev1.EndpointPort{
                Name:     port.Name,
                Port:     port.Port,
                Protocol: port.Protocol,
            }
        }
    } else {
        // Fallback to default port if source service has no ports
        servicePorts = []corev1.ServicePort{{Port: int32(*port)}}
        endpointPorts = []corev1.EndpointPort{{Port: int32(*port)}}
    }

    // Ensure namespace exists
    if _, err := dst.CoreV1().Namespaces().Get(ctx, *dstNS, metav1.GetOptions{}); err != nil {
        if _, err := dst.CoreV1().Namespaces().Create(ctx, &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: *dstNS}}, metav1.CreateOptions{}); err != nil {
            return err
        }
    }

    // Check if Service exists and if it's managed by us
    existingSvc, err := dst.CoreV1().Services(*dstNS).Get(ctx, serviceName, metav1.GetOptions{})
    if err != nil {
        // Service doesn't exist, create it with sync label
        svc := &corev1.Service{
            ObjectMeta: metav1.ObjectMeta{
                Name: serviceName,
                Labels: map[string]string{
                    "sync": "true",
                },
            },
            Spec: corev1.ServiceSpec{
                ClusterIP: corev1.ClusterIPNone,
                Ports:     servicePorts,
            },
        }
        if _, err := dst.CoreV1().Services(*dstNS).Create(ctx, svc, metav1.CreateOptions{}); err != nil {
            return err
        }
        logInfo("created service %s/%s with sync label and %d ports", *dstNS, serviceName, len(servicePorts))
    } else {
        // Service exists, check if it's managed by us
        if existingSvc.Labels["sync"] != "true" {
            logInfo("service %s/%s exists but not managed by sync (missing sync=true label), skipping", *dstNS, serviceName)
            return nil
        }
    }

    // Desired Endpoints
    desired := &corev1.Endpoints{
        ObjectMeta: metav1.ObjectMeta{Name: serviceName, Namespace: *dstNS},
        Subsets: []corev1.EndpointSubset{{
            Addresses: toEPAddrs(ips),
            Ports:     endpointPorts,
        }},
    }

    // Try to get existing endpoints
    cur, err := dst.CoreV1().Endpoints(*dstNS).Get(ctx, serviceName, metav1.GetOptions{})
    if err != nil {
        // Endpoints don't exist, create them
        if _, err := dst.CoreV1().Endpoints(*dstNS).Create(ctx, desired, metav1.CreateOptions{}); err != nil {
            return fmt.Errorf("create endpoints: %w", err)
        }
        logInfo("[%s/%s/%s → %s/%s/%s] created endpoints → %d IPs", *srcCtx, *srcNS, serviceName, *dstCtx, *dstNS, serviceName, len(ips))
        return nil
    }

    // Endpoints exist, check if update is needed
    if sameIPs(cur, ips) {
        return nil // No update needed
    }

    // Update existing endpoints
    desired.ResourceVersion = cur.ResourceVersion
    if _, err := dst.CoreV1().Endpoints(*dstNS).Update(ctx, desired, metav1.UpdateOptions{}); err != nil {
        return fmt.Errorf("update endpoints: %w", err)
    }
    logInfo("[%s/%s/%s → %s/%s/%s] updated endpoints → %d IPs", *srcCtx, *srcNS, serviceName, *dstCtx, *dstNS, serviceName, len(ips))
    return nil
}

func removeService(ctx context.Context, dst *kubernetes.Clientset, serviceName string) error {
    // Check if service exists and is managed by us before deletion
    existingSvc, err := dst.CoreV1().Services(*dstNS).Get(ctx, serviceName, metav1.GetOptions{})
    if err != nil {
        logInfo("service %s/%s not found for deletion", *dstNS, serviceName)
    } else {
        // Only delete if it has sync=true label
        if existingSvc.Labels["sync"] == "true" {
            if err := dst.CoreV1().Services(*dstNS).Delete(ctx, serviceName, metav1.DeleteOptions{}); err != nil {
                logErr("failed to delete service %s/%s: %v", *dstNS, serviceName, err)
            } else {
                logInfo("deleted service %s/%s", *dstNS, serviceName)
            }
        } else {
            logInfo("service %s/%s exists but not managed by sync (missing sync=true label), skipping deletion", *dstNS, serviceName)
        }
    }

    // Always try to remove endpoints (they don't have labels to check)
    if err := dst.CoreV1().Endpoints(*dstNS).Delete(ctx, serviceName, metav1.DeleteOptions{}); err != nil {
        logErr("failed to delete endpoints %s/%s: %v", *dstNS, serviceName, err)
    } else {
        logInfo("deleted endpoints %s/%s", *dstNS, serviceName)
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
    fmt.Printf("%s " + format + "\n", append([]interface{}{time.Now().Format("2006-01-02 15:04:05")}, a...)...)
}

func logErr(format string, a ...interface{}) {
    fmt.Fprintf(os.Stderr, "%s " + format + "\n", append([]interface{}{time.Now().Format("2006-01-02 15:04:05")}, a...)...)
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
