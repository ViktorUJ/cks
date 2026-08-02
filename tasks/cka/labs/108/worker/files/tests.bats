#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. PV pv-analytics (100Mi, RWO, hostPath /pv/analytics)" {
  echo '1' >> /var/work/tests/result/all
  cap=$(kubectl get pv pv-analytics --context $CTX -o jsonpath='{.spec.capacity.storage}' 2>/dev/null)
  am=$(kubectl get pv pv-analytics --context $CTX -o jsonpath='{.spec.accessModes[0]}' 2>/dev/null)
  hp=$(kubectl get pv pv-analytics --context $CTX -o jsonpath='{.spec.hostPath.path}' 2>/dev/null)
  if [[ "$cap" == "100Mi" ]] && [[ "$am" == "ReadWriteOnce" ]] && [[ "$hp" == "/pv/analytics" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "pv cap=$cap am=$am hostPath=$hp"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. PVC pvc-analytics is Bound (100Mi, RWO)" {
  echo '1' >> /var/work/tests/result/all
  phase=$(kubectl get pvc pvc-analytics --context $CTX -o jsonpath='{.status.phase}' 2>/dev/null)
  if [[ "$phase" == "Bound" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "pvc phase=$phase"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. Pod analytics uses PVC, runs on node node_2, mounts /pv/analytics" {
  echo '1' >> /var/work/tests/result/all
  claim=$(kubectl get po analytics --context $CTX -o json 2>/dev/null | jq -r '.spec.volumes[]? | select(.persistentVolumeClaim.claimName=="pvc-analytics") | .persistentVolumeClaim.claimName' | head -1)
  node=$(kubectl get po analytics --context $CTX -o jsonpath='{.spec.nodeName}' 2>/dev/null)
  lbl=$(kubectl get node "$node" --context $CTX -o jsonpath='{.metadata.labels.node}' 2>/dev/null)
  mp=$(kubectl get po analytics --context $CTX -o jsonpath='{.spec.containers[0].volumeMounts[0].mountPath}' 2>/dev/null)
  if [[ "$claim" == "pvc-analytics" ]] && [[ "$lbl" == "node_2" ]] && [[ "$mp" == "/pv/analytics" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "analytics claim=$claim node=$node label=$lbl mountPath=$mp"; result=1; fi
  [ "$result" == "0" ]
}
