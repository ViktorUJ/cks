#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Pod nginx1233 (web-ns) has livenessProbe exec ls /var/www/html/, delay 10, period 60" {
  echo '1' >> /var/work/tests/result/all
  cmd=$(kubectl get po nginx1233 -n web-ns --context $CTX -o json 2>/dev/null | jq -r '.spec.containers[0].livenessProbe.exec.command | join(" ")')
  d=$(kubectl get po nginx1233 -n web-ns --context $CTX -o jsonpath='{.spec.containers[0].livenessProbe.initialDelaySeconds}' 2>/dev/null)
  p=$(kubectl get po nginx1233 -n web-ns --context $CTX -o jsonpath='{.spec.containers[0].livenessProbe.periodSeconds}' 2>/dev/null)
  if [[ "$cmd" == *"/var/www/html/"* ]] && [[ "$d" == "10" ]] && [[ "$p" == "60" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "nginx1233 cmd=$cmd delay=$d period=$p"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. Logs of app-xyz3322 exported to /opt/logs/app-xyz123.log" {
  echo '1' >> /var/work/tests/result/all
  if [[ -s /opt/logs/app-xyz123.log ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "/opt/logs/app-xyz123.log missing/empty"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. CLI scripts: top pods by cpu, events sorted" {
  echo '1' >> /var/work/tests/result/all
  ok=1
  grep -qi "top" /var/work/artifact/top.sh 2>/dev/null && grep -qi "cpu" /var/work/artifact/top.sh 2>/dev/null || ok=0
  grep -qi "events" /var/work/artifact/events.sh 2>/dev/null && grep -qi "sort-by" /var/work/artifact/events.sh 2>/dev/null || ok=0
  if [[ "$ok" == "1" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "top.sh/events.sh missing expected content"; result=1; fi
  [ "$result" == "0" ]
}

@test "4. Deprecated manifest fixed and app-21 deployment is ready" {
  echo '1' >> /var/work/tests/result/all
  api=$(kubectl get deploy app-21 --context $CTX -o jsonpath='{.apiVersion}' 2>/dev/null)
  ready=$(kubectl get deploy app-21 --context $CTX -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "$api" == "apps/v1" ]] && [[ "$ready" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "app-21 apiVersion=$api ready=$ready"; result=1; fi
  [ "$result" == "0" ]
}
