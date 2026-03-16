#!/bin/bash
echo " *** worker pc ica lab 02 k8s-1"
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

address=$(kubectl get no -o json  | jq -r '.items[] | select(.kind == "Node") | .status.addresses[] | select(.type == "InternalIP") | .address')
echo "$address myapp.local">>/etc/hosts
