#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-108"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-108 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. LBC ServiceAccount is bound to the IRSA role and controller is Running" {
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

@test "3. Deployment web (viktoruj/ping_pong, 2 replicas) is Ready" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get deploy web -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ready=$(kubectl get deploy web -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "$image" == *ping_pong* ]] && [[ "$ready" == "2" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "web image=$image ready=$ready"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Service web is a Network Load Balancer, internet-facing, with an external address" {
  echo '1' >> /var/work/tests/result/all
  lb_type=$(kubectl get svc web -n "$NS" \
    -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-type}' 2>/dev/null)
  target_type=$(kubectl get svc web -n "$NS" \
    -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-nlb-target-type}' 2>/dev/null)
  scheme=$(kubectl get svc web -n "$NS" \
    -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-scheme}' 2>/dev/null)
  hostname=$(kubectl get svc web -n "$NS" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
  f=/var/work/tests/artifacts/4/nlb.txt
  if [[ "$lb_type" == "external" ]] && [[ "$target_type" == "ip" ]] \
    && [[ "$scheme" == "internet-facing" ]] && [[ -n "$hostname" ]] \
    && [[ -s "$f" ]] && grep -qi 'network' "$f" && grep -qi 'internet-facing' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "lb_type=$lb_type target_type=$target_type scheme=$scheme hostname=$hostname file=$f"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Target group targets are pod IPs, confirming target-type ip" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/5/targets.txt
  if [[ -s "$f" ]] && grep -qi '"TargetType": "ip"' "$f" \
    && grep -Eq '"Id": "10\.10\.[0-9]+\.[0-9]+"' "$f" \
    && ! grep -Eq '"Id": "i-[0-9a-f]+"' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or targets are not pod IPs from 10.10.0.0/16"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. Artifact explains a healthy reconcile and an AccessDenied symptom" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/6/reconcile.txt
  if [[ -s "$f" ]] && grep -qi 'arn:aws:elasticloadbalancing' "$f" \
    && grep -qi 'AccessDenied' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention an NLB ARN and AccessDenied"
    result=1
  fi
  [ "$result" == "0" ]
}
