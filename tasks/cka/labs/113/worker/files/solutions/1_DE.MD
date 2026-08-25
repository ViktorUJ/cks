[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 113 — Referenzlösung (RBAC + Zertifikate/CSR)

## Aufgabe 1. Benutzer `john` über CSR + Role + RoleBinding

```bash
kubectl create namespace development

# Schlüssel und CSR (auf dem Worker)
openssl genrsa -out john.key 2048
openssl req -new -key john.key -out john.csr -subj "/CN=john"

# CSR-Objekt
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: john-developer
spec:
  request: $(cat john.csr | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  usages: ["client auth"]
EOF

kubectl certificate approve john-developer

# Rechte
kubectl create role developer -n development --verb=create,list,get --resource=pods
kubectl create rolebinding developer-role-binding -n development \
  --role=developer --user=john

# Prüfung
kubectl auth can-i create pods -n development --as=john
```

## Aufgabe 2. SA `pvviewer` + ClusterRole + ClusterRoleBinding + Pod

```bash
kubectl create serviceaccount pvviewer
kubectl create clusterrole pvviewer-role --verb=list,get --resource=persistentvolumes
kubectl create clusterrolebinding pvviewer-role-binding \
  --clusterrole=pvviewer-role --serviceaccount=default:pvviewer
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pvviewer
spec:
  serviceAccountName: pvviewer
  containers:
  - name: pvviewer
    image: viktoruj/cks-lab:latest
    command: ["sleep","60000"]
```

```bash
kubectl auth can-i list persistentvolumes --as=system:serviceaccount:default:pvviewer
```

## Aufgabe 3. SA `pod-sa` + Role + RoleBinding in `team-elephant`

```bash
kubectl create namespace team-elephant
kubectl create serviceaccount pod-sa -n team-elephant
kubectl create role pod-sa-role -n team-elephant --verb=list,get --resource=pods
kubectl create rolebinding pod-sa-roleBinding -n team-elephant \
  --role=pod-sa-role --serviceaccount=team-elephant:pod-sa
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-sa
  namespace: team-elephant
spec:
  serviceAccountName: pod-sa
  containers:
  - name: pod-sa
    image: viktoruj/cks-lab
    command: ["sleep","60000"]
```

```bash
kubectl auth can-i list pods -n team-elephant \
  --as=system:serviceaccount:team-elephant:pod-sa
```
