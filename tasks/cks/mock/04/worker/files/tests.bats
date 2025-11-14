#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]

}

@test "1.1. Check if user was removed from docker group" {
  echo '1'>>/var/work/tests/result/all
  set +e
  timeout 2s ssh -oStrictHostKeyChecking=no docker-worker "groups user " | grep docker
  result=$?
  set -e
  if [[ "$result" == "1" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "1" ]
}

@test "1.2. Check docker socket configuration" {
  echo '1' >>/var/work/tests/result/all
  timeout 2s ssh -oStrictHostKeyChecking=no docker-worker "stat -c %G /var/run/docker.sock" | grep root
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


@test "1.3. Docker is NOT exposed on TCP 2375" {
  echo '1' >>/var/work/tests/result/all
  set +e
  timeout 2s ssh -oBatchMode=yes -oStrictHostKeyChecking=no -oConnectTimeout=5 docker-worker 'ss -ltn  | grep -qE "[:.]2375(\\s|$)"'
  result=$?
  set -e
  if [[ "$result" == "1" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "1" ]
}

@test "1.4. Docker daemon is running" {
  echo '1' >>/var/work/tests/result/all
  timeout 2s ssh -oStrictHostKeyChecking=no docker-worker "systemctl is-active docker" | grep active
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "1.5. Docker socket is active" {
  echo '1' >>/var/work/tests/result/all
  timeout 2s ssh -oStrictHostKeyChecking=no docker-worker "systemctl is-active docker.socket" | grep active
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


@test "2.1 Check that ALL pods have injection" {
  echo '1' >> /var/work/tests/result/all

  total_pods=$(kubectl get pods -n market --no-headers  --context cluster12-admin@cluster12 | wc -l)

  pods_with_sidecar=$(kubectl get pods -n market -o json --context cluster12-admin@cluster12 | jq -r '.items[] | select(.spec.containers[].name == "istio-proxy") | .metadata.name' | wc -l)

  if [[ "$total_pods" -eq "$pods_with_sidecar" ]] && [[ "$total_pods" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Total pods: $total_pods, Pods with sidecar: $pods_with_sidecar"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.2 Check if mtls enabled" {
  echo '1' >> /var/work/tests/result/all
  mtls_policies=$(kubectl get peerauthentication -n market -o json --context cluster12-admin@cluster12 | jq -r '.items[] | select(.spec.mtls.mode == "STRICT") | .metadata.name' | wc -l)
  if [[ "$mtls_policies" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    result=1
  fi
  [ "$result" == "0" ]
}


@test "3 Falco. Check that proper deployment was scaled to 0" {
  echo '2'>>/var/work/tests/result/all
  app1_replicas=$(kubectl get deployments.apps --context cluster8-admin@cluster8 -n north app1 -o jsonpath='{.spec.replicas}')
  app2_replicas=$(kubectl get deployments.apps --context cluster8-admin@cluster8 -n north app2 -o jsonpath='{.spec.replicas}')
  app3_replicas=$(kubectl get deployments.apps --context cluster8-admin@cluster8 -n north app3 -o jsonpath='{.spec.replicas}')
  if [[ "$app1_replicas" == "1" && "$app2_replicas" == "1" && "$app3_replicas" == "0" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [[ "$app1_replicas" == "1" && "$app2_replicas" == "1" && "$app3_replicas" == "0" ]]
}



@test "4.1 Check  Ingress using the provided certificate. " {
  echo '2'>>/var/work/tests/result/all
  timeout 2 curl https://cks.local:31139 -kv 2>&1  | grep 'CN=cks.local'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "4.2 Check  Ingress redirect from http to https. " {
  echo '2'>>/var/work/tests/result/all
  timeout 2 curl http://cks.local:30102  2>&1  | grep '308 Permanent Redirect'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}



@test "5.1 Network policy. can connect from prod NS to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec prod-app -n prod --context cluster6-admin@cluster6 -- sh -c ' curl db.prod-db.svc:3306 --connect-timeout 1 -s ' | grep 'mysql'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "5.2 Network policy. can  connect from stage NS  and  label: role=db-connect  to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec stage-app -n stage --context cluster6-admin@cluster6 -- sh -c ' curl db.prod-db.svc:3306 --connect-timeout 1 -s ' | grep 'mysql'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "5.3 Network policy. can connect from any Namespaces and have label: role=db-external-connect  to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec all-app -n default --context cluster6-admin@cluster6 -- sh -c ' curl db.prod-db.svc:3306 --connect-timeout 1 -s ' | grep 'mysql'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "5.4 Network policy. can't connect from stage NameSpace all pod   to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  set +e
  kubectl exec not-db-app -n stage  --context cluster6-admin@cluster6 -- sh -c ' curl db.prod-db.svc:3306 --connect-timeout 1 -s '
  result=$?
  set -e
  if (( $result > 0 )); then
   echo '1'>>/var/work/tests/result/ok
  fi
  (( $result > 0 ))
}

@test "5.5 Network policy. can't connect all   pod   to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  set +e
  kubectl exec all-not-db-app -n default   --context cluster6-admin@cluster6 -- sh -c ' curl db.prod-db.svc:3306 --connect-timeout 1 -s '
  result=$?
  set -e
  if (( $result > 0 )); then
   echo '1'>>/var/work/tests/result/ok
  fi
   (( $result > 0 ))
}

@test "5.6 Network policy. can connect from all    pod   to google.com  " {
  echo '1'>>/var/work/tests/result/all
  set +e && kubectl exec all-not-db-app -n default    --context cluster6-admin@cluster6 -- sh -c ' curl https://google.com --connect-timeout 1 -s '
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}



@test "6.1 Deployment  security . check prevent escalation  " {
  echo '1'>>/var/work/tests/result/all
  kubectl  get deployment secure -n secure --context cluster6-admin@cluster6  -o yaml  | grep allowPrivilegeEscalation | grep false |grep -v '{}'| wc -l  | grep 3
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


@test "6.2 Deployment  security . Read only root file system c1  " {
  echo '.5'>>/var/work/tests/result/all
  set +e
  pod=$(kubectl  get po  -n secure --context cluster6-admin@cluster6 -o jsonpath='{.items..metadata.name}')
  kubectl  exec $pod  -n secure --context cluster6-admin@cluster6  -c c1 -- sh -c 'echo "test" >/var/tmp_xxx'
  result=$?
  set -e
   if (( $result > 0 )); then
   echo '.5'>>/var/work/tests/result/ok
  fi
  (( $result > 0 ))
}

@test "6.3 Deployment  security . Read only root file system c2  " {
  echo '.5'>>/var/work/tests/result/all
  set +e
  pod=$(kubectl  get po  -n secure --context cluster6-admin@cluster6 -o jsonpath='{.items..metadata.name}')
  kubectl  exec $pod  -n secure --context cluster6-admin@cluster6  -c c2 -- sh -c 'echo "test" >/var/tmp_xxx'
  result=$?
  set -e
   if (( $result > 0 )); then
   echo '.5'>>/var/work/tests/result/ok
  fi
  (( $result > 0 ))
}

@test "6.4 Deployment  security . Read only root file system c3  " {
  echo '.5'>>/var/work/tests/result/all
  set +e
  pod=$(kubectl  get po  -n secure --context cluster6-admin@cluster6 -o jsonpath='{.items..metadata.name}')
  kubectl  exec $pod  -n secure --context cluster6-admin@cluster6  -c c3 -- sh -c 'echo "test" >/var/tmp_xxx'
  result=$?
  set -e
   if (( $result > 0 )); then
   echo '.5'>>/var/work/tests/result/ok
  fi
  (( $result > 0 ))
}

@test "6.5 Deployment  security . user_id,  c1  " {
  echo '.5'>>/var/work/tests/result/all
  pod=$(kubectl  get po  -n secure --context cluster6-admin@cluster6 -o jsonpath='{.items..metadata.name}')
  kubectl  exec $pod  -n secure --context cluster6-admin@cluster6  -c c1 -- sh -c 'id ' | grep 3000
  result=$?
   if [[ "$result" == "0" ]]; then
   echo '.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "6.6 Deployment  security . user_id,  c2  " {
  echo '1'>>/var/work/tests/result/all
  pod=$(kubectl  get po  -n secure --context cluster6-admin@cluster6 -o jsonpath='{.items..metadata.name}')
  kubectl  exec $pod  -n secure --context cluster6-admin@cluster6  -c c2 -- sh -c 'id ' | grep 3000
  result=$?
   if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
@test "6.7 Deployment  security . user_id,  c3  " {
  echo '1'>>/var/work/tests/result/all
  pod=$(kubectl  get po  -n secure --context cluster6-admin@cluster6 -o jsonpath='{.items..metadata.name}')
  kubectl  exec $pod  -n secure --context cluster6-admin@cluster6  -c c3 -- sh -c 'id ' | grep 3000
  result=$?
   if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "6.8 Deployment  security . allow wread to /tmp/  container c1 " {
  echo '1'>>/var/work/tests/result/all
  pod=$(kubectl  get po  -n secure --context cluster6-admin@cluster6 -o jsonpath='{.items..metadata.name}')
  kubectl  exec $pod  -n secure --context cluster6-admin@cluster6  -c c1 -- sh -c 'echo "test">/tmp/test '
  result=$?
   if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


@test "7.1  disable sa secret auto-mount. " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  get sa team20   -n team-20  -o jsonpath='{.automountServiceAccountToken}'  --context cluster6-admin@cluster6)
  if [[ "$result" == "false" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "false" ]
}

@test "7.2 check mount secret " {
  echo '2'>>/var/work/tests/result/all
  pod=$(kubectl get  po  -n team-20    --context cluster6-admin@cluster6  -l app=team20 -o jsonpath={.items..metadata.name})
  kubectl exec $pod -ti -n  team-20    --context cluster6-admin@cluster6 -- bash -c ' cat /var/team20/secret/token'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "8.1 check right images and containters " {
  echo '1'>>/var/work/tests/result/all
  [ "$(kubectl get deployment -n team-xxx --context cluster6-admin@cluster6 -o jsonpath='{.items[*].spec.template.spec.containers[*].name}')" = "app1" ] \
  && [ "$(kubectl get deployment -n team-xxx --context cluster6-admin@cluster6 -o jsonpath='{.items[*].spec.template.spec.containers[*].image}')" = "viktoruj/ping_pong:b7a1494-arm64-alpine" ] \
  && [ "$(kubectl get deployment -n team-xxx --context cluster6-admin@cluster6 -o jsonpath='{.items[*].spec.template.spec.containers[*].name}' | wc -w)" -eq 1 ]

  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "8.2  Image Vulnerability Scanning. /var/work/02/kube_scheduler_sbom.json " {
  echo '1'>>/var/work/tests/result/all
  bom generate --image registry.k8s.io/kube-scheduler:v1.32.0 --format json --output /tmp/kube_scheduler_sbom.json

  diff <(jq --sort-keys 'del(.. | .created?, .creationTimestamp?, .generatedAt?, .timestamp?, .buildTime?, .documentNamespace?, .name?, .SPDXID?, .checksumValue?, .checksums?, .copyrightText?, .downloadLocation?, .filesAnalyzed?, .versionInfo?, .supplier?, .externalRefs?, .referenceLocator?, .relatedSpdxElement?, .spdxElementId?, .relationshipType?)' /tmp/kube_scheduler_sbom.json) \
       <(jq --sort-keys 'del(.. | .created?, .creationTimestamp?, .generatedAt?, .timestamp?, .buildTime?, .documentNamespace?, .name?, .SPDXID?, .checksumValue?, .checksums?, .copyrightText?, .downloadLocation?, .filesAnalyzed?, .versionInfo?, .supplier?, .externalRefs?, .referenceLocator?, .relatedSpdxElement?, .spdxElementId?, .relationshipType?)' /var/work/02/kube_scheduler_sbom.json)
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "9.1 Pod Security Standard . check enabled restricted  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  get ns   team-red   --context cluster6-admin@cluster6  -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' )
  if [[ "$result" == "restricted" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "restricted" ]
}

@test "9.2 Pod Security Standard . pod is Ready  " {
  echo '1'>>/var/work/tests/result/all
  [ "$(kubectl get po -n team-red -l app=container-host-hacker --context cluster6-admin@cluster6 -o jsonpath='{.items[0].status.phase}')" = "Running" ]
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
@test "10.1 deloyment pod mount secret. crt file  " {
  echo '1'>>/var/work/tests/result/all
  POD=$(kubectl get pod -n team-black10 -l app=app --context cluster6-admin@cluster6  -o jsonpath='{.items[0].metadata.name}')
  diff -q /var/work/19/cks.local.crt <(kubectl exec "$POD" -n team-black10 --context cluster6-admin@cluster6  -- sh -c 'cat /mnt/secret-volume/tls.crt')
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
@test "10.2 deloyment pod mount secret. key file  " {
  echo '1'>>/var/work/tests/result/all
  POD=$(kubectl get pod -n team-black10 -l app=app --context cluster6-admin@cluster6  -o jsonpath='{.items[0].metadata.name}')
  diff -q /var/work/19/cks.local.key <(kubectl exec "$POD" -n team-black10 --context cluster6-admin@cluster6  -- sh -c 'cat /mnt/secret-volume/tls.key')
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
@test "11.1 update cluster. worker node version  " {
  echo '1'>>/var/work/tests/result/all
  cp_ver=$(kubectl get node --context cluster7-admin@cluster7 -l node-role.kubernetes.io/control-plane= -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}')
  wk_ver=$(kubectl get node --context cluster7-admin@cluster7 -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}')
  [[ "$cp_ver" == "$wk_ver" ]]
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "11.2 update cluster. worker node has Ready status " {
  echo '1'>>/var/work/tests/result/all
  status=$(kubectl get node --context cluster7-admin@cluster7  -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')
  [[ "$status" == "True" ]]
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


@test "12.1 Enable audit log. cluster are available " {
  echo '1'>>/var/work/tests/result/all
  kubectl get  ns   --context cluster2-admin@cluster2
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "12.2 Enable audit log. check secrets in log " {
  echo '3'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster2-admin@cluster2  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo chmod +r /var/logs/kubernetes-api.log ;cat /var/logs/kubernetes-api.log | grep 'secrets' | grep 'Metadata'| grep 'prod' "
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "12.3 Enable audit log. check configmap in log " {
  echo '3'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster2-admin@cluster2  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo chmod +r /var/logs/kubernetes-api.log ;cat /var/logs/kubernetes-api.log | grep 'configmap' | grep 'RequestResponse'| grep 'billing'"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "13.1 CIS Benchmark. check kube-apiserver 1.2.15  " {
  echo '.75'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster3-admin@cluster3  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo kube-bench | grep 1.2.15  | grep PASS"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.75'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "13.2 CIS Benchmark. check controller-manager 1.3.2 " {
  echo '.75'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster3-admin@cluster3  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo kube-bench | grep 1.3.2 | grep PASS"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.75'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "13.3 CIS Benchmark. check kube-scheduler 1.4.1 " {
  echo '.75'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster3-admin@cluster3  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo kube-bench | grep 1.4.1 | grep PASS"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.75'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "13.4 CIS Benchmark. check  protect-kernel-defaults 4.2.6 " {
  echo '.75'>>/var/work/tests/result/all
  worker_node=$(kubectl get no -l work_type=worker --context cluster3-admin@cluster3  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $worker_node "sudo kube-bench | grep 4.2.6 | grep PASS"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.75'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "14.1 Check if ingress rule is working" {
  echo '1'>>/var/work/tests/result/all
 curl --connect-timeout 1 --max-time 1 -s http://myapp.local:30800 -v
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "14.2 Check if mtls enabled" {
  echo '1'>>/var/work/tests/result/all
  kubectl get cnp -n myapp --context cluster4-admin@cluster4  -o yaml | grep deny-all && kubectl get cnp --context cluster4-admin@cluster4  -n myapp -o yaml | grep "mode: required"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
# 15 all
control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster1-admin@cluster1  -o jsonpath='{.items..metadata.name}')

@test "15.1 Check anonymous-auth is disabled" {
  echo '1'>>/var/work/tests/result/all
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep 'anonymous-auth=false'"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "15.2 Check authorization-mode is Node,RBAC" {
  echo '1'>>/var/work/tests/result/all
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep 'authorization-mode=Node,RBAC'"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
@test "15.3 Check anonymous access is denied" {
  echo '1'>>/var/work/tests/result/all
  set +e
  ssh -oStrictHostKeyChecking=no $control_plane_node "curl -k https://127.0.0.1:6443/api/v1/namespaces 2>&1 | grep 'Unauthorized'"
  result=$?
  set -e
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "15.4 Check clusterrolebinding anonymous-binding is deleted" {
  echo '1'>>/var/work/tests/result/all
  set +e
  kubectl get clusterrolebinding anonymous-binding --context cluster1-admin@cluster1 2>&1 | grep 'NotFound'
  result=$?
  set -e
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
@test "15.5 Check clusterrole anonymous is deleted" {
  echo '1'>>/var/work/tests/result/all
  set +e
  kubectl get clusterrole anonymous --context cluster1-admin@cluster1 2>&1 | grep 'NotFound'
  result=$?
  set -e
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "16.1 Dockerfile: Check 1" {
  echo '1'>>/var/work/tests/result/all
  # Check that USER is couchdb, not root
  grep -E '^USER couchdb' /var/work/16/Dockerfile
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "16.2 Dockerfile: Check 2" {
  echo '1'>>/var/work/tests/result/all
  # Check that the problematic separate RUN command is removed
  set +e
  grep -E '^RUN\s+rm -rf /var/lib/apt/lists/\*' /var/work/16/Dockerfile
  result=$?
  set -e
  # Should NOT find standalone rm command (result should be 1)
  if [[ "$result" == "1" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "1" ]
}

@test "16.3 Dockerfile: Check 3" {
  echo '1'>>/var/work/tests/result/all
  # Check that line with gnupg ends with '; \', next line has rm -rf /var/lib/apt/lists/*.
  awk '
    /gnupg/ && /;[[:space:]]*\\[[:space:]]*$/ { found_prev=1; next }
    found_prev && /^[[:space:]]*rm[[:space:]]+-rf[[:space:]]+\/var\/lib\/apt\/lists\/\*/ {
      print "Found proper chain"
      exit 0
    }
    END { exit 1 }
  ' /var/work/16/Dockerfile | grep -q "Found proper chain"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
