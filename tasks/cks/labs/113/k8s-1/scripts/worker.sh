#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

# Интерактивный `apt-get install` в Ubuntu 22.04 показывает диалог needrestart (OK/Cancel) и теряет
# вставленные в терминал команды. Только выводим список сервисов, не показывая диалог.
mkdir -p /etc/needrestart/conf.d
echo "\$nrconf{restart} = 'l';" > /etc/needrestart/conf.d/99-cks-lab.conf

echo "*** worker node bootstrap: CKS lab 113 (kubeadm upgrade)"
until kubectl get node "$(hostname)" >/dev/null 2>&1; do sleep 5; done

echo "*** worker node starting Kubernetes version:"
kubelet --version
kubectl get node "$(hostname)" -o wide

echo "*** worker node bootstrap for lab 113 is complete"
