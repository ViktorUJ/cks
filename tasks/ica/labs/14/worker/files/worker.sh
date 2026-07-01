#!/bin/bash
echo " *** worker pc ica lab 14 k8s-1"
export KUBECONFIG=/root/.kube/config

# Wait until at least one node is available
echo "Waiting for at least one node to be available..."
while true; do
    node_count=$(kubectl get no --no-headers 2>/dev/null | wc -l)
    if [ "$node_count" -gt 0 ]; then
        echo "Found $node_count node(s), proceeding..."
        break
    fi
    echo "No nodes found yet, waiting..."
    sleep 5
done

# Node zone labels (topology.kubernetes.io/zone) are set at join time via
# node_labels (kubelet --node-labels) — see k8s-1/terragrunt.hcl.

address=$(kubectl get no -o json | jq -r '.items[].status.addresses[] | select(.type=="InternalIP") | .address' | head -1)
echo "$address myapp.local">>/etc/hosts
