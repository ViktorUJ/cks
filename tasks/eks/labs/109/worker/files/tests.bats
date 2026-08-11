#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-109"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace, Service and web workload" {
  echo '1' >> /var/work/tests/result/all
  ns=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  image=$(kubectl get deploy web -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ready=$(kubectl get deploy web -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  svc_type=$(kubectl get svc web -n "$NS" -o jsonpath='{.spec.type}' 2>/dev/null)
  svc_port=$(kubectl get svc web -n "$NS" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
  result=1
  if [[ "$ns" == "$NS" ]] && [[ "$image" == *ping_pong* ]] && [[ "$ready" == "2" ]] && \
     [[ "$svc_type" == "ClusterIP" ]] && [[ "$svc_port" == "80" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "ns=$ns image=$image ready=$ready svc_type=$svc_type svc_port=$svc_port"
  fi
  [ "$result" == "0" ]
}

@test "2. ServiceAccount and AWS Load Balancer Controller" {
  echo '1' >> /var/work/tests/result/all
  role=$(kubectl get sa aws-load-balancer-controller -n kube-system \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null)
  ready=$(kubectl get deploy aws-load-balancer-controller -n kube-system \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  result=1
  if [[ "$role" == *lbc-irsa* ]] && [[ -n "$ready" ]] && [[ "$ready" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "sa role-arn=$role lbc ready replicas=$ready"
  fi
  [ "$result" == "0" ]
}

@test "3. Ingress web through ALB: internal, target-type ip" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/3/alb.txt
  result=1
  for i in $(seq 1 30); do
    class=$(kubectl get ingress web -n "$NS" -o jsonpath='{.spec.ingressClassName}' 2>/dev/null)
    addr=$(kubectl get ingress web -n "$NS" \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [[ "$class" == "alb" ]] && [[ -n "$addr" ]] && [[ -s "$f" ]] && \
       grep -q '"Type": "application"' "$f" && grep -q '"Scheme": "internal"' "$f" && \
       grep -q '"Port": 80' "$f"; then
      echo '1' >> /var/work/tests/result/ok
      result=0
      break
    fi
    sleep 10
  done
  if [[ "$result" != "0" ]]; then
    echo "ingressClassName=$class address=$addr file=$f"
  fi
  [ "$result" == "0" ]
}

@test "4. TLS: ACM certificate, HTTPS listener, redirect" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/4/https.txt
  cert=$(kubectl get ingress web -n "$NS" \
    -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/certificate-arn}' 2>/dev/null)
  tls_host=$(kubectl get ingress web -n "$NS" -o jsonpath='{.spec.tls[0].hosts[0]}' 2>/dev/null)
  result=1
  if [[ -n "$cert" ]] && [[ -n "$tls_host" ]] && [[ -s "$f" ]] && \
     grep -q '"Protocol": "HTTPS"' "$f" && grep -q '"Port": 443' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "certificate-arn=$cert tls host=$tls_host file=$f"
  fi
  [ "$result" == "0" ]
}

@test "5. external-dns: ALIAS and TXT records in the private zone" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/5/dns.txt
  ready=$(kubectl get deploy external-dns -n kube-system \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  result=1
  if [[ -n "$ready" ]] && [[ "$ready" -ge 1 ]] && [[ -s "$f" ]] && \
     grep -q 'app.eks-task109.internal' "$f" && grep -q '"Type": "A"' "$f" && \
     grep -qi 'TXT' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "external-dns ready replicas=$ready file=$f"
  fi
  [ "$result" == "0" ]
}

@test "6. Diagnostics: wrong ingressClassName, then fixed via IngressGroup" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/6/groupfix.txt
  status_class=$(kubectl get ingress status -n "$NS" \
    -o jsonpath='{.spec.ingressClassName}' 2>/dev/null)
  status_addr=$(kubectl get ingress status -n "$NS" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
  web_addr=$(kubectl get ingress web -n "$NS" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
  result=1
  if [[ -s "$f" ]] && grep -q 'ingressClassName' "$f" && grep -q 'wrong-class' "$f" && \
     [[ "$status_class" == "alb" ]] && [[ -n "$status_addr" ]] && \
     [[ "$status_addr" == "$web_addr" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file=$f status_class=$status_class status_addr=$status_addr web_addr=$web_addr"
  fi
  [ "$result" == "0" ]
}
