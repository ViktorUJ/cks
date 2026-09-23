#!/usr/bin/env bats

ROOT=/home/ubuntu/cks-111
KEYDIR=/home/ubuntu/.cks111-cosign
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
  result=1
  image=$(jq -r '.ArtifactName // ""' "$report" 2>/dev/null)
  checker_report=$(mktemp)
  if [[ -s "$report" ]] \
    && [[ "$image" =~ ^nginx:1[.]27[.]3-alpine@sha256:[a-f0-9]{64}$ ]] \
    && jq -e '(.Results | type == "array")' "$report" >/dev/null 2>&1 \
    && jq -e '(.Metadata.RepoDigests | type == "array") and (.Metadata.RepoDigests | length > 0)' "$report" >/dev/null 2>&1 \
    && trivy image --scanners vuln --vuln-type os,library --format json --output "$checker_report" "$image" >/dev/null 2>&1 \
    && jq -e --arg image "$image" '.ArtifactName == $image and (.Results | type == "array")' "$checker_report" >/dev/null 2>&1; then
    result=0
  else
    echo "HINT: Report is empty/invalid JSON, or .ArtifactName is not exactly 'nginx:1.27.3-alpine@sha256:<64-hex>' - make sure you scanned the immutable \$IMAGE reference (tag@digest), not a bare mutable tag like 'nginx:1.27.3-alpine' or 'nginx:latest'. The checker also independently re-runs 'trivy image' against the SAME reference and requires that real scan to also succeed and match - a hand-written JSON that merely matches the schema/regex does not pass."
    echo "Missing or invalid Trivy report: $report"
  fi
  rm -f "$checker_report"
  record_result "$result"
}

@test "1b. Multi-image CVE triage identifies the actual offending candidate" {
  CHECKER=/var/lib/cks-lab111-checker
  answer="$ART/1b/answer.txt"
  scan="$ART/1b/target-scan.json"
  result=1

  target_cve=$(sudo grep -m1 '^TARGET_CVE=' "$CHECKER/task1b-baseline.txt" | cut -d= -f2-)
  target_ref=$(sudo grep -m1 '^TARGET_IMAGE_REF=' "$CHECKER/task1b-baseline.txt" | cut -d= -f2-)
  student_ref=$(grep -m1 '^OFFENDING_IMAGE=' "$answer" 2>/dev/null | cut -d= -f2-)

  if [[ -n "$target_cve" && -n "$target_ref" && "$student_ref" == "$target_ref" ]] \
    && [[ -s "$scan" ]] \
    && jq -e --arg image "$student_ref" '.ArtifactName == $image' "$scan" >/dev/null 2>&1 \
    && jq -e --arg cve "$target_cve" '[.Results[]? | .Vulnerabilities[]? | .VulnerabilityID] | index($cve) != null' "$scan" >/dev/null 2>&1; then
    # Independently re-scan the SAME reference the student named - a hand-written JSON
    # that merely matches the schema/CVE-ID string does not pass.
    checker_scan=$(mktemp)
    if trivy image --scanners vuln --format json --output "$checker_scan" "$student_ref" >/dev/null 2>&1 \
      && jq -e --arg cve "$target_cve" '[.Results[]? | .Vulnerabilities[]? | .VulnerabilityID] | index($cve) != null' "$checker_scan" >/dev/null 2>&1; then
      result=0
    else
      echo "HINT: the checker independently re-ran 'trivy image' against the exact reference in your answer.txt and did not find $target_cve there - $scan may be hand-edited rather than real scanner output."
    fi
    rm -f "$checker_scan"
  else
    echo "HINT: /home/ubuntu/cks-111/candidates.txt lists TARGET_CVE and three candidate image references (CANDIDATE_1/2/3). Scan ALL THREE with 'trivy image --format json <ref>', find which one's Vulnerabilities array actually contains TARGET_CVE, save that scan's JSON to $scan, and write 'OFFENDING_IMAGE=<that exact ref>' to $answer."
  fi
  record_result "$result"
}

@test "1c. Workload CRITICAL-severity triage ranking is correct and remediation is applied" {
  result=1
  mapfile -t deploys < <(kubectl -n cks-111 get deployment -l cks.io/task=1c \
    -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.template.spec.containers[0].image}{" "}{.spec.replicas}{"\n"}{end}' 2>/dev/null)

  if [[ "${#deploys[@]}" -ne 4 ]]; then
    echo "HINT: expected exactly 4 Deployments labelled cks.io/task=1c in namespace cks-111 - the lab fixture may not have provisioned correctly."
    echo "found=${#deploys[@]}"
    record_result "$result"
    return
  fi

  declare -A live_image live_replicas
  for line in "${deploys[@]}"; do
    name=$(awk '{print $1}' <<<"$line")
    live_image["$name"]=$(awk '{print $2}' <<<"$line")
    live_replicas["$name"]=$(awk '{print ($3 == "" ? 0 : $3)}' <<<"$line")
  done

  # Checker independently re-scans all 4 LIVE images fresh, right now, rather than
  # trusting a bootstrap-time snapshot or any student-submitted count - the actual
  # CRITICAL ranking can drift over the lab's lifetime as the vulnerability DB updates.
  declare -A fresh_critical
  for name in "${!live_image[@]}"; do
    scan_tmp=$(mktemp)
    trivy image --scanners vuln --severity CRITICAL --format json --quiet "${live_image[$name]}" > "$scan_tmp" 2>/dev/null
    fresh_critical["$name"]=$(jq -r '[.Results[]? | .Vulnerabilities[]? | select(.Severity=="CRITICAL") | .VulnerabilityID] | unique | length' "$scan_tmp" 2>/dev/null || echo 0)
    rm -f "$scan_tmp"
  done

  mapfile -t ranked < <(for name in "${!fresh_critical[@]}"; do printf '%s %s\n' "${fresh_critical[$name]}" "$name"; done | sort -rn -k1,1 | awk '{print $2}')
  most_vulnerable="${ranked[0]}"
  least_1="${ranked[-1]}"
  least_2="${ranked[-2]}"

  ranking_file="$ART/1c/ranking.txt"
  student_most=$(awk -F= '$1=="MOST_VULNERABLE"{print substr($0,index($0,"=")+1)}' "$ranking_file" 2>/dev/null)
  student_least1=$(awk -F= '$1=="LEAST_VULNERABLE_1"{print substr($0,index($0,"=")+1)}' "$ranking_file" 2>/dev/null)
  student_least2=$(awk -F= '$1=="LEAST_VULNERABLE_2"{print substr($0,index($0,"=")+1)}' "$ranking_file" 2>/dev/null)

  ranking_ok=0
  if [[ "$student_most" == "$most_vulnerable" ]] \
    && { [[ "$student_least1" == "$least_1" && "$student_least2" == "$least_2" ]] \
      || [[ "$student_least1" == "$least_2" && "$student_least2" == "$least_1" ]]; }; then
    ranking_ok=1
  fi

  cdx="$ART/1c/cyclonedx.json"
  cdx_ok=0
  most_digest="${live_image[$most_vulnerable]#*@}"
  if [[ -s "$cdx" ]] && jq -e '.bomFormat == "CycloneDX"' "$cdx" >/dev/null 2>&1 \
    && grep -qF "$most_digest" "$cdx"; then
    cdx_ok=1
  fi

  remediation_ok=1
  for name in "${!live_replicas[@]}"; do
    if [[ "$name" == "$least_1" || "$name" == "$least_2" ]]; then
      [[ "${live_replicas[$name]}" -ge 1 ]] || remediation_ok=0
    else
      [[ "${live_replicas[$name]}" -eq 0 ]] || remediation_ok=0
    fi
  done

  if [[ "$ranking_ok" -eq 1 && "$cdx_ok" -eq 1 && "$remediation_ok" -eq 1 ]]; then
    result=0
  else
    [[ "$ranking_ok" -ne 1 ]] && echo "HINT: $ranking_file's MOST_VULNERABLE/LEAST_VULNERABLE_1/2 (deployment names) does not match the checker's own fresh 'trivy image --severity CRITICAL' re-scan of the 4 live Deployments' images right now - actually scan all 4 and count unique VulnerabilityIDs, do not guess or hand-write this."
    [[ "$cdx_ok" -ne 1 ]] && echo "HINT: cyclonedx.json must be a real Trivy-generated CycloneDX document ('trivy image --format cyclonedx') whose content references the digest of the image the checker independently determined to be MOST vulnerable right now, not Syft output or a document for a different image."
    [[ "$remediation_ok" -ne 1 ]] && echo "HINT: exactly the two LEAST vulnerable Deployments (per the checker's fresh scan) must have replicas > 0; the other two (including the most vulnerable) must be scaled to replicas=0."
    echo "most_vulnerable=$most_vulnerable least_1=$least_1 least_2=$least_2 student_most=${student_most:-missing} student_least1=${student_least1:-missing} student_least2=${student_least2:-missing}"
  fi
  record_result "$result"
}

@test "2. Before-fix reports from Hadolint, kubesec, and kube-linter exist" {
  h="$ART/2/hadolint-before.txt"; k="$ART/2/kubesec-before.json"; l="$ART/2/kube-linter-before.json"
  CHECKER=/var/lib/cks-lab111-checker
  result=1
  if [[ -s "$h" ]] && grep -Eq 'DL[0-9]+' "$h" && jq -e 'type == "array" and length > 0 and .[0].scoring' "$k" >/dev/null 2>&1 && jq -e '
    type == "object" and
    (.Summary | type == "object") and
    (.Reports | type == "array") and
    (.Reports | length > 0)
  ' "$l" >/dev/null 2>&1; then
    # Compare student-submitted evidence against the bootstrap-owned baseline captured
    # from the ORIGINAL starter files before the student could touch them - this rules
    # out a hand-written text/JSON file that merely satisfies the schema/regex above but
    # was never actually produced by running the three analyzers on the real starter files.
    if cmp -s "$h" <(sudo cat "$CHECKER/hadolint-before.txt") \
      && diff -q <(jq -S . "$k") <(sudo jq -S . "$CHECKER/kubesec-before.json") >/dev/null 2>&1 \
      && diff -q <(jq -S . "$l") <(sudo jq -S . "$CHECKER/kube-linter-before.json") >/dev/null 2>&1; then
      result=0
    else
      echo "HINT: One of the three before-fix reports does not match the bootstrap-captured baseline from the ORIGINAL starter Dockerfile/deployment.yaml - re-run hadolint/kubesec/kube-linter directly against the untouched starter files (before making any remediation edits), do not hand-write or reconstruct the report text."
      echo "Before-fix evidence in $ART/2 does not match the checker-owned baseline"
    fi
  else
    echo "HINT: One of the three before-fix reports is missing/empty or in the wrong format. hadolint-before.txt must actually contain a DL#### finding code (the starter Dockerfile has real issues); kubesec-before.json must be a JSON array with a 'scoring' key; kube-linter-before.json must be KubeLinter's native JSON object with a 'Summary' object and a non-empty 'Reports' array - check you used --format json for kube-linter."
    echo "Expected three valid before-fix reports in $ART/2"
  fi
  record_result "$result"
}

@test "3. Dockerfile is pinned, has no secret or remote ADD, and runs non-root" {
  file="$ROOT/Dockerfile"; report="$ART/3/hadolint-after.txt"
  result=1
  if [[ -f "$file" ]] && grep -Eq '^FROM[[:space:]]+nginx:1[.]27[.]3-alpine@sha256:[a-f0-9]{64}$' "$file" && ! grep -Eqi '^[[:space:]]*ADD[[:space:]]+https?://|^[[:space:]]*ENV[[:space:]].*(API_TOKEN|TOKEN)|sudo|:latest' "$file" && grep -Eq '^[[:space:]]*USER[[:space:]]+[1-9][0-9]*(:[0-9]+)?[[:space:]]*$' "$file" && grep -Eq '^[[:space:]]*ARG[[:space:]]+CKS_SIGNATURE_TEST' "$file" && grep -Eq '^[[:space:]]*LABEL[[:space:]]+cks[.]signature-test=\$CKS_SIGNATURE_TEST[[:space:]]*$' "$file" && [[ -s "$report" ]] && ! grep -Eq 'DL3007|DL3013|DL3020|DL3045' "$report"; then
    # Independently re-run hadolint against the CURRENT Dockerfile rather than trusting
    # only the student artifact, which could be hand-edited or left over from a stale run.
    # An independent re-run alone only proves the file's CURRENT state is clean - it does
    # NOT prove the submitted artifact's actual content came from hadolint, so also
    # require the artifact to match this fresh run exactly.
    checker_after=$(mktemp)
    hadolint "$file" > "$checker_after" 2>&1 || true
    if ! grep -Eq 'DL3007|DL3013|DL3020|DL3045' "$checker_after" && cmp -s "$report" "$checker_after"; then
      result=0
    elif grep -Eq 'DL3007|DL3013|DL3020|DL3045' "$checker_after"; then
      echo "HINT: The checker independently re-ran hadolint against the CURRENT Dockerfile and it still reports one of DL3007/DL3013/DL3020/DL3045 - your hadolint-after.txt artifact does not reflect the file's actual current state."
      echo "Checker re-run of hadolint still finds a target finding code"
    else
      echo "HINT: hadolint-after.txt does not match the checker's own fresh 'hadolint \$ROOT/Dockerfile' run against the CURRENT file byte-for-byte - do not hand-write or edit this artifact, save the real hadolint output."
      echo "Submitted hadolint-after.txt does not match checker re-run"
    fi
    rm -f "$checker_after"
  else
    echo "HINT: Check each requirement individually - FROM must pin nginx:1.27.3-alpine@sha256:<64-hex>, no remote ADD/API_TOKEN/sudo/:latest, USER must be a numeric non-zero uid (USER root/USER 0 both FAIL, even though they pass a naive 'not literally 0' text check), and both 'ARG CKS_SIGNATURE_TEST' + a LABEL that actually references \$CKS_SIGNATURE_TEST (not a hardcoded value like 'LABEL cks.signature-test=signed') - needed later by task 9c so the build-arg genuinely changes the image digest. hadolint-after.txt must be non-empty and show none of DL3007/DL3013/DL3020/DL3045 remaining."
    echo "Dockerfile remediation or Hadolint after-report is incomplete"
  fi
  record_result "$result"
}

@test "4. Live Deployment has the required hardening and serves HTTP" {
  file="$ROOT/deployment.yaml"; k="$ART/4/kubesec-after.json"; l="$ART/4/kube-linter-after.json"

  result=1

  if ! jq -e 'type == "array"' "$k" >/dev/null 2>&1; then
    echo "HINT: kubesec-after.json must be a JSON array (kubesec's native output format)."
    echo "Invalid kubesec after-report"
    record_result "$result"
    return
  fi

  if ! jq -e '
      type == "object" and
      (.Summary | type == "object") and
      ((.Reports == null) or (.Reports | type == "array"))
    ' "$l" >/dev/null 2>&1; then
    echo "HINT: kube-linter-after.json must be KubeLinter's native JSON object with a 'Summary' object (Reports may be null/empty after remediation, but the file itself must be a valid KubeLinter object, not a bare array)."
    echo "Invalid KubeLinter after-report"
    record_result "$result"
    return
  fi

  # Independently re-run kubesec/kube-linter against the CURRENT deployment.yaml rather
  # than trusting only the student artifacts, which could be any syntactically valid JSON
  # of the right top-level type without ever having been produced by the real tools.
  checker_kubesec=$(mktemp); checker_kubelinter=$(mktemp)
  kubesec scan "$file" > "$checker_kubesec" 2>&1 || true
  kube-linter lint "$file" --format json > "$checker_kubelinter" 2>&1 || true
  if ! jq -e 'type == "array" and length > 0 and .[0].scoring' "$checker_kubesec" >/dev/null 2>&1; then
    echo "HINT: The checker independently re-ran kubesec against the CURRENT deployment.yaml and could not get a valid scored JSON array from it - check the file is still valid YAML kubesec can parse."
    echo "Checker re-run of kubesec against current deployment.yaml is invalid"
    rm -f "$checker_kubesec" "$checker_kubelinter"
    record_result "$result"
    return
  fi
  if ! jq -e 'type == "object" and (.Summary | type == "object")' "$checker_kubelinter" >/dev/null 2>&1; then
    echo "HINT: The checker independently re-ran kube-linter against the CURRENT deployment.yaml and could not get a valid KubeLinter JSON object from it."
    echo "Checker re-run of kube-linter against current deployment.yaml is invalid"
    rm -f "$checker_kubesec" "$checker_kubelinter"
    record_result "$result"
    return
  fi
  # An independent re-run alone only proves the CURRENT file's state is clean - it does
  # NOT prove the submitted artifact's actual content came from the real tool. Compare
  # the security-relevant substance (kubesec's scoring/advise, kube-linter's check names)
  # against this fresh run, normalized via jq -S and ignoring genuinely nondeterministic
  # fields (timestamps) rather than requiring byte-for-byte equality.
  student_kubesec_norm=$(jq -Sc '[.[] | .scoring]' "$k" 2>/dev/null)
  checker_kubesec_norm=$(jq -Sc '[.[] | .scoring]' "$checker_kubesec" 2>/dev/null)
  student_kubelinter_norm=$(jq -Sc '{summaryStatus: .Summary.ChecksStatus, checks: ([.Reports[]?.Check] | sort)}' "$l" 2>/dev/null)
  checker_kubelinter_norm=$(jq -Sc '{summaryStatus: .Summary.ChecksStatus, checks: ([.Reports[]?.Check] | sort)}' "$checker_kubelinter" 2>/dev/null)
  rm -f "$checker_kubesec" "$checker_kubelinter"

  if [[ -z "$student_kubesec_norm" || "$student_kubesec_norm" != "$checker_kubesec_norm" ]]; then
    echo "HINT: kubesec-after.json's scoring/advise content does not match the checker's own fresh 'kubesec scan' run against the CURRENT deployment.yaml - do not hand-write or edit this artifact, save the real kubesec output."
    echo "Submitted kubesec-after.json does not match checker re-run substance"
    record_result "$result"
    return
  fi
  if [[ -z "$student_kubelinter_norm" || "$student_kubelinter_norm" != "$checker_kubelinter_norm" ]]; then
    echo "HINT: kube-linter-after.json's Summary status/check-name set does not match the checker's own fresh 'kube-linter lint --format json' run against the CURRENT deployment.yaml - do not hand-write or edit this artifact, save the real kube-linter output."
    echo "Submitted kube-linter-after.json does not match checker re-run substance"
    record_result "$result"
    return
  fi

  if [[ ! -f "$file" ]] || ! kubectl apply -f "$file" >/dev/null 2>&1; then
    echo "HINT: deployment.yaml does not exist or does not apply - check for YAML syntax errors."
    echo "deployment.yaml does not apply"
    record_result "$result"
    return
  fi

  if ! kubectl rollout status deployment/catalog -n cks-111 --timeout=180s >/dev/null 2>&1; then
    echo "HINT: Deployment did not become Available - with readOnlyRootFilesystem:true, nginx needs writable emptyDir mounts for /tmp, /var/run, /var/cache/nginx, and /etc/nginx/conf.d (via the init container copying config first). A missing writable mount is the most common cause of CrashLoopBackOff here."
    echo "catalog Deployment did not become Available"
    record_result "$result"
    return
  fi

  deploy=$(kubectl get deployment catalog -n cks-111 -o json 2>/dev/null || true)

  # Structural validation against the LIVE effective Pod spec, not a text grep on the
  # YAML source - a comment containing 'runAsNonRoot: true' or a securityContext placed
  # on the wrong object/container could otherwise satisfy a plain grep without actually
  # being effective at runtime.
  hardening_ok=0
  if jq -e '
      .spec.template.spec.automountServiceAccountToken == false and
      .spec.template.spec.securityContext.runAsNonRoot == true and
      .spec.template.spec.securityContext.runAsUser == 101 and
      .spec.template.spec.securityContext.seccompProfile.type == "RuntimeDefault" and

      ([.spec.template.spec.initContainers[]? |
        select(.name == "prepare-nginx-config") |
        .securityContext.allowPrivilegeEscalation == false and
        (.securityContext.capabilities.drop | index("ALL") != null)
      ] | any) and

      ([.spec.template.spec.containers[]? |
        select(.name == "catalog") |
        (.image | test("@sha256:[a-f0-9]{64}$")) and
        ((.image | test("(^|/)nginx([:@]|$)")) | not) and
        .securityContext.allowPrivilegeEscalation == false and
        .securityContext.readOnlyRootFilesystem == true and
        (.securityContext.capabilities.drop | index("ALL") != null) and
        (.resources.requests.cpu | type == "string") and
        (.resources.requests.memory | type == "string") and
        (.resources.limits.cpu | type == "string") and
        (.resources.limits.memory | type == "string") and
        ([.volumeMounts[]? | .mountPath] |
          (index("/tmp") != null) and
          (index("/var/run") != null) and
          (index("/var/cache/nginx") != null) and
          (index("/etc/nginx/conf.d") != null))
      ] | any) and

      ([.spec.template.spec.volumes[]?.name] |
        (index("nginx-tmp") != null) and
        (index("nginx-run") != null) and
        (index("nginx-cache") != null) and
        (index("nginx-config") != null))
    ' <<<"$deploy" >/dev/null 2>&1; then
    hardening_ok=1
  fi

  ready=$(jq -r '.status.availableReplicas // 0' <<<"$deploy")

  set +e
  run kubectl run catalog-http-smoke -n cks-111 \
    --rm -i --restart=Never --image=curlimages/curl:8.11.0 -- \
    curl -fsS --max-time 10 http://catalog
  smoke_status="$status"
  set -e

  if [[ "$hardening_ok" -eq 1 && "$ready" -ge 1 && "$smoke_status" -eq 0 ]]; then
    result=0
  else
    if [[ "$hardening_ok" -ne 1 ]]; then
      echo "HINT: deployment.yaml must use YOUR digest-pinned hardened image (not upstream nginx), have the prepare-nginx-config init container + nginx-tmp/nginx-run/nginx-cache/nginx-config volumes, and set all of: automountServiceAccountToken:false, runAsNonRoot:true+runAsUser:101, seccompProfile RuntimeDefault, allowPrivilegeEscalation:false, readOnlyRootFilesystem:true, capabilities.drop:[ALL] on the catalog container, and CPU/memory requests+limits. This is checked against the LIVE Deployment spec, not text in the file - a comment or misplaced field will not pass."
    elif [[ "$ready" -lt 1 ]]; then
      echo "HINT: Deployment does not have availableReplicas >= 1."
    else
      echo "HINT: HTTP smoke test against Service 'catalog' failed."
    fi
    echo "Live catalog Deployment does not have the required effective hardening or HTTP smoke failed"
  fi

  record_result "$result"
}

@test "5. Version search evidence comes from Trivy package listing and includes canonical RepoDigest" {
  report="$ART/5/version-search.txt"

  image=$(awk -F= '$1 == "image" {
    print substr($0, index($0, "=") + 1)
  }' "$report" 2>/dev/null)

  repo_digest=$(awk -F= '$1 == "repo_digest" {
    print substr($0, index($0, "=") + 1)
  }' "$report" 2>/dev/null)

  image_digest="${image##*@}"
  canonical_digest="${repo_digest##*@}"

  result=1

  if [[ ! ( -s "$report" \
        && "$image" =~ ^nginx:1[.]27[.]3-alpine@sha256:[a-f0-9]{64}$ \
        && "$repo_digest" =~ ^nginx@sha256:[a-f0-9]{64}$ \
        && "$image_digest" == "$canonical_digest" ) ]] \
     || ! grep -Fq "trivy image --list-all-pkgs" "$report"; then
    echo "HINT: version-search.txt must contain the literal command 'trivy image --list-all-pkgs', an 'image=' line matching exactly nginx:1.27.3-alpine@sha256:<64-hex>, and a 'repo_digest=' line matching exactly nginx@sha256:<64-hex> with the SAME digest as image=."
    echo "Version-search evidence must include command and canonical image/repo_digest (same digest)"
    record_result "$result"
    return
  fi

  # Independently re-run the real scan and cross-check every saved name=version pair, and
  # the repo_digest=, against it - a hand-written but syntactically valid package list must
  # not pass without having actually come from Trivy's output for this exact image.
  checker_packages=$(mktemp)
  if ! trivy image --list-all-pkgs --format json "$image" > "$checker_packages" 2>/dev/null; then
    echo "HINT: The checker could not independently re-scan \$image with Trivy - check the image reference is valid."
    echo "Checker re-scan of the required image failed"
    rm -f "$checker_packages"
    record_result "$result"
    return
  fi

  real_repo_digest=$(jq -r '.Metadata.RepoDigests[0] // ""' "$checker_packages")
  if [[ "$repo_digest" != "$real_repo_digest" ]]; then
    echo "HINT: repo_digest= does not match the checker's own fresh 'Metadata.RepoDigests[0]' for this image - do not hand-write the digest, save the actual scanner output."
    echo "repo_digest mismatch against checker re-scan: saved=$repo_digest real=$real_repo_digest"
    rm -f "$checker_packages"
    record_result "$result"
    return
  fi

  confirmed=0
  while IFS='=' read -r name version; do
    if jq -e --arg name "$name" --arg version "$version" '
      any(.Results[]?.Packages[]?; .Name == $name and .Version == $version)
    ' "$checker_packages" >/dev/null 2>&1; then
      confirmed=$((confirmed + 1))
    fi
  done < <(grep -E '^[[:alnum:]_.+/-]+=[[:alnum:].+~:_-]+$' "$report" | grep -v '^image=\|^repo_digest=')

  rm -f "$checker_packages"

  if [[ "$confirmed" -ge 3 ]]; then
    result=0
  else
    echo "HINT: At least 3 saved name=version package lines must be independently confirmed against the checker's own fresh 'trivy image --list-all-pkgs' output for this image - do not hand-write the package list, save the actual scanner output. Only $confirmed of the saved lines were confirmed."
    echo "Insufficient package lines confirmed against checker re-scan: confirmed=$confirmed"
  fi
  record_result "$result"
}

@test "5b. Package-version audit correctly finds and removes only the offending containers" {
  CHECKER=/var/lib/cks-lab111-checker
  result=1

  target_package=$(sudo grep -m1 '^TARGET_PACKAGE=' "$CHECKER/task5b-baseline.txt" 2>/dev/null | cut -d= -f2-)
  target_version=$(sudo grep -m1 '^TARGET_VERSION=' "$CHECKER/task5b-baseline.txt" 2>/dev/null | cut -d= -f2-)
  clean_container=$(sudo grep -m1 '^CLEAN_CONTAINER=' "$CHECKER/task5b-baseline.txt" 2>/dev/null | cut -d= -f2-)
  offending_image_1=$(sudo grep -m1 '^OFFENDING_IMAGE_1=' "$CHECKER/task5b-baseline.txt" 2>/dev/null | cut -d= -f2-)

  if [[ -z "$target_package" || -z "$target_version" || -z "$clean_container" ]]; then
    echo "HINT: checker-owned task5b-baseline.txt is missing or unreadable - this is an infrastructure precondition failure, not something fixable from inside the lab."
    record_result "$result"
    return
  fi

  # Independently confirm the checker-owned ground truth is real, right now: re-run
  # 'bom generate' against the ORIGINAL offending image (recorded at provisioning,
  # since the live Deployment's offending containers are expected to be gone by now)
  # rather than trusting only the persisted baseline text or the student's own artifact.
  checker_sbom=$(mktemp)
  checker_confirms=0
  if bom generate --format json --output "$checker_sbom" --image "$offending_image_1" >/dev/null 2>&1 \
    && jq -e --arg pkg "$target_package" --arg ver "$target_version" \
      'any(.packages[]?; .name == $pkg and .versionInfo == $ver)' "$checker_sbom" >/dev/null 2>&1; then
    checker_confirms=1
  fi
  rm -f "$checker_sbom"

  answer="$ART/5b/answer.txt"
  student_pkg=$(awk -F= '$1=="TARGET_PACKAGE"{print substr($0,index($0,"=")+1)}' "$answer" 2>/dev/null)
  student_ver=$(awk -F= '$1=="TARGET_VERSION"{print substr($0,index($0,"=")+1)}' "$answer" 2>/dev/null)
  identify_ok=0
  [[ "$student_pkg" == "$target_package" && "$student_ver" == "$target_version" ]] && identify_ok=1

  bom_dir="$ART/5b/bom"
  spdx_ok=0
  if [[ -d "$bom_dir" ]]; then
    for f in "$bom_dir"/*.json; do
      [[ -f "$f" ]] || continue
      if jq -e --arg pkg "$target_package" --arg ver "$target_version" \
        'any(.packages[]?; .name == $pkg and .versionInfo == $ver)' "$f" >/dev/null 2>&1; then
        spdx_ok=1
        break
      fi
    done
  fi

  deploy=$(kubectl -n cks-111 get deployment pkg-audit-app -o json 2>/dev/null)
  remaining=$(jq -r '[.spec.template.spec.containers[]?.name] | sort | join(",")' <<<"$deploy" 2>/dev/null)
  expected_remaining=$(printf '%s\n' "$clean_container" | tr ',' '\n' | sort | tr '\n' ',' | sed 's/,$//')
  available=$(jq -r '.status.availableReplicas // 0' <<<"$deploy" 2>/dev/null)

  remediation_ok=0
  [[ "$remaining" == "$expected_remaining" ]] && remediation_ok=1

  if [[ "$checker_confirms" -eq 1 && "$identify_ok" -eq 1 && "$spdx_ok" -eq 1 \
    && "$remediation_ok" -eq 1 && "$available" -ge 1 ]]; then
    result=0
  else
    [[ "$checker_confirms" -ne 1 ]] && echo "HINT: infrastructure precondition failure - the checker's own independent 'bom generate' re-run against the original offending image did not confirm the recorded TARGET_PACKAGE/TARGET_VERSION. Contact the lab operator."
    [[ "$identify_ok" -ne 1 ]] && echo "HINT: $answer must contain TARGET_PACKAGE=/TARGET_VERSION= exactly matching this lab instance's real offending package/version, found by actually running 'bom generate' against all three container images - this is generated per lab instance, do not guess or copy from another run."
    [[ "$spdx_ok" -ne 1 ]] && echo "HINT: save at least one real 'bom generate' SPDX JSON output (per scanned container image) under $bom_dir/ that actually lists TARGET_PACKAGE at TARGET_VERSION - a hand-written file does not count."
    [[ "$remediation_ok" -ne 1 ]] && echo "HINT: Deployment pkg-audit-app must end up with ONLY the non-offending container(s) remaining (expected: $clean_container) - remove exactly the containers that contained the target package/version by editing spec.template.spec.containers, not just the field that matched."
    [[ "$available" -lt 1 ]] && echo "HINT: Deployment pkg-audit-app must remain Available (availableReplicas >= 1) after removing the offending containers."
    echo "target_package=$target_package target_version=$target_version clean_container=$clean_container remaining=$remaining expected_remaining=$expected_remaining available=$available checker_confirms=$checker_confirms"
  fi
  record_result "$result"
}

@test "6. bom generated an SPDX SBOM and command evidence" {
  sbom="$ART/6/bom.spdx.json"; command_file="$ART/6/bom-command.txt"
  expected_image=$(jq -r '.ArtifactName // ""' "$ART/1/trivy-report.json" 2>/dev/null)
  expected_digest="${expected_image#*@}"
  result=1
  if [[ "$expected_image" =~ ^nginx:1[.]27[.]3-alpine@sha256:[a-f0-9]{64}$ ]] \
    && jq -e --arg digest "$expected_digest" '
      . as $doc |
      ($doc.spdxVersion | startswith("SPDX-")) and
      ($doc.packages | type == "array") and
      (($doc.documentDescribes // []) | type == "array") and
      (
        [
          $doc.packages[]
          | select(
              .SPDXID as $id |
              (($doc.documentDescribes // []) | index($id)) != null
            )
          | (.versionInfo // .name // "")
          | select(endswith($digest))
        ]
        | length > 0
      )
    ' "$sbom" >/dev/null 2>&1 \
    && grep -q 'bom generate' "$command_file" 2>/dev/null \
    && grep -Fq -- "--image $expected_image" "$command_file" 2>/dev/null; then
    # Independently re-run bom against the SAME required image, rather than trusting only
    # a hand-written SPDX JSON that merely satisfies the schema/digest-binding checks above
    # - this confirms the tool can actually generate evidence for this exact image right now,
    # and additionally cross-checks the package INVENTORY (not just top-level digest binding)
    # so a minimal hand-written SBOM with only the required digest cannot pass.
    checker_sbom=$(mktemp)
    if bom generate --format json --output "$checker_sbom" --image "$expected_image" >/dev/null 2>&1 \
      && jq -e --arg digest "$expected_digest" '
        . as $doc |
        ($doc.spdxVersion | startswith("SPDX-")) and
        (
          [
            $doc.packages[]
            | select(.SPDXID as $id | (($doc.documentDescribes // []) | index($id)) != null)
            | (.versionInfo // .name // "")
            | select(endswith($digest))
          ] | length > 0
        )
      ' "$checker_sbom" >/dev/null 2>&1; then
      student_pkgs=$(jq -Sc '[.packages[]? | {name: .name, versionInfo: (.versionInfo // "")}] | sort' "$sbom" 2>/dev/null)
      checker_pkgs=$(jq -Sc '[.packages[]? | {name: .name, versionInfo: (.versionInfo // "")}] | sort' "$checker_sbom" 2>/dev/null)
      student_pkg_count=$(jq '.packages | length' "$sbom" 2>/dev/null || echo 0)
      checker_pkg_count=$(jq '.packages | length' "$checker_sbom" 2>/dev/null || echo 0)
      # Require a realistic, non-trivial package inventory (not just the one top-level
      # described package) and require the student SBOM's package set to actually match
      # the checker's fresh re-run for this same image.
      if [[ "$checker_pkg_count" -ge 2 && "$student_pkg_count" -ge 2 && "$student_pkgs" == "$checker_pkgs" ]]; then
        result=0
      else
        echo "HINT: bom.spdx.json's package inventory (name/versionInfo set) does not match the checker's own fresh 'bom generate --image \$expected_image' run for the SAME image, or is too small to be a real image scan (student_pkg_count=$student_pkg_count, checker_pkg_count=$checker_pkg_count) - a minimal hand-written SPDX document containing only the required top-level digest is not sufficient; save the actual bom output."
        echo "Submitted bom SBOM package inventory does not match checker re-run"
      fi
    else
      echo "HINT: The checker independently re-ran 'bom generate --image \$expected_image' and could not reproduce a valid SPDX document describing the same digest - check that bom can actually be invoked against this exact image reference right now."
      echo "Checker re-run of bom generate against the required image failed"
    fi
    rm -f "$checker_sbom"
  else
    echo "HINT: bom.spdx.json must have an 'spdxVersion' field starting with 'SPDX-' and a 'packages' array - this is bom's native output format, not the same schema as Syft's SPDX. One of the top-level packages referenced by 'documentDescribes' must actually identify the SAME manifest digest as the required immutable \$IMAGE from task 1 (via its versionInfo/name) - an SPDX SBOM for a different image (e.g. alpine, busybox) must not pass even with a forged bom-command.txt. bom-command.txt must also contain the literal text 'bom generate' AND '--image <the exact same immutable \$IMAGE from task 1's trivy report>'."
    echo "Missing valid bom SPDX SBOM describing the required image digest, or command evidence tied to the required image"
  fi
  record_result "$result"
}

@test "7. Syft CycloneDX SBOM and keyless Cosign verification are valid" {
  sbom="$ART/7/syft.cdx.json"
  verify="$ART/7/cosign-verify.txt"
  expected_image=$(jq -r '.ArtifactName // ""' "$ART/1/trivy-report.json" 2>/dev/null)
  expected_digest="${expected_image#*@}"
  result=1

  cosign_ok=0
  if cosign verify \
      --certificate-oidc-issuer https://accounts.google.com \
      --certificate-identity keyless@distroless.iam.gserviceaccount.com \
      gcr.io/distroless/static-debian13:nonroot \
      >/dev/null 2>&1; then
    cosign_ok=1
  fi

  if [[ "$expected_image" =~ ^nginx:1[.]27[.]3-alpine@sha256:[a-f0-9]{64}$ ]] \
    && jq -e --arg digest "$expected_digest" '
      .bomFormat == "CycloneDX" and
      (.components | type == "array") and
      (.components | length > 0) and
      .metadata.component.type == "container" and
      .metadata.component.version == $digest
    ' "$sbom" >/dev/null 2>&1 \
    && [[ -s "$verify" ]] \
    && grep -Fq 'gcr.io/distroless/static-debian13:nonroot' "$verify" \
    && [[ "$cosign_ok" -eq 1 ]]; then
    # Independently re-run syft against the SAME required image, rather than trusting
    # only a hand-written CycloneDX JSON that merely satisfies the digest-binding check
    # above - this confirms the tool can actually generate evidence for this image now,
    # and additionally cross-checks the component INVENTORY so a minimal hand-written
    # CycloneDX document with only the required digest cannot pass.
    checker_sbom=$(mktemp)
    if syft "$expected_image" -o "cyclonedx-json=$checker_sbom" >/dev/null 2>&1 \
      && jq -e --arg digest "$expected_digest" '
        .bomFormat == "CycloneDX" and
        .metadata.component.type == "container" and
        .metadata.component.version == $digest
      ' "$checker_sbom" >/dev/null 2>&1; then
      student_components=$(jq -Sc '[.components[]? | {name: .name, version: (.version // "")}] | sort' "$sbom" 2>/dev/null)
      checker_components=$(jq -Sc '[.components[]? | {name: .name, version: (.version // "")}] | sort' "$checker_sbom" 2>/dev/null)
      student_comp_count=$(jq '.components | length' "$sbom" 2>/dev/null || echo 0)
      checker_comp_count=$(jq '.components | length' "$checker_sbom" 2>/dev/null || echo 0)
      # Require a realistic, non-trivial component inventory and require the student
      # SBOM's component set to actually match the checker's fresh re-run for this image.
      if [[ "$checker_comp_count" -ge 2 && "$student_comp_count" -ge 2 && "$student_components" == "$checker_components" ]]; then
        result=0
      else
        echo "HINT: syft.cdx.json's component inventory (name/version set) does not match the checker's own fresh 'syft \$expected_image -o cyclonedx-json' run for the SAME image, or is too small to be a real image scan (student_comp_count=$student_comp_count, checker_comp_count=$checker_comp_count) - a minimal hand-written CycloneDX document containing only the required top-level digest is not sufficient; save the actual syft output."
        echo "Submitted syft SBOM component inventory does not match checker re-run"
      fi
    else
      echo "HINT: The checker independently re-ran 'syft \$expected_image -o cyclonedx-json' and could not reproduce a valid CycloneDX document for the same digest - check that syft can actually be invoked against this exact image reference right now."
      echo "Checker re-run of syft against the required image failed"
    fi
    rm -f "$checker_sbom"
  else
    echo "HINT: syft.cdx.json must have bomFormat 'CycloneDX', a non-empty 'components' array, and metadata.component.type=='container' with metadata.component.version equal to the SAME digest as the required immutable \$IMAGE from task 1 - an SBOM for a different image (e.g. alpine, busybox) must not pass. cosign-verify.txt must be non-empty and mention 'gcr.io/distroless/static-debian13:nonroot' (the current supported Distroless tag - 'gcr.io/distroless/static:nonroot' without the -debian13 suffix is deprecated and no longer updated per the official Distroless README). The checker also independently runs 'cosign verify' itself for this image/issuer/identity and requires it to succeed (exit code 0) - real cosign output does NOT contain the literal string 'Verified OK', success is determined by exit code."
    echo "Syft CycloneDX SBOM or real Distroless Cosign verification is invalid"
  fi

  record_result "$result"
}

@test "8. trivy sbom can scan the task-6 SBOM file" {
  report="$ART/8/sbom-scan.json"
  input_sbom="$ART/6/bom.spdx.json"
  cmd_file="$ART/8/sbom-scan-command.txt"
  checker_report=$(mktemp)

  result=1

  if [[ -s "$report" ]] \
    && jq -e '(.Results | type == "array")' "$report" >/dev/null 2>&1 \
    && grep -Fq "trivy sbom" "$cmd_file" 2>/dev/null \
    && grep -Fq "$input_sbom" "$cmd_file" 2>/dev/null \
    && trivy sbom --format json --output "$checker_report" "$input_sbom" \
         >/dev/null 2>&1 \
    && jq -e '(.Results | type == "array")' "$checker_report" \
         >/dev/null 2>&1; then
    result=0
  else
    echo "HINT: sbom-scan.json must be valid native Trivy JSON with a 'Results' array (not hand-modified with an added ScanCommand field), sbom-scan-command.txt must show 'trivy sbom' actually run against the task-6 SBOM file, and the checker independently re-runs 'trivy sbom' on that exact input file itself - it does not trust any student-authored ScanCommand field inside the JSON."
    echo "Missing or impure trivy sbom scan evidence: $report"
  fi

  rm -f "$checker_report"
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
  if [[ -n "$hardened_image" && -s "$KEYDIR/cosign.pub" ]] \
    && cosign verify --key "$KEYDIR/cosign.pub" "$hardened_image" >/dev/null 2>&1; then cosign_ok=1; fi
  # Check the SPECIFIC admission-controller Deployment, not any Deployment matching a
  # shared part-of=kyverno label - that label also selects background/cleanup/reports
  # controllers, whose readiness says nothing about the admission webhook itself.
  admission_ready=$(kubectl -n kyverno get deployment kyverno-admission-controller -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)
  admission_ok=0
  if [[ "$admission_ready" =~ ^[0-9]+$ ]] && (( admission_ready >= 1 )); then
    admission_ok=1
  fi
  if [[ -n "$crd" && "$policy_ok" -eq 1 && "$admission_ok" -eq 1 && "$cosign_ok" -eq 1 ]] \
    && [[ -s "$sign" ]] && grep -Eiq 'signing|pushing|tlog|signed' "$sign"; then
    result=0
  else
    if [[ -z "$crd" ]]; then
      echo "HINT: ImageValidatingPolicy CRD is missing - run 'sudo install-kyverno' and wait for the Helm release/CRDs to finish installing."
    elif [[ "$policy_ok" -ne 1 ]]; then
      echo "HINT: Policy must deny, contain a Cosign key and verifyImageSignatures expression, and match exactly \$HARDENED_REPO:* plus \$HARDENED_REPO@* (not the unsafe \$HARDENED_REPO* prefix)."
    elif [[ "$admission_ok" -ne 1 ]]; then
      echo "HINT: Deployment kyverno/kyverno-admission-controller does not have availableReplicas >= 1 - this is the specific Deployment that runs the admission webhook (not the background/cleanup/reports controllers, which share the same app.kubernetes.io/part-of=kyverno label but do not enforce ImageValidatingPolicy). Wait longer for it to become Ready."
    elif [[ "$cosign_ok" -ne 1 ]]; then
      echo "HINT: Direct 'cosign verify --key cosign.pub \$HARDENED_IMAGE' must succeed; a plausible cosign-sign.txt alone is not signature proof."
    else
      echo "HINT: cosign-sign.txt does not look like a successful 'cosign sign' output for \$HARDENED_IMAGE - check you signed YOUR hardened image, not upstream nginx."
    fi
    echo "crd=${crd:-missing} policy_ok=$policy_ok admission_ok=$admission_ok admission_ready=${admission_ready:-none} hardened_image=${hardened_image:-missing} cosign_ok=$cosign_ok sign=$sign"
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
  if [[ "$image_ok" -eq 1 && -s "$KEYDIR/cosign.pub" ]] \
    && cosign verify --key "$KEYDIR/cosign.pub" "$pod_image" >/dev/null 2>&1; then cosign_ok=1; fi
  evidence_ok=0
  if [[ -s "$evidence" ]] && jq -e \
      --arg policy "$policy_created" \
      --arg created "$pod_created" \
      --arg image "$pod_image" \
      --arg phase "$pod_phase" \
      --argjson ready "$pod_ready" '
        (.policyCreationTimestamp // "") == $policy and
        (.creationTimestamp // "") == $created and
        (.creationTimestamp > .policyCreationTimestamp) and
        (.createdAfterPolicy == true) and
        (.image // "") == $image and
        (.phase // "") == $phase and
        (.ready // false) == $ready
      ' "$evidence" >/dev/null 2>&1; then
    evidence_ok=1
  fi
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

@test "9c. A real unsigned digest in the same repository is denied for signature reasons" {
  digest_file="$ART/9c/digest-comparison.txt"
  hardened_image=$(kubectl get deployment catalog -n cks-111 \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)

  hardened_repo="${hardened_image%@*}"
  hardened_digest="${hardened_image#*@}"

  unsigned_image=$(awk -F= '$1 == "unsigned_image" {
    print substr($0, index($0, "=") + 1)
  }' "$digest_file" 2>/dev/null)

  unsigned_repo="${unsigned_image%@*}"
  unsigned_digest="${unsigned_image#*@}"

  result=1

  if [[ -z "$hardened_image" \
        || ! "$hardened_image" =~ @sha256:[a-f0-9]{64}$ \
        || -z "$unsigned_image" \
        || ! "$unsigned_image" =~ @sha256:[a-f0-9]{64}$ \
        || "$unsigned_repo" != "$hardened_repo" \
        || "$unsigned_digest" == "$hardened_digest" ]]; then
    echo "HINT: digest-comparison.txt must contain an unsigned_image= line with a full tag@digest reference in the EXACT SAME repository as the hardened image, with a genuinely different digest."
    echo "Unsigned candidate must be a different digest in the exact same repository"
    record_result "$result"
    return
  fi

  if ! docker buildx imagetools inspect "$unsigned_image" >/dev/null 2>&1; then
    echo "HINT: The unsigned_image reference does not resolve in the registry - it must be a real, pullable manifest."
    echo "Unsigned image does not resolve in the registry"
    record_result "$result"
    return
  fi

  if cosign verify --key "$KEYDIR/cosign.pub" "$unsigned_image" >/dev/null 2>&1; then
    echo "HINT: cosign verify unexpectedly SUCCEEDED for the 'unsigned' candidate - it must not actually be signed with your key."
    echo "Unsigned candidate unexpectedly has a valid signature"
    record_result "$result"
    return
  fi

  probe="catalog-unsigned-checker-${BATS_TEST_NUMBER:-9}-$$"
  set +e
  deny_output=$(kubectl run "$probe" -n cks-111 \
    --image="$unsigned_image" --restart=Never 2>&1)
  deny_rc=$?
  set -e

  # If the policy unexpectedly let the Pod through, clean it up and FAIL - PASS must
  # never be achievable by hand-writing evidence text files without a real DENY.
  if kubectl get pod "$probe" -n cks-111 >/dev/null 2>&1; then
    kubectl delete pod "$probe" -n cks-111 --ignore-not-found >/dev/null 2>&1 || true
    echo "HINT: The checker's own fresh admission request for the real unsigned digest was ADMITTED, not denied - the ImageValidatingPolicy is not actually blocking unsigned images in this repository."
    echo "Unsigned Pod was admitted"
    record_result "$result"
    return
  fi

  if [[ "$deny_rc" -ne 0 ]] \
    && grep -Fq \
      'catalog image must have a valid release signature' \
      <<<"$deny_output"; then
    result=0
  else
    echo "HINT: Admission was denied, but not with the unique validation message of require-signed-catalog-images ('catalog image must have a valid release signature') - check the actual denial message; a DENY from an unrelated policy that merely mentions the word 'signature' or 'attestor' does not count."
    echo "Admission denial was not produced by require-signed-catalog-images"
    echo "$deny_output"
  fi

  record_result "$result"
}
