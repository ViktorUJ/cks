#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
ARTIFACTS="/var/work/tests/artifacts"
TARGET_MINOR="1.36"
START_MINOR="1.35"

# Node objects are named after the instance hostnames (ip-10-...), not after the ssh aliases
# k8s113_controlPlane_1 / k8s113_node_worker1, so resolve them by role.
cp_node() { kubectl get nodes --context "$CTX" -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true; }
worker_node() { kubectl get nodes --context "$CTX" -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true; }

monitor_value() {
  local key="$1" state="$2" result
  [[ -r "$state" ]] || { printf 'missing'; return; }
  result=$(sed -n "s/^${key}=\([0-9][0-9]*\)$/\1/p" "$state" | tail -n 1)
  [[ "$result" =~ ^[0-9]+$ ]] || { printf 'missing'; return; }
  printf '%s' "$result"
}

node_packages_and_repo_ok() {
  local host="$1"
  timeout 20s ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" bash -s <<'REMOTE' >/dev/null 2>&1
set -euo pipefail
grep -Eq '^[[:space:]]*deb[[:space:]]+\[signed-by=[^]]+\][[:space:]]+https://pkgs\.k8s\.io/core:/stable:/v1\.36/deb/[[:space:]]+/[[:space:]]*$' /etc/apt/sources.list.d/kubernetes.list
for package in kubeadm kubelet kubectl; do
  version=$(dpkg-query -W -f='${Version}' "$package")
  [[ "$version" == 1.36.* ]] || exit 1
done
REMOTE
}

record_result() {
  echo '1' >> /var/work/tests/result/all
  if [[ "$1" -eq 0 ]]; then echo '1' >> /var/work/tests/result/ok; fi
  return "$1"
}

@test "0 Init" {
  : > /var/work/tests/result/all
  : > /var/work/tests/result/ok
}

@test "1. control-plane kubeadm/kubelet/kubectl upgraded to the target minor and node is Ready" {
  kubeadm_ver=$(ssh -o BatchMode=yes k8s113_controlPlane_1 'kubeadm version -o short' 2>/dev/null || true)
  kubelet_ver=$(ssh -o BatchMode=yes k8s113_controlPlane_1 'kubelet --version' 2>/dev/null || true)
  api_server_ver=$(kubectl version --context "$CTX" -o json 2>/dev/null | jq -r '.serverVersion.gitVersion // empty')
  cp_kubectl_ver=$(ssh -o BatchMode=yes k8s113_controlPlane_1 'kubectl version --client -o json' 2>/dev/null | jq -r '.clientVersion.gitVersion // empty')
  node_status=$(kubectl get node "$(cp_node)" --context "$CTX" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  evidence="$ARTIFACTS/1/kubeadm-upgrade-apply.txt"
  if [[ "$kubeadm_ver" == v${TARGET_MINOR}.* && "$kubelet_ver" == *"v${TARGET_MINOR}."* \
        && "$api_server_ver" == v${TARGET_MINOR}.* && "$cp_kubectl_ver" == v${TARGET_MINOR}.* \
        && "$node_status" == "True" ]] \
     && node_packages_and_repo_ok k8s113_controlPlane_1 \
     && [[ -s "$evidence" ]] && grep -qi 'SUCCESS' "$evidence" && grep -q "v${TARGET_MINOR}" "$evidence"; then
    result=0
  else
    if [[ "$kubeadm_ver" != v${TARGET_MINOR}.* ]]; then
      echo "HINT: 'kubeadm version' on the control-plane must report v${TARGET_MINOR}.x - upgrade the kubeadm package via the v${TARGET_MINOR} pkgs.k8s.io repo before running 'kubeadm upgrade apply'."
    elif [[ "$api_server_ver" != v${TARGET_MINOR}.* ]]; then
      echo "HINT: kube-apiserver (checked via 'kubectl version') is not yet on v${TARGET_MINOR}.x - run 'kubeadm upgrade apply vX.Y.Z' on the control-plane after upgrading the kubeadm package."
    elif [[ "$cp_kubectl_ver" != v${TARGET_MINOR}.* ]]; then
      echo "HINT: the local 'kubectl' client package on the control-plane is not on v${TARGET_MINOR}.x yet - upgrade the kubectl package alongside kubelet."
    elif [[ "$kubelet_ver" != *"v${TARGET_MINOR}."* ]]; then
      echo "HINT: kubelet on the control-plane is not on v${TARGET_MINOR}.x yet - after 'kubeadm upgrade apply' succeeds, drain the node, upgrade the kubelet/kubectl packages, and restart kubelet."
    elif [[ "$node_status" != "True" ]]; then
      echo "HINT: control-plane node is not Ready - did you uncordon it after upgrading kubelet? Check 'kubectl get nodes'."
    else
      echo "HINT: $evidence is missing or doesn't contain the real 'kubeadm upgrade apply' output with 'SUCCESS' and the target version - save the actual command output, not a paraphrase."
    fi
    echo "kubeadm=${kubeadm_ver:-missing} kubelet=${kubelet_ver:-missing} api_server=${api_server_ver:-missing} kubectl=${cp_kubectl_ver:-missing} node_ready=${node_status:-missing}"
    result=1
  fi
  record_result "$result"
}

@test "2. worker node kubeadm/kubelet/kubectl upgraded to the target minor and node is Ready" {
  kubeadm_ver=$(ssh -o BatchMode=yes k8s113_node_worker1 'kubeadm version -o short' 2>/dev/null || true)
  kubelet_ver=$(ssh -o BatchMode=yes k8s113_node_worker1 'kubelet --version' 2>/dev/null || true)
  worker_kubectl_ver=$(ssh -o BatchMode=yes k8s113_node_worker1 'kubectl version --client -o json' 2>/dev/null | jq -r '.clientVersion.gitVersion // empty')
  node_status=$(kubectl get node "$(worker_node)" --context "$CTX" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  node_version=$(kubectl get node "$(worker_node)" --context "$CTX" -o jsonpath='{.status.nodeInfo.kubeletVersion}' 2>/dev/null || true)
  evidence="$ARTIFACTS/2/kubeadm-upgrade-node.txt"
  if [[ "$kubeadm_ver" == v${TARGET_MINOR}.* && "$kubelet_ver" == *"v${TARGET_MINOR}."* \
        && "$worker_kubectl_ver" == v${TARGET_MINOR}.* \
        && "$node_version" == v${TARGET_MINOR}.* && "$node_status" == "True" ]] \
     && node_packages_and_repo_ok k8s113_node_worker1 \
     && [[ -s "$evidence" ]]; then
    result=0
  else
    if [[ "$kubeadm_ver" != v${TARGET_MINOR}.* ]]; then
      echo "HINT: 'kubeadm version' on the worker node must report v${TARGET_MINOR}.x - upgrade the kubeadm package via the v${TARGET_MINOR} pkgs.k8s.io repo, then run 'kubeadm upgrade node' (not 'apply' - that's control-plane only)."
    elif [[ "$worker_kubectl_ver" != v${TARGET_MINOR}.* ]]; then
      echo "HINT: the local 'kubectl' client package on the worker node is not on v${TARGET_MINOR}.x yet - upgrade the kubectl package alongside kubelet."
    elif [[ "$node_version" != v${TARGET_MINOR}.* ]]; then
      echo "HINT: 'kubectl get nodes' still reports the worker's the old kubelet version - after 'kubeadm upgrade node' succeeds on the worker, drain it, upgrade kubelet/kubectl packages, restart kubelet."
    elif [[ "$node_status" != "True" ]]; then
      echo "HINT: worker node is not Ready - did you uncordon it after the kubelet restart? Check 'kubectl get nodes'."
    else
      echo "HINT: $evidence is missing or empty - save the real 'kubeadm upgrade node' command output from the worker as evidence."
    fi
    echo "kubeadm=${kubeadm_ver:-missing} kubelet=${kubelet_ver:-missing} kubectl=${worker_kubectl_ver:-missing} node_version=${node_version:-missing} node_ready=${node_status:-missing}"
    result=1
  fi
  record_result "$result"
}

@test "3. control-plane was upgraded before the worker node (correct kubeadm upgrade order)" {
  monitor=/var/lib/cks-lab113-checker/upgrade-monitor.log
  state=/var/lib/cks-lab113-checker/order-state
  baseline_seen=$(monitor_value baseline_seen "$state")
  cp_done_seen=$(monitor_value cp_done_seen "$state")
  order_violation=$(monitor_value order_violation "$state")
  worker_target_seen=$(monitor_value worker_target_seen "$state")
  history_gap_seen=$(monitor_value history_gap_seen "$state")
  cp_done_at=$(monitor_value cp_done_at "$state")
  worker_target_at=$(monitor_value worker_target_at "$state")
  last_ts=$(monitor_value last_ts "$state")
  now=$(date +%s)

  if [[ "$baseline_seen" == 1 && "$cp_done_seen" == 1 &&
        "$order_violation" == 0 && "$worker_target_seen" == 1 &&
        "$history_gap_seen" == 0 && "$cp_done_at" =~ ^[0-9]+$ &&
        "$worker_target_at" =~ ^[0-9]+$ && "$last_ts" =~ ^[0-9]+$ ]] &&
     ((cp_done_at > 0 && worker_target_at > cp_done_at &&
       now >= last_ts && now - last_ts <= 60)) &&
     [[ -s "$monitor" ]]; then
    result=0
  else
    echo "HINT: the checker-owned monitor must record a 1.35 baseline, complete 1.36 control-plane readiness while the worker is still 1.35, and only then the worker target. Monitor state must survive restarts and sampling gaps must not exceed 60 s."
    echo "baseline=$baseline_seen cp_done=$cp_done_seen violation=$order_violation worker_target=$worker_target_seen gap=$history_gap_seen cp_done_at=$cp_done_at worker_target_at=$worker_target_at last_ts=$last_ts"
    result=1
  fi
  record_result "$result"
}

@test "4. canary workload in upgrade-113 remained Available throughout the upgrade (no unplanned downtime)" {
  checker_log=/var/lib/cks-lab113-checker/upgrade-monitor.log
  state=/var/lib/cks-lab113-checker/order-state
  student_evidence="$ARTIFACTS/4/canary-availability.log"
  deployment=$(kubectl get deployment canary -n upgrade-113 --context "$CTX" -o json 2>/dev/null || true)
  pdb=$(kubectl get pdb canary -n upgrade-113 --context "$CTX" -o json 2>/dev/null || true)
  workload_valid=false
  pdb_valid=false
  if printf '%s' "$deployment" | jq -e '
    .spec.replicas == 2 and .status.availableReplicas == 2 and
    .spec.selector.matchLabels == {"app":"canary"} and
    .spec.template.metadata.labels.app == "canary" and
    .spec.template.spec.automountServiceAccountToken == false and
    (.spec.template.spec.containers | length == 1) and
    .spec.template.spec.containers[0].name == "canary" and
    .spec.template.spec.containers[0].image == "registry.k8s.io/pause:3.9" and
    (.spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution | length == 1) and
    .spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey == "kubernetes.io/hostname" and
    .spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchLabels == {"app":"canary"} and
    (.spec.template.spec.readinessGates // [] | length == 0)
  ' >/dev/null 2>&1; then workload_valid=true; fi
  if printf '%s' "$pdb" | jq -e '
    .spec.minAvailable == 1 and .spec.selector == {"matchLabels":{"app":"canary"}}
  ' >/dev/null 2>&1; then pdb_valid=true; fi

  baseline=$(monitor_value baseline_seen "$state")
  outage=$(monitor_value canary_outage_seen "$state")
  unknown=$(monitor_value canary_unknown_seen "$state")
  gap=$(monitor_value history_gap_seen "$state")
  samples=$(monitor_value healthy_samples "$state")
  cp_done_at=$(monitor_value cp_done_at "$state")
  worker_target_at=$(monitor_value worker_target_at "$state")
  first_sample=0; last_sample=0; student_samples=0
  if [[ -s "$student_evidence" ]]; then
    read -r first_sample last_sample student_samples < <(
      awk '
        /^[0-9][0-9]* available=([0-9][0-9]*|api-unreachable)$/ {
          ts=$1+0; if (count == 0 || ts < first) first=ts;
          if (ts > last) last=ts;
          count++
        }
        END {printf "%d %d %d\n", first+0, last+0, count+0}
      ' "$student_evidence"
    )
  fi
  if [[ "$workload_valid" == true && "$pdb_valid" == true &&
        "$baseline" == 1 && "$outage" == 0 && "$unknown" == 0 &&
        "$gap" == 0 && "$samples" =~ ^[0-9]+$ &&
        "$cp_done_at" =~ ^[0-9]+$ && "$worker_target_at" =~ ^[0-9]+$ ]] &&
     ((samples >= 3 && student_samples >= 2 &&
       first_sample > 0 && first_sample <= cp_done_at &&
       last_sample >= worker_target_at && worker_target_at > cp_done_at)) &&
     [[ -s "$checker_log" ]]; then
    result=0
  else
    echo "HINT: preserve the exact canary Deployment and PDB, keep two Available replicas at the end, and collect valid checker-owned observations throughout both upgrades. SSH/CRI/API failures produce UNKNOWN, not a fabricated zero; unresolved evidence gaps are not a PASS. Student log must span the upgrade milestones."
    echo "deployment=$workload_valid pdb=$pdb_valid baseline=$baseline outage=$outage unknown=$unknown gap=$gap healthy_samples=$samples student_samples=$student_samples first=$first_sample cp_done_at=$cp_done_at worker_target_at=$worker_target_at last=$last_sample"
    result=1
  fi
  record_result "$result"
}

@test "5. no node is left in an old minor version or stuck cordoned" {
  cp_version=$(kubectl get node "$(cp_node)" --context "$CTX" -o jsonpath='{.status.nodeInfo.kubeletVersion}' 2>/dev/null || true)
  worker_version=$(kubectl get node "$(worker_node)" --context "$CTX" -o jsonpath='{.status.nodeInfo.kubeletVersion}' 2>/dev/null || true)
  cp_unschedulable=$(kubectl get node "$(cp_node)" --context "$CTX" -o jsonpath='{.spec.unschedulable}' 2>/dev/null || true)
  worker_unschedulable=$(kubectl get node "$(worker_node)" --context "$CTX" -o jsonpath='{.spec.unschedulable}' 2>/dev/null || true)
  if [[ "$cp_version" == v${TARGET_MINOR}.* && "$worker_version" == v${TARGET_MINOR}.* ]] \
     && [[ -z "$cp_unschedulable" || "$cp_unschedulable" == "false" ]] \
     && [[ -z "$worker_unschedulable" || "$worker_unschedulable" == "false" ]]; then
    result=0
  else
    if [[ "$cp_version" != v${TARGET_MINOR}.* || "$worker_version" != v${TARGET_MINOR}.* ]]; then
      echo "HINT: at least one node still reports an old kubelet version - both nodes must be fully upgraded to v${TARGET_MINOR}.x."
    else
      echo "HINT: at least one node is still cordoned (spec.unschedulable=true) - run 'kubectl uncordon <node>' after finishing its upgrade steps."
    fi
    echo "cp_version=${cp_version:-missing} worker_version=${worker_version:-missing} cp_unschedulable=${cp_unschedulable:-false} worker_unschedulable=${worker_unschedulable:-false}"
    result=1
  fi
  record_result "$result"
}
