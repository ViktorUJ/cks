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
  service=$(kubectl --context "$CTX" get service backend -n "$NS" -o json 2>/dev/null | jq -r '
    .spec.selector == {"app":"backend"} and
    (.spec.ports | length == 1) and
    .spec.ports[0].protocol == "TCP" and
    .spec.ports[0].port == 8080 and
    .spec.ports[0].targetPort == 8080')
  endpoint=$(kubectl --context "$CTX" get endpoints backend -n "$NS" -o json 2>/dev/null | jq -r '
    any(.subsets[]?; (.addresses // []) | length > 0)')
  if [[ "$state" == true && "$apps" == true && "$service" == true && "$endpoint" == true ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "HINT: Create ready frontend/backend Deployments with matching pinned images and a backend Service selecting app=backend with one TCP 8080 to 8080 port and an endpoint."
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
    .spec.podSelector == {"matchLabels":{"app":"frontend"}} and
    .spec.policyTypes == ["Egress"] and
    (.spec.egress | length == 1) and
    (.spec.egress[0].to | length == 1) and
    .spec.egress[0].to[0].podSelector == {"matchLabels":{"app":"backend"}} and
    (.spec.egress[0].to[0] | has("namespaceSelector") | not) and
    (.spec.egress[0].to[0] | has("ipBlock") | not) and
    .spec.egress[0].ports == [{"protocol":"TCP","port":8080}]')
  backend=$(kubectl --context "$CTX" get networkpolicy allow-backend-ingress-from-frontend -n "$NS" -o json 2>/dev/null | jq -r '
    .spec.podSelector == {"matchLabels":{"app":"backend"}} and
    .spec.policyTypes == ["Ingress"] and
    (.spec.ingress | length == 1) and
    (.spec.ingress[0].from | length == 1) and
    .spec.ingress[0].from[0].podSelector == {"matchLabels":{"app":"frontend"}} and
    (.spec.ingress[0].from[0] | has("namespaceSelector") | not) and
    (.spec.ingress[0].from[0] | has("ipBlock") | not) and
    .spec.ingress[0].ports == [{"protocol":"TCP","port":8080}]')
  additive=$(kubectl --context "$CTX" get networkpolicy -n "$NS" -o json 2>/dev/null | jq -r '
    def expression_matches($labels):
      . as $expression |
      ($labels[$expression.key]) as $value |
      if $expression.operator == "In" then
        $value != null and ($expression.values | index($value) != null)
      elif $expression.operator == "NotIn" then
        $value == null or ($expression.values | index($value) == null)
      elif $expression.operator == "Exists" then
        $value != null
      elif $expression.operator == "DoesNotExist" then
        $value == null
      else false end;
    def selector_matches($labels):
      . as $selector |
      (($selector.matchLabels // {}) | all(to_entries[]?; $labels[.key] == .value)) and
      (($selector.matchExpressions // []) | all(.[]?; expression_matches($labels)));
    def has_egress_allow: ((.spec.egress // []) | length > 0);
    def has_ingress_allow: ((.spec.ingress // []) | length > 0);
    ([.items[]? |
      select((.metadata.name as $name | ["allow-frontend-egress-to-backend", "allow-frontend-dns"] | index($name) | not) and
             has_egress_allow and
             ((.spec.podSelector // {}) | selector_matches({"app":"frontend"}))) |
      .metadata.name] | length == 0) and
    ([.items[]? |
      select((.metadata.name as $name | ["allow-backend-ingress-from-frontend", "allow-backend-ingress-from-legacy"] | index($name) | not) and
             has_ingress_allow and
             ((.spec.podSelector // {}) | selector_matches({"app":"backend"}))) |
      .metadata.name] | length == 0)')
  if [[ "$frontend" == true && "$backend" == true && "$additive" == true ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "HINT: The named frontend/backend policies must contain only the required TCP/8080 rules, and no additional matching policy may add frontend egress or backend ingress."
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "4. Frontend DNS policy is limited to kube-system DNS on both protocols" {
  echo '1' >> /var/work/tests/result/all
  valid=$(kubectl --context "$CTX" get networkpolicy allow-frontend-dns -n "$NS" -o json 2>/dev/null | jq -r '
    def strict_dns_rule:
      (.to | length == 1) and
      (.to[0] | keys | sort == ["namespaceSelector", "podSelector"]) and
      .to[0].namespaceSelector == {"matchLabels":{"kubernetes.io/metadata.name":"kube-system"}} and
      .to[0].podSelector == {"matchLabels":{"k8s-app":"kube-dns"}} and
      (.ports | type == "array" and length > 0) and
      (all(.ports[]; (keys | sort) == ["port", "protocol"]));
    .spec.podSelector == {"matchLabels":{"app":"frontend"}} and
    .spec.policyTypes == ["Egress"] and
    (.spec.egress | length > 0) and
    ([.spec.egress[] | strict_dns_rule] | all) and
    ([.spec.egress[] | .ports[] | {protocol, port}] | unique | sort_by(.protocol, .port)) ==
      [{"protocol":"TCP","port":53}, {"protocol":"UDP","port":53}]')
  if [[ "$valid" == true ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "HINT: allow-frontend-dns must select frontend and use only exact kube-system/kube-dns peers; its aggregate ports must be TCP/53 and UDP/53."
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
    .spec.selector == {"matchLabels":{"app":"legacy-client"}} and
    .spec.template.metadata.labels == {"app":"legacy-client"} and
    (.status.readyReplicas // 0) >= 1 and
    (.spec.template.spec.containers | length == 1) and
    .spec.template.spec.containers[0].image == "curlimages/curl:8.11.1" and
    .spec.template.spec.containers[0].command == ["sleep", "3600"]')
  ingress=$(kubectl --context "$CTX" get networkpolicy allow-backend-ingress-from-legacy -n "$NS" -o json 2>/dev/null | jq -r '
    .spec.podSelector == {"matchLabels":{"app":"backend"}} and
    .spec.policyTypes == ["Ingress"] and
    (.spec.ingress | length == 1) and
    (.spec.ingress[0].from | length == 1) and
    (.spec.ingress[0].from[0] | keys | sort == ["namespaceSelector", "podSelector"]) and
    .spec.ingress[0].from[0].namespaceSelector == {"matchLabels":{"kubernetes.io/metadata.name":"cks-101-legacy"}} and
    .spec.ingress[0].from[0].podSelector == {"matchLabels":{"app":"legacy-client"}} and
    .spec.ingress[0].ports == [{"protocol":"TCP","port":8080}]')
  egress=$(kubectl --context "$CTX" get networkpolicy allow-legacy-egress -n "$LEGACY_NS" -o json 2>/dev/null | jq -r '
    .spec.podSelector == {"matchLabels":{"app":"legacy-client"}} and
    .spec.policyTypes == ["Egress"] and
    (.spec.egress | length == 1) and
    .spec.egress[0].to == [{"ipBlock":{"cidr":"0.0.0.0/0","except":["169.254.169.254/32"]}}] and
    ((.spec.egress[0] | has("ports")) | not)')
  no_default_deny=$(kubectl --context "$CTX" get networkpolicy -n "$LEGACY_NS" -o json 2>/dev/null | jq -r '
    all(.items[]?; ((.spec.podSelector == {}) and
                     ((.spec.ingress // []) | length == 0) and
                     ((.spec.egress // []) | length == 0)) | not)')
  additive=$(kubectl --context "$CTX" get networkpolicy -n "$LEGACY_NS" -o json 2>/dev/null | jq -r '
    def expression_matches($labels):
      . as $expression |
      ($labels[$expression.key]) as $value |
      if $expression.operator == "In" then
        $value != null and ($expression.values | index($value) != null)
      elif $expression.operator == "NotIn" then
        $value == null or ($expression.values | index($value) == null)
      elif $expression.operator == "Exists" then
        $value != null
      elif $expression.operator == "DoesNotExist" then
        $value == null
      else false end;
    def selector_matches($labels):
      . as $selector |
      (($selector.matchLabels // {}) | all(to_entries[]?; $labels[.key] == .value)) and
      (($selector.matchExpressions // []) | all(.[]?; expression_matches($labels)));
    [.items[]? |
      select(.metadata.name != "allow-legacy-egress" and
             ((.spec.egress // []) | length > 0) and
             ((.spec.podSelector // {}) | selector_matches({"app":"legacy-client"}))) |
      .metadata.name] | length == 0')
  if [[ "$legacy" == true && "$client" == true && "$ingress" == true && "$egress" == true && "$no_default_deny" == true && "$additive" == true ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "HINT: Use the fixed legacy Deployment, exact one-peer namespace/pod AND selector, TCP/8080, metadata exception, no legacy default-deny, and no additional matching egress policy."
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "7. hostNetwork observation and comparison are recorded" {
  echo '1' >> /var/work/tests/result/all
  host=$(kubectl --context "$CTX" get pod hostnetwork-probe -n "$NS" -o json 2>/dev/null | jq -r '
    .spec.hostNetwork == true and
    .metadata.labels.app == "frontend" and
    (.spec.containers | length == 1) and
    .spec.containers[0].image == "curlimages/curl:8.11.1" and
    ((.status.conditions // []) | any(.[]; .type == "Ready" and .status == "True"))')
  task5=/var/work/tests/artifacts/5/metadata.output
  task7=/var/work/tests/artifacts/7/hostnetwork-metadata.output
  comparison=/var/work/tests/artifacts/7/comparison.txt
  task5_rc=$(sed -n 's/.*CURL_EXIT:\([0-9][0-9]*\).*/\1/p' "$task5" 2>/dev/null | tail -n 1)
  task5_code=$(sed -n 's/.*HTTPCODE:\([0-9][0-9][0-9]\).*/\1/p' "$task5" 2>/dev/null | tail -n 1)
  task7_rc=$(sed -n 's/.*CURL_EXIT:\([0-9][0-9]*\).*/\1/p' "$task7" 2>/dev/null | tail -n 1)
  task7_code=$(sed -n 's/.*HTTPCODE:\([0-9][0-9][0-9]\).*/\1/p' "$task7" 2>/dev/null | tail -n 1)
  comparison5=$(sed -n 's/^task5_result=curl_exit=\([0-9][0-9]*\) http_code=\([0-9][0-9][0-9]\)$/\1 \2/p' "$comparison" 2>/dev/null)
  comparison7=$(sed -n 's/^task7_result=curl_exit=\([0-9][0-9]*\) http_code=\([0-9][0-9][0-9]\)$/\1 \2/p' "$comparison" 2>/dev/null)
  if [[ "$host" == true && "$task5_rc" =~ ^[0-9]+$ && "$task5_code" =~ ^[0-9]{3}$ && \
        "$task7_rc" =~ ^[0-9]+$ && "$task7_code" =~ ^[0-9]{3}$ && \
        "$comparison5" == "$task5_rc $task5_code" && "$comparison7" == "$task7_rc $task7_code" ]] && \
     grep -qi 'environment-specific' "$comparison" 2>/dev/null; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "HINT: Use a ready hostNetwork frontend probe with curlimages/curl:8.11.1, record numeric probe results, and copy both values exactly into an environment-specific comparison."
    result=1
  fi
  [ "$result" -eq 0 ]
}
