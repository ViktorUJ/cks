#!/usr/bin/env bash
set -euo pipefail

echo "*** worker pc cks lab 103 k8s-1"
export KUBECONFIG=/root/.kube/config
CTX="cluster1-admin@cluster1"
KUBE_BENCH_VERSION="0.10.0"

# Do not prepare the lab until the single control-plane node is visible through the
# same context used by tests and students.
echo "Waiting for a Kubernetes node..."
until kubectl get nodes --context "$CTX" --no-headers 2>/dev/null | grep -q .; do
  sleep 5
done

CONTROL_PLANE_IP=$(kubectl get nodes --context "$CTX" -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
printf '%s control-plane\n' "$CONTROL_PLANE_IP" >> /etc/hosts

# kube-bench ships its benchmark configuration alongside the binary. Keep the complete,
# pinned release on the worker so it can be copied to the control-plane for task 1.
arch=$(dpkg --print-architecture)
case "$arch" in
  amd64) release_arch="amd64" ;;
  arm64) release_arch="arm64" ;;
  *) echo "Unsupported architecture for kube-bench: $arch" >&2; exit 1 ;;
esac

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
curl -fsSL -o "$workdir/kube-bench.tar.gz" \
  "https://github.com/aquasecurity/kube-bench/releases/download/v${KUBE_BENCH_VERSION}/kube-bench_${KUBE_BENCH_VERSION}_linux_${release_arch}.tar.gz"
tar -xzf "$workdir/kube-bench.tar.gz" -C "$workdir"
install -d -m 0755 /opt/kube-bench
cp -a "$workdir"/cfg /opt/kube-bench/cfg
install -m 0755 "$workdir/kube-bench" /opt/kube-bench/kube-bench
ln -sf /opt/kube-bench/kube-bench /usr/local/bin/kube-bench

mkdir -p /var/work/tests/artifacts/{1,5,6}
chown -R ubuntu:ubuntu /var/work/tests/artifacts
