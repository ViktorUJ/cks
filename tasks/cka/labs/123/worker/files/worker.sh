#!/bin/bash
echo " *** worker pc cka lab 123 k8s-1"
export KUBECONFIG=/root/.kube/config

echo "Waiting for the API server to answer..."
while true; do
    if kubectl get no --no-headers 2>/dev/null | grep -q .; then
        echo "API is reachable (nodes may be NotReady until CNI is installed)."
        break
    fi
    sleep 5
done

mkdir -p /home/ubuntu/answers
chown -R ubuntu:ubuntu /home/ubuntu/answers
