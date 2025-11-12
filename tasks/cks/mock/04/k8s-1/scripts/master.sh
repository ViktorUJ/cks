#!/bin/bash
echo " *** master node cks mock 04 k8s-1"
export KUBECONFIG=/root/.kube/config

# Untaint master node
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-

cat >anonymous-rbac.yaml <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: anonymous
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: anonymous-binding
subjects:
- kind: User
  name: system:anonymous
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: anonymous
  apiGroup: rbac.authorization.k8s.io
YAML

kubectl apply -f anonymous-rbac.yaml
