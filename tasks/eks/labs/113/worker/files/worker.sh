#!/bin/bash
# *** worker pc, EKS course lab 113 (cluster upgrade and rollback) ***
# Ничего не сеем заранее: студент выполняет апгрейд и откат сам.
# Ждём, пока кластер станет доступен, появятся ноды и версия control plane
# окажется той стартовой, с которой должна начинаться лаба - 1.35.
export KUBECONFIG=/root/.kube/config

echo "*** eks course lab 113 ***"

echo "Waiting for the cluster API to answer..."
while ! kubectl get ns >/dev/null 2>&1; do
  echo "cluster API is not ready yet, waiting..."
  sleep 5
done

echo "Waiting for at least one node to register..."
while [ "$(kubectl get no --no-headers 2>/dev/null | wc -l)" -lt 1 ]; do
  sleep 5
done

echo "Waiting for the control plane to report version 1.35..."
while true; do
  ver=$(kubectl version -o json 2>/dev/null | grep -o '"gitVersion": *"v1\.35[^"]*"' | head -n1)
  if [[ -n "$ver" ]]; then
    break
  fi
  sleep 5
done

echo "*** cluster is ready on 1.35, you can start lab 113 ***"
