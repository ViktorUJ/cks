#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
TRIVY_VERSION="0.58.1"
KUBESEC_VERSION="2.14.0"
KUBE_LINTER_VERSION="0.7.1"
HADOLINT_VERSION="2.12.0"
SYFT_VERSION="1.18.1"
BOM_VERSION="0.7.0"
COSIGN_VERSION="2.4.1"

printf '%s\n' '*** worker bootstrap CKS lab 111: pinned supply-chain tools'
until kubectl get nodes --no-headers >/dev/null 2>&1; do sleep 5; done

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ca-certificates curl jq golang-go
arch=$(dpkg --print-architecture)
case "$arch" in amd64) gh_arch=amd64 ;; arm64) gh_arch=arm64 ;; *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; esac
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

curl -fsSL -o "$workdir/trivy.tgz" "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"
tar -xzf "$workdir/trivy.tgz" -C "$workdir" trivy
install -m 0755 "$workdir/trivy" /usr/local/bin/trivy

curl -fsSL -o "$workdir/kubesec.tgz" "https://github.com/controlplaneio/kubesec/releases/download/v${KUBESEC_VERSION}/kubesec_linux_amd64.tar.gz"
tar -xzf "$workdir/kubesec.tgz" -C "$workdir"
install -m 0755 "$workdir/kubesec" /usr/local/bin/kubesec

curl -fsSL -o "$workdir/kube-linter.tgz" "https://github.com/stackrox/kube-linter/releases/download/v${KUBE_LINTER_VERSION}/kube-linter-linux.tar.gz"
tar -xzf "$workdir/kube-linter.tgz" -C "$workdir"
install -m 0755 "$workdir/kube-linter" /usr/local/bin/kube-linter

curl -fsSL -o /usr/local/bin/hadolint "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64"
chmod 0755 /usr/local/bin/hadolint

curl -fsSL -o "$workdir/syft.tgz" "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_linux_${gh_arch}.tar.gz"
tar -xzf "$workdir/syft.tgz" -C "$workdir" syft
install -m 0755 "$workdir/syft" /usr/local/bin/syft

# Kubernetes SIGs BOM has no distribution dependency: pin the Go module release itself.
GOBIN=/usr/local/bin go install "sigs.k8s.io/bom/cmd/bom@v${BOM_VERSION}"

curl -fsSL -o /usr/local/bin/cosign "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-${gh_arch}"
chmod 0755 /usr/local/bin/cosign

install -d -m 0755 /home/ubuntu/cks-111 /var/work/tests/artifacts/{1,2,5,6,7}
cat > /home/ubuntu/cks-111/Dockerfile <<'EOF'
FROM nginx:latest
ADD https://example.invalid/agent /usr/local/bin/agent
RUN apt-get update && apt-get install -y curl sudo
ENV API_TOKEN=training-token
COPY . /usr/share/nginx/html
CMD ["nginx", "-g", "daemon off;"]
EOF
cat > /home/ubuntu/cks-111/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  namespace: cks-111
spec:
  replicas: 1
  selector:
    matchLabels:
      app: catalog
  template:
    metadata:
      labels:
        app: catalog
    spec:
      containers:
      - name: catalog
        image: nginx:latest
        securityContext:
          privileged: true
EOF
cat > /home/ubuntu/cks-111/README.txt <<'EOF'
Исправляйте только Dockerfile и deployment.yaml. Отчёты храните в /var/work/tests/artifacts.
Базовый образ для анализа: nginx:1.27.3-alpine. Не публикуйте и не подписывайте собственный образ.
EOF
chown -R ubuntu:ubuntu /home/ubuntu/cks-111 /var/work/tests/artifacts

for binary in trivy kubesec kube-linter hadolint syft bom cosign; do
  command -v "$binary" >/dev/null
  "$binary" --version >/dev/null 2>&1 || "$binary" version >/dev/null 2>&1 || true
done
