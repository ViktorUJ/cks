#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
TRIVY_VERSION="0.74.0"
KUBESEC_VERSION="2.14.0"
KUBE_LINTER_VERSION="0.8.3"
HADOLINT_VERSION="2.12.0"
SYFT_VERSION="1.51.0"
BOM_VERSION="0.7.0"
COSIGN_VERSION="3.0.6"

printf '%s\n' '*** worker bootstrap CKS lab 111: pinned supply-chain tools'
until kubectl get nodes --no-headers >/dev/null 2>&1; do sleep 5; done

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ca-certificates curl jq golang-go
arch=$(dpkg --print-architecture)
case "$arch" in
  amd64) gh_arch=amd64 ;;
  arm64) gh_arch=arm64 ;;
  *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
esac
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

# Verify every directly downloaded release binary against the publisher's checksum asset
# before extraction or installation. Go verifies the bom module through the Go checksum DB.
download_verified() {
  local asset_url="$1" checksum_url="$2" asset="$3" checksum_file expected
  checksum_file="$workdir/${asset}.checksums"
  curl --fail --location --silent --show-error -o "$workdir/$asset" "$asset_url"
  curl --fail --location --silent --show-error -o "$checksum_file" "$checksum_url"
  expected=$(awk -v name="$asset" '$2 == name || $2 == "*" name {print $1; exit}' "$checksum_file")
  # Per-asset .sha256 files commonly contain just '<digest>  <filename>'.
  [[ -n "$expected" ]] || expected=$(awk 'NF {print $1; exit}' "$checksum_file")
  [[ "$expected" =~ ^[a-fA-F0-9]{64}$ ]] || { echo "No SHA-256 for $asset in $checksum_url" >&2; exit 1; }
  printf '%s  %s\n' "$expected" "$workdir/$asset" | sha256sum --check --status -
}

download_verified \
  "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" \
  "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_checksums.txt" \
  "trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"
tar -xzf "$workdir/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" -C "$workdir" trivy
install -m 0755 "$workdir/trivy" /usr/local/bin/trivy

download_verified \
  "https://github.com/controlplaneio/kubesec/releases/download/v${KUBESEC_VERSION}/kubesec_linux_amd64.tar.gz" \
  "https://github.com/controlplaneio/kubesec/releases/download/v${KUBESEC_VERSION}/kubesec_linux_amd64.tar.gz.sha256" \
  "kubesec_linux_amd64.tar.gz"
tar -xzf "$workdir/kubesec_linux_amd64.tar.gz" -C "$workdir"
install -m 0755 "$workdir/kubesec" /usr/local/bin/kubesec

download_verified \
  "https://github.com/stackrox/kube-linter/releases/download/v${KUBE_LINTER_VERSION}/kube-linter-linux.tar.gz" \
  "https://github.com/stackrox/kube-linter/releases/download/v${KUBE_LINTER_VERSION}/kube-linter_${KUBE_LINTER_VERSION}_checksums.txt" \
  "kube-linter-linux.tar.gz"
tar -xzf "$workdir/kube-linter-linux.tar.gz" -C "$workdir"
install -m 0755 "$workdir/kube-linter" /usr/local/bin/kube-linter

download_verified \
  "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64" \
  "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64.sha256" \
  "hadolint"
install -m 0755 "$workdir/hadolint" /usr/local/bin/hadolint

download_verified \
  "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_linux_${gh_arch}.tar.gz" \
  "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_checksums.txt" \
  "syft_${SYFT_VERSION}_linux_${gh_arch}.tar.gz"
tar -xzf "$workdir/syft_${SYFT_VERSION}_linux_${gh_arch}.tar.gz" -C "$workdir" syft
install -m 0755 "$workdir/syft" /usr/local/bin/syft

# BOM is installed through Go's module checksum verification; do not disable GOSUMDB.
GOSUMDB=sum.golang.org GOBIN=/usr/local/bin go install "sigs.k8s.io/bom/cmd/bom@v${BOM_VERSION}"

download_verified \
  "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-${gh_arch}" \
  "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign_checksums.txt" \
  "cosign"
install -m 0755 "$workdir/cosign" /usr/local/bin/cosign

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
Базовый образ начинается с nginx:1.27.3-alpine, но итоговые base и hardened image должны быть pinned registry manifest digest.
EOF
chown -R ubuntu:ubuntu /home/ubuntu/cks-111 /var/work/tests/artifacts

for binary in trivy kubesec kube-linter hadolint syft bom cosign; do
  command -v "$binary" >/dev/null
  "$binary" --version >/dev/null 2>&1 || "$binary" version >/dev/null 2>&1 || true
done
