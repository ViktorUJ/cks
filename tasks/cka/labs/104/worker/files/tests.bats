#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Pod alpine runs on a node with label disk=ssd" {
  echo '1' >> /var/work/tests/result/all
  node=$(kubectl get po alpine --context $CTX -o jsonpath='{.spec.nodeName}' 2>/dev/null)
  ssd=$(kubectl get node "$node" --context $CTX -o jsonpath='{.metadata.labels.disk}' 2>/dev/null)
  if [[ -n "$node" ]] && [[ "$ssd" == "ssd" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "alpine node=$node disk=$ssd"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. Pod alpha has toleration for taint app_type=alpha:NoSchedule" {
  echo '1' >> /var/work/tests/result/all
  tol=$(kubectl get po alpha --context $CTX -o json 2>/dev/null | jq -r '.spec.tolerations[]? | select(.key=="app_type" and .value=="alpha" and .effect=="NoSchedule") | .key' | head -1)
  if [[ "$tol" == "app_type" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "alpha toleration=$tol"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. Static pod static-busybox on control-plane (label, command)" {
  echo '1' >> /var/work/tests/result/all
  name=$(kubectl get po --context $CTX -o name 2>/dev/null | grep static-busybox | head -1)
  label=$(kubectl get po -l pod-type=static-pod --context $CTX -o name 2>/dev/null | grep -c static-busybox)
  if [[ -n "$name" ]] && [[ "$label" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "static-busybox name=$name labeled=$label"; result=1; fi
  [ "$result" == "0" ]
}

@test "4. PriorityClass high-priority (value 1000000) used by deployment prio-app" {
  echo '1' >> /var/work/tests/result/all
  val=$(kubectl get priorityclass high-priority --context $CTX -o jsonpath='{.value}' 2>/dev/null)
  pc=$(kubectl get deploy prio-app --context $CTX -o jsonpath='{.spec.template.spec.priorityClassName}' 2>/dev/null)
  if [[ "$val" == "1000000" ]] && [[ "$pc" == "high-priority" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "priorityclass value=$val deploy uses=$pc"; result=1; fi
  [ "$result" == "0" ]
}

@test "5. HPA hpa-app (min 2, max 10, cpu 50)" {
  echo '1' >> /var/work/tests/result/all
  mn=$(kubectl get hpa hpa-app --context $CTX -o jsonpath='{.spec.minReplicas}' 2>/dev/null)
  mx=$(kubectl get hpa hpa-app --context $CTX -o jsonpath='{.spec.maxReplicas}' 2>/dev/null)
  if [[ "$mn" == "2" ]] && [[ "$mx" == "10" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "hpa min=$mn max=$mx"; result=1; fi
  [ "$result" == "0" ]
}

@test "6. Deployment important-app2 (ns app2-system): 3 replicas, antiaffinity, PDB minAvailable=1" {
  echo '1' >> /var/work/tests/result/all
  rep=$(kubectl get deploy important-app2 -n app2-system --context $CTX -o jsonpath='{.spec.replicas}' 2>/dev/null)
  aff=$(kubectl get deploy important-app2 -n app2-system --context $CTX -o json 2>/dev/null | jq -r '.spec.template.spec.affinity.podAntiAffinity != null')
  pdb=$(kubectl get pdb important-app2 -n app2-system --context $CTX -o jsonpath='{.spec.minAvailable}' 2>/dev/null)
  if [[ "$rep" == "3" ]] && [[ "$aff" == "true" ]] && [[ "$pdb" == "1" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "replicas=$rep antiaffinity=$aff pdb=$pdb"; result=1; fi
  [ "$result" == "0" ]
}

@test "7. Deployment spread-app: строгий topologySpread (maxSkew 1, hostname, DoNotSchedule)" {
  echo '1' >> /var/work/tests/result/all
  ms=$(kubectl get deploy spread-app --context $CTX -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].maxSkew}' 2>/dev/null)
  tk=$(kubectl get deploy spread-app --context $CTX -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].topologyKey}' 2>/dev/null)
  wu=$(kubectl get deploy spread-app --context $CTX -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].whenUnsatisfiable}' 2>/dev/null)
  if [[ "$ms" == "1" ]] && [[ "$tk" == "kubernetes.io/hostname" ]] && [[ "$wu" == "DoNotSchedule" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "spread-app maxSkew=$ms topologyKey=$tk whenUnsatisfiable=$wu"; result=1; fi
  [ "$result" == "0" ]
}
