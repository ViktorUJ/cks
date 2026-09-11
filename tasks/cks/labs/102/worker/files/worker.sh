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

CILIUM_ARCHIVE="cilium-linux-${ARCH}.tar.gz"
curl -fsSL --retry 5 -o "/tmp/${CILIUM_ARCHIVE}" \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/${CILIUM_ARCHIVE}"
curl -fsSL --retry 5 -o "/tmp/${CILIUM_ARCHIVE}.sha256sum" \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/${CILIUM_ARCHIVE}.sha256sum"
(
  cd /tmp
  sha256sum --check "${CILIUM_ARCHIVE}.sha256sum"
)
tar -xzf "/tmp/${CILIUM_ARCHIVE}" -C /usr/local/bin cilium
rm -f "/tmp/${CILIUM_ARCHIVE}" "/tmp/${CILIUM_ARCHIVE}.sha256sum"

HUBBLE_ARCHIVE="hubble-linux-${ARCH}.tar.gz"
curl -fsSL --retry 5 -o "/tmp/${HUBBLE_ARCHIVE}" \
  "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/${HUBBLE_ARCHIVE}"
curl -fsSL --retry 5 -o "/tmp/${HUBBLE_ARCHIVE}.sha256sum" \
  "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/${HUBBLE_ARCHIVE}.sha256sum"
(
  cd /tmp
  sha256sum --check "${HUBBLE_ARCHIVE}.sha256sum"
)
tar -xzf "/tmp/${HUBBLE_ARCHIVE}" -C /usr/local/bin hubble
rm -f "/tmp/${HUBBLE_ARCHIVE}" "/tmp/${HUBBLE_ARCHIVE}.sha256sum"

cilium status --wait
# Relay нужен для hubble observe с рабочей машины. Повторный запуск безопасен.
cilium hubble enable --relay --wait

echo "Cilium and Hubble CLIs are ready. Run 'cilium hubble port-forward &' before hubble observe."
