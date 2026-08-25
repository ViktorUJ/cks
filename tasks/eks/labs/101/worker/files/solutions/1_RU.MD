[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 101 - эталонное решение (кластер как код: доступ, вычисления, сеть, AMI)

Все команды выполняются на рабочей машине (worker) по SSH. kubectl уже настроен на
кластер (kubeconfig собран через `aws eks update-kubeconfig` при загрузке машины).

## Задание 1. Namespace `eks-101`

```bash
kubectl create namespace eks-101
```

## Задание 2. Deployment `web` (viktoruj/ping_pong, 3 реплики) на EC2-нодах

Системные поды (kube-system, karpenter) идут на Fargate, а любой под в обычном namespace
планируется на EC2-ноду, которую поднимает Karpenter. Поэтому Deployment в `eks-101`
автоматически попадает на EC2:

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=3 -n eks-101
kubectl rollout status deployment/web -n eks-101
```

Проверка, что поды не на Fargate (имя ноды начинается с `ip-`, а не `fargate-`):

```bash
kubectl get po -n eks-101 -l app=web -o wide
```

Почему так: Fargate запускает под, только если namespace пода попадает под Fargate-профиль.
В этой лабе профиль настроен на `kube-system` и `karpenter`, а на `eks-101` профиля нет,
поэтому нагрузку `eks-101` берёт Karpenter (EC2). Это объяснение вы зафиксируете в задании 7.

## Задание 3. Артефакт: разделение системных и рабочих нод

Сохраняем список нод с указанием, какие из них Fargate, а какие EC2:

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl get nodes -o wide > /var/work/tests/artifacts/3/nodes.txt
cat /var/work/tests/artifacts/3/nodes.txt
```

В файле должны быть и ноды `fargate-...` (системные поды), и ноды `ip-...` (рабочие ноды
Karpenter). Это и есть разделение вычислений из главы 9.

## Задание 4. Артефакт: IP пода из CIDR VPC

VPC CNI выдаёт подам маршрутизируемые адреса из подсети ноды (`10.10.15.0/24` или
`10.10.16.0/24`), то есть из VPC `10.10.0.0/16`:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl get po -n eks-101 -l app=web -o jsonpath='{.items[0].status.podIP}' \
  > /var/work/tests/artifacts/4/podip.txt
echo >> /var/work/tests/artifacts/4/podip.txt
cat /var/work/tests/artifacts/4/podip.txt
```

Чтобы прочувствовать VPC CNI, сверьте адрес пода с CIDR приватных подсетей (под получил IP
из подсети своей ноды):

```bash
VPC=$(aws eks describe-cluster --name "$(kubectl config current-context | sed 's|.*/||')" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null)
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'Subnets[].[CidrBlock,AvailabilityZone]' --output table
```

## Задание 5. Артефакт: AMI рабочей ноды (AL2023)

Смотрим образ ОС любой рабочей (EC2) ноды. Дефолтный NodePool собран на `al2023@latest`,
поэтому это Amazon Linux 2023:

```bash
mkdir -p /var/work/tests/artifacts/5
NODE=$(kubectl get po -n eks-101 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
kubectl get node "$NODE" -o jsonpath='{.status.nodeInfo.osImage}' \
  > /var/work/tests/artifacts/5/ami.txt
echo >> /var/work/tests/artifacts/5/ami.txt
cat /var/work/tests/artifacts/5/ami.txt
```

## Задание 6. Deployment `batch` (6 реплик с запросом CPU) - масштаб через Karpenter

Нагрузка с явными requests заставляет Karpenter добавить вычислительные ресурсы. Создаём
деплой с запросом CPU и ждём готовности всех реплик:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch
  namespace: eks-101
spec:
  replicas: 6
  selector:
    matchLabels:
      app: batch
  template:
    metadata:
      labels:
        app: batch
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "128Mi"
EOF

kubectl rollout status deployment/batch -n eks-101
```

Наблюдать, как Karpenter поднимает ноды, можно так:

```bash
kubectl get nodeclaims.karpenter.sh
kubectl get nodes -l work_type=default -o wide
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | tail -n 20
```

## Задание 7. Граница ответственности: симптом и объяснение

Намеренно просим Fargate там, где его нет. Под должен зависнуть в `Pending`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: fg-probe
  namespace: eks-101
spec:
  nodeSelector:
    eks.amazonaws.com/compute-type: fargate
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

kubectl get po fg-probe -n eks-101 -o wide
kubectl describe po fg-probe -n eks-101 | sed -n '/Events/,$p'
# события всего namespace по времени - навык SRE-диагностики отказа планирования
kubectl get events -n eks-101 --sort-by='.metadata.creationTimestamp'
```

Под остаётся `Pending`: для `eks-101` нет Fargate-профиля, поэтому EKS не поднимает под на
Fargate, а Karpenter не создаёт EC2-ноду, потому что его ноды не несут label
`eks.amazonaws.com/compute-type: fargate`. Никто не может выполнить это требование.

Сохраняем объяснение в артефакт:

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/whyfargate.txt <<'EOF'
Поды web и batch пошли на EC2-ноды Karpenter, а не на Fargate: Fargate запускает под,
только если namespace пода попадает под Fargate-профиль. В кластере профиль есть для
kube-system и karpenter, а для eks-101 профиля нет.

fg-probe завис в Pending, потому что он явно просит Fargate (nodeSelector
eks.amazonaws.com/compute-type: fargate), но профиля для eks-101 нет, а EC2-ноды Karpenter
такой label не имеют. Требование не может выполнить ни Fargate, ни Karpenter.
EOF
cat /var/work/tests/artifacts/7/whyfargate.txt
```

Границу ответственности видно наглядно: за то, какие namespace идут на Fargate, отвечаете
вы (через Fargate-профили, глава 9), а не EKS «сам по себе».

## Быстрая проверка

```bash
check_result
```
