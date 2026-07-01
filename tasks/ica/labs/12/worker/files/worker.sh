#!/bin/bash
echo " *** worker pc ica lab 12 k8s-1"
export KUBECONFIG=/root/.kube/config

# Install istioctl on the worker PC so the student can run the troubleshooting
# tools (istioctl analyze / proxy-status / proxy-config).
version=1.29.1
cd /tmp
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
mv /tmp/istio-$version/bin/istioctl /usr/local/bin/istioctl
chmod +x /usr/local/bin/istioctl

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
