# k8s-svc-sync

## Description

`k8s-svc-sync` is a service for synchronizing EKS(Kubernetes) services and their endpoints between two clusters in real-time with periodic full synchronization to ensure consistency.

The program works using leader election mechanism to ensure high availability.

## Prerequisites
- VPCs where both clusters are located have network connectivity (e.g., through VPC Peering or Transit Gateway, etc.)
- CIDR ranges of VPCs do not overlap
- Amazon VPC CNI is used and pods have IP addresses from VPC CIDR
- `kubectl` is installed and access to both clusters is configured

## Key Features

- **Service synchronization** between source and destination clusters, and different namespaces
- **Selective synchronization** based on labels
- **Periodic full synchronization** to ensure consistency and recover from missed events
- **Leader Election** to ensure only one active instance is running
- **ExternalName services support**
- **Change monitoring** through Kubernetes Watch API
- **Health checks** through HTTP endpoints

## Architecture

### Components

1. **Leader Election** - uses Lease-based mechanism to select active instance
2. **Service Watcher** - monitors service changes in source cluster
3. **Endpoints Watcher** - monitors endpoints changes in source cluster
4. **Periodic Sync** - performs full synchronization at configured intervals
5. **HTTP Server** - provides health, readiness and leader status endpoints
6. **Sync Engine** - performs resource synchronization

### How it works

```
Source Cluster                    Destination Cluster
┌─────────────┐                  ┌────────────────────┐
│   Service   │ ────────────────▶│      Service       │
│ sync=true   │                  │ sync=true-external │
└─────────────┘                  └────────────────────┘
       │                                │
       ▼                                ▼
┌─────────────┐                  ┌─────────────┐
│  Endpoints  │ ────────────────▶│  Endpoints  │
└─────────────┘                  └─────────────┘
```

## Periodic Synchronization

The application performs periodic full synchronization in addition to real-time event-based synchronization:

- **Interval**: Configurable via `-sync-interval` flag (default: 3 minutes)
- **Purpose**: Ensures consistency and recovers from missed events
- **Scope**: Full synchronization of all services with `sync=true` label
- **Logging**: Reports changes detected during periodic sync

### Periodic Sync Behavior

1. **Initial sync**: Performed immediately when becoming leader
2. **Scheduled syncs**: Run at configured intervals
3. **Change detection**: Reports created, updated, and deleted services
4. **No-change optimization**: Logs "no changes" when everything is in sync

## Command Line Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-kubeconfig` | `$KUBECONFIG` | Path to kubeconfig file |
| `-src-context` | `local-cluster` | Source cluster context |
| `-dst-context` | `external-cluster` | Destination cluster context |
| `-src-ns` | `default` | Namespace in source cluster |
| `-dst-ns` | `prod-test` | Namespace in destination cluster |
| `-sync-label` | `sync=true` | Label selector for synchronization |
| `-leader-election-namespace` | `k8s-sync` | Namespace for leader election |
| `-leader-election-name` | `k8s-svc-sync-leader` | Name for leader election |
| `-pod-name` | `$HOSTNAME` | Pod name for leader election |
| `-sync-interval` | `3m` | Interval for periodic full synchronization |

## HTTP Endpoints

### `/health`
- **Method**: GET
- **Description**: Application health check
- **Response**: `200 OK` - application is running

### `/ready`
- **Method**: GET
- **Description**: Readiness check
- **Response**:
  - `200 OK` - connection to clusters established
  - `503 Service Unavailable` - connection issues

### `/leader`
- **Method**: GET
- **Description**: Leadership status
- **Response**:
  - `Leader: <pod-name>` - if instance is the leader
  - `Follower` - if instance is not the leader

## Deployment

#### 1. Setting up Service Account in external cluster

```bash
cd external
kubectl apply -f install_sa.yaml --context prod-old
```

#### 2. Generate and apply ConfigMap with kubeconfig for local cluster

```bash
cd ..
./generate_kubeconfig.sh
kubectl apply -f kubeconfig.yaml  # local cluster
```

### Apply manifests in local cluster

```
kubectl apply -f deploy/local/
```

### Deployment characteristics

- **Replicas**: 3 instances for high availability
- **Anti-affinity**: Pods are distributed across different nodes
- **Resources**:
  - Requests: 100m CPU, 128Mi Memory
  - Limits: 1000m CPU, 512Mi Memory
- **PodDisruptionBudget**: Minimum 1 available pod

## Synchronization Logic

### Services with `sync=true` label

1. **Discovery**: Service is marked with `sync=true` label
2. **Tracking**: Added to tracked services list
3. **Creation**: Similar service is created in destination cluster
4. **Endpoints synchronization**: Endpoints are automatically updated

### Service Types

#### ClusterIP services
- ClusterIP type service is created
- All ports from source service are synchronized
- Endpoints contain IP addresses of ready pods

#### ExternalName services
- ExternalName type service is created
- ExternalName and ports are copied
- Endpoints are not created

### Service Deletion

1. **Label removal**: When `sync=true` is removed, service stops being tracked and is deleted from destination cluster
2. **Service deletion**: When source service is deleted, destination service is deleted
3. **Protection**: Only services with `sync=true-external` label are deleted

## Monitoring and Logging

### Log Format

```
2024-01-15 10:30:45 [pod-name] message
```

### Event Types

- **INFO**: Informational messages about synchronization
- **ERROR**: Synchronization and cluster connection errors

### Log Examples

```bash
# Successful synchronization
2024-01-15 10:30:45 [k8s-svc-sync-abc123] [local-cluster/default/my-service → prod-cluster/prod-test/my-service] updated endpoints → 3 IPs

# Starting service tracking
2024-01-15 10:30:46 [k8s-svc-sync-abc123] started syncing service my-service, currently tracking: [my-service, other-service]

# Leader election
2024-01-15 10:30:47 [k8s-svc-sync-abc123] became leader, starting sync operations

# Periodic sync logs
2024-01-15 10:33:47 [k8s-svc-sync-abc123] performing periodic full sync
2024-01-15 10:33:48 [k8s-svc-sync-abc123] periodic sync completed - created: 1, updated: 2, deleted: 0, endpoints: 3
2024-01-15 10:33:48 [k8s-svc-sync-abc123] next periodic sync scheduled in 3m0s

# No changes during periodic sync
2024-01-15 10:36:48 [k8s-svc-sync-abc123] periodic sync completed - no changes
```

## Security Requirements

### RBAC Permissions

The application requires the following permissions:

**Source cluster**:
- `services`: get, list, watch
- `endpoints`: get, list, watch
- `leases`: get, list, create, update

**Destination cluster**:
- `services`: get, list, create, update, delete
- `endpoints`: get, list, create, update, delete
- `namespaces`: get, create

## Troubleshooting

### Common Issues

1. **Service not synchronizing**
   - Check for `sync=true` label presence
   - Ensure endpoints have ready addresses

2. **Cluster connection errors**
   - Check kubeconfig and API server availability
   - Verify context correctness

3. **Leader election not working**
   - Check RBAC permissions for lease resources
   - Ensure namespace for leader election exists

4. **Periodic sync issues**
   - Check logs for sync interval configuration
   - Verify leadership status during sync operations

### Status Check

```bash
# Health check
curl http://localhost:8080/health

# Readiness check
curl http://localhost:8080/ready

# Leadership check
curl http://localhost:8080/leader
```

## Usage Example

### Running locally

```bash
go build -o k8s-svc-sync .
./k8s-svc-sync \
  -src-context local-cluster \
  -dst-context prod-cluster \
  -src-ns default \
  -dst-ns production \
  -sync-interval 5m
```

### Marking service for synchronization

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  labels:
    sync: "true"  # This label enables synchronization
spec:
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
```
