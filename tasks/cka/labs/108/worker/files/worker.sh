#!/bin/bash
echo " *** worker pc cka lab 108 k8s-1"
export KUBECONFIG=/root/.kube/config

echo "Waiting for at least two nodes to be available..."
while true; do
    node_count=$(kubectl get no --no-headers 2>/dev/null | wc -l)
    if [ "$node_count" -ge 2 ]; then
        echo "Found $node_count node(s), proceeding..."
        break
    fi
    sleep 5
done
