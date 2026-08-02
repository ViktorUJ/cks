#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Pod non-root-pod (redis:alpine, runAsUser 1000, fsGroup 2000)" {
  echo '1' >> /var/work/tests/result/all
  uid=$(kubectl get po non-root-pod --context $CTX -o jsonpath='{.spec.securityContext.runAsUser}' 2>/dev/null)
  fsg=$(kubectl get po non-root-pod --context $CTX -o jsonpath='{.spec.securityContext.fsGroup}' 2>/dev/null)
  if [[ "$uid" == "1000" ]] && [[ "$fsg" == "2000" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "non-root-pod runAsUser=$uid fsGroup=$fsg"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. Pod appsec-pod (root, capability SYS_TIME)" {
  echo '1' >> /var/work/tests/result/all
  cap=$(kubectl get po appsec-pod --context $CTX -o json 2>/dev/null | jq -r '.spec.containers[0].securityContext.capabilities.add[]?' | grep -c SYS_TIME)
  if [[ "$cap" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "appsec-pod SYS_TIME add count=$cap"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. Deployment deployment-app-y (ns app-y): allowPrivilegeEscalation=false, privileged=false" {
  echo '1' >> /var/work/tests/result/all
  ape=$(kubectl get deploy deployment-app-y -n app-y --context $CTX -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}' 2>/dev/null)
  priv=$(kubectl get deploy deployment-app-y -n app-y --context $CTX -o jsonpath='{.spec.template.spec.containers[0].securityContext.privileged}' 2>/dev/null)
  if [[ "$ape" == "false" ]] && [[ "$priv" == "false" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "app-y allowPrivEsc=$ape privileged=$priv"; result=1; fi
  [ "$result" == "0" ]
}

@test "4. Deployment sword-app (ns swordfish): runAsUser 5000, no priv escalation" {
  echo '1' >> /var/work/tests/result/all
  uid=$(kubectl get deploy sword-app -n swordfish --context $CTX -o jsonpath='{.spec.template.spec.containers[0].securityContext.runAsUser}' 2>/dev/null)
  ape=$(kubectl get deploy sword-app -n swordfish --context $CTX -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}' 2>/dev/null)
  if [[ "$uid" == "5000" ]] && [[ "$ape" == "false" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "sword-app runAsUser=$uid allowPrivEsc=$ape"; result=1; fi
  [ "$result" == "0" ]
}
