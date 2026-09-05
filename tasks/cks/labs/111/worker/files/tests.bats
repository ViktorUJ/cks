#!/usr/bin/env bats

ROOT=/home/ubuntu/cks-111
ART=/var/work/tests/artifacts

record_result() {
  echo '1' >> /var/work/tests/result/all
  if [[ "$1" -eq 0 ]]; then echo '1' >> /var/work/tests/result/ok; fi
  return "$1"
}

@test "0 Init" {
  : > /var/work/tests/result/all
  : > /var/work/tests/result/ok
  : > /var/work/tests/result/requests
}

@test "1. Trivy vulnerability report is structured and identifies the required image" {
  report="$ART/1/trivy-report.json"
  if [[ -s "$report" ]] && jq -e '(.Results | type == "array") and ((.ArtifactName // "") | contains("nginx:1.27.3-alpine"))' "$report" >/dev/null 2>&1; then result=0; else echo "Missing or invalid Trivy report: $report"; result=1; fi
  record_result "$result"
}

@test "2. Before-fix reports from Hadolint, kubesec, and kube-linter exist" {
  h="$ART/2/hadolint-before.txt"; k="$ART/2/kubesec-before.json"; l="$ART/2/kube-linter-before.json"
  if [[ -s "$h" ]] && grep -Eq 'DL[0-9]+' "$h" && jq -e 'type == "array" and length > 0 and .[0].scoring' "$k" >/dev/null 2>&1 && jq -e 'type == "array"' "$l" >/dev/null 2>&1; then result=0; else echo "Expected three valid before-fix reports in $ART/2"; result=1; fi
  record_result "$result"
}

@test "3. Dockerfile is pinned, has no secret or remote ADD, and runs non-root" {
  file="$ROOT/Dockerfile"; report="$ART/3/hadolint-after.txt"
  if [[ -f "$file" ]] && grep -qx 'FROM nginx:1.27.3-alpine' "$file" && ! grep -Eqi '^[[:space:]]*ADD[[:space:]]+https?://|^[[:space:]]*ENV[[:space:]].*(API_TOKEN|TOKEN)|sudo|:latest' "$file" && grep -Eq '^[[:space:]]*USER[[:space:]]+[^[:space:]0][^[:space:]]*' "$file" && [[ -f "$report" ]] && ! grep -Eq 'DL3007|DL3013|DL3020|DL3045' "$report"; then result=0; else echo "Dockerfile remediation or Hadolint after-report is incomplete"; result=1; fi
  record_result "$result"
}

@test "4. Deployment applies required pod and container hardening and has after reports" {
  file="$ROOT/deployment.yaml"; k="$ART/4/kubesec-after.json"; l="$ART/4/kube-linter-after.json"
  required='nginx:1.27.3-alpine|automountServiceAccountToken: false|runAsNonRoot: true|type: RuntimeDefault|allowPrivilegeEscalation: false|readOnlyRootFilesystem: true|drop: \["ALL"\]|cpu:|memory:'
  if [[ -f "$file" ]] && ! grep -Eq 'privileged:[[:space:]]*true|:latest' "$file" && grep -Eq 'image:[[:space:]]*nginx:1.27.3-alpine' "$file" && grep -q 'automountServiceAccountToken: false' "$file" && grep -q 'runAsNonRoot: true' "$file" && grep -q 'type: RuntimeDefault' "$file" && grep -q 'allowPrivilegeEscalation: false' "$file" && grep -q 'readOnlyRootFilesystem: true' "$file" && grep -Eq 'drop:[[:space:]]*\["ALL"\]' "$file" && grep -q 'requests:' "$file" && grep -q 'limits:' "$file" && jq -e 'type == "array"' "$k" >/dev/null 2>&1 && jq -e 'type == "array"' "$l" >/dev/null 2>&1; then result=0; else echo "Deployment hardening or after-fix static reports are incomplete"; result=1; fi
  record_result "$result"
}

@test "5. Version search evidence comes from Trivy package listing and includes digest" {
  report="$ART/5/version-search.txt"
  packages=$(grep -Ec '^[[:alnum:]_.+/-]+=[[:alnum:].+~:_-]+$' "$report" 2>/dev/null || true)
  if [[ -s "$report" ]] && grep -q 'trivy image --list-all-pkgs' "$report" && grep -q 'nginx:1.27.3-alpine' "$report" && grep -q 'sha256:' "$report" && [[ "$packages" -ge 3 ]]; then result=0; else echo "Version-search evidence must include command, image, digest, and three package=version lines"; result=1; fi
  record_result "$result"
}

@test "6. bom generated an SPDX SBOM and command evidence" {
  sbom="$ART/6/bom.spdx.json"; command_file="$ART/6/bom-command.txt"
  if jq -e '(.spdxVersion | startswith("SPDX-")) and (.packages | type == "array")' "$sbom" >/dev/null 2>&1 && grep -q 'bom generate' "$command_file" 2>/dev/null; then result=0; else echo "Missing valid bom SPDX SBOM or command evidence"; result=1; fi
  record_result "$result"
}

@test "7. Syft CycloneDX SBOM and keyless Cosign verification evidence are present" {
  sbom="$ART/7/syft.cdx.json"; verify="$ART/7/cosign-verify.txt"
  if jq -e '.bomFormat == "CycloneDX" and (.components | type == "array") and (.components | length > 0)' "$sbom" >/dev/null 2>&1 && grep -q 'Verified OK' "$verify" 2>/dev/null && grep -q 'gcr.io/distroless/static:nonroot' "$verify" 2>/dev/null; then result=0; else echo "Missing Syft CycloneDX SBOM or successful Cosign verification evidence"; result=1; fi
  record_result "$result"
}
