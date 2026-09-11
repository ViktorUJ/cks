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
  if [[ -s "$report" ]] && jq -e '(.Results | type == "array") and ((.ArtifactName // "") | contains("nginx:1.27.3-alpine"))' "$report" >/dev/null 2>&1; then result=0; else echo "HINT: Report is empty/invalid JSON, or .ArtifactName does not contain 'nginx:1.27.3-alpine' - make sure you scanned the immutable \$IMAGE reference (tag@digest), not a bare 'nginx:latest'."; echo "Missing or invalid Trivy report: $report"; result=1; fi
  record_result "$result"
}

@test "2. Before-fix reports from Hadolint, kubesec, and kube-linter exist" {
  h="$ART/2/hadolint-before.txt"; k="$ART/2/kubesec-before.json"; l="$ART/2/kube-linter-before.json"
  if [[ -s "$h" ]] && grep -Eq 'DL[0-9]+' "$h" && jq -e 'type == "array" and length > 0 and .[0].scoring' "$k" >/dev/null 2>&1 && jq -e 'type == "array"' "$l" >/dev/null 2>&1; then result=0; else echo "HINT: One of the three before-fix reports is missing/empty or in the wrong format. hadolint-before.txt must actually contain a DL#### finding code (the starter Dockerfile has real issues); kubesec-before.json must be a JSON array with a 'scoring' key; kube-linter-before.json must be a JSON array - check you used --format json for kube-linter."; echo "Expected three valid before-fix reports in $ART/2"; result=1; fi
  record_result "$result"
}

@test "3. Dockerfile is pinned, has no secret or remote ADD, and runs non-root" {
  file="$ROOT/Dockerfile"; report="$ART/3/hadolint-after.txt"
  if [[ -f "$file" ]] && grep -Eq '^FROM[[:space:]]+nginx:1[.]27[.]3-alpine@sha256:[a-f0-9]{64}$' "$file" && ! grep -Eqi '^[[:space:]]*ADD[[:space:]]+https?://|^[[:space:]]*ENV[[:space:]].*(API_TOKEN|TOKEN)|sudo|:latest' "$file" && grep -Eq '^[[:space:]]*USER[[:space:]]+[^[:space:]0][^[:space:]]*' "$file" && grep -Eq '^[[:space:]]*ARG[[:space:]]+CKS_SIGNATURE_TEST' "$file" && grep -Eq '^[[:space:]]*LABEL[[:space:]]+cks\.signature-test=' "$file" && [[ -f "$report" ]] && ! grep -Eq 'DL3007|DL3013|DL3020|DL3045' "$report"; then result=0; else echo "HINT: Check each requirement individually - FROM must pin nginx:1.27.3-alpine@sha256:<64-hex>, no remote ADD/API_TOKEN/sudo/:latest, a non-root USER (uid != 0), and both 'ARG CKS_SIGNATURE_TEST' + 'LABEL cks.signature-test=\$CKS_SIGNATURE_TEST' lines (needed later by task 9c). hadolint-after.txt must show none of DL3007/DL3013/DL3020/DL3045 remaining."; echo "Dockerfile remediation or Hadolint after-report is incomplete"; result=1; fi
  record_result "$result"
}

@test "4. Deployment applies required pod and container hardening and has after reports" {
  file="$ROOT/deployment.yaml"; k="$ART/4/kubesec-after.json"; l="$ART/4/kube-linter-after.json"
  required='nginx:1.27.3-alpine|automountServiceAccountToken: false|runAsNonRoot: true|type: RuntimeDefault|allowPrivilegeEscalation: false|readOnlyRootFilesystem: true|drop: \["ALL"\]|cpu:|memory:'
  if [[ -f "$file" ]] && ! grep -Eq 'privileged:[[:space:]]*true|:latest' "$file" && grep -Eq 'image:[[:space:]]*[^[:space:]]+@sha256:[a-f0-9]{64}' "$file" && ! grep -Eq 'image:[[:space:]]*nginx:1[.]27[.]3-alpine([[:space:]]|$)' "$file" && grep -q 'prepare-nginx-config' "$file" && grep -q 'nginx-cache' "$file" && grep -q 'nginx-config' "$file" && grep -q 'automountServiceAccountToken: false' "$file" && grep -q 'runAsNonRoot: true' "$file" && grep -q 'type: RuntimeDefault' "$file" && grep -q 'allowPrivilegeEscalation: false' "$file" && grep -q 'readOnlyRootFilesystem: true' "$file" && grep -Eq 'drop:[[:space:]]*\["ALL"\]' "$file" && grep -q 'requests:' "$file" && grep -q 'limits:' "$file" && jq -e 'type == "array"' "$k" >/dev/null 2>&1 && jq -e 'type == "array"' "$l" >/dev/null 2>&1; then result=0; else echo "HINT: deployment.yaml must use YOUR digest-pinned hardened image (not upstream nginx), have no privileged:true/latest, include the prepare-nginx-config init container + nginx-cache/nginx-config volumes, and set all of: automountServiceAccountToken:false, runAsNonRoot:true, seccompProfile RuntimeDefault, allowPrivilegeEscalation:false, readOnlyRootFilesystem:true, capabilities.drop:[ALL], and CPU/memory requests+limits. Check each field is present - missing just one fails this test."; echo "Deployment hardening or after-fix static reports are incomplete"; result=1; fi
  if [[ "$result" -eq 0 ]]; then
    kubectl apply -f "$file" >/dev/null 2>&1 && kubectl rollout status deployment/catalog -n cks-111 --timeout=180s >/dev/null 2>&1
    runtime_status=$?
    ready=$(kubectl get deployment/catalog -n cks-111 -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)
    run kubectl run catalog-http-smoke -n cks-111 --rm -i --restart=Never --image=curlimages/curl:8.11.0 -- curl -fsS --max-time 10 http://catalog
    if [[ "$runtime_status" -ne 0 || "$ready" != "1" || "$status" -ne 0 ]]; then
      echo "HINT: Deployment did not become Available or the HTTP smoke test failed - with readOnlyRootFilesystem:true, nginx needs writable emptyDir mounts for /tmp, /var/run, /var/cache/nginx, and /etc/nginx/conf.d (via the init container copying config first). A missing writable mount is the most common cause of CrashLoopBackOff here."
      echo "Hardened Deployment must become Available and serve an HTTP smoke request"
      result=1
    fi
  fi
  record_result "$result"
}

@test "5. Version search evidence comes from Trivy package listing and includes canonical RepoDigest" {
  report="$ART/5/version-search.txt"
  packages=$(grep -Ec '^[[:alnum:]_.+/-]+=[[:alnum:].+~:_-]+$' "$report" 2>/dev/null || true)
  if [[ -s "$report" ]] && grep -q 'trivy image --list-all-pkgs' "$report" && grep -q 'nginx:1.27.3-alpine' "$report" && grep -q 'sha256:' "$report" && [[ "$packages" -ge 3 ]]; then result=0; else echo "HINT: version-search.txt must contain the literal command 'trivy image --list-all-pkgs', the image reference 'nginx:1.27.3-alpine', a 'sha256:' digest, and at least 3 lines matching 'name=version' - do not hand-write the package list, save the actual scanner output."; echo "Version-search evidence must include command, image, digest, and three package=version lines"; result=1; fi
  record_result "$result"
}

@test "6. bom generated an SPDX SBOM and command evidence" {
  sbom="$ART/6/bom.spdx.json"; command_file="$ART/6/bom-command.txt"
  if jq -e '(.spdxVersion | startswith("SPDX-")) and (.packages | type == "array")' "$sbom" >/dev/null 2>&1 && grep -q 'bom generate' "$command_file" 2>/dev/null; then result=0; else echo "HINT: bom.spdx.json must have an 'spdxVersion' field starting with 'SPDX-' and a 'packages' array - this is bom's native output format, not the same schema as Syft's SPDX. bom-command.txt must contain the literal text 'bom generate'."; echo "Missing valid bom SPDX SBOM or command evidence"; result=1; fi
  record_result "$result"
}

@test "7. Syft CycloneDX SBOM and keyless Cosign verification evidence are present" {
  sbom="$ART/7/syft.cdx.json"; verify="$ART/7/cosign-verify.txt"
  if jq -e '.bomFormat == "CycloneDX" and (.components | type == "array") and (.components | length > 0)' "$sbom" >/dev/null 2>&1 && grep -q 'Verified OK' "$verify" 2>/dev/null && grep -q 'gcr.io/distroless/static:nonroot' "$verify" 2>/dev/null; then result=0; else echo "HINT: syft.cdx.json must have bomFormat 'CycloneDX' and a non-empty 'components' array - check you used Syft's -o cyclonedx-json output flag. cosign-verify.txt must show 'Verified OK' for exactly 'gcr.io/distroless/static:nonroot' using keyless verification with the correct issuer/identity for Distroless."; echo "Missing Syft CycloneDX SBOM or successful Cosign verification evidence"; result=1; fi
  record_result "$result"
}

@test "8. trivy sbom scans the generated SBOM file for vulnerabilities" {
  report="$ART/8/sbom-scan.json"; input_sbom="$ART/6/bom.spdx.json"
  if [[ -s "$report" ]] && jq -e --arg input "$input_sbom" '
    (.Results | type == "array") and
    (.ScanCommand | type == "string") and
    (.ScanCommand | test("(^|[[:space:]])trivy[[:space:]]+sbom([[:space:]]|$)")) and
    (.ScanCommand | contains($input))
  ' "$report" >/dev/null 2>&1; then result=0
  else echo "HINT: sbom-scan.json must be valid Trivy JSON with a 'Results' array and a ScanCommand that runs 'trivy sbom' on the task-6 SBOM file ($input_sbom), not 'trivy image' against \$IMAGE."; echo "Missing or impure trivy sbom scan evidence: $report"; result=1
  fi
  record_result "$result"
}

@test "9a. Kyverno policy has exact repository scope and a verifiable Cosign signature" {
  sign="$ART/9a/cosign-sign.txt"
  crd=$(kubectl get crd imagevalidatingpolicies.policies.kyverno.io -o name 2>/dev/null)
  policy=$(kubectl get imagevalidatingpolicy require-signed-catalog-images -o json 2>/dev/null)
  hardened_image=$(kubectl get deployment catalog -n cks-111 -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
  hardened_repo=${hardened_image%@*}
  policy_ok=0; cosign_ok=0
  if [[ -n "$policy" && -n "$hardened_repo" ]] && echo "$policy" | jq -e --arg repo "$hardened_repo" '
    .apiVersion == "policies.kyverno.io/v1" and
    (.spec.validationActions | index("Deny") != null) and
    ([.spec.matchImageReferences[]?.glob] | sort == [$repo + ":*", $repo + "@*"]) and
    (any(.spec.attestors[]?; .cosign.key.data? | type == "string" and length > 0)) and
    (any(.spec.validations[]?; (.expression // "") | contains("verifyImageSignatures")))
  ' >/dev/null 2>&1; then policy_ok=1; fi
  if [[ -n "$hardened_image" && -s "$ROOT/cosign.pub" ]] \
    && cosign verify --key "$ROOT/cosign.pub" "$hardened_image" >/dev/null 2>&1; then cosign_ok=1; fi
  admission_ready=$(kubectl -n kyverno get deployment -l app.kubernetes.io/part-of=kyverno -o jsonpath='{.items[*].status.availableReplicas}' 2>/dev/null || true)
  if [[ -n "$crd" && "$policy_ok" -eq 1 && -n "$admission_ready" && "$cosign_ok" -eq 1 ]] \
    && [[ -s "$sign" ]] && grep -Eiq 'signing|pushing|tlog|signed' "$sign"; then
    result=0
  else
    if [[ -z "$crd" ]]; then
      echo "HINT: ImageValidatingPolicy CRD is missing - run 'sudo install-kyverno' and wait for the Helm release/CRDs to finish installing."
    elif [[ "$policy_ok" -ne 1 ]]; then
      echo "HINT: Policy must deny, contain a Cosign key and verifyImageSignatures expression, and match exactly \$HARDENED_REPO:* plus \$HARDENED_REPO@* (not the unsafe \$HARDENED_REPO* prefix)."
    elif [[ -z "$admission_ready" ]]; then
      echo "HINT: No Kyverno admission controller Deployment has availableReplicas set - wait longer for the Pods to become Ready."
    elif [[ "$cosign_ok" -ne 1 ]]; then
      echo "HINT: Direct 'cosign verify --key cosign.pub \$HARDENED_IMAGE' must succeed; a plausible cosign-sign.txt alone is not signature proof."
    else
      echo "HINT: cosign-sign.txt does not look like a successful 'cosign sign' output for \$HARDENED_IMAGE - check you signed YOUR hardened image, not upstream nginx."
    fi
    echo "crd=${crd:-missing} policy_ok=$policy_ok admission_ready=${admission_ready:-none} hardened_image=${hardened_image:-missing} cosign_ok=$cosign_ok sign=$sign"
    result=1
  fi
  record_result "$result"
}

@test "9b. A fresh Pod is admitted with the exact Cosign-verified signed image" {
  evidence="$ART/9b/signed-admission-check.json"
  policy_created=$(kubectl get imagevalidatingpolicy require-signed-catalog-images -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)
  catalog_image=$(kubectl get deployment catalog -n cks-111 -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
  pod=$(kubectl get pod signed-admission-check -n cks-111 -o json 2>/dev/null)
  pod_created=$(jq -r '.metadata.creationTimestamp // ""' <<<"$pod" 2>/dev/null)
  pod_phase=$(jq -r '.status.phase // ""' <<<"$pod" 2>/dev/null)
  pod_ready=$(jq -r '[.status.conditions[]? | select(.type == "Ready") | .status] | any(. == "True")' <<<"$pod" 2>/dev/null)
  pod_image=$(jq -r '.spec.containers[0].image // ""' <<<"$pod" 2>/dev/null)
  image_ok=0; cosign_ok=0
  if [[ -n "$catalog_image" && "$pod_image" == "$catalog_image" && "$pod_image" =~ @sha256:[a-f0-9]{64}$ ]]; then image_ok=1; fi
  if [[ "$image_ok" -eq 1 && -s "$ROOT/cosign.pub" ]] \
    && cosign verify --key "$ROOT/cosign.pub" "$pod_image" >/dev/null 2>&1; then cosign_ok=1; fi
  evidence_ok=0
  if [[ -s "$evidence" ]] && jq -e --arg policy "$policy_created" --arg image "$pod_image" '(.creationTimestamp // "") > $policy and (.image // "") == $image' "$evidence" >/dev/null 2>&1; then evidence_ok=1; fi
  if [[ -n "$policy_created" && -n "$pod_created" ]] \
    && [[ "$pod_created" > "$policy_created" ]] \
    && [[ "$pod_phase" != "Failed" && "$image_ok" -eq 1 && "$cosign_ok" -eq 1 ]] \
    && [[ "$pod_ready" == "true" || "$pod_phase" == "Succeeded" ]] \
    && [[ "$evidence_ok" -eq 1 ]]; then
    result=0
  else
    if [[ -z "$pod_created" ]]; then
      echo "HINT: Pod 'signed-admission-check' does not exist - create it with 'kubectl run' AFTER the ImageValidatingPolicy, using \$HARDENED_IMAGE."
    elif [[ "$pod_created" < "$policy_created" ]]; then
      echo "HINT: This Pod was created BEFORE the policy (pod_created=$pod_created <= policy_created=$policy_created). Re-run the new Pod after policy creation."
    elif [[ "$image_ok" -ne 1 ]]; then
      echo "HINT: Pod must use the exact digest-pinned hardened image configured by deployment/catalog, not merely any digest-pinned image."
    elif [[ "$cosign_ok" -ne 1 ]]; then
      echo "HINT: Direct 'cosign verify --key cosign.pub' for the Pod image must succeed; Ready alone is not signature proof."
    elif [[ "$pod_ready" != "true" && "$pod_phase" != "Succeeded" ]]; then
      echo "HINT: Pod is not Ready/Succeeded (phase=$pod_phase) - check it was actually admitted and started."
    else
      echo "HINT: signed-admission-check.json must record this Pod image and a creationTimestamp later than the policy."
    fi
    echo "policy_created=$policy_created pod_created=$pod_created pod_phase=$pod_phase pod_ready=$pod_ready catalog_image=${catalog_image:-missing} pod_image=${pod_image:-missing} image_ok=$image_ok cosign_ok=$cosign_ok evidence_ok=$evidence_ok"
    result=1
  fi
  record_result "$result"
}

@test "9c. An unsigned digest that exists in the same repository is denied for signature reasons" {
  exists_file="$ART/9c/unsigned-exists.txt"
  not_signed_file="$ART/9c/unsigned-not-signed.txt"
  deny_file="$ART/9c/admission-deny.txt"
  digest_file="$ART/9c/digest-comparison.txt"
  set +e
  kubectl get pod catalog-unsigned-probe -n cks-111 >/dev/null 2>&1
  probe_absent=$?
  set -e
  hardened_digest=$(awk -F= '$1 == "hardened_digest" {print $2}' "$digest_file" 2>/dev/null)
  unsigned_digest=$(awk -F= '$1 == "unsigned_digest" {print $2}' "$digest_file" 2>/dev/null)
  if [[ -s "$exists_file" ]] && [[ -s "$not_signed_file" ]] && [[ -s "$deny_file" ]] && [[ -s "$digest_file" ]] \
    && grep -Eiq 'digest|sha256|manifest' "$exists_file" \
    && grep -Eiq 'error|fail|no matching signatures|not.*signed' "$not_signed_file" \
    && "$probe_absent" -ne 0 \
    && grep -Eiq 'require-signed-catalog-images|signature|attestor|verifyImageSignatures|ImageValidatingPolicy' "$deny_file" \
    && [[ -n "$hardened_digest" && -n "$unsigned_digest" && "$hardened_digest" != "$unsigned_digest" ]]; then
    result=0
  else
    if [[ -z "$hardened_digest" || -z "$unsigned_digest" ]]; then
      echo "HINT: digest-comparison.txt is missing hardened_digest= and/or unsigned_digest= lines. Build the second tag with a distinguishing --build-arg (e.g. CKS_SIGNATURE_TEST=unsigned-1) so it gets a genuinely different manifest digest, then save both digests in this exact key=value format."
    elif [[ "$hardened_digest" == "$unsigned_digest" ]]; then
      echo "HINT: hardened_digest equals unsigned_digest - your 'unsigned' build produced the SAME content as the already-signed image (e.g. reproducible build with no distinguishing change). It must be a genuinely different artifact - use a distinct build-arg/label value."
    elif ! [[ -s "$exists_file" ]] || ! grep -Eiq 'digest|sha256|manifest' "$exists_file"; then
      echo "HINT: unsigned-exists.txt must prove the unsigned digest is a real, pullable manifest in the SAME repository - run 'docker buildx imagetools inspect' on it and save the output BEFORE testing the policy."
    elif ! [[ -s "$not_signed_file" ]] || ! grep -Eiq 'error|fail|no matching signatures|not.*signed' "$not_signed_file"; then
      echo "HINT: unsigned-not-signed.txt must show 'cosign verify' actually FAILING for this digest with your key - save that failure output before creating the test Pod."
    elif [[ "$probe_absent" -eq 0 ]]; then
      echo "HINT: Pod 'catalog-unsigned-probe' still exists - the unsigned image should have been denied by admission, so this Pod should never actually be created."
    else
      echo "HINT: admission-deny.txt does not mention the policy name/signature/attestor - the rejection may be for an unrelated reason (e.g. manifest not found). Check the digest genuinely exists in the repository first (see unsigned-exists.txt)."
    fi
    echo "exists_file=$exists_file not_signed_file=$not_signed_file deny_file=$deny_file probe_absent=$probe_absent hardened_digest=$hardened_digest unsigned_digest=$unsigned_digest"
    result=1
  fi
  record_result "$result"
}
