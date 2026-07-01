#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 All app pods have Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total_pods=$(kubectl get pods -n default --no-headers 2>/dev/null | wc -l)
  pods_with_sidecar=$(kubectl get pods -n default -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total_pods" -gt 0 ]] && [[ "$total_pods" -eq "$pods_with_sidecar" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Total pods: $total_pods, with sidecar: $pods_with_sidecar"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 Prometheus is running" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy prometheus -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then echo '1' >> /var/work/tests/result/ok; result=0; else result=1; fi
  [ "$result" == "0" ]
}

@test "2.2 Grafana is running" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy grafana -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then echo '1' >> /var/work/tests/result/ok; result=0; else result=1; fi
  [ "$result" == "0" ]
}

@test "2.3 Jaeger is running" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy jaeger -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then echo '1' >> /var/work/tests/result/ok; result=0; else result=1; fi
  [ "$result" == "0" ]
}

@test "2.4 Kiali is running" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy kiali -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then echo '1' >> /var/work/tests/result/ok; result=0; else result=1; fi
  [ "$result" == "0" ]
}

@test "3.1 Prometheus scrapes Istio request metrics for the app" {
  echo '1' >> /var/work/tests/result/all

  # generate traffic so metrics exist, then give Prometheus time to scrape
  for i in $(seq 20); do curl -s -o /dev/null --max-time 8 http://myapp.local:32080 || true; done
  sleep 20

  out=$(kubectl exec -n default deploy/curl-client -c curl -- \
    curl -s --max-time 15 'http://prometheus.istio-system:9090/api/v1/query?query=istio_requests_total' 2>/dev/null)
  count=$(echo "$out" | jq '.data.result | length' 2>/dev/null)

  if [[ "${count:-0}" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Prometheus returned no istio_requests_total series"
    result=1
  fi

  [ "$result" == "0" ]
}
