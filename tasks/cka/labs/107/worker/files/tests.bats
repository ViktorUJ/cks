#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. multi-pod: alpha(ping_pong,env name=alpha) + beta(ping_pong,env name=beta)" {
  echo '1' >> /var/work/tests/result/all
  aimg=$(kubectl get po multi-pod --context $CTX -o jsonpath='{.spec.containers[?(@.name=="alpha")].image}' 2>/dev/null)
  bimg=$(kubectl get po multi-pod --context $CTX -o jsonpath='{.spec.containers[?(@.name=="beta")].image}' 2>/dev/null)
  aenv=$(kubectl get po multi-pod --context $CTX -o json 2>/dev/null | jq -r '.spec.containers[] | select(.name=="alpha") | .env[]? | select(.name=="name") | .value')
  benv=$(kubectl get po multi-pod --context $CTX -o json 2>/dev/null | jq -r '.spec.containers[] | select(.name=="beta") | .env[]? | select(.name=="name") | .value')
  if [[ "$aimg" == *ping_pong* ]] && [[ "$bimg" == *ping_pong* ]] && [[ "$aenv" == "alpha" ]] && [[ "$benv" == "beta" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "alpha=$aimg/$aenv beta=$bimg/$benv"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. logger pod: 2 containers share emptyDir volume logs" {
  echo '1' >> /var/work/tests/result/all
  cnt=$(kubectl get po logger --context $CTX -o json 2>/dev/null | jq -r '.spec.containers | length')
  ed=$(kubectl get po logger --context $CTX -o json 2>/dev/null | jq -r '[.spec.volumes[]? | select(.emptyDir!=null and .name=="logs")] | length')
  mounts=$(kubectl get po logger --context $CTX -o json 2>/dev/null | jq -r '[.spec.containers[].volumeMounts[]? | select(.name=="logs")] | length')
  if [[ "$cnt" -ge 2 ]] && [[ "$ed" -ge 1 ]] && [[ "$mounts" -ge 2 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "logger containers=$cnt emptyDir=$ed mounts=$mounts"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. redis-storage pod: emptyDir data sizeLimit 500Mi mounted /data/redis" {
  echo '1' >> /var/work/tests/result/all
  img=$(kubectl get po redis-storage --context $CTX -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
  sl=$(kubectl get po redis-storage --context $CTX -o jsonpath='{.spec.volumes[?(@.name=="data")].emptyDir.sizeLimit}' 2>/dev/null)
  mp=$(kubectl get po redis-storage --context $CTX -o jsonpath='{.spec.containers[0].volumeMounts[?(@.name=="data")].mountPath}' 2>/dev/null)
  if [[ "$img" == redis:alpine ]] && [[ "$sl" == "500Mi" ]] && [[ "$mp" == "/data/redis" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "redis-storage img=$img sizeLimit=$sl mountPath=$mp"; result=1; fi
  [ "$result" == "0" ]
}

@test "4. Built image ckad:0.0.1 exported to oci-archive /var/work/107/ckad.tar" {
  echo '1' >> /var/work/tests/result/all
  if [[ -s /var/work/107/ckad.tar ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "/var/work/107/ckad.tar missing or empty"; result=1; fi
  [ "$result" == "0" ]
}
