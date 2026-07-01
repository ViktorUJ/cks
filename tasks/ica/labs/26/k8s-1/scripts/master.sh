#!/bin/bash
echo " *** master node ica lab-26 k8s-1 (cert-manager + istio-csr)"
export KUBECONFIG=/root/.kube/config

# Installation of metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
-p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]]'

# Untaint master node so Istio and workloads can be scheduled
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-

# Tools: helm + istioctl
curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod +x /tmp/get_helm.sh
/tmp/get_helm.sh

version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/

# 1) cert-manager
helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --namespace cert-manager --create-namespace --set crds.enabled=true --wait

kubectl create namespace istio-system

# 2) A self-signed root CA + a CA Issuer named istio-ca (the mesh CA that
#    cert-manager will use to sign istiod and workload certificates).
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: selfsigned
  namespace: istio-system
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: istio-ca
  namespace: istio-system
spec:
  isCA: true
  duration: 87600h
  secretName: istio-ca
  commonName: istio-ca
  subject:
    organizations:
      - cluster.local
      - cert-manager
  issuerRef:
    name: selfsigned
    kind: Issuer
    group: cert-manager.io
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: istio-ca
  namespace: istio-system
spec:
  ca:
    secretName: istio-ca
EOF

# 3) Wait for the root CA secret, export it and store as istio-root-ca for istio-csr.
echo "Waiting for the istio-ca secret to be issued..."
until kubectl get -n istio-system secret istio-ca >/dev/null 2>&1; do sleep 3; done
kubectl get -n istio-system secret istio-ca -ogo-template='{{index .data "tls.crt"}}' | base64 -d > /tmp/ca.pem
kubectl create secret generic -n cert-manager istio-root-ca --from-file=ca.pem=/tmp/ca.pem

# 4) istio-csr: the cert-manager agent that serves the Istio CA gRPC API.
helm upgrade cert-manager-istio-csr oci://quay.io/jetstack/charts/cert-manager-istio-csr \
  --install --namespace cert-manager --wait \
  --set "app.tls.rootCAFile=/var/run/secrets/istio-csr/ca.pem" \
  --set "volumeMounts[0].name=root-ca" \
  --set "volumeMounts[0].mountPath=/var/run/secrets/istio-csr" \
  --set "volumes[0].name=root-ca" \
  --set "volumes[0].secret.secretName=istio-root-ca"

# 5) Install Istio pointed at istio-csr, with istiod's built-in CA disabled.
cat <<EOF > /root/istio-csr-install.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  namespace: istio-system
spec:
  profile: default
  meshConfig:
    trustDomain: cluster.local
  values:
    global:
      caAddress: cert-manager-istio-csr.cert-manager.svc:443
  components:
    pilot:
      k8s:
        env:
        - name: ENABLE_CA_SERVER
          value: "false"
EOF
istioctl install -f /root/istio-csr-install.yaml -y

# NOTE: deploying a workload and verifying that its certificate is issued by
# cert-manager (through istio-csr) is the task of this lab — see README.MD.
