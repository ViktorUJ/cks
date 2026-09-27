#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** worker node bootstrap: CKS lab 103 (CIS Benchmark / kube-bench)"
until kubectl get node "$(hostname)" >/dev/null 2>&1; do sleep 5; done

# kubeadm's default KubeletConfiguration does not set protectKernelDefaults at all (it is
# absent, which is the same as the insecure "false" default) - this is the intentional
# starting vulnerability for task 10 (CIS 4.2.6, kube-bench "node" target). No action needed
# here to create it; the point of the task is to DISCOVER this via kube-bench, not to have
# it planted explicitly like the file-permission fixtures in tasks 7/8.
#
# kube-bench itself is intentionally NOT pre-installed here: exactly like task 1's control-
# plane report (the student copies the pinned release there from the worker/bastion machine),
# installing it on THIS node is part of task 10's own solution steps ("CIS Benchmark is
# installed on nodes" is graded work, not bootstrap plumbing).

echo "*** worker node starting Kubernetes version:"
kubelet --version
kubectl get node "$(hostname)" -o wide

echo "*** worker node bootstrap for lab 103 is complete"
