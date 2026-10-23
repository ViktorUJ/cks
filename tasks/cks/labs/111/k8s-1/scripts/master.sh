#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
printf '%s\n' '*** control-plane bootstrap CKS lab 111'
until kubectl get nodes --no-headers >/dev/null 2>&1; do sleep 5; done
# CKA-style one-node infrastructure: the control-plane is deliberately usable for lab workloads.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true
kubectl label node "$(hostname)" cks.io/lab=111 --overwrite

# ---------------------------------------------------------------------------
# Lab-owned OCI registry for tasks 3 and 9a-9c (replaces the public ttl.sh, whose uploads
# regularly hang). It must be reachable from three places, all by the SAME name, because the
# digest-pinned reference `<node-ip>:5000/catalog@sha256:...` is what ends up in the Deployment,
# the Kyverno policy and the signature:
#   * the worker (docker push, cosign sign)            -> plain HTTP over the VPC
#   * containerd on this node (kubelet image pull)     -> hosts.toml below
#   * Kyverno admission controller (signature check)   -> credentials.allowInsecureRegistry
NODE_NAME="$(hostname)"
NODE_IP=$(kubectl get node "$NODE_NAME" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
REGISTRY="${NODE_IP}:5000"
REGISTRY_DATA=/var/lib/cks111-registry

# containerd v2 ships with an empty registry config_path, so hosts.toml files are ignored until
# it points at certs.d.
if ! grep -q "config_path = '/etc/containerd/certs.d'" /etc/containerd/config.toml; then
  sed -i "/'io.containerd.cri.v1.images'.registry\]/{n;s#config_path = ''#config_path = '/etc/containerd/certs.d'#}" /etc/containerd/config.toml
fi
grep -q "config_path = '/etc/containerd/certs.d'" /etc/containerd/config.toml \
  || { echo "FATAL: could not enable containerd certs.d registry config" >&2; exit 1; }
install -d -m 0755 "/etc/containerd/certs.d/${REGISTRY}"
cat > "/etc/containerd/certs.d/${REGISTRY}/hosts.toml" <<EOF
server = "http://${REGISTRY}"

[host."http://${REGISTRY}"]
  capabilities = ["pull", "resolve"]
EOF
systemctl restart containerd
until kubectl get node "$NODE_NAME" --no-headers 2>/dev/null | grep -q ' Ready'; do sleep 3; done

install -d -m 0755 "$REGISTRY_DATA"
mkdir -p /etc/cks111
printf '%s\n' "$REGISTRY" > /etc/cks111/registry

# Persistent storage on the node itself (no StorageClass/provisioner exists in this cluster):
# a static `local` PV pinned to this node, bound through a PVC, so pushed images survive a
# registry Pod restart.
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: registry-111
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: cks111-local
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: cks111-registry
spec:
  capacity:
    storage: 5Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: cks111-local
  local:
    path: ${REGISTRY_DATA}
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: ["${NODE_NAME}"]
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: registry-data
  namespace: registry-111
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: cks111-local
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry
  namespace: registry-111
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: registry
  template:
    metadata:
      labels:
        app: registry
    spec:
      containers:
      - name: registry
        image: registry:2
        ports:
        - containerPort: 5000
          hostPort: 5000
        volumeMounts:
        - name: data
          mountPath: /var/lib/registry
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: registry-data
EOF
kubectl -n registry-111 rollout status deployment/registry --timeout=300s
curl --fail --silent --max-time 10 "http://${REGISTRY}/v2/" >/dev/null \
  || { echo "FATAL: lab registry ${REGISTRY} does not answer" >&2; exit 1; }
printf '%s\n' "*** lab registry ready at ${REGISTRY} (PV ${REGISTRY_DATA})"
