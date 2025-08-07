#!/bin/bash
# generate_kubeconfig.sh

context="external-cluster"  # Change this  to external cluster context name
template_file="kubeconfig_template.yaml"
output_file="kubeconfig.yaml"

echo "Getting token from external cluster..."

TOKEN=$(kubectl get secret k8s-svc-sync-token -n k8s-sync --context $context -o jsonpath='{.data.token}' | base64 -d)

CA_DATA=$(kubectl get secret k8s-svc-sync-token -n k8s-sync --context $context -o jsonpath='{.data.ca\.crt}')

SERVER_URL=$(kubectl config view --minify --context $context -o jsonpath='{.clusters[0].cluster.server}')

echo "Token: $TOKEN"
echo "CA Data: $CA_DATA"
echo "Server URL: $SERVER_URL"
echo ""

# Check if template file exists
if [ ! -f "$template_file" ]; then
    echo "Error: Template file $template_file not found"
    exit 1
fi

echo "Generating kubeconfig from template..."

# Substitute variables in template and create new file
sed -e "s|\$TOKEN|$TOKEN|g" \
    -e "s|\$CA_DATA|$CA_DATA|g" \
    -e "s|\$SERVER|$SERVER_URL|g" \
    "$template_file" > "$output_file"

echo "Kubeconfig generated successfully: $output_file"