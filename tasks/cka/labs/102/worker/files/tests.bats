#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Deployment web (viktoruj/ping_pong, 3 replicas) exists and ready" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get deploy web --context $CTX -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ready=$(kubectl get deploy web --context $CTX -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  # web стартует с :latest (задание 1), затем обновляется на :alpine (задание 2) —
  # поэтому здесь проверяем только сам деплой и 3 готовые реплики, без привязки к тегу
  if [[ "$image" == viktoruj/ping_pong:* ]] && [[ "$ready" == "3" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "web image=$image ready=$ready"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. web rolled to viktoruj/ping_pong:alpine with >=2 revisions" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get deploy web --context $CTX -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  revs=$(kubectl rollout history deploy web --context $CTX 2>/dev/null | grep -cE '^[0-9]+')
  if [[ "$image" == "viktoruj/ping_pong:alpine" ]] && [[ "$revs" -ge 2 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "web image=$image revisions=$revs"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. Deployment roll rolled back to viktoruj/ping_pong:latest (>=3 revisions history)" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get deploy roll --context $CTX -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  gen=$(kubectl get deploy roll --context $CTX -o jsonpath='{.metadata.generation}' 2>/dev/null)
  if [[ "$image" == "viktoruj/ping_pong:latest" ]] && [[ "$gen" -ge 3 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "roll image=$image generation=$gen"; result=1; fi
  [ "$result" == "0" ]
}

@test "4. Canary in ns canary: app-v1=7, app-v2=3, service app selects app=app" {
  echo '1' >> /var/work/tests/result/all
  v1=$(kubectl get deploy app-v1 -n canary --context $CTX -o jsonpath='{.spec.replicas}' 2>/dev/null)
  v2=$(kubectl get deploy app-v2 -n canary --context $CTX -o jsonpath='{.spec.replicas}' 2>/dev/null)
  sel=$(kubectl get svc app -n canary --context $CTX -o jsonpath='{.spec.selector.app}' 2>/dev/null)
  eps=$(kubectl get endpoints app -n canary --context $CTX -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
  if [[ "$v1" == "7" ]] && [[ "$v2" == "3" ]] && [[ "$sel" == "app" ]] && [[ "$eps" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "v1=$v1 v2=$v2 selector=$sel endpoints=$eps"; result=1; fi
  [ "$result" == "0" ]
}

@test "5. Deployment web strategy: RollingUpdate maxSurge=2, maxUnavailable=0" {
  echo '1' >> /var/work/tests/result/all
  st=$(kubectl get deploy web --context $CTX -o jsonpath='{.spec.strategy.type}' 2>/dev/null)
  ms=$(kubectl get deploy web --context $CTX -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}' 2>/dev/null)
  mu=$(kubectl get deploy web --context $CTX -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}' 2>/dev/null)
  if [[ "$st" == "RollingUpdate" ]] && [[ "$ms" == "2" ]] && [[ "$mu" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "web strategy=$st maxSurge=$ms maxUnavailable=$mu"; result=1; fi
  [ "$result" == "0" ]
}

@test "6. Blue/Green in ns bg: service bg-svc switched to version=green" {
  echo '1' >> /var/work/tests/result/all
  sel=$(kubectl get svc bg-svc -n bg --context $CTX -o jsonpath='{.spec.selector.version}' 2>/dev/null)
  blue=$(kubectl get deploy bg-blue -n bg --context $CTX -o jsonpath='{.metadata.name}' 2>/dev/null)
  green=$(kubectl get deploy bg-green -n bg --context $CTX -o jsonpath='{.metadata.name}' 2>/dev/null)
  eps=$(kubectl get endpoints bg-svc -n bg --context $CTX -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
  if [[ "$sel" == "green" ]] && [[ "$blue" == "bg-blue" ]] && [[ "$green" == "bg-green" ]] && [[ "$eps" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "bg-svc selector.version=$sel blue=$blue green=$green endpoints=$eps"; result=1; fi
  [ "$result" == "0" ]
}
