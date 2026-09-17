#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

control_plane() {
  kubectl get nodes --context "$CTX" -l node-role.kubernetes.io/control-plane \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

node_ssh() {
  ssh -oBatchMode=yes -oStrictHostKeyChecking=no -oConnectTimeout=10 "$(control_plane)" "$@"
}

record_result() {
  local number="$1"
  local result="$2"
  echo '1' >> /var/work/tests/result/all
  if [[ "$result" -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  return "$result"
}

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. kube-bench report was collected from the control-plane" {
  report=/var/work/tests/artifacts/1/kube-bench.txt
  sections_ok=true
  if [[ -s "$report" ]]; then
    for target in master node controlplane etcd policies; do
      grep -Eq "^== Summary ${target} ==\$" "$report" || sections_ok=false
    done
  else
    sections_ok=false
  fi
  if [[ -s "$report" ]] \
    && grep -Eq '^kubernetes_version=v1[.]36([.]|$)' "$report" \
    && grep -Eq '^kube_bench_version=v?0[.]16[.]0$' "$report" \
    && grep -qx 'benchmark=cis-1.12' "$report" \
    && grep -qx 'mapping_status=forced-approximate' "$report" \
    && grep -Eq '\[(PASS|WARN|FAIL)\]' "$report" \
    && [[ "$sections_ok" == true ]]; then
    result=0
  else
    if ! [[ -s "$report" ]]; then
      echo "HINT: kube-bench.txt is missing or empty - save the report at exactly $report."
    elif ! grep -Eq '^kubernetes_version=v1[.]36([.]|$)' "$report"; then
      echo "HINT: Report must include a line 'kubernetes_version=v1.36.x' - check kube-bench actually detected this cluster's version."
    elif ! grep -Eq '^kube_bench_version=v?0[.]16[.]0$' "$report"; then
      echo "HINT: Report must include 'kube_bench_version=v0.16.0' (or without 'v') matching the tool version installed in this lab."
    elif ! grep -qx 'benchmark=cis-1.12' "$report"; then
      echo "HINT: Report must include a line 'benchmark=cis-1.12' exactly - this pinned kube-bench 0.16.0 has no profile newer than cis-1.12 (its version_mapping tops out at '1.34': 'cis-1.12'; there is no cis-2.0 in this release at all), so cis-1.12 is the closest existing profile to run explicitly."
    elif ! grep -qx 'mapping_status=forced-approximate' "$report"; then
      echo "HINT: Report must include 'mapping_status=forced-approximate' exactly - this documents that v1.36 is newer than kube-bench's built-in version map."
    elif [[ "$sections_ok" != true ]]; then
      echo "HINT: Report must contain a '== Summary <target> ==' line for EVERY target (master, node, controlplane, etcd, policies), not just any single [PASS]/[WARN]/[FAIL] line - run with --targets master,node,controlplane,etcd,policies to get the full section set. A report missing the 'controlplane' or 'etcd' target can still contain strings like 'Control Plane Node Configuration' inside the 'master' target output, so checking for those substrings alone is not sufficient proof all five targets ran."
    else
      echo "HINT: Report must contain at least one line with [PASS], [WARN], or [FAIL] - check kube-bench actually ran the full scan, not just the config check."
    fi
    echo "Report must record Kubernetes, kube-bench, CIS config, forced/approximate mapping, and full-section scan results: $report"
    result=1
  fi
  record_result 1 "$result"
}

@test "2. kubelet disables read-only port and anonymous authentication on the node" {
  configz=$(kubectl get --raw="/api/v1/nodes/$(control_plane)/proxy/configz" --context "$CTX" 2>/dev/null)
  configz_ok=$(printf '%s' "$configz" | jq -e '
    .kubeletconfig.readOnlyPort == 0 and
    .kubeletconfig.authentication.anonymous.enabled == false
  ' >/dev/null 2>&1 && echo true || echo false)
  ready=$(kubectl get node "$(control_plane)" --context "$CTX" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  if [[ "$configz_ok" == "true" && "$ready" == "True" ]]; then
    result=0
  else
    if [[ "$configz_ok" != "true" ]]; then
      echo "HINT: The node's actuated kubelet configuration (via /configz) does not show readOnlyPort=0 and authentication.anonymous.enabled=false. A text-only edit that never restarted kubelet, or a wrong YAML nesting (e.g. editing a field with the same name under a different parent like webhook.enabled), will not show up here - only what kubelet itself reports as active."
    else
      echo "HINT: control-plane node is not Ready (status=$ready) after the kubelet config change/restart."
    fi
    echo "configz=$configz"
    result=1
  fi
  record_result 2 "$result"
}

@test "3. kube-apiserver has profiling disabled and is healthy" {
  command_json=$(kubectl -n kube-system get pod -l component=kube-apiserver --context "$CTX" -o json 2>/dev/null \
    | jq -c '.items[0].spec.containers[0].command' 2>/dev/null)
  manifest_status=1
  if printf '%s' "$command_json" | jq -e 'index("--profiling=false") != null' >/dev/null 2>&1; then
    manifest_status=0
  fi
  ready=$(kubectl get --raw='/readyz' --context "$CTX" 2>/dev/null)
  phase=$(kubectl get pods -n kube-system --context "$CTX" -l component=kube-apiserver -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
  if [[ "$manifest_status" -eq 0 && "$ready" == "ok" && "$phase" == "Running" ]]; then
    result=0
  else
    if [[ "$manifest_status" -ne 0 ]]; then
      echo "HINT: The running kube-apiserver Pod's command does not include '--profiling=false'. Check /etc/kubernetes/manifests/kube-apiserver.yaml has this flag in the command list (any valid YAML indentation works - what matters is the actual running Pod spec, checked via the Kubernetes API)."
    elif [[ "$ready" != "ok" ]]; then
      echo "HINT: API server is not ready after the manifest edit. Wait longer for kubelet to pick up the change and restart the static Pod, or check for a YAML syntax error in the manifest."
    elif [[ "$phase" != "Running" ]]; then
      echo "HINT: kube-apiserver Pod is not Running (phase=$phase). Check 'kubectl describe pod' events on this Pod for the actual startup error."
    fi
    echo "command=$command_json"
    echo "readyz=$ready phase=$phase"
    result=1
  fi
  record_result 3 "$result"
}

@test "4. TLS Secret and secure Ingress are configured" {
  secret_type=$(kubectl get secret secure-ingress-tls -n cks-103 --context "$CTX" -o jsonpath='{.type}' 2>/dev/null)
  cert=$(kubectl get secret secure-ingress-tls -n cks-103 --context "$CTX" -o jsonpath='{.data.tls\.crt}' 2>/dev/null)
  key=$(kubectl get secret secure-ingress-tls -n cks-103 --context "$CTX" -o jsonpath='{.data.tls\.key}' 2>/dev/null)
  ingress_class=$(kubectl get ingress secure-ingress -n cks-103 --context "$CTX" -o jsonpath='{.spec.ingressClassName}' 2>/dev/null)
  ssl_redirect=$(kubectl get ingress secure-ingress -n cks-103 --context "$CTX" -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/ssl-redirect}' 2>/dev/null)
  host=$(kubectl get ingress secure-ingress -n cks-103 --context "$CTX" -o jsonpath='{.spec.tls[0].hosts[0]}' 2>/dev/null)
  secret_name=$(kubectl get ingress secure-ingress -n cks-103 --context "$CTX" -o jsonpath='{.spec.tls[0].secretName}' 2>/dev/null)
  path=$(kubectl get ingress secure-ingress -n cks-103 --context "$CTX" -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null)
  path_type=$(kubectl get ingress secure-ingress -n cks-103 --context "$CTX" -o jsonpath='{.spec.rules[0].http.paths[0].pathType}' 2>/dev/null)
  service=$(kubectl get ingress secure-ingress -n cks-103 --context "$CTX" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null)
  service_port=$(kubectl get ingress secure-ingress -n cks-103 --context "$CTX" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null)
  service_endpoint=$(kubectl -n cks-103 get endpoints secure-app --context "$CTX" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)
  controller_ready=$(kubectl -n ingress-nginx get deploy ingress-nginx-controller --context "$CTX" \
    -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
  controller_svc_ip=$(kubectl -n ingress-nginx get svc ingress-nginx-controller --context "$CTX" \
    -o jsonpath='{.spec.clusterIP}' 2>/dev/null)

  # SAN сертификата (точное DNS-имя, не substring) и cert/key pairing по public key
  # (не привязано к RSA - работает и для EC/ECDSA пар).
  san_ok=false
  cert_pub=""
  key_pub=""
  if [[ -n "$cert" && -n "$key" ]]; then
    san=$(printf '%s' "$cert" | base64 -d 2>/dev/null | openssl x509 -noout -ext subjectAltName 2>/dev/null)
    grep -Eq '(^|[ ,])DNS:secure[.]cks[.]local([, ]|$)' <<<"$san" && san_ok=true
    cert_pub=$(printf '%s' "$cert" | base64 -d 2>/dev/null \
      | openssl x509 -pubkey -noout 2>/dev/null \
      | openssl pkey -pubin -outform DER 2>/dev/null \
      | sha256sum | awk '{print $1}')
    key_pub=$(printf '%s' "$key" | base64 -d 2>/dev/null \
      | openssl pkey -pubout -outform DER 2>/dev/null \
      | sha256sum | awk '{print $1}')
  fi
  cert_key_match=false
  [[ -n "$cert_pub" && "$cert_pub" == "$key_pub" ]] && cert_key_match=true

  # Реальный runtime request через controller Service ClusterIP, выполненный с
  # control-plane node (Pod IP из Endpoints не гарантированно маршрутизируется с
  # отдельной worker VM - Pod CIDR в этой лабе отличается от VPC CIDR). Проверяем не
  # просто класс статус-кода, а конкретное заявленное поведение: HTTPS должен реально
  # дойти до secure-app (status==200 И тело ответа содержит nginx default welcome page
  # marker - иначе ssl-redirect/другая аннотация может вернуть 2xx/3xx без реального
  # доступа к backend), а HTTP должен redirect-ить именно на https://secure.cks.local/.
  https_status=""
  https_body=""
  http_status=""
  http_location=""
  if [[ -n "$controller_svc_ip" ]]; then
    https_response=$(node_ssh "curl -sS -D - -o /tmp/https_body.$$ -w 'HTTPCODE:%{http_code}' --max-time 5 -k \
      --resolve secure.cks.local:443:${controller_svc_ip} https://secure.cks.local/; cat /tmp/https_body.$$; rm -f /tmp/https_body.$$" 2>/dev/null)
    https_status=$(grep -oE 'HTTPCODE:[0-9]+' <<<"$https_response" | tail -1 | cut -d: -f2)
    https_body="$https_response"
    http_headers=$(node_ssh "curl -sS -D - -o /dev/null -w 'HTTPCODE:%{http_code}' --max-time 5 \
      --resolve secure.cks.local:80:${controller_svc_ip} http://secure.cks.local/" 2>/dev/null)
    http_status=$(grep -oE 'HTTPCODE:[0-9]+' <<<"$http_headers" | tail -1 | cut -d: -f2)
    http_location=$(grep -i '^location:' <<<"$http_headers" | tr -d '\r' | awk '{print $2}')
  fi
  https_ok=false
  [[ "$https_status" == "200" && "$https_body" == *"Welcome to nginx"* ]] && https_ok=true
  http_redirect_ok=false
  [[ "$http_status" =~ ^3[0-9][0-9]$ && "$http_location" == "https://secure.cks.local/"* ]] && http_redirect_ok=true

  if [[ "$secret_type" == "kubernetes.io/tls" && -n "$cert" && -n "$key" \
        && "$ingress_class" == "nginx" && "$ssl_redirect" == "true" \
        && "$host" == "secure.cks.local" && "$secret_name" == "secure-ingress-tls" \
        && "$path" == "/" && -n "$path_type" \
        && "$service" == "secure-app" && "$service_port" == "80" \
        && -n "$service_endpoint" \
        && -n "$controller_ready" && "$controller_ready" -ge 1 \
        && "$san_ok" == "true" && "$cert_key_match" == "true" \
        && "$https_ok" == "true" && "$http_redirect_ok" == "true" ]]; then
    result=0
  else
    if [[ "$secret_type" != "kubernetes.io/tls" ]]; then
      echo "HINT: Secret 'secure-ingress-tls' must have type 'kubernetes.io/tls' - a generic Opaque Secret with tls.crt/tls.key keys does not satisfy Ingress TLS requirements the same way."
    elif [[ -z "$cert" || -z "$key" ]]; then
      echo "HINT: Secret 'secure-ingress-tls' is missing tls.crt or tls.key data - both must be present and base64-encoded (kubectl handles this automatically with 'kubectl create secret tls')."
    elif [[ "$ingress_class" != "nginx" ]]; then
      echo "HINT: Ingress 'secure-ingress' spec.ingressClassName must be exactly 'nginx'."
    elif [[ "$ssl_redirect" != "true" ]]; then
      echo "HINT: Ingress 'secure-ingress' must have annotation nginx.ingress.kubernetes.io/ssl-redirect: \"true\"."
    elif [[ "$host" != "secure.cks.local" ]]; then
      echo "HINT: Ingress 'secure-ingress' spec.tls[0].hosts[0] must be exactly 'secure.cks.local'."
    elif [[ "$secret_name" != "secure-ingress-tls" ]]; then
      echo "HINT: Ingress 'secure-ingress' spec.tls[0].secretName must reference 'secure-ingress-tls' exactly."
    elif [[ "$path" != "/" || -z "$path_type" ]]; then
      echo "HINT: Ingress rule path must be '/' with a valid pathType (e.g. Prefix)."
    elif [[ "$service" != "secure-app" || "$service_port" != "80" ]]; then
      echo "HINT: Ingress backend must reference Service 'secure-app' on port 80 exactly."
    elif [[ -z "$service_endpoint" ]]; then
      echo "HINT: Service 'secure-app' has no endpoint - check the Deployment is Ready and label selectors match."
    elif [[ -z "$controller_ready" || "$controller_ready" -lt 1 ]]; then
      echo "HINT: ingress-nginx-controller Deployment is not Available (this is a lab-owned fixture, should already be Ready - check 'kubectl -n ingress-nginx get pods')."
    elif [[ "$san_ok" != "true" ]]; then
      echo "HINT: the TLS certificate's Subject Alternative Name must contain the exact DNS name 'secure.cks.local' (not just the CN, and not merely a substring match like 'notsecure.cks.local') - regenerate with -addext 'subjectAltName=DNS:secure.cks.local'."
    elif [[ "$cert_key_match" != "true" ]]; then
      echo "HINT: the certificate and private key in the Secret do not form a valid pair (public key mismatch) - re-generate them together with the same openssl command. This check works for RSA and EC/ECDSA keys alike."
    elif [[ "$https_ok" != "true" ]]; then
      echo "HINT: a real HTTPS request through the ingress-nginx-controller Service ClusterIP (from the control-plane node) did not return status 200 with the nginx default welcome page body (status=$https_status). A redirect-only annotation or misrouted Ingress can return some 2xx/3xx without ever reaching secure-app - this check requires the actual backend response, not just a similar-looking status class."
    else
      echo "HINT: a plain HTTP request through the controller did not redirect to https://secure.cks.local/ specifically (status=$http_status, location=$http_location) - check the ssl-redirect annotation is 'true' and that the redirect Location header actually points at the HTTPS host, not just any 3xx."
    fi
    echo "secret_type=$secret_type ingress_class=$ingress_class ssl_redirect=$ssl_redirect host=$host secret=$secret_name path=$path/$path_type backend=$service:$service_port"
    echo "service_endpoint=$service_endpoint controller_ready=$controller_ready controller_svc_ip=$controller_svc_ip san_ok=$san_ok cert_key_match=$cert_key_match https_status=$https_status http_status=$http_status http_location=$http_location"
    result=1
  fi
  record_result 4 "$result"
}

@test "5. TLS 1.3 is active and TLS 1.2 is rejected by the control plane" {
  report=/var/work/tests/artifacts/5/tls13.txt
  api_command=$(kubectl -n kube-system get pod -l component=kube-apiserver --context "$CTX" -o json 2>/dev/null \
    | jq -c '.items[0].spec.containers[0].command' 2>/dev/null)
  etcd_command=$(kubectl -n kube-system get pod -l component=etcd --context "$CTX" -o json 2>/dev/null \
    | jq -c '.items[0].spec.containers[0].command' 2>/dev/null)
  manifest_status=1
  if printf '%s' "$api_command" | jq -e '
       index("--tls-min-version=VersionTLS13") != null and
       any(.[]; startswith("--tls-cipher-suites=") and (contains("TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256") and contains("TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384")))
     ' >/dev/null 2>&1 \
     && printf '%s' "$etcd_command" | jq -e '
       any(.[]; startswith("--cipher-suites=") and (contains("TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256") and contains("TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384")))
     ' >/dev/null 2>&1; then
    manifest_status=0
  fi
  ready=$(kubectl get --raw='/readyz' --context "$CTX" 2>/dev/null)
  etcd_phase=$(kubectl get pods -n kube-system --context "$CTX" -l component=etcd -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
  run node_ssh "openssl s_client -connect 127.0.0.1:6443 -tls1_2 -brief </dev/null"
  tls12_status=$status
  tls12_output=$output
  if [[ "$manifest_status" -eq 0 && "$ready" == "ok" && "$etcd_phase" == "Running" && "$tls12_status" -ne 0 ]] \
    && grep -Eq 'TLSv1[.]3' "$report" \
    && grep -Fq 'TLS 1.2 correctly rejected' "$report"; then
    result=0
  else
    if [[ "$manifest_status" -ne 0 ]]; then
      echo "HINT: The running kube-apiserver Pod's command must include --tls-min-version=VersionTLS13 and a --tls-cipher-suites entry containing both TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 and TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384; the running etcd Pod's command must include a --cipher-suites entry with the same two suites. This is checked against the actual running Pod spec via the Kubernetes API, not by matching exact YAML text."
    elif [[ "$ready" != "ok" || "$etcd_phase" != "Running" ]]; then
      echo "HINT: API server or etcd is not healthy after the TLS change. A too-restrictive cipher list can break internal component communication - double check the exact cipher suite strings for typos."
    elif [[ "$tls12_status" -eq 0 ]]; then
      echo "HINT: A TLS 1.2 handshake to :6443 succeeded - it should be rejected once --tls-min-version=VersionTLS13 is active. Confirm the static Pod actually restarted with the new manifest."
    else
      echo "HINT: TLS handshake succeeded/failed as expected, but the evidence file $report does not contain 'TLSv1.3' and/or 'TLS 1.2 correctly rejected' - save both proofs in that exact wording."
    fi
    echo "api_command=$api_command"
    echo "etcd_command=$etcd_command"
    echo "readyz=$ready etcd_phase=$etcd_phase tls12_exit=$tls12_status"
    echo "$tls12_output"
    result=1
  fi
  record_result 5 "$result"
}

@test "6. kubelet and kubectl SHA-256 verification succeeded" {
  report=/var/work/tests/artifacts/6/binaries.sha256.txt

  if [[ ! -s "$report" ]]; then
    echo "HINT: binaries.sha256.txt is missing or empty - save your own sha256sum -c results at exactly $report."
    record_result 6 1
    return
  fi

  # Не доверяем student artifact на слово: checker независимо вычисляет SHA-256 реально
  # установленных бинарников и сравнивает с trusted checksum, загруженным при bootstrap
  # (не тем же файлом, который проверяется).
  trusted_kubelet=$(awk '{print $1}' /var/work/tests/checker-fixtures/kubelet.sha256 2>/dev/null)
  trusted_kubectl=$(awk '{print $1}' /var/work/tests/checker-fixtures/kubectl.sha256 2>/dev/null)

  kubelet_path=$(node_ssh "command -v kubelet" 2>/dev/null)
  actual_kubelet=$(node_ssh "sha256sum \"$kubelet_path\"" 2>/dev/null | awk '{print $1}')
  actual_kubectl=$(sha256sum "$(command -v kubectl)" 2>/dev/null | awk '{print $1}')

  kubelet_ok=false
  [[ -n "$trusted_kubelet" && "$trusted_kubelet" == "$actual_kubelet" ]] && kubelet_ok=true
  kubectl_ok=false
  [[ -n "$trusted_kubectl" && "$trusted_kubectl" == "$actual_kubectl" ]] && kubectl_ok=true

  artifact_ok=false
  grep -Eq 'kubelet.*: OK' "$report" && grep -Eq 'kubectl.*: OK' "$report" && artifact_ok=true

  if [[ "$kubelet_ok" == "true" && "$kubectl_ok" == "true" && "$artifact_ok" == "true" ]]; then
    result=0
  else
    if [[ "$kubelet_ok" != "true" ]]; then
      echo "HINT: the actual installed kubelet on control-plane does not match the official v1.36.0 checksum (independently verified by the checker, not by trusting your artifact). expected=$trusted_kubelet actual=$actual_kubelet"
    elif [[ "$kubectl_ok" != "true" ]]; then
      echo "HINT: the actual installed kubectl on worker does not match the official v1.36.0 checksum (independently verified by the checker, not by trusting your artifact). expected=$trusted_kubectl actual=$actual_kubectl"
    else
      echo "HINT: binaries.sha256.txt must contain lines matching 'kubelet...: OK' and 'kubectl...: OK' from your own sha256sum -c run - this is the standard 'sha256sum --check' output format."
    fi
    echo "$report contents:"
    cat "$report" 2>/dev/null
    result=1
  fi
  record_result 6 "$result"
}

@test "7. kube-bench check 1.1.1 goes from FAIL to PASS after fixing manifest permissions" {
  before=/var/work/tests/artifacts/7/before.txt
  after=/var/work/tests/artifacts/7/after.txt
  perm=$(node_ssh "sudo stat -c '%a' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null)
  ready=$(kubectl get --raw='/readyz' --context "$CTX" 2>/dev/null)
  phase=$(kubectl get pods -n kube-system --context "$CTX" -l component=kube-apiserver -o jsonpath='{.items[0].status.phase}' 2>/dev/null)

  # Exact correlation: строка должна начинаться с [FAIL]/[PASS] и содержать именно "1.1.1"
  # как номер check (не просто где-то в файле рядом с несвязанным [FAIL] другого check).
  before_check_ok=false
  grep -Eq '^\[FAIL\][[:space:]]+1[.]1[.]1([[:space:]]|$)' "$before" && before_check_ok=true
  after_pass_ok=false
  grep -Eq '^\[PASS\][[:space:]]+1[.]1[.]1([[:space:]]|$)' "$after" && after_pass_ok=true
  after_no_fail=true
  grep -Eq '^\[FAIL\][[:space:]]+1[.]1[.]1([[:space:]]|$)' "$after" && after_no_fail=false

  if [[ -s "$before" && "$before_check_ok" == "true" ]] \
    && [[ -s "$after" && "$after_pass_ok" == "true" && "$after_no_fail" == "true" ]] \
    && [[ "$perm" == "600" ]] \
    && [[ "$ready" == "ok" && "$phase" == "Running" ]]; then
    result=0
  else
    if [[ ! -s "$before" || "$before_check_ok" != "true" ]]; then
      echo "HINT: before.txt must be captured BEFORE any fix and contain a line starting with exactly '[FAIL] 1.1.1' (not just the substring '1.1.1' anywhere near an unrelated [FAIL]) - this is the CIS check for kube-apiserver manifest file permissions."
    elif [[ "$perm" != "600" ]]; then
      echo "HINT: /etc/kubernetes/manifests/kube-apiserver.yaml permissions are '$perm', not 600. Run 'chmod 600' on this file - CIS 1.1.1 requires it to be readable/writable only by its owner."
    elif [[ "$after_pass_ok" != "true" || "$after_no_fail" != "true" ]]; then
      echo "HINT: after.txt must contain a line starting with exactly '[PASS] 1.1.1' and no line starting with '[FAIL] 1.1.1' - re-run kube-bench --check 1.1.1 after the chmod and save the fresh output."
    else
      echo "HINT: kube-apiserver must remain healthy after the chmod (readyz=ok, Pod Running) - this is a fs-only permission change and should not require the static Pod to be recreated."
    fi
    echo "Expected exact '[FAIL] 1.1.1' in $before and exact '[PASS] 1.1.1' (no '[FAIL] 1.1.1') in $after, node permission exactly 600 (actual: ${perm:-missing}), and healthy API server (readyz=$ready phase=$phase)"
    result=1
  fi
  record_result 7 "$result"
}
