#!/bin/bash
echo " *** master node ica lab-29 k8s-1 (Ingress TLS: MUTUAL + PASSTHROUGH)"
export KUBECONFIG=/root/.kube/config

# Installation of metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
-p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]]'

# Untaint master node so Istio and workloads can be scheduled
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-

version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/

# Install Istio; expose HTTPS on a fixed NodePort 32443.
cat <<EOF > /root/istio-install.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  components:
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
      k8s:
        service:
          type: NodePort
          ports:
          - port: 443
            targetPort: 8443
            nodePort: 32443
            name: https
EOF
istioctl install -f /root/istio-install.yaml -y
until kubectl get ns istio-system >/dev/null 2>&1; do sleep 2; done

# ---- Generate the PKI used by this lab ----
cd /tmp
# Root CA
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -subj "/O=CKS-Lab/CN=CKS-Lab-Root" -keyout ca.key -out ca.crt
# Gateway server cert for myapp.local (MUTUAL termination)
openssl req -new -nodes -newkey rsa:2048 -subj "/CN=myapp.local/O=app" -keyout server.key -out server.csr
openssl x509 -req -days 3650 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -extfile <(printf "subjectAltName=DNS:myapp.local")
# Client cert signed by the CA (used to authenticate to the MUTUAL gateway)
openssl req -new -nodes -newkey rsa:2048 -subj "/CN=client/O=client-org" -keyout client.key -out client.csr
openssl x509 -req -days 3650 -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt
# Backend cert for passthrough.local (backend terminates TLS itself)
openssl req -new -nodes -newkey rsa:2048 -subj "/CN=passthrough.local/O=backend" -keyout backend.key -out backend.csr
openssl x509 -req -days 3650 -in backend.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out backend.crt -extfile <(printf "subjectAltName=DNS:passthrough.local")

# Namespaces
kubectl create namespace app
kubectl label namespace app istio-injection=enabled --overwrite
kubectl create namespace backend

# Secrets
# MUTUAL gateway credential (server cert + key + CA to verify clients)
kubectl create -n istio-system secret generic myapp-credential \
  --from-file=tls.crt=server.crt --from-file=tls.key=server.key --from-file=ca.crt=ca.crt
# Client cert bundle (the test/student reads it to call the MUTUAL gateway)
kubectl create -n app secret generic client-certs \
  --from-file=client.crt=client.crt --from-file=client.key=client.key --from-file=ca.crt=ca.crt
# Backend TLS cert for the passthrough backend
kubectl create -n backend secret tls backend-tls --cert=backend.crt --key=backend.key

# Deploy the apps: ping-pong (MUTUAL target) and a TLS-only backend (passthrough).
# Building the Gateway (MUTUAL + PASSTHROUGH) and the routes is the task — see README.MD.
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/29/k8s-1/scripts/1.yaml
