#!/bin/bash
echo " *** master node  mock-3  k8s-8"
#!/bin/bash
echo " *** master node  task 203"
kubectl taint nodes --all node-role.kubernetes.io/master- --kubeconfig=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane-  --kubeconfig=/root/.kube/config

export KUBECONFIG=/root/.kube/config


sudo apt update
sudo apt install golang-cfssl

#create CSR to send to KubeAPI
cat <<EOF | cfssl genkey - | cfssljson -bare server
{
  "hosts": [
    "image-bouncer-webhook",
    "image-bouncer-webhook.default.svc",
    "image-bouncer-webhook.default.svc.cluster.local",
    "192.168.56.10",
    "10.96.0.0"
  ],
  "CN": "system:node:image-bouncer-webhook.default.pod.cluster.local",
  "key": {
    "algo": "ecdsa",
    "size": 256
  },
  "names": [
    {
      "O": "system:nodes"
    }
  ]
}
EOF

#create csr request
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: image-bouncer-webhook.default
spec:
  request: $(cat server.csr | base64 | tr -d '\n')
  signerName: kubernetes.io/kubelet-serving
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

#approver cert
kubectl certificate approve image-bouncer-webhook.default

# download signed server.crt
kubectl get csr image-bouncer-webhook.default -o jsonpath='{.status.certificate}' | base64 --decode > server.crt

mkdir -p /etc/kubernetes/pki/webhook/

#copy to /etc/kubernetes/pki/webhook
cp server.crt /etc/kubernetes/pki/webhook/server.crt

# create secret with signed server.crt
kubectl create secret tls tls-image-bouncer-webhook --key server-key.pem --cert server.crt

echo "127.0.0.1 image-bouncer-webhook" >> /etc/hosts


kubectl  apply -f https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/03/k8s-8/scripts/task1.yaml


curl "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/03/k8s-8/scripts/admission_config.json" -o "admission_config.json"
curl "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/03/k8s-8/scripts/admission_kube_config.yaml" -o "admission_kube_config.yaml"
mv admission_config.json  /etc/kubernetes/pki/admission_config.json
mv admission_kube_config.yaml  /etc/kubernetes/pki/webhook/admission_kube_config.yaml
