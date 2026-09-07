#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
ARTIFACTS="/var/work/tests/artifacts"
TARGET_MINOR="1.36"
START_MINOR="1.35"

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
  kubectl_ver=$(kubectl version --context "$CTX" -o json 2>/dev/null | jq -r '.serverVersion.gitVersion // empty')
  node_status=$(kubectl get node k8s113_controlPlane_1 --context "$CTX" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  evidence="$ARTIFACTS/1/kubeadm-upgrade-apply.txt"
  if [[ "$kubeadm_ver" == v${TARGET_MINOR}.* && "$kubelet_ver" == *"v${TARGET_MINOR}."* && "$kubectl_ver" == v${TARGET_MINOR}.* \
        && "$node_status" == "True" ]] \
     && [[ -s "$evidence" ]] && grep -qi 'SUCCESS' "$evidence" && grep -q "v${TARGET_MINOR}" "$evidence"; then
    result=0
  else
    if [[ "$kubeadm_ver" != v${TARGET_MINOR}.* ]]; then
      echo "HINT: 'kubeadm version' on the control-plane must report v${TARGET_MINOR}.x - upgrade the kubeadm package via the v${TARGET_MINOR} pkgs.k8s.io repo before running 'kubeadm upgrade apply'."
    elif [[ "$kubectl_ver" != v${TARGET_MINOR}.* ]]; then
      echo "HINT: kube-apiserver (checked via 'kubectl version') is not yet on v${TARGET_MINOR}.x - run 'kubeadm upgrade apply vX.Y.Z' on the control-plane after upgrading the kubeadm package."
    elif [[ "$kubelet_ver" != *"v${TARGET_MINOR}."* ]]; then
      echo "HINT: kubelet on the control-plane is not on v${TARGET_MINOR}.x yet - after 'kubeadm upgrade apply' succeeds, drain the node, upgrade the kubelet/kubectl packages, and restart kubelet."
    elif [[ "$node_status" != "True" ]]; then
      echo "HINT: control-plane node is not Ready - did you uncordon it after upgrading kubelet? Check 'kubectl get node k8s113_controlPlane_1'."
    else
      echo "HINT: $evidence is missing or doesn't contain the real 'kubeadm upgrade apply' output with 'SUCCESS' and the target version - save the actual command output, not a paraphrase."
    fi
    echo "kubeadm=${kubeadm_ver:-missing} kubelet=${kubelet_ver:-missing} kubectl=${kubectl_ver:-missing} node_ready=${node_status:-missing}"
    result=1
  fi
  record_result "$result"
}

@test "2. worker node kubeadm/kubelet/kubectl upgraded to the target minor and node is Ready" {
  kubeadm_ver=$(ssh -o BatchMode=yes k8s113_node_worker1 'kubeadm version -o short' 2>/dev/null || true)
  kubelet_ver=$(ssh -o BatchMode=yes k8s113_node_worker1 'kubelet --version' 2>/dev/null || true)
  node_status=$(kubectl get node k8s113_node_worker1 --context "$CTX" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  node_version=$(kubectl get node k8s113_node_worker1 --context "$CTX" -o jsonpath='{.status.nodeInfo.kubeletVersion}' 2>/dev/null || true)
  evidence="$ARTIFACTS/2/kubeadm-upgrade-node.txt"
  if [[ "$kubeadm_ver" == v${TARGET_MINOR}.* && "$kubelet_ver" == *"v${TARGET_MINOR}."* \
        && "$node_version" == v${TARGET_MINOR}.* && "$node_status" == "True" ]] \
     && [[ -s "$evidence" ]]; then
    result=0
  else
    if [[ "$kubeadm_ver" != v${TARGET_MINOR}.* ]]; then
      echo "HINT: 'kubeadm version' on the worker node must report v${TARGET_MINOR}.x - upgrade the kubeadm package via the v${TARGET_MINOR} pkgs.k8s.io repo, then run 'kubeadm upgrade node' (not 'apply' - that's control-plane only)."
    elif [[ "$node_version" != v${TARGET_MINOR}.* ]]; then
      echo "HINT: 'kubectl get node k8s113_node_worker1' still reports the old kubelet version - after 'kubeadm upgrade node' succeeds on the worker, drain it, upgrade kubelet/kubectl packages, restart kubelet."
    elif [[ "$node_status" != "True" ]]; then
      echo "HINT: worker node is not Ready - did you uncordon it after the kubelet restart? Check 'kubectl get node k8s113_node_worker1'."
    else
      echo "HINT: $evidence is missing or empty - save the real 'kubeadm upgrade node' command output from the worker as evidence."
    fi
    echo "kubeadm=${kubeadm_ver:-missing} kubelet=${kubelet_ver:-missing} node_version=${node_version:-missing} node_ready=${node_status:-missing}"
    result=1
  fi
  record_result "$result"
}

@test "3. control-plane was upgraded before the worker node (correct kubeadm upgrade order)" {
  cp_log="$ARTIFACTS/1/kubeadm-upgrade-apply.txt"
  worker_log="$ARTIFACTS/2/kubeadm-upgrade-node.txt"
  if [[ -s "$cp_log" && -s "$worker_log" ]] \
     && [[ "$(stat -c %Y "$cp_log" 2>/dev/null || echo 0)" -le "$(stat -c %Y "$worker_log" 2>/dev/null || echo 0)" ]]; then
    result=0
  else
    echo "HINT: evidence file timestamps suggest the worker was upgraded before (or without) the control-plane being fully upgraded first. kubeadm requires the control-plane to be fully upgraded first: 'kubeadm upgrade apply' on control-plane, then 'kubeadm upgrade node' on each worker."
    echo "cp_log_mtime=$(stat -c %Y "$cp_log" 2>/dev/null || echo missing) worker_log_mtime=$(stat -c %Y "$worker_log" 2>/dev/null || echo missing)"
    result=1
  fi
  record_result "$result"
}

@test "4. canary workload in upgrade-113 remained Available throughout the upgrade (no unplanned downtime)" {
  desired=$(kubectl get deployment canary -n upgrade-113 --context "$CTX" -o jsonpath='{.spec.replicas}' 2>/dev/null || true)
  available=$(kubectl get deployment canary -n upgrade-113 --context "$CTX" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)
  evidence="$ARTIFACTS/4/canary-availability.log"
  min_available_seen=$(grep -oE 'available=[0-9]+' "$evidence" 2>/dev/null | cut -d= -f2 | sort -n | head -1)
  if [[ "$desired" == "2" && "$available" == "2" ]] \
     && [[ -s "$evidence" ]] && [[ -n "$min_available_seen" ]] && [[ "$min_available_seen" -ge 1 ]]; then
    result=0
  else
    if [[ "$available" != "2" ]]; then
      echo "HINT: Deployment 'canary' in namespace 'upgrade-113' does not currently have 2 available replicas - the upgrade should not have taken this workload down; check 'kubectl get pods -n upgrade-113'."
    elif [[ -z "$min_available_seen" ]]; then
      echo "HINT: $evidence is missing or doesn't contain any 'available=N' lines - you must have been polling and logging deployment availability (e.g. via a loop with 'kubectl get deployment canary -n upgrade-113 -o jsonpath=...') DURING the drain/upgrade steps, not just checking it once at the end."
    else
      echo "HINT: The availability log shows at least one point where available replicas dropped below 1 (min_available_seen=$min_available_seen) - with 2 replicas spread appropriately and a proper rolling drain (one node at a time, PodDisruptionBudget-aware or at least sequential), the Deployment should never have zero available replicas."
    fi
    echo "desired=${desired:-missing} available=${available:-missing} min_available_seen=${min_available_seen:-missing}"
    result=1
  fi
  record_result "$result"
}

@test "5. no node is left in an old minor version or stuck cordoned" {
  cp_version=$(kubectl get node k8s113_controlPlane_1 --context "$CTX" -o jsonpath='{.status.nodeInfo.kubeletVersion}' 2>/dev/null || true)
  worker_version=$(kubectl get node k8s113_node_worker1 --context "$CTX" -o jsonpath='{.status.nodeInfo.kubeletVersion}' 2>/dev/null || true)
  cp_unschedulable=$(kubectl get node k8s113_controlPlane_1 --context "$CTX" -o jsonpath='{.spec.unschedulable}' 2>/dev/null || true)
  worker_unschedulable=$(kubectl get node k8s113_node_worker1 --context "$CTX" -o jsonpath='{.spec.unschedulable}' 2>/dev/null || true)
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
