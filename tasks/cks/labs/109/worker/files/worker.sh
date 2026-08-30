#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
CTX="cluster1-admin@cluster1"
ETCD_VERSION="3.6.0"
ETCD_DIR="/var/lib/cks-109/etcd"

echo "*** CKS lab 109 worker bootstrap"
until kubectl get nodes --context "$CTX" --no-headers >/dev/null 2>&1; do sleep 5; done
for attempt in {1..24}; do
  if ssh -o BatchMode=yes -o ConnectTimeout=5 control-plane 'sudo -n true' >/dev/null 2>&1; then break; fi
  sleep 5
  if [[ "$attempt" == 24 ]]; then echo "control-plane SSH is unavailable" >&2; exit 1; fi
done

arch=$(dpkg --print-architecture)
case "$arch" in amd64) etcd_arch=amd64 ;; arm64) etcd_arch=arm64 ;; *) echo "unsupported architecture: $arch" >&2; exit 1 ;; esac
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
curl -fsSL "https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-${etcd_arch}.tar.gz" -o "$workdir/etcd.tgz"
tar -xzf "$workdir/etcd.tgz" -C "$workdir"
install -m 0755 "$workdir/etcd-v${ETCD_VERSION}-linux-${etcd_arch}/etcdctl" /usr/local/bin/etcdctl

# The private etcd client material is copied only to a root-owned directory on this
# disposable lab worker. The SSH tunnel keeps etcd bound to loopback on the control-plane.
install -d -m 0700 "$ETCD_DIR"
for file in ca.crt server.crt server.key; do
  ssh -o BatchMode=yes control-plane "sudo cat /etc/kubernetes/pki/etcd/${file}" >"${ETCD_DIR}/${file}"
done
chmod 0600 "$ETCD_DIR"/*

cat >/usr/local/bin/etcdctl-109 <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ETCD_DIR=/var/lib/cks-109/etcd
if ! ss -ltn 2>/dev/null | grep -q '127.0.0.1:23790'; then
  ssh -f -N -o BatchMode=yes -o ExitOnForwardFailure=yes \
    -L 127.0.0.1:23790:127.0.0.1:2379 control-plane
fi
exec env ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:23790 \
  --cacert="${ETCD_DIR}/ca.crt" \
  --cert="${ETCD_DIR}/server.crt" \
  --key="${ETCD_DIR}/server.key" "$@"
EOF
chmod 0755 /usr/local/bin/etcdctl-109

install -d -o ubuntu -g ubuntu -m 0755 /var/work/109
kubectl config use-context "$CTX" >/dev/null
echo "*** etcdctl $(etcdctl version | head -n1) is ready; use etcdctl-109 for the tunnelled lab endpoint"
