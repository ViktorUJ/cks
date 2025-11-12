#!/bin/bash
# Cluster-specific setup for ICA Mock Exam
# Handles Istio ingress gateway configuration and test services

echo "*** Starting ICA cluster-specific setup"

export KUBECONFIG=/root/.kube/config

# Determine architecture
arch=$(uname -m)
case $arch in
  x86_64) arc_name="amd64" ;;
  aarch64) arc_name="arm64" ;;
esac

# ================================================
# Wait for cluster3 to be ready
# ================================================
echo "*** Waiting for cluster3 to be ready..."

max_retries=60
retry_count=0
cluster_ready=false

while [ $retry_count -lt $max_retries ]; do
  if kubectl get nodes --context cluster3-admin@cluster3 &>/dev/null; then
    echo "✓ Cluster3 is ready!"
    cluster_ready=true
    break
  fi

  retry_count=$((retry_count + 1))
  echo "  Waiting for cluster3... (attempt $retry_count/$max_retries)"
  sleep 10
done

if [ "$cluster_ready" = false ]; then
  echo "⚠ Warning: Cluster3 not ready after $max_retries attempts. Continuing anyway..."
fi

# Get node IP for /etc/hosts configuration
NODE_IP=$(kubectl get nodes --context cluster3-admin@cluster3 -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null )

# ================================================
# Configure /etc/hosts for Istio Ingress Gateway
# ================================================
echo "*** Configuring /etc/hosts for Istio ingress gateway access"

# Add ingress gateway hostnames to /etc/hosts
declare -a ingress_hosts=(
  "echo.example.com"
  "ship.milkyway.gal"
  "app.domain.com"
  "test.gateway.ica"
)

for hostname in "${ingress_hosts[@]}"; do
  if ! grep -q "$hostname" /etc/hosts; then
    echo "$NODE_IP $hostname" | tee -a /etc/hosts
    echo "  - Added: $hostname -> $NODE_IP"
  fi
done

# ================================================
# Download helper scripts from repo
# ================================================
echo "*** Downloading helper scripts from repository"

REPO_BASE="https://raw.githubusercontent.com/ViktorUJ/cks/AG-117/tasks/ica/mock/01/worker/files/scripts"

wget -q "$REPO_BASE/hosts" -O /usr/local/bin/hosts
chmod +x /usr/local/bin/hosts
chown ubuntu:ubuntu /usr/local/bin/hosts

wget -q "$REPO_BASE/check_result" -O /usr/bin/check_result
chmod +x /usr/bin/check_result

wget -q "$REPO_BASE/time_left" -O /usr/bin/time_left
chmod +x /usr/bin/time_left
