#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]

}

@test "1.1  Container Runtime Sandbox gVisor.RuntimeClass " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get runtimeclasses.node.k8s.io  gvisor  --context cluster1-admin@cluster1  -o jsonpath={.handler})
  if [[ "$result" == "runsc" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "runsc" ]
}


@test "1.2  Container Runtime Sandbox gVisor.node label " {
  echo '.5'>>/var/work/tests/result/all
  result=$(kubectl get no -l node_name=node_2 --context cluster1-admin@cluster1  -o jsonpath='{.items..metadata.labels.RuntimeClass}')
  if [[ "$result" == "runsc" ]]; then
   echo '.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "runsc" ]
}

@test "1.3  Container Runtime Sandbox gVisor. deployment1 nodeSelector " {
  echo '.3'>>/var/work/tests/result/all
  result=$(kubectl get  deployment deployment1   -n team-purple  --context cluster1-admin@cluster1 -o jsonpath={.spec.template.spec.nodeSelector.RuntimeClass})
  if [[ "$result" == "runsc" ]]; then
   echo '.3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "runsc" ]
}


@test "1.4  Container Runtime Sandbox gVisor. deployment2 nodeSelector " {
  echo '.3'>>/var/work/tests/result/all
  result=$(kubectl get  deployment deployment2   -n team-purple  --context cluster1-admin@cluster1 -o jsonpath={.spec.template.spec.nodeSelector.RuntimeClass})
  if [[ "$result" == "runsc" ]]; then
   echo '.3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "runsc" ]
}

@test "1.5  Container Runtime Sandbox gVisor. deployment3 nodeSelector " {
  echo '.3'>>/var/work/tests/result/all
  result=$(kubectl get  deployment deployment3   -n team-purple  --context cluster1-admin@cluster1 -o jsonpath={.spec.template.spec.nodeSelector.RuntimeClass})
  if [[ "$result" == "runsc" ]]; then
   echo '.3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "runsc" ]
}

@test "1.6  Container Runtime Sandbox gVisor. RuntimeClass deployment1  " {
  echo '.3'>>/var/work/tests/result/all
  result=$(kubectl get  deployment deployment1   -n team-purple  --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.spec.runtimeClassName}')
  if [[ "$result" == "gvisor" ]]; then
   echo '.3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "gvisor" ]
}

@test "1.7  Container Runtime Sandbox gVisor. RuntimeClass deployment2  " {
  echo '.3'>>/var/work/tests/result/all
  result=$(kubectl get  deployment deployment2   -n team-purple  --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.spec.runtimeClassName}')
  if [[ "$result" == "gvisor" ]]; then
   echo '.3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "gvisor" ]
}

@test "1.8  Container Runtime Sandbox gVisor. RuntimeClass deployment3  " {
  echo '.3'>>/var/work/tests/result/all
  result=$(kubectl get  deployment deployment3   -n team-purple  --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.spec.runtimeClassName}')
  if [[ "$result" == "gvisor" ]]; then
   echo '.3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "gvisor" ]
}

@test "1.9  Container Runtime Sandbox gVisor. logs dmesg  " {
  echo '.7'>>/var/work/tests/result/all
  cat /var/work/tests/artifacts/1/gvisor-dmesg | grep 'Starting gVisor'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.7'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# all =4 , task =4

# task 2

@test "2.1  Image Vulnerability Scanning. /var/work/02/critical_image.json " {
  echo '1'>>/var/work/tests/result/all
  trivy image --format cyclonedx --output /tmp/critical_image.json  nginx:1.23-bullseye-perl
  diff <(jq 'walk(if type == "object" then del(.serialNumber, .timestamp, .["bom-ref"], .["ref"]) elif type == "string" and test("^[a-f0-9-]{36}$") then empty else . end)' /tmp/critical_image.json) \
     <(jq 'walk(if type == "object" then del(.serialNumber, .timestamp, .["bom-ref"], .["ref"]) elif type == "string" and test("^[a-f0-9-]{36}$") then empty else . end)' /var/work/02/critical_image.json)

  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "2.2  Image Vulnerability Scanning. /var/work/02/kube_scheduler_sbom.json " {
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

@test "2.3  Image Vulnerability Scanning. /var/work/02/result_sbom.json " {
  echo '1'>>/var/work/tests/result/all
   trivy sbom --format json --output /tmp/result_sbom.json /var/work/02/check_sbom.json
   diff <(jq --sort-keys 'del(.CreatedAt?)' /tmp/result_sbom.json) \
     <(jq --sort-keys 'del(.CreatedAt?)' /var/work/02/result_sbom.json)
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}



#  all =6 , task =2


# task 3
@test "3.1 Enable audit log. cluster are available " {
  echo '1'>>/var/work/tests/result/all
  kubectl get  ns   --context cluster2-admin@cluster2
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "3.2 Enable audit log. check secrets in log " {
  echo '3'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster2-admin@cluster2  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo chmod +r /var/logs/kubernetes-api.log ;cat /var/logs/kubernetes-api.log | grep 'secrets' | grep 'Metadata'| grep 'prod' "
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "3.3 Enable audit log. check configmap in log " {
  echo '3'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster2-admin@cluster2  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo chmod +r /var/logs/kubernetes-api.log ;cat /var/logs/kubernetes-api.log | grep 'configmap' | grep 'RequestResponse'| grep 'billing'"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
# all = 13  , task =7

#task 4

@test "4.1 CIS Benchmark. check 1.2.15  " {
  echo '.75'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster3-admin@cluster3  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo kube-bench | grep 1.2.15  | grep PASS"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.75'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "4.2 CIS Benchmark. check 1.3.2 " {
  echo '.75'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster3-admin@cluster3  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo kube-bench | grep 1.3.2 | grep PASS"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.75'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "4.3 CIS Benchmark. check 1.4.1 " {
  echo '.75'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster3-admin@cluster3  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo kube-bench | grep 1.4.1 | grep PASS"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.75'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "4.4 CIS Benchmark. check 4.2.6 " {
  echo '.75'>>/var/work/tests/result/all
  worker_node=$(kubectl get no -l work_type=worker --context cluster3-admin@cluster3  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $worker_node "sudo kube-bench | grep 4.2.6 | grep PASS"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.75'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# all = 16  , task =3

#task 5


@test "5.1  Secrets . /var/work/tests/artifacts/5/user  " {
  echo '.5'>>/var/work/tests/result/all
  cat /var/work/tests/artifacts/5/user | grep 'ad-admin'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "5.2  Secrets . /var/work/tests/artifacts/5/password  " {
  echo '.5'>>/var/work/tests/result/all
  cat /var/work/tests/artifacts/5/password | grep 'Pa1636worD'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "5.5  Secrets . secret file user in /mnt/secret " {
  echo '.5'>>/var/work/tests/result/all
  kubectl exec db-admin  -n team-5 --context cluster6-admin@cluster6 -- sh -c 'cat /mnt/secret/password | grep 'yyyy' '
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "5.6  Secrets . secret file user in /mnt/user " {
  echo '.5'>>/var/work/tests/result/all
  kubectl exec db-admin  -n team-5 --context cluster6-admin@cluster6 -- sh -c 'cat /mnt/secret/user | grep 'xxx' '
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# all = 18  , task =2

@test "6.1 set tls version  and  allowed ciphers.etcd cipher " {
  echo '2'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster4-admin@cluster4  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo cat   /etc/kubernetes/manifests/etcd.yaml | grep 'cipher-suites' | grep 'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "6.2 set tls version  and  allowed ciphers.kube-api cipher " {
  echo '2'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster4-admin@cluster4  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo cat  /etc/kubernetes/manifests/kube-apiserver.yaml |  grep 'tls-cipher-suites' | grep 'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "6.3 set tls version  and  allowed ciphers.kube-api tls version " {
  echo '2'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster4-admin@cluster4  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo cat  /etc/kubernetes/manifests/kube-apiserver.yaml |grep 'tls-min-version' | grep 'VersionTLS13'"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# all = 24  , task =6



@test "7.1 encrypt  secrets in  ETCD. kube-api encrypt config " {
  echo '1'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster5-admin@cluster5  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo cat  /etc/kubernetes/manifests/kube-apiserver.yaml |grep 'encryption-provider-config' | grep 'etc/kubernetes/enc/enc.yaml'"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "7.2 encrypt  secrets in  ETCD. cluster are available " {
  echo '.5'>>/var/work/tests/result/all
  kubectl get  ns   --context cluster5-admin@cluster5
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "7.3 encrypt  secrets in  ETCD. check encrypt  config [aescbc] " {
  echo '.5'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster5-admin@cluster5  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo cat  /etc/kubernetes/enc/enc.yaml |grep 'aescbc' "
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


@test "7.4 encrypt  secrets in  ETCD. check encrypt  config [key1] " {
  echo '.5'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster5-admin@cluster5  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo cat  /etc/kubernetes/enc/enc.yaml  | grep 'MTIzNDU2Nzg5MDEyMzQ1Ng==' "
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}



@test "7.5 encrypt  secrets in  ETCD. check encrypt  config [resources] " {
  echo '.5'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster5-admin@cluster5  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo cat  /etc/kubernetes/enc/enc.yaml |grep 'secret'  "
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "7.6 encrypt  secrets in  ETCD. check stage secret in  NS = stage " {
  echo '2'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster5-admin@cluster5  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo etcd_read 'stage' 'stage' " | grep 'aescbc'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


@test "7.7 encrypt  secrets in  ETCD. check secret in prod " {
  echo '1'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster5-admin@cluster5  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo etcd_read 'prod' 'test-secret' " | grep 'aescbc'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}





# all = 30  , task =6


@test "8.1 Network policy. can connect from prod NS to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec prod-pod -n prod --context cluster6-admin@cluster6 -- sh -c ' curl mysql.prod-db.svc --connect-timeout 1 -s ' | grep 'mysql'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "8.2 Network policy. can  connect from stage NS  and  label: role=db-connect  to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec db-connect-stage-pod -n stage --context cluster6-admin@cluster6 -- sh -c ' curl mysql.prod-db.svc --connect-timeout 1 -s ' | grep 'mysql'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "8.3 Network policy. can connect from any Namespaces and have label: role=db-external-connect  to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec all-pod-db-external -n user-client --context cluster6-admin@cluster6 -- sh -c ' curl mysql.prod-db.svc --connect-timeout 1 -s ' | grep 'mysql'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "8.4 Network policy. can't connect from stage NameSpace all pod   to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  set +e
  kubectl exec all-stage-pod -n stage  --context cluster6-admin@cluster6 -- sh -c ' curl mysql.prod-db.svc --connect-timeout 1 -s '
  result=$?
  set -e
  if (( $result > 0 )); then
   echo '1'>>/var/work/tests/result/ok
  fi
  (( $result > 0 ))
}

@test "8.5 Network policy. can't connect all   pod   to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  set +e
  kubectl exec all-pod -n user-client   --context cluster6-admin@cluster6 -- sh -c ' curl mysql.prod-db.svc --connect-timeout 1 -s '
  result=$?
  set -e
  if (( $result > 0 )); then
   echo '1'>>/var/work/tests/result/ok
  fi
   (( $result > 0 ))
}

@test "8.6 Network policy. can connect from all    pod   to google.com  " {
  echo '1'>>/var/work/tests/result/all
  set +e && kubectl exec all-pod -n user-client   --context cluster6-admin@cluster6 -- sh -c ' curl https://google.com --connect-timeout 1 -s '
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# all = 36  , task =6

@test "9.1 AppArmor. check installed appArmor profile " {
  echo '1'>>/var/work/tests/result/all
  worker_node=$(kubectl get no -l work_type=worker --context cluster6-admin@cluster6  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $worker_node "sudo apparmor_status | grep very-secure"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "9.2 AppArmor. check check pod log " {
  echo '2'>>/var/work/tests/result/all
  cat /var/work/tests/artifacts/9/log | grep 'Permission denied'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# all = 39  , task =3

@test "10.1 Deployment  security . check prevent escalation  " {
  echo '1'>>/var/work/tests/result/all
  kubectl  get deployment secure -n secure --context cluster6-admin@cluster6  -o yaml  | grep allowPrivilegeEscalation | grep false |grep -v '{}'| wc -l  | grep 3
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


@test "10.2 Deployment  security . Read only root file system c1  " {
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

@test "10.3 Deployment  security . Read only root file system c2  " {
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

@test "10.4 Deployment  security . Read only root file system c3  " {
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

@test "10.5 Deployment  security . user_id,  c1  " {
  echo '.5'>>/var/work/tests/result/all
  pod=$(kubectl  get po  -n secure --context cluster6-admin@cluster6 -o jsonpath='{.items..metadata.name}')
  kubectl  exec $pod  -n secure --context cluster6-admin@cluster6  -c c1 -- sh -c 'id ' | grep 3000
  result=$?
   if [[ "$result" == "0" ]]; then
   echo '.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "10.6 Deployment  security . user_id,  c2  " {
  echo '1'>>/var/work/tests/result/all
  pod=$(kubectl  get po  -n secure --context cluster6-admin@cluster6 -o jsonpath='{.items..metadata.name}')
  kubectl  exec $pod  -n secure --context cluster6-admin@cluster6  -c c2 -- sh -c 'id ' | grep 3000
  result=$?
   if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
@test "10.7 Deployment  security . user_id,  c3  " {
  echo '1'>>/var/work/tests/result/all
  pod=$(kubectl  get po  -n secure --context cluster6-admin@cluster6 -o jsonpath='{.items..metadata.name}')
  kubectl  exec $pod  -n secure --context cluster6-admin@cluster6  -c c3 -- sh -c 'id ' | grep 3000
  result=$?
   if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "10.8 Deployment  security . allow wread to /tmp/  container c1 " {
  echo '1'>>/var/work/tests/result/all
  pod=$(kubectl  get po  -n secure --context cluster6-admin@cluster6 -o jsonpath='{.items..metadata.name}')
  kubectl  exec $pod  -n secure --context cluster6-admin@cluster6  -c c1 -- sh -c 'echo "test">/tmp/test '
  result=$?
   if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# all = 45  , task =6



@test "11.1 RBAC. NS=rbac-1,resource = pods , verb=delete " {
  echo '1'>>/var/work/tests/result/all
  set +e
  result=$(kubectl auth can-i delete   pods -n rbac-1 --as=system:serviceaccount:rbac-1:dev --context cluster6-admin@cluster6)
  set -e
  if [[ "$result" == "no" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "no" ]
}


@test "11.2 RBAC. NS=rbac-1,resource = pods , verb=watch " {
  echo '1'>>/var/work/tests/result/all
  set +e
  result=$(kubectl auth can-i watch   pods -n rbac-1 --as=system:serviceaccount:rbac-1:dev --context cluster6-admin@cluster6)
  set -e
  if [[ "$result" == "yes" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "yes" ]
}


@test "11.3 RBAC. NS=rbac-2,resource = configmaps , verb=get " {
  echo '1'>>/var/work/tests/result/all
  set +e
  result=$(kubectl auth can-i get  configmaps -n rbac-2 --as=system:serviceaccount:rbac-1:dev --context cluster6-admin@cluster6)
  set -e
  if [[ "$result" == "yes" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "yes" ]
}

@test "11.4 RBAC. NS=rbac-2,resource = configmaps , verb=list " {
  echo '1'>>/var/work/tests/result/all
  set +e
  result=$(kubectl auth can-i list  configmaps -n rbac-2 --as=system:serviceaccount:rbac-1:dev --context cluster6-admin@cluster6)
  set -e
  if [[ "$result" == "yes" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "yes" ]
}

@test "11.5 RBAC. NS=rbac-1 pod serviceAccount = dev  " {
  echo '1'>>/var/work/tests/result/all
  kubectl get po dev-rbac  --context cluster6-admin@cluster6  -n rbac-1  -o yaml  | grep serviceAccount: | grep dev
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


@test "11.6 RBAC. NS=rbac-1 pod   get configmap  map from  rbac-2  " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec  dev-rbac  --context cluster6-admin@cluster6  -n rbac-1   -- sh -c 'export NS_CONFIGMAP=rbac-2; export CONFIGMAP=db-config;get_secret.sh configmap ' | grep aaa | grep bbb
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# all = 51  , task =6


@test "12.1 falco log" {
  echo '5'>>/var/work/tests/result/all
  cat /var/work/tests/artifacts/12/log |  grep '/etc/shadow ' | grep 'ns=default' |  grep 'Warning read ' |  grep ' pod_name=deployment1' |  grep 'user_name=root' | grep 'container_image=docker.io/viktoruj/cks-lab:cks_mock2_12_app1'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "12.2 scale deployment to 0 replicas" {
  echo '1'>>/var/work/tests/result/all
  result=$( kubectl get deployments.apps deployment1 -o jsonpath='{.spec.replicas}' --context cluster7-admin@cluster7)
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}



# all = 57  , task =6

@test "13.1 image policy webhook . deny creating pod with latest tag" {
  echo '5'>>/var/work/tests/result/all
  pod_postfix=$(date +%s)
  set +e
  kubectl run  test-bats-latest-$pod_postfix --image=inginx    --context cluster8-admin@cluster8
  result=$?
  set -e
  if (( $result > 0 )); then
   echo '5'>>/var/work/tests/result/ok
  fi
  (( $result > 0 ))
}

@test "13.2 image policy webhook . allow creating pod with specific  tag" {
  echo '1'>>/var/work/tests/result/all
  pod_postfix=$(date +%s)
  set +e
  kubectl run test-bats-tag-$pod_postfix --image=inginx:alpine3.17    --context cluster8-admin@cluster8
  result=$?
  set -e
  if [ "$result" == "0" ]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# all = 63  , task =6

#  podman  run -d --name  cks-14   cks:14

@test "14 fix Dockerfile " {
  echo '4'>>/var/work/tests/result/all
  podman  run -d --name  cks-14   cks:14
  sleep 2
  podman logs cks-14 | grep myuser
  result=$?
  podman stop cks-14
  podman rm  cks-14
  if [ "$result" == "0" ]; then
   echo '4'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "15 Pod Security Standard" {
  echo '6'>>/var/work/tests/result/all
  cat /var/work/tests/artifacts/15/logs | grep FailedCreate | grep forbidden
  result=$?
  set -e
  if  [ "$result" == "0" ]; then
   echo '6'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# 16

@test "16.1 check private api from finance namespace  " {
  echo '1'>>/var/work/tests/result/all
  kubectl  exec  -n finance finance --context cluster11-admin@cluster11  --  curl http://portal.production/private/api123 --connect-timeout 1 | grep 'http://portal.production/private/api123'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "16.2 check public api from finance namespace  " {
  echo '1'>>/var/work/tests/result/all
  kubectl  exec  -n finance finance   --context cluster11-admin@cluster11 --  curl http://portal.production/public/api123  --connect-timeout 1 | grep 'http://portal.production/public/api123'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "16.3 check private api from external namespace  " {
  echo '1'>>/var/work/tests/result/all
  kubectl  exec  -n external external  --context cluster11-admin@cluster11 --  curl http://portal.production/private/api123   --connect-timeout 1 | grep 'Access denied'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "16.4 check public api from external namespace  " {
  echo '1'>>/var/work/tests/result/all
  kubectl  exec  -n external external  --context cluster11-admin@cluster11 --  curl http://portal.production/public/api123  --connect-timeout 1 | grep 'http://portal.production/public/api123'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


@test "17 Open Policy Agent" {
  echo '6'>>/var/work/tests/result/all
  set +e
  kubectl  delete po test --force
  kubectl run test --image very-bad-registry.com/image --context cluster9-admin@cluster9 2>&1 | grep "not trusted image"| grep 'k8strustedimages'
  result=$?
  set -e
  if  [ "$result" == "0" ]; then
   echo '6'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "18.1 seccomp . profile name   " {
  echo '2'>>/var/work/tests/result/all
  result=$(kubectl get po seccomp  --context cluster10-admin@cluster10  -o jsonpath='{.spec.securityContext.seccompProfile.localhostProfile}')
  if [[ "$result" == "profile-nginx.json" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "profile-nginx.json" ]
}

@test "18.2 seccomp . profile type   " {
  echo '2'>>/var/work/tests/result/all
  result=$(kubectl get po seccomp  --context cluster10-admin@cluster10  -o jsonpath='{.spec.securityContext.seccompProfile.type}')
  if [[ "$result" == "Localhost" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "Localhost" ]
}

@test "18.3 seccomp . pod status = Running   " {
  echo '2'>>/var/work/tests/result/all
  kubectl get po seccomp  --context cluster10-admin@cluster10 | grep seccomp  | grep 'Running'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "19 Update the existing Ingress using the provided certificate. " {
  echo '4'>>/var/work/tests/result/all
  curl https://cks.local:31139 -kv 2>&1  | grep 'CN=cks.local'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '4'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "20.1  disable sa secret auto-mount. " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  get sa team20   -n team-20  -o jsonpath='{.automountServiceAccountToken}'  --context cluster6-admin@cluster6)
  if [[ "$result" == "false" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "false" ]
}

@test "20.2 check mount secret " {
  echo '2'>>/var/work/tests/result/all
  pod=$(kubectl get  po  -n team-20    --context cluster6-admin@cluster6  -l app=team20 -o jsonpath={.items..metadata.name})
  kubectl exec $pod -ti -n  team-20    --context cluster6-admin@cluster6 -- bash -c ' cat /var/team20/secret/token'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
