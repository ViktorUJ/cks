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

install -d -m 0755 /home/ubuntu/cks-111 /var/work/tests/artifacts/{1,1c,2,5,5b,6,7,8,9a,9b,9c}
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


# Task 1b fixture: multi-image CVE triage. Candidates are official, well-maintained
# Python images spanning several years of base-OS packages, so real (not synthetic)
# CVE differences between them are expected without us hand-picking any specific CVE ID
# at authoring time - the target CVE is discovered dynamically, right here, from a live
# Trivy scan of whatever these tags currently resolve to. That keeps the task correct
# forever instead of hardcoding a CVE ID that a future Trivy DB update or upstream patch
# could silently invalidate.
CANDIDATE_TAGS=(python:3.9-slim python:3.11-slim python:3.13-slim)
declare -A CANDIDATE_REF
declare -A CANDIDATE_CVES
for tag in "${CANDIDATE_TAGS[@]}"; do
  probe_json=$(trivy image --scanners vuln --format json --quiet "$tag" 2>/dev/null)
  repo_digest=$(jq -r '.Metadata.RepoDigests[0] // ""' <<<"$probe_json")
  if [[ -z "$repo_digest" ]]; then
    echo "FATAL: could not resolve a RepoDigest for candidate image $tag" >&2
    exit 1
  fi
  ref="${tag}@${repo_digest#*@}"
  pinned_json=$(trivy image --scanners vuln --format json --quiet "$ref" 2>/dev/null)
  cves=$(jq -r '[.Results[]? | .Vulnerabilities[]? | select(.Severity=="CRITICAL" or .Severity=="HIGH") | .VulnerabilityID] | unique | .[]' <<<"$pinned_json")
  CANDIDATE_REF["$tag"]="$ref"
  CANDIDATE_CVES["$tag"]="$cves"
done

target_cve=""
target_tag=""
for tag in "${CANDIDATE_TAGS[@]}"; do
  while read -r cve; do
    [[ -z "$cve" ]] && continue
    hits=0
    for other in "${CANDIDATE_TAGS[@]}"; do
      grep -qxF "$cve" <<<"${CANDIDATE_CVES[$other]}" && hits=$((hits + 1))
    done
    if [[ "$hits" -eq 1 ]]; then
      target_cve="$cve"
      target_tag="$tag"
      break 2
    fi
  done <<<"${CANDIDATE_CVES[$tag]}"
done

if [[ -z "$target_cve" ]]; then
  echo "FATAL: no CRITICAL/HIGH CVE unique to exactly one of ${CANDIDATE_TAGS[*]} was found - task 1b fixture cannot be built for this lab instance" >&2
  exit 1
fi

cat > /home/ubuntu/cks-111/candidates.txt <<EOF
# Task 1b: which of these three images actually contains $target_cve?
CANDIDATE_1=${CANDIDATE_REF[python:3.9-slim]}
CANDIDATE_2=${CANDIDATE_REF[python:3.11-slim]}
CANDIDATE_3=${CANDIDATE_REF[python:3.13-slim]}
TARGET_CVE=$target_cve
EOF
chown ubuntu:ubuntu /home/ubuntu/cks-111/candidates.txt

cat > "$CHECKER/task1b-baseline.txt" <<EOF
TARGET_CVE=$target_cve
TARGET_IMAGE_REF=${CANDIDATE_REF[$target_tag]}
CANDIDATE_1=${CANDIDATE_REF[python:3.9-slim]}
CANDIDATE_2=${CANDIDATE_REF[python:3.11-slim]}
CANDIDATE_3=${CANDIDATE_REF[python:3.13-slim]}
EOF

# ---------------------------------------------------------------------------
# Task 1c fixture: workload image CRITICAL-severity triage. Candidates span
# several real, independently-maintained image generations, so their CRITICAL
# vulnerability counts differ for genuine reasons (real base-OS package
# sets), not a synthetic/hand-picked score - discovered dynamically here
# against the live Trivy vulnerability DB, exactly like task 1b's CVE
# search, so this fixture stays correct as the DB and upstream images change.
# No ranking is persisted: tests.bats always recomputes it fresh from a live
# re-scan at check_result time, since a bootstrap-time snapshot could drift.
TRIAGE_POOL=(python:3.7-slim python:3.8-slim python:3.9-slim python:3.10-slim python:3.11-slim python:3.12-slim python:3.13-slim node:18-slim)
declare -A TRIAGE_REF
declare -A TRIAGE_CRITICAL
for tag in "${TRIAGE_POOL[@]}"; do
  probe_json=$(trivy image --scanners vuln --format json --quiet "$tag" 2>/dev/null)
  repo_digest=$(jq -r '.Metadata.RepoDigests[0] // ""' <<<"$probe_json")
  if [[ -z "$repo_digest" ]]; then
    echo "FATAL: could not resolve a RepoDigest for triage candidate $tag" >&2
    exit 1
  fi
  ref="${tag}@${repo_digest#*@}"
  crit_json=$(trivy image --scanners vuln --severity CRITICAL --format json --quiet "$ref" 2>/dev/null)
  count=$(jq -r '[.Results[]? | .Vulnerabilities[]? | select(.Severity=="CRITICAL") | .VulnerabilityID] | unique | length' <<<"$crit_json")
  TRIAGE_REF["$tag"]="$ref"
  TRIAGE_CRITICAL["$tag"]="$count"
done

# Pick 4 candidates whose CRITICAL counts are pairwise distinct: the single
# highest (most vulnerable), the two lowest (least vulnerable), and one more
# from the remaining spread - so the exercise has an unambiguous ranking.
mapfile -t _sorted_triage_tags < <(for tag in "${TRIAGE_POOL[@]}"; do printf '%s %s\n' "${TRIAGE_CRITICAL[$tag]}" "$tag"; done | sort -rn -k1,1 | awk '!seen[$1]++ {print $2}')
if [[ "${#_sorted_triage_tags[@]}" -lt 4 ]]; then
  echo "FATAL: fewer than 4 triage candidates have distinct CRITICAL counts - cannot build an unambiguous task 1c ranking for this lab instance" >&2
  exit 1
fi
TRIAGE_TAGS=("${_sorted_triage_tags[0]}" "${_sorted_triage_tags[1]}" "${_sorted_triage_tags[-1]}" "${_sorted_triage_tags[-2]}")
TRIAGE_NAMES=(triage-w1 triage-w2 triage-w3 triage-w4)

for i in 0 1 2 3; do
  name="${TRIAGE_NAMES[$i]}"
  ref="${TRIAGE_REF[${TRIAGE_TAGS[$i]}]}"
  kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $name
  namespace: cks-111
  labels:
    cks.io/task: "1c"
spec:
  replicas: 1
  selector:
    matchLabels: {app: $name}
  template:
    metadata:
      labels: {app: $name}
    spec:
      containers:
      - name: $name
        image: $ref
        command: ["sleep", "infinity"]
EOF
done
kubectl -n cks-111 wait --for=condition=Available deployment -l cks.io/task=1c --timeout=180s

# ---------------------------------------------------------------------------
# Task 5b fixture: package-version workload remediation. Discover, from the
# live SBOM of several independently-maintained real images, a genuine
# package/version pair shared by exactly two of some three candidates and
# absent (or at a different version) from the third - dynamically, exactly
# like tasks 1b/1c, so this never depends on a hand-picked package version
# that a future base-image update could silently invalidate.
PKG_POOL=(python:3.11-slim python:3.12-slim python:3.13-slim node:18-slim node:20-slim ruby:3.2-slim)
declare -A PKG_REF
declare -A PKG_SBOM
for tag in "${PKG_POOL[@]}"; do
  probe_json=$(trivy image --scanners vuln --format json --quiet "$tag" 2>/dev/null)
  repo_digest=$(jq -r '.Metadata.RepoDigests[0] // ""' <<<"$probe_json")
  if [[ -z "$repo_digest" ]]; then
    echo "FATAL: could not resolve a RepoDigest for package-search candidate $tag" >&2
    exit 1
  fi
  ref="${tag}@${repo_digest#*@}"
  sbom_tmp=$(mktemp)
  bom generate --format json --output "$sbom_tmp" --image "$ref" >/dev/null 2>&1
  PKG_REF["$tag"]="$ref"
  PKG_SBOM["$tag"]=$(jq -r '.packages[]? | select(.name and .versionInfo) | "\(.name)=\(.versionInfo)"' "$sbom_tmp" | sort -u)
  rm -f "$sbom_tmp"
done

TARGET_PACKAGE=""; TARGET_VERSION=""; OFFENDING_TAGS=(); CLEAN_TAG=""
pool_len=${#PKG_POOL[@]}
for ((a=0; a<pool_len; a++)); do
  for ((b=a+1; b<pool_len; b++)); do
    for ((c=0; c<pool_len; c++)); do
      [[ "$c" == "$a" || "$c" == "$b" ]] && continue
      tag_a="${PKG_POOL[$a]}"; tag_b="${PKG_POOL[$b]}"; tag_c="${PKG_POOL[$c]}"
      shared=$(comm -12 <(printf '%s\n' "${PKG_SBOM[$tag_a]}") <(printf '%s\n' "${PKG_SBOM[$tag_b]}"))
      while IFS='=' read -r pkg ver; do
        [[ -z "$pkg" ]] && continue
        if ! grep -qxF "${pkg}=${ver}" <<<"${PKG_SBOM[$tag_c]}"; then
          TARGET_PACKAGE="$pkg"; TARGET_VERSION="$ver"
          OFFENDING_TAGS=("$tag_a" "$tag_b"); CLEAN_TAG="$tag_c"
          break
        fi
      done <<<"$shared"
      [[ -n "$TARGET_PACKAGE" ]] && break
    done
    [[ -n "$TARGET_PACKAGE" ]] && break
  done
  [[ -n "$TARGET_PACKAGE" ]] && break
done

if [[ -z "$TARGET_PACKAGE" ]]; then
  echo "FATAL: no package/version shared by exactly two of ${PKG_POOL[*]} (absent from a third) was found - task 5b fixture cannot be built for this lab instance" >&2
  exit 1
fi

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pkg-audit-app
  namespace: cks-111
  labels:
    cks.io/task: "5b"
spec:
  replicas: 1
  selector:
    matchLabels: {app: pkg-audit-app}
  template:
    metadata:
      labels: {app: pkg-audit-app}
    spec:
      containers:
      - name: c1
        image: ${PKG_REF[${OFFENDING_TAGS[0]}]}
        command: ["sleep", "infinity"]
      - name: c2
        image: ${PKG_REF[${OFFENDING_TAGS[1]}]}
        command: ["sleep", "infinity"]
      - name: c3
        image: ${PKG_REF[$CLEAN_TAG]}
        command: ["sleep", "infinity"]
EOF
kubectl -n cks-111 wait --for=condition=Available deployment/pkg-audit-app --timeout=180s

cat > "$CHECKER/task5b-baseline.txt" <<EOF
TARGET_PACKAGE=$TARGET_PACKAGE
TARGET_VERSION=$TARGET_VERSION
OFFENDING_CONTAINERS=c1,c2
CLEAN_CONTAINER=c3
OFFENDING_IMAGE_1=${PKG_REF[${OFFENDING_TAGS[0]}]}
OFFENDING_IMAGE_2=${PKG_REF[${OFFENDING_TAGS[1]}]}
CLEAN_IMAGE=${PKG_REF[$CLEAN_TAG]}
EOF

chown -R root:root "$CHECKER"
chmod 0400 "$CHECKER"/*

chown -R ubuntu:ubuntu /home/ubuntu/cks-111 /var/work/tests/artifacts

for binary in trivy kubesec kube-linter hadolint syft bom cosign; do
  command -v "$binary" >/dev/null
  "$binary" --version >/dev/null 2>&1 || "$binary" version >/dev/null 2>&1 || true
done
