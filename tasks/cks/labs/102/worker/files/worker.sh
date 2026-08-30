#!/bin/bash
set -euo pipefail

echo "*** worker pc cks lab 102: Cilium NetworkPolicy and Hubble ***"
export KUBECONFIG=/root/.kube/config

CILIUM_CLI_VERSION="v0.18.8"
HUBBLE_VERSION="v1.18.3"
ARCH="amd64"

# Ждём API и Cilium, прежде чем включать relay и устанавливать клиенты.
until kubectl get nodes --no-headers >/dev/null 2>&1 && [ "$(kubectl get nodes --no-headers 2>/dev/null | wc -l)" -gt 0 ]; do
  echo "Waiting for a Kubernetes node..."
  sleep 5
done

curl -fsSL --retry 5 -o /tmp/cilium.tar.gz \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz"
tar -xzf /tmp/cilium.tar.gz -C /usr/local/bin cilium
rm -f /tmp/cilium.tar.gz

curl -fsSL --retry 5 -o /tmp/hubble.tar.gz \
  "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-${ARCH}.tar.gz"
tar -xzf /tmp/hubble.tar.gz -C /usr/local/bin hubble
rm -f /tmp/hubble.tar.gz

cilium status --wait
# Relay нужен для hubble observe с рабочей машины. Повторный запуск безопасен.
cilium hubble enable --relay --wait

echo "Cilium and Hubble CLIs are ready. Run 'cilium hubble port-forward &' before hubble observe."
