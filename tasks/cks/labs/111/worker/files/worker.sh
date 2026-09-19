#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
TRIVY_VERSION="0.74.0"
KUBESEC_VERSION="2.14.0"
KUBE_LINTER_VERSION="0.8.3"
HADOLINT_VERSION="2.12.0"
SYFT_VERSION="1.51.0"
BOM_VERSION="0.7.0"
COSIGN_VERSION="3.1.3"

printf '%s\n' '*** worker bootstrap CKS lab 111: pinned supply-chain tools'
until kubectl get nodes --no-headers >/dev/null 2>&1; do sleep 5; done
kubectl create namespace cks-111 --dry-run=client -o yaml | kubectl apply -f -

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
#
# checksum_name is the exact filename as it appears in the checksum manifest (column 2),
# which is not always identical to the local filename we choose to save the asset as.
# There is intentionally NO "take the first line" fallback: for multi-asset manifests
# (trivy/syft/cosign *_checksums.txt) that would silently pick an unrelated asset's hash
# (e.g. a different OS/architecture) if checksum_name does not match exactly.
download_verified() {
  local asset_url="$1" checksum_url="$2" local_name="$3" checksum_name="${4:-$3}" checksum_file expected
  checksum_file="$workdir/${local_name}.checksums"
  curl --fail --location --silent --show-error -o "$workdir/$local_name" "$asset_url"
  curl --fail --location --silent --show-error -o "$checksum_file" "$checksum_url"
  expected=$(awk -v name="$checksum_name" '$2 == name || $2 == "*" name {print $1; exit}' "$checksum_file")
  [[ "$expected" =~ ^[a-fA-F0-9]{64}$ ]] || { echo "No SHA-256 for $checksum_name in $checksum_url" >&2; exit 1; }
  printf '%s  %s\n' "$expected" "$workdir/$local_name" | sha256sum --check --status -
}

# Verify a downloaded asset against a checksum pinned directly in this script, for releases
# that do not publish a plain SHA-256 checksums manifest (e.g. kube-linter v0.8.3 only ships
# Sigstore .sigstore.json bundles, not a checksums.txt). The expected hash below was computed
# from the publisher's own release asset and recorded at pin time; bump it together with
# KUBE_LINTER_VERSION.
download_verified_pinned() {
  local asset_url="$1" local_name="$2" expected_sha256="$3"
  curl --fail --location --silent --show-error -o "$workdir/$local_name" "$asset_url"
  printf '%s  %s\n' "$expected_sha256" "$workdir/$local_name" | sha256sum --check --status -
}

download_verified \
  "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" \
  "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_checksums.txt" \
  "trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"
tar -xzf "$workdir/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" -C "$workdir" trivy
install -m 0755 "$workdir/trivy" /usr/local/bin/trivy

download_verified \
  "https://github.com/controlplaneio/kubesec/releases/download/v${KUBESEC_VERSION}/kubesec_linux_amd64.tar.gz" \
  "https://github.com/controlplaneio/kubesec/releases/download/v${KUBESEC_VERSION}/kubesec_checksums.txt" \
  "kubesec_linux_amd64.tar.gz"
tar -xzf "$workdir/kubesec_linux_amd64.tar.gz" -C "$workdir"
install -m 0755 "$workdir/kubesec" /usr/local/bin/kubesec

# kube-linter v0.8.3 publishes only Sigstore .sigstore.json bundles for this release, not a
# plain SHA-256 checksums manifest, so the asset is verified against a checksum pinned in
# this script (computed from the publisher's own kube-linter-linux.tar.gz at pin time).
download_verified_pinned \
  "https://github.com/stackrox/kube-linter/releases/download/v${KUBE_LINTER_VERSION}/kube-linter-linux.tar.gz" \
  "kube-linter-linux.tar.gz" \
  "1a6d8419b11971372971fdbc22682b684ebfb7cf1c39591662d1b6ca736c41df"
tar -xzf "$workdir/kube-linter-linux.tar.gz" -C "$workdir"
install -m 0755 "$workdir/kube-linter" /usr/local/bin/kube-linter

download_verified \
  "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64" \
  "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64.sha256" \
  "hadolint" \
  "hadolint-Linux-x86_64"
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
  "cosign" \
  "cosign-linux-${gh_arch}"
install -m 0755 "$workdir/cosign" /usr/local/bin/cosign

# Helm и install-kyverno нужны для задания 9 (admission block неподписанных образов).
# Kyverno намеренно НЕ установлен здесь: установка - часть задания, как в лабе 108.
HELM_VERSION="v3.17.3"
case "$arch" in
  amd64) helm_arch=amd64 ;;
  arm64) helm_arch=arm64 ;;
esac
# Same fail-fast checksum verification contract as every other directly downloaded
# release binary above - Helm publishes a matching .sha256sum asset per release archive.
helm_dist="helm-${HELM_VERSION}-linux-${helm_arch}.tar.gz"
helm_url="https://get.helm.sh/${helm_dist}"
curl --fail --location --silent --show-error -o "$workdir/helm.tgz" "$helm_url"
curl --fail --location --silent --show-error -o "$workdir/helm.tgz.sha256sum" "${helm_url}.sha256sum"
helm_sha256=$(awk '{print $1; exit}' "$workdir/helm.tgz.sha256sum")
[[ "$helm_sha256" =~ ^[a-fA-F0-9]{64}$ ]] || { echo "Invalid Helm SHA-256" >&2; exit 1; }
printf '%s  %s\n' "$helm_sha256" "$workdir/helm.tgz" | sha256sum --check --status -
tar -xzf "$workdir/helm.tgz" -C "$workdir"
install -m 0755 "$workdir/linux-${helm_arch}/helm" /usr/local/bin/helm

cat >/usr/local/bin/install-kyverno <<'KYVERNO_EOF'
#!/usr/bin/env bash
set -euo pipefail
# Kyverno 1.19 / chart 3.9.0: current supported branch verified 2026-08-31,
# первый релиз с полным CEL-policy feature parity (ImageValidatingPolicy).
#
# LAB-SPECIFIC ARCHITECTURE EXCEPTION: официальная support matrix Kyverno 1.19
# охватывает Kubernetes 1.33-1.35 (см. https://kyverno.io/docs/releases/); этот кластер
# закреплён на Kubernetes 1.36, что вне протестированного диапазона upstream ("Other
# Kubernetes versions may work, but are not tested and therefore no guarantees are made
# as to their full compatibility"). Комбинация 1.36 используется в этой лабе как
# осознанный trade-off после smoke-проверки install/admission на конкретной паре версий.
# Обновить закреплённую версию Kyverno/chart и снять это исключение, когда выйдет релиз с
# официальной поддержкой Kubernetes 1.36.
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno --create-namespace \
  --version 3.9.0 \
  --set admissionController.replicas=1 \
  --wait --timeout 5m
KYVERNO_EOF
chmod 0755 /usr/local/bin/install-kyverno

install -d -m 0755 /home/ubuntu/cks-111 /var/work/tests/artifacts/{1,2,5,6,7,8,9a,9b,9c}
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

# Checker-owned before-fix baseline, captured from the ORIGINAL starter files before the
# student can touch them. tests.bats compares student-submitted evidence against this
# bootstrap-origin baseline instead of trusting hand-written text/JSON that merely matches
# a schema/regex - this is analogous to Lab 109's checker-owned baseline pattern.
CHECKER=/var/lib/cks-lab111-checker
install -d -o root -g root -m 0700 "$CHECKER"
hadolint /home/ubuntu/cks-111/Dockerfile > "$CHECKER/hadolint-before.txt" 2>&1 || true
kubesec scan /home/ubuntu/cks-111/deployment.yaml > "$CHECKER/kubesec-before.json" 2>&1 || true
kube-linter lint /home/ubuntu/cks-111/deployment.yaml --format json > "$CHECKER/kube-linter-before.json" 2>&1 || true

# The "|| true" above only tolerates the EXPECTED non-zero exit from findings being
# present - it must not also silently accept a genuinely broken/empty/malformed baseline.
# Validate positive postconditions before handing the lab to the student: if the trusted
# reference baseline itself is invalid, this is an infrastructure failure and must abort
# bootstrap rather than turn into an unexplainable student FAIL in test 2 later.
if ! grep -Eq 'DL[0-9]+' "$CHECKER/hadolint-before.txt"; then
  echo "FATAL: bootstrap hadolint baseline does not contain a DL#### finding" >&2
  exit 1
fi
if ! jq -e 'type == "array" and length > 0 and .[0].scoring' "$CHECKER/kubesec-before.json" >/dev/null 2>&1; then
  echo "FATAL: bootstrap kubesec baseline is not a valid non-empty scored JSON array" >&2
  exit 1
fi
if ! jq -e 'type == "object" and (.Summary | type == "object") and (.Reports | type == "array") and (.Reports | length > 0)' \
    "$CHECKER/kube-linter-before.json" >/dev/null 2>&1; then
  echo "FATAL: bootstrap kube-linter baseline is not a valid KubeLinter JSON object with findings" >&2
  exit 1
fi

chown -R root:root "$CHECKER"
chmod 0400 "$CHECKER"/*

chown -R ubuntu:ubuntu /home/ubuntu/cks-111 /var/work/tests/artifacts

for binary in trivy kubesec kube-linter hadolint syft bom cosign; do
  command -v "$binary" >/dev/null
  "$binary" --version >/dev/null 2>&1 || "$binary" version >/dev/null 2>&1 || true
done
