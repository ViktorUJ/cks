#!/bin/bash
# *** worker pc, EKS course lab 106 (EBS CSI: gp3, привязка к AZ, расширение, снапшот) ***
# Ничего не сеем заранее: студент создаёт все объекты сам.
# EBS CSI driver уже поставлен terraform-компонентом eks_addon_ebs_irsa (managed addon
# aws-ebs-csi-driver, роль через IRSA). Здесь только ждём готовности кластера и нод.
export KUBECONFIG=/root/.kube/config

echo "*** eks course lab 106 ***"

echo "Waiting for the cluster API to answer..."
while ! kubectl get ns >/dev/null 2>&1; do
  echo "cluster API is not ready yet, waiting..."
  sleep 5
done

echo "Waiting for at least one node to register..."
while [ "$(kubectl get no --no-headers 2>/dev/null | wc -l)" -lt 1 ]; do
  sleep 5
done

echo "Waiting for the aws-ebs-csi-driver addon to become ACTIVE..."
for i in $(seq 1 60); do
  status=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver \
    --no-headers 2>/dev/null | grep -c Running)
  if [ "$status" -ge 1 ]; then
    break
  fi
  sleep 5
done

# Кластер стартует с нулём EC2-нод (только Fargate под системными подами, профиль
# eks_fargate_system покрывает kube-system и karpenter). Драйвер ebs.csi.aws.com с
# volumeBindingMode: Immediate (задание 2-3) не может определить зону тома, пока
# CSINode ни одной EC2-ноды не сообщил topology-ключи, а Karpenter явно отказывается
# поднимать ноду под под с непривязанным Immediate PVC ("pvc with immediate volume
# binding mode must be bound") - без прогрева это тупик навечно для обоих
# контроллеров. Держим служебный под без PVC постоянно в отдельном namespace (НЕ
# kube-system/karpenter - те под Fargate-профилем и не потянут EC2-ноду через
# Karpenter). Не удаляем под - иначе Karpenter консолидирует пустую ноду через 30с
# раньше, чем студент дойдёт до задания 3, и тупик вернётся.
echo "Warming up one EC2 node so ebs.csi.aws.com CSINode topology is known..."
kubectl create namespace ebs-csi-warmup >/dev/null 2>&1
kubectl run ebs-csi-topology-warmup --image=viktoruj/ping_pong:latest --restart=Never \
  -n ebs-csi-warmup >/dev/null 2>&1

echo "Waiting for at least one EC2 (non-Fargate) node to register..."
for i in $(seq 1 60); do
  ec2_nodes=$(kubectl get no --no-headers 2>/dev/null | grep -vc '^fargate-')
  if [ "$ec2_nodes" -ge 1 ]; then
    break
  fi
  sleep 5
done

echo "*** cluster is ready, you can start lab 106 ***"
