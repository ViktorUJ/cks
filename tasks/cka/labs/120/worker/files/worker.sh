#!/bin/bash
echo " *** worker pc cka lab 120 k8s-1"
export KUBECONFIG=/root/.kube/config

echo "Waiting for at least one node to be available..."
while true; do
    node_count=$(kubectl get no --no-headers 2>/dev/null | wc -l)
    if [ "$node_count" -gt 0 ]; then
        echo "Found $node_count node(s), proceeding..."
        break
    fi
    sleep 5
done

mkdir -p /home/ubuntu/answers
chown -R ubuntu:ubuntu /home/ubuntu/answers
