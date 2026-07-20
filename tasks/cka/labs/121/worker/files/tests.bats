#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
SA="system:serviceaccount:rbac:app-sa"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. ServiceAccount app-sa exists in ns rbac" {
  echo '1' >> /var/work/tests/result/all
  sa=$(kubectl -n rbac get sa app-sa --context $CTX -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$sa" == "app-sa" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "sa app-sa not found"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. Role pod-reader (get/list/watch pods) in ns rbac" {
  echo '1' >> /var/work/tests/result/all
  res=$(kubectl -n rbac get role pod-reader --context $CTX -o jsonpath='{.rules[*].resources[*]}' 2>/dev/null)
  verbs=$(kubectl -n rbac get role pod-reader --context $CTX -o jsonpath='{.rules[*].verbs[*]}' 2>/dev/null)
  if echo "$res" | grep -qw pods && echo "$verbs" | grep -qw get && echo "$verbs" | grep -qw list && echo "$verbs" | grep -qw watch; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "pod-reader resources='$res' verbs='$verbs'"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. RoleBinding read-pods binds pod-reader to app-sa" {
  echo '1' >> /var/work/tests/result/all
  ref=$(kubectl -n rbac get rolebinding read-pods --context $CTX -o jsonpath='{.roleRef.name}' 2>/dev/null)
  subj=$(kubectl -n rbac get rolebinding read-pods --context $CTX -o jsonpath='{.subjects[*].name}' 2>/dev/null)
  if [[ "$ref" == "pod-reader" ]] && echo "$subj" | grep -qw app-sa; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "read-pods roleRef=$ref subjects='$subj'"; result=1; fi
  [ "$result" == "0" ]
}

@test "4. ClusterRole cr-viewer (get/list nodes)" {
  echo '1' >> /var/work/tests/result/all
  res=$(kubectl get clusterrole cr-viewer --context $CTX -o jsonpath='{.rules[*].resources[*]}' 2>/dev/null)
  verbs=$(kubectl get clusterrole cr-viewer --context $CTX -o jsonpath='{.rules[*].verbs[*]}' 2>/dev/null)
  if echo "$res" | grep -qw nodes && echo "$verbs" | grep -qw get && echo "$verbs" | grep -qw list; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "cr-viewer resources='$res' verbs='$verbs'"; result=1; fi
  [ "$result" == "0" ]
}

@test "5. ClusterRoleBinding crb-viewer binds cr-viewer to app-sa" {
  echo '1' >> /var/work/tests/result/all
  ref=$(kubectl get clusterrolebinding crb-viewer --context $CTX -o jsonpath='{.roleRef.name}' 2>/dev/null)
  sname=$(kubectl get clusterrolebinding crb-viewer --context $CTX -o jsonpath='{.subjects[*].name}' 2>/dev/null)
  sns=$(kubectl get clusterrolebinding crb-viewer --context $CTX -o jsonpath='{.subjects[*].namespace}' 2>/dev/null)
  if [[ "$ref" == "cr-viewer" ]] && echo "$sname" | grep -qw app-sa && echo "$sns" | grep -qw rbac; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "crb-viewer roleRef=$ref subject=$sname ns=$sns"; result=1; fi
  [ "$result" == "0" ]
}

@test "6. Effective permissions of app-sa are correct" {
  echo '1' >> /var/work/tests/result/all
  can_pods=$(kubectl auth can-i get pods -n rbac --as=$SA --context $CTX 2>/dev/null)
  can_nodes=$(kubectl auth can-i get nodes --as=$SA --context $CTX 2>/dev/null)
  cannot_del=$(kubectl auth can-i delete pods -n rbac --as=$SA --context $CTX 2>/dev/null)
  if [[ "$can_pods" == "yes" ]] && [[ "$can_nodes" == "yes" ]] && [[ "$cannot_del" == "no" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "can-i get pods=$can_pods, get nodes=$can_nodes, delete pods=$cannot_del"; result=1; fi
  [ "$result" == "0" ]
}
