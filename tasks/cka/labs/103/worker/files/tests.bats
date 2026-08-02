#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Job hi-job (busybox, completions 3, backoffLimit 6, restartPolicy Never)" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get job hi-job --context $CTX -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  comp=$(kubectl get job hi-job --context $CTX -o jsonpath='{.spec.completions}' 2>/dev/null)
  bo=$(kubectl get job hi-job --context $CTX -o jsonpath='{.spec.backoffLimit}' 2>/dev/null)
  rp=$(kubectl get job hi-job --context $CTX -o jsonpath='{.spec.template.spec.restartPolicy}' 2>/dev/null)
  if [[ "$image" == busybox* ]] && [[ "$comp" == "3" ]] && [[ "$bo" == "6" ]] && [[ "$rp" == "Never" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "hi-job image=$image completions=$comp backoff=$bo restartPolicy=$rp"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. CronJob cron-job1 in rnd (schedule */15, Forbid, hist 5/7)" {
  echo '1' >> /var/work/tests/result/all
  sch=$(kubectl get cronjob cron-job1 -n rnd --context $CTX -o jsonpath='{.spec.schedule}' 2>/dev/null)
  cp=$(kubectl get cronjob cron-job1 -n rnd --context $CTX -o jsonpath='{.spec.concurrencyPolicy}' 2>/dev/null)
  sh=$(kubectl get cronjob cron-job1 -n rnd --context $CTX -o jsonpath='{.spec.successfulJobsHistoryLimit}' 2>/dev/null)
  fh=$(kubectl get cronjob cron-job1 -n rnd --context $CTX -o jsonpath='{.spec.failedJobsHistoryLimit}' 2>/dev/null)
  if [[ "$sch" == "*/15 * * * *" ]] && [[ "$cp" == "Forbid" ]] && [[ "$sh" == "5" ]] && [[ "$fh" == "7" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "cron schedule=$sch concurrency=$cp succHist=$sh failHist=$fh"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. DaemonSet important-app in app-system runs on ALL nodes" {
  echo '1' >> /var/work/tests/result/all
  nodes=$(kubectl get nodes --context $CTX --no-headers 2>/dev/null | wc -l)
  desired=$(kubectl get ds important-app -n app-system --context $CTX -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
  ready=$(kubectl get ds important-app -n app-system --context $CTX -o jsonpath='{.status.numberReady}' 2>/dev/null)
  if [[ "$desired" == "$nodes" ]] && [[ "$ready" == "$nodes" ]] && [[ "$nodes" -ge 2 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "nodes=$nodes desired=$desired ready=$ready"; result=1; fi
  [ "$result" == "0" ]
}
