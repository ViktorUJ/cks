#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** worker PC bootstrap: CKS lab 110"
until [[ "$(kubectl get nodes --no-headers 2>/dev/null | awk '$2 == "Ready" {count++} END {print count+0}')" -ge 2 ]]; do sleep 5; done

arch=$(uname -m)
case "$arch" in
  x86_64) arch=amd64 ;;
  aarch64) arch=arm64 ;;
  *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
esac

CILIUM_CLI_VERSION=v0.19.7
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
curl -fsSL -o "$tmpdir/cilium-linux-${arch}.tar.gz" \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${arch}.tar.gz"
curl -fsSL -o "$tmpdir/cilium-linux-${arch}.tar.gz.sha256sum" \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${arch}.tar.gz.sha256sum"
(cd "$tmpdir" && sha256sum --check "cilium-linux-${arch}.tar.gz.sha256sum")
sudo tar -xzf "$tmpdir/cilium-linux-${arch}.tar.gz" -C /usr/local/bin cilium

# Istio latest verified 2026-08-31 (1.30.4, published 2026-08-27); linux-amd64/arm64
# assets confirmed present. Istio 1.30 supports Kubernetes 1.32-1.36 (compatible with the
# lab cluster). Verify the newest supported release before each course build.
ISTIO_VERSION=1.30.4
curl -fsSL "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-${arch}.tar.gz" \
  | tar -xz -C "$tmpdir"
sudo install -m 0755 "$tmpdir/istio-${ISTIO_VERSION}/bin/istioctl" /usr/local/bin/istioctl

cilium version --client
istioctl version --remote=false

echo "*** cilium CLI and istioctl are ready; cluster context is configured"
