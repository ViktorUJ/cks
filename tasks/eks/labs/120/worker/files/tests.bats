#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-120"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-120 with Deployments api, client and Service api" {
  echo '1' >> /var/work/tests/result/all
  ns=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  api_image=$(kubectl get deploy api -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  api_ready=$(kubectl get deploy api -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  client_image=$(kubectl get deploy client -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  client_ready=$(kubectl get deploy client -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  svc_port=$(kubectl get svc api -n "$NS" -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null)
  if [[ "$ns" == "$NS" ]] && [[ "$api_image" == *ping_pong* ]] && [[ "$api_ready" == "2" ]] \
     && [[ "$client_image" == *busybox* ]] && [[ "$client_ready" == "1" ]] \
     && [[ "$svc_port" == "8080" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "ns=$ns api_image=$api_image api_ready=$api_ready client_image=$client_image" \
         "client_ready=$client_ready svc_port=$svc_port"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "2. Baseline connectivity works and artifact shows node SG on api's ENI" {
  echo '1' >> /var/work/tests/result/all
  f1=/var/work/tests/artifacts/2/connectivity.txt
  f2=/var/work/tests/artifacts/2/api_sg.txt
  if [[ -s "$f1" ]] && grep -qi 'Server Name' "$f1" \
     && [[ -s "$f2" ]] && grep -q 'GroupId' "$f2"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f1 or $f2 missing/empty or missing expected content"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. AWS Load Balancer Controller is Running with the IRSA role" {
  echo '1' >> /var/work/tests/result/all
  role=$(kubectl get sa aws-load-balancer-controller -n kube-system \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null)
  ready=$(kubectl get deploy aws-load-balancer-controller -n kube-system \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "$role" == *lbc-irsa* ]] && [[ "${ready:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "sa role-arn=$role controller readyReplicas=$ready"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Symptom: NLB api-lb targets are unhealthy" {
  echo '1' >> /var/work/tests/result/all
  lb_type=$(kubectl get svc api-lb -n "$NS" \
    -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-type}' 2>/dev/null)
  sgs=$(kubectl get svc api-lb -n "$NS" \
    -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-security-groups}' 2>/dev/null)
  hostname=$(kubectl get svc api-lb -n "$NS" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
  f=/var/work/tests/artifacts/4/unhealthy.txt
  if [[ "$lb_type" == "external" ]] && [[ -n "$sgs" ]] && [[ -n "$hostname" ]] \
     && [[ -s "$f" ]] && grep -qi 'unhealthy' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "lb_type=$lb_type sgs=$sgs hostname=$hostname file=$f"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Diagnostics: broken SG has no inbound, artifact explains SG vs health check" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/5/diagnosis.txt
  if [[ -s "$f" ]] && grep -qi 'security group' "$f" && grep -qi 'health check' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention security group and health check"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. Fix: authorize-security-group-ingress, targets became healthy" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/6/healthy.txt
  if [[ -s "$f" ]] && grep -qi 'healthy' "$f" && ! grep -qi 'FailedHealthChecks' "$f" \
     && grep -qi 'Server Name' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty, still shows FailedHealthChecks, or missing app response"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "7. DNS resolves both internal and external names (not the failure in this lab)" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/7/dns.txt
  if [[ -s "$f" ]] && grep -qi 'kubernetes.default' "$f" && grep -qi 'example.com' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention both names"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "8. Summary: symptom, probable cause and check command from the checklist" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/8/summary.txt
  if [[ -s "$f" ]] && grep -qi 'unhealthy' "$f" && grep -qi 'security group' "$f" \
     && grep -qi 'health check' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention unhealthy, security group, health check"
    result=1
  fi
  [ "$result" == "0" ]
}
