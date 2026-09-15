#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
NS="cks-101"
LEGACY_NS="cks-101-legacy"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Immutable frontend and backend application is ready" {
  echo '1' >> /var/work/tests/result/all
  state=$(kubectl --context "$CTX" get namespace "$NS" -o json 2>/dev/null | jq -r '
    .metadata.name == "cks-101"')
  apps=$(kubectl --context "$CTX" get deployment frontend backend -n "$NS" -o json 2>/dev/null | jq -r '
    (.items | length == 2) and
    ([.items[] | .metadata.name] | sort == ["backend", "frontend"]) and
    ([.items[] | .status.readyReplicas // 0] | all(. >= 1)) and
    ([.items[] | .spec.template.metadata.labels.app] | sort == ["backend", "frontend"]) and
    ([.items[] | .spec.template.spec.containers[0].image] as $images |
      ($images | length == 2) and
      ($images | unique | length == 1) and
      ($images | all(test("^viktoruj/ping_pong@sha256:[a-f0-9]{64}$"))))')
  endpoint=$(kubectl --context "$CTX" get endpoints backend -n "$NS" -o json 2>/dev/null | jq -r '
    any(.subsets[]?; (.addresses // []) | length > 0)')
  if [[ "$state" == true && "$apps" == true && "$endpoint" == true ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "HINT: Create ready frontend/backend Deployments with matching pinned images and a backend Service endpoint."
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "2. default-deny isolates all pods for ingress and egress" {
  echo '1' >> /var/work/tests/result/all
  valid=$(kubectl --context "$CTX" get networkpolicy default-deny -n "$NS" -o json 2>/dev/null | jq -r '
    .spec.podSelector == {} and
    ((.spec.policyTypes | sort) == ["Egress", "Ingress"]) and
    ((.spec.ingress // []) | length == 0) and
    ((.spec.egress // []) | length == 0)')
  if [[ "$valid" == true ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "HINT: default-deny must select all pods, define Ingress and Egress, and contain no allow rules."
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "3. Frontend and backend policies permit only TCP 8080" {
  echo '1' >> /var/work/tests/result/all
  frontend=$(kubectl --context "$CTX" get networkpolicy allow-frontend-egress-to-backend -n "$NS" -o json 2>/dev/null | jq -r '
    .spec.podSelector.matchLabels == {"app":"frontend"} and
    .spec.policyTypes == ["Egress"] and
    (.spec.egress | length == 1) and
    (.spec.egress[0].to | length == 1) and
    .spec.egress[0].to[0].podSelector.matchLabels == {"app":"backend"} and
    (.spec.egress[0].to[0] | has("namespaceSelector") | not) and
    (.spec.egress[0].to[0] | has("ipBlock") | not) and
    .spec.egress[0].ports == [{"protocol":"TCP","port":8080}]')
  backend=$(kubectl --context "$CTX" get networkpolicy allow-backend-ingress-from-frontend -n "$NS" -o json 2>/dev/null | jq -r '
    .spec.podSelector.matchLabels == {"app":"backend"} and
    .spec.policyTypes == ["Ingress"] and
    (.spec.ingress | length == 1) and
    (.spec.ingress[0].from | length == 1) and
    .spec.ingress[0].from[0].podSelector.matchLabels == {"app":"frontend"} and
    (.spec.ingress[0].from[0] | has("namespaceSelector") | not) and
    (.spec.ingress[0].from[0] | has("ipBlock") | not) and
    .spec.ingress[0].ports == [{"protocol":"TCP","port":8080}]')
  if [[ "$frontend" == true && "$backend" == true ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "HINT: The named frontend/backend policies must contain only the required app selectors and TCP/8080 rule."
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "4. Frontend DNS policy is limited to kube-system DNS on both protocols" {
  echo '1' >> /var/work/tests/result/all
  valid=$(kubectl --context "$CTX" get networkpolicy allow-frontend-dns -n "$NS" -o json 2>/dev/null | jq -r '
    def dns_rule:
      (.to | length == 1) and
      .to[0].namespaceSelector.matchLabels["kubernetes.io/metadata.name"] == "kube-system" and
      .to[0].podSelector.matchLabels["k8s-app"] == "kube-dns" and
      (.to[0] | has("ipBlock") | not) and
      ([.ports[]? | "\(.protocol):\(.port)"] | sort) == ["TCP:53", "UDP:53"];
    .spec.podSelector.matchLabels == {"app":"frontend"} and
    .spec.policyTypes == ["Egress"] and
    (.spec.egress | length > 0) and
    ([.spec.egress[] | dns_rule] | all)')
  if [[ "$valid" == true ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "HINT: allow-frontend-dns must select frontend and allow only kube-system kube-dns on UDP/53 and TCP/53."
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "5. Metadata network-deny evidence is recorded" {
  echo '1' >> /var/work/tests/result/all
  artifact=/var/work/tests/artifacts/5/metadata.output
  policy_state=$(kubectl --context "$CTX" get networkpolicy allow-frontend-egress-to-backend allow-frontend-dns -n "$NS" -o json 2>/dev/null | jq -r '
    [.items[].spec.egress[]?.to[]?.ipBlock? | select(.cidr == "169.254.169.254/32")] | length == 0')
  if [[ "$policy_state" == true ]] && cat "$artifact" 2>/dev/null | grep -q 'CURL_EXIT:\(7\|28\)' && \
     cat "$artifact" 2>/dev/null | grep -q 'HTTPCODE:000' && \
     cat "$artifact" 2>/dev/null | grep -q 'level=network'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "HINT: metadata.output must record CURL_EXIT 7 or 28, HTTPCODE:000, and level=network without metadata egress."
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "6. Legacy policies use one AND peer and exclude metadata" {
  echo '1' >> /var/work/tests/result/all
  legacy=$(kubectl --context "$CTX" get namespace "$LEGACY_NS" -o json 2>/dev/null | jq -r '.metadata.name == "cks-101-legacy"')
  client=$(kubectl --context "$CTX" get deployment legacy-client -n "$LEGACY_NS" -o json 2>/dev/null | jq -r '
    .spec.template.metadata.labels.app == "legacy-client" and (.status.readyReplicas // 0) >= 1')
  ingress=$(kubectl --context "$CTX" get networkpolicy allow-backend-ingress-from-legacy -n "$NS" -o json 2>/dev/null | jq -r '
    .spec.podSelector.matchLabels == {"app":"backend"} and
    .spec.policyTypes == ["Ingress"] and
    (.spec.ingress | length == 1) and
    (.spec.ingress[0].from | length == 1) and
    .spec.ingress[0].from[0].namespaceSelector.matchLabels["kubernetes.io/metadata.name"] == "cks-101-legacy" and
    .spec.ingress[0].from[0].podSelector.matchLabels == {"app":"legacy-client"} and
    .spec.ingress[0].ports == [{"protocol":"TCP","port":8080}]')
  egress=$(kubectl --context "$CTX" get networkpolicy allow-legacy-egress -n "$LEGACY_NS" -o json 2>/dev/null | jq -r '
    .spec.podSelector.matchLabels == {"app":"legacy-client"} and
    .spec.policyTypes == ["Egress"] and
    (.spec.egress | length == 1) and
    (.spec.egress[0].to | length == 1) and
    .spec.egress[0].to[0].ipBlock.cidr == "0.0.0.0/0" and
    (.spec.egress[0].to[0].ipBlock.except == ["169.254.169.254/32"]) and
    ((.spec.egress[0] | has("ports")) | not)')
  if [[ "$legacy" == true && "$client" == true && "$ingress" == true && "$egress" == true ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "HINT: Use the fixed legacy objects, one combined namespace/pod ingress peer, TCP/8080, and one 0.0.0.0/0 exception for metadata."
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "7. hostNetwork observation and comparison are recorded" {
  echo '1' >> /var/work/tests/result/all
  host=$(kubectl --context "$CTX" get pod hostnetwork-probe -n "$NS" -o json 2>/dev/null | jq -r '
    .spec.hostNetwork == true and .metadata.labels.app == "frontend"')
  task5=/var/work/tests/artifacts/5/metadata.output
  task7=/var/work/tests/artifacts/7/hostnetwork-metadata.output
  comparison=/var/work/tests/artifacts/7/comparison.txt
  if [[ "$host" == true ]] && cat "$task5" 2>/dev/null | grep -q 'CURL_EXIT:' && \
     cat "$task5" 2>/dev/null | grep -q 'HTTPCODE:' && \
     cat "$task7" 2>/dev/null | grep -q 'CURL_EXIT:' && \
     cat "$task7" 2>/dev/null | grep -q 'HTTPCODE:' && \
     cat "$comparison" 2>/dev/null | grep -q 'task5_result=curl_exit=' && \
     cat "$comparison" 2>/dev/null | grep -q 'task7_result=curl_exit=' && \
     cat "$comparison" 2>/dev/null | grep -qi 'environment-specific'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "HINT: Record both observed probes and an environment-specific task5/task7 comparison."
    result=1
  fi
  [ "$result" -eq 0 ]
}
