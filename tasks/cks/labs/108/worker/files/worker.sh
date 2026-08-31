#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
CTX="cluster1-admin@cluster1"
HELM_VERSION="v3.17.3"
# Kyverno 1.19 / chart 3.9.0: current supported branch verified 2026-08-31.
# This is the first release with full CEL-policy feature parity; legacy ClusterPolicy is
# deprecated and scheduled for removal in 1.20.
KYVERNO_CHART_VERSION="3.9.0"

echo "*** worker pc cks lab 108 k8s-1"
until kubectl get nodes --context "$CTX" --no-headers 2>/dev/null | grep -q .; do
  sleep 5
done

# Helm нужен для задания 1. Версия закреплена, чтобы команда установки была
# воспроизводимой; сам Kyverno намеренно ещё не установлен.
arch=$(dpkg --print-architecture)
case "$arch" in
  amd64) helm_arch="amd64" ;;
  arm64) helm_arch="arm64" ;;
  *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
esac
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${helm_arch}.tar.gz" -o "$workdir/helm.tgz"
tar -xzf "$workdir/helm.tgz" -C "$workdir"
install -m 0755 "$workdir/linux-${helm_arch}/helm" /usr/local/bin/helm

cat >/usr/local/bin/install-kyverno <<EOF
#!/usr/bin/env bash
set -euo pipefail
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm upgrade --install kyverno kyverno/kyverno \\
  --namespace kyverno --create-namespace \\
  --version ${KYVERNO_CHART_VERSION} \\
  --set admissionController.replicas=1 \\
  --wait --timeout 5m
EOF
chmod 0755 /usr/local/bin/install-kyverno

kubectl config use-context "$CTX" >/dev/null
echo "*** cluster is ready; complete the tasks and run check_result ***"
