#!/bin/bash
# Полный сетап делает СТУДЕНТ. Здесь мы только убираем предустановленный
# модулем docker/containerd, чтобы нода node была «чистой» — рантайм студент
# ставит и настраивает сам (симметрично ноде cp).
set -x
echo " *** cka lab-116 (node): убираем предустановленный docker/containerd (чистая нода)"

systemctl stop docker containerd 2>/dev/null || true
apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true
rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.asc
rm -rf /etc/containerd /var/lib/containerd
apt-get update -qq || true

echo " *** нода node чистая. Установка containerd + kubeadm/kubelet/kubectl + join — задача студента."
