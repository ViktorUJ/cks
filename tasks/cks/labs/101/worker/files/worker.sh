#!/bin/bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
IMDS_URL=http://169.254.169.254/

echo "*** worker pc cks lab 101 EC2 IMDS runtime"
echo "Waiting for at least one node to be available..."
while ! kubectl get nodes --no-headers 2>/dev/null | grep -q .; do
  sleep 5
done

echo "Lab 101 uses real EC2 IMDS at $IMDS_URL."
echo "No additional HTTP endpoints are installed."
