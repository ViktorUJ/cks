#!/bin/bash
echo " *** master node ica lab-35 k8s-1 (multicluster mesh — cluster1)"
export KUBECONFIG=/root/.kube/config

# Preparation only creates a BARE cluster — nothing (Istio, CA, apps) is
# installed here. Installing istioctl/Istio, the shared CA, the east-west
# gateway, cross-cluster discovery and the sample apps is the student's task
# (see README.MD). We only untaint the control-plane so a single-node cluster
# can schedule the workloads the student will deploy.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true

echo "*** cluster1 ready (bare)" > /tmp/master_ready
