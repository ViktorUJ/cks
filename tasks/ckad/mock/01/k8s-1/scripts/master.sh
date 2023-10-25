#!/bin/bash
echo " *** master node  mock-1  k8s-1"
export KUBECONFIG=/root/.kube/config

acrh=$(uname -m)
case $acrh in
x86_64)
  awscli_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
;;
aarch64)
  awscli_url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
;;
esac

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: messaging
---
apiVersion: v1
kind: Namespace
metadata:
  name: rsapp
---
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: rs-app2223
  namespace: rsapp
  labels:
    app: app2223
spec:
  replicas: 2
  selector:
    matchLabels:
      app: rs-app2223
  template:
    metadata:
      labels:
        app: rs-app2223
    spec:
      containers:
      - name: redis
        image: rrredis:alpine
---
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: text-printer
  name: text-printer
spec:
  containers:
  - image: busybox
    name: text-printer
    command:
      - '/bin/sh'
      - '-c'
      - 'while true; do echo "Environment VAR: $COLOR"; sleep 60; done'
    env:
    - name: COLOR
      value: "RED"
EOF
