[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 126 - эталонное решение (security groups for pods)

Все команды выполняются на рабочей машине (worker) по SSH, как и в остальных лабах курса:
роль worker получила права на создание security group, правил к ней и на присоединение
политики `AmazonEKSVPCResourceController` к роли кластера (см. README, раздел
«Инфраструктура»).

Переменные, общие для решения:

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
CLUSTER=$(kubectl config current-context | awk -F/ '{print $NF}')
REGION=eu-central-1
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.resourcesVpcConfig.vpcId' --output text)
echo "cluster=$CLUSTER vpc=$VPC_ID"
```

## Задание 1. Namespace `eks-126`

```bash
kubectl create namespace eks-126
```

## Задание 2. Проверка предпосылок

Узнаём имя роли control plane и проверяем присоединённые политики (на worker):

```bash
ROLE_ARN=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.roleArn' --output text)
ROLE_NAME=$(echo "$ROLE_ARN" | sed 's|.*/||')
echo "cluster role: $ROLE_NAME"
aws iam list-attached-role-policies --role-name "$ROLE_NAME"
```

По умолчанию её там нет (у роли только `AmazonEKSClusterPolicy` и политика шифрования),
поэтому присоединяем:

```bash
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSVPCResourceController
```

Политика идёт на роль **control plane** (кластера), а не на роль ноды Karpenter -
именно она разрешает EKS создавать/удалять branch ENI и управлять их IP.

Проверяем три переменные VPC CNI - все уже заданы terraform через `configuration`
аддона `vpc-cni`:

```bash
kubectl describe daemonset aws-node -n kube-system \
  | grep -E 'ENABLE_POD_ENI|POD_SECURITY_GROUP_ENFORCING_MODE|DISABLE_TCP_EARLY_DEMUX'
```

Ожидаемый вывод: `ENABLE_POD_ENI: true`, `POD_SECURITY_GROUP_ENFORCING_MODE: strict`,
`DISABLE_TCP_EARLY_DEMUX: true`. Первая включает trunk interface, вторая оставляет
проверку правил SG пода для трафика с ноды (в режиме `standard` её нет, и симптом задания
4 не появился бы), третья разрешает `kubelet` открывать TCP к поду на branch ENI.

Сохраняем оба подтверждения:

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "cluster role: $ROLE_NAME"
  aws iam list-attached-role-policies --role-name "$ROLE_NAME"
  echo "---"
  kubectl describe daemonset aws-node -n kube-system | grep ENABLE_POD_ENI
} > /var/work/tests/artifacts/2/prereqs.txt
cat /var/work/tests/artifacts/2/prereqs.txt
```

## Задание 3. Неполная security group и SecurityGroupPolicy

Создаём SG в VPC лабы. Важно: НЕ ставим тег `karpenter.sh/discovery`, иначе EC2NodeClass
подберёт эту SG как SG нод:

```bash
SG_ID=$(aws ec2 create-security-group \
  --group-name eks-task126-secured-pod-sg \
  --description "security group for secured-app pods (lab 126, intentionally incomplete)" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' --output text)
echo "$SG_ID"
```

Никаких `authorize-security-group-ingress` и `egress` пока не добавляем: у свежей SG есть
только AWS-дефолтный allow-all egress и ноль inbound-правил - ровно то состояние, которое
даст симптом.

Создаём `SecurityGroupPolicy`:

```bash
mkdir -p /var/work/tests/artifacts/3
echo -n "$SG_ID" > /var/work/tests/artifacts/3/sg_id.txt

cat <<EOF | kubectl apply -f -
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: secured-sgp
  namespace: eks-126
spec:
  podSelector:
    matchLabels:
      app: secured
  securityGroups:
    groupIds:
      - ${SG_ID}
EOF

kubectl get securitygrouppolicy secured-sgp -n eks-126 -o yaml
```

## Задание 4. Симптом: Running, но никогда не Ready

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secured-app
  namespace: eks-126
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secured
  template:
    metadata:
      labels:
        app: secured
    spec:
      nodeSelector:
        work_type: nitro
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          periodSeconds: 5
          failureThreshold: 3
EOF

kubectl rollout status deployment/secured-app -n eks-126 --timeout=180s || true
kubectl get pod -n eks-126 -l app=secured
```

Под виснет `0/1 Ready`, хотя фаза `Running` - branch ENI создалась, но SG пода не
пропускает пробу kubelet. Сохраняем диагностику:

```bash
mkdir -p /var/work/tests/artifacts/4
POD=$(kubectl get pod -n eks-126 -l app=secured -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod "$POD" -n eks-126 > /var/work/tests/artifacts/4/pod_not_ready.txt
grep -i 'readiness probe failed\|unhealthy' /var/work/tests/artifacts/4/pod_not_ready.txt
```

Событие выглядит так (проверено на стенде):

```
Warning  Unhealthy  49s (x33 over 5m44s)  kubelet  Readiness probe failed:
Get "http://10.10.16.177:8080/": context deadline exceeded
```

Убеждаемся, что под действительно на branch ENI, а не на ENI ноды:

```bash
kubectl get pod "$POD" -n eks-126 \
  -o jsonpath='{.metadata.annotations.vpc\.amazonaws\.com/pod-eni}{"\n"}'
kubectl get pod "$POD" -n eks-126 -o jsonpath='{.spec.containers[0].resources.limits}{"\n"}'
aws ec2 describe-network-interfaces --filters "Name=group-id,Values=$SG_ID" \
  --query 'NetworkInterfaces[].[NetworkInterfaceId,InterfaceType,Status,PrivateIpAddress]' \
  --output text
```

В аннотации будет `eniId`, `vlanId` и `associationID` вида `trunk-assoc-...`, в лимитах -
`vpc.amazonaws.com/pod-eni: 1`, а у интерфейса тип `branch` и тот же IP, что у пода.

## Задание 5. Починка проб: правило inbound от SG нод

Находим SG нод Karpenter через ноду, на которой сидит `secured-app` (на worker):

```bash
NODE=$(kubectl get pod "$POD" -n eks-126 -o jsonpath='{.spec.nodeName}')
INSTANCE_ID=$(kubectl get node "$NODE" -o jsonpath='{.spec.providerID}' | sed 's|.*/||')
NODE_SG=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)
echo "node=$NODE instance=$INSTANCE_ID node_sg=$NODE_SG"
```

Добавляем inbound-правило в SG пода:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 8080 \
  --source-group "$NODE_SG"
```

Ждём, пока проба пройдёт, и сохраняем результат:

```bash
sleep 15
kubectl get pod -n eks-126 -l app=secured
mkdir -p /var/work/tests/artifacts/5
kubectl get pod "$POD" -n eks-126 > /var/work/tests/artifacts/5/pod_ready.txt
cat /var/work/tests/artifacts/5/pod_ready.txt
```

`READY` должен показать `1/1` - kubelet теперь может достучаться до branch ENI пода на
порту пробы.

## Задание 6. Диагностика и починка DNS

Проверяем резолвинг из-под `secured-app`. У образа `viktoruj/ping_pong:latest` нет
shell-утилит для DNS (собран из `scratch`), поэтому используем отдельный
диагностический под с той же меткой `app: secured`, чтобы на него тоже действовала
`secured-sgp`:

```bash
kubectl run dns-probe -n eks-126 --image=busybox --restart=Never \
  --labels='app=secured' \
  --overrides='{"spec":{"nodeSelector":{"work_type":"nitro"}}}' \
  -- sleep 3600
kubectl wait --for=condition=Ready pod/dns-probe -n eks-126 --timeout=120s || true

mkdir -p /var/work/tests/artifacts/6
kubectl exec dns-probe -n eks-126 -- nslookup kubernetes.default.svc.cluster.local \
  > /var/work/tests/artifacts/6/dns_before.txt 2>&1 || true
cat /var/work/tests/artifacts/6/dns_before.txt
```

Вывод - `;; connection timed out; no servers could be reached`. Важно правильно назвать
причину: egress тут не при чём, у свежей SG дефолтное правило allow-all egress, и запрос
уходит. Пакет теряется на входе принимающей стороны, у которой нет правила для нашей SG.
CoreDNS в этой лабе на Fargate и живёт за cluster primary security group:

```bash
CLUSTER_PRIMARY_SG=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
echo "cluster primary sg (CoreDNS on Fargate): $CLUSTER_PRIMARY_SG"
```

Добавляем inbound `53` TCP и UDP на cluster primary SG с источником - нашей SG пода.
Одного этого правила достаточно, security group stateful: ответ на разрешённый входящий
запрос уходит обратно без отдельного правила.

```bash
aws ec2 authorize-security-group-ingress --group-id "$CLUSTER_PRIMARY_SG" \
  --ip-permissions \
    "IpProtocol=tcp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$SG_ID}]" \
    "IpProtocol=udp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$SG_ID}]"
```

Проверяем резолвинг снова:

```bash
sleep 5
kubectl exec dns-probe -n eks-126 -- nslookup kubernetes.default.svc.cluster.local \
  > /var/work/tests/artifacts/6/dns_after.txt 2>&1
cat /var/work/tests/artifacts/6/dns_after.txt
```

Теперь второй шаг, по принципу минимальных прав. Дефолтный allow-all egress у SG пода
означает «поду разрешено наружу всё» - для пода с собственной security group это ровно
то, от чего мы пытались уйти. Сужаем egress до `53` и убеждаемся, что DNS продолжает
работать:

```bash
aws ec2 revoke-security-group-egress --group-id "$SG_ID" \
  --protocol -1 --port all --cidr 0.0.0.0/0
aws ec2 authorize-security-group-egress --group-id "$SG_ID" \
  --ip-permissions \
    "IpProtocol=tcp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$CLUSTER_PRIMARY_SG}]" \
    "IpProtocol=udp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$CLUSTER_PRIMARY_SG}]"

kubectl delete pod dns-probe -n eks-126 --ignore-not-found
kubectl run dns-probe -n eks-126 --image=busybox --restart=Never --labels='app=secured' \
  --overrides='{"spec":{"nodeSelector":{"work_type":"nitro"}}}' \
  --command -- sh -c 'nslookup kubernetes.default.svc.cluster.local'
sleep 45
kubectl logs dns-probe -n eks-126 | tee -a /var/work/tests/artifacts/6/dns_after.txt
```

Собираем артефакт:

```bash
cat > /var/work/tests/artifacts/6/dns_fix.txt <<EOF
До починки (dns_before.txt): nslookup к kubernetes.default падал с
";; connection timed out; no servers could be reached".

Причина НЕ в egress: у свежей security group ${SG_ID} есть дефолтное правило allow-all
egress, запрос из пода уходит. Пакет отбрасывается на ВХОДЕ принимающей стороны - у
cluster primary security group ${CLUSTER_PRIMARY_SG}, за которой работает CoreDNS на
Fargate, нет inbound-правила для нашей SG. Правило нужно именно там, и одного его хватает:
security group stateful, ответ на разрешённый входящий запрос уходит обратно сам.

Починка: inbound 53 TCP и UDP на ${CLUSTER_PRIMARY_SG} с source-group ${SG_ID}.
После этого nslookup резолвит kubernetes.default.svc.cluster.local (dns_after.txt).

Второй шаг: дефолтный allow-all egress снят с SG пода, вместо него оставлен явный egress
53 TCP и UDP к ${CLUSTER_PRIMARY_SG}. DNS продолжает работать - это показывает, что egress
на стороне источника и inbound на стороне приёмника это два независимых правила, и
разрешать поду весь исходящий трафик для DNS не требуется.
EOF
cat /var/work/tests/artifacts/6/dns_fix.txt
```

## Задание 7. Ловушка: одна нода, разные security group

Ставим опыт: два пода с РАЗНЫМИ security group на одной ноде. Заводим вторую SG и второй
`SecurityGroupPolicy` на метку `app: other`:

```bash
mkdir -p /var/work/tests/artifacts/7
SG2=$(aws ec2 create-security-group \
  --group-name eks-task126-other-pod-sg \
  --description "second pod sg for the same-node experiment (lab 126)" \
  --vpc-id "$VPC_ID" --query 'GroupId' --output text)
echo "second pod sg: $SG2"

cat <<EOF | kubectl apply -f -
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: other-sgp
  namespace: eks-126
spec:
  podSelector:
    matchLabels:
      app: other
  securityGroups:
    groupIds:
      - ${SG2}
EOF
```

Определяем под Deployment (именно его, а не диагностические поды - они тоже носят метку
`app: secured`) и запускаем рядом под с другой SG:

```bash
APP_POD=$(kubectl get pod -n eks-126 -l app=secured \
  -o jsonpath='{range .items[?(@.metadata.ownerReferences[0].kind=="ReplicaSet")]}{.metadata.name}{"\n"}{end}' \
  | head -1)
APP_IP=$(kubectl get pod "$APP_POD" -n eks-126 -o jsonpath='{.status.podIP}')
APP_NODE=$(kubectl get pod "$APP_POD" -n eks-126 -o jsonpath='{.spec.nodeName}')
echo "secured-app=$APP_POD ip=$APP_IP node=$APP_NODE"

kubectl delete pod othersg -n eks-126 --ignore-not-found --wait=true
kubectl run othersg -n eks-126 --image=busybox --restart=Never --labels='app=other' \
  --overrides="{\"spec\":{\"nodeName\":\"$APP_NODE\"}}" \
  --command -- sh -c "wget -T 10 -qO- http://$APP_IP:8080/ ; echo RC=\$?"
sleep 55
kubectl logs othersg -n eks-126 | tee /var/work/tests/artifacts/7/before.txt
```

Результат - `wget: download timed out`: у пода своя SG, у соседа своя, разрешения между
ними нет. Добавляем правило и повторяем:

```bash
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 8080 --source-group "$SG2"

kubectl delete pod othersg -n eks-126 --ignore-not-found --wait=true
kubectl run othersg -n eks-126 --image=busybox --restart=Never --labels='app=other' \
  --overrides="{\"spec\":{\"nodeName\":\"$APP_NODE\"}}" \
  --command -- sh -c "wget -T 10 -qO- http://$APP_IP:8080/ ; echo RC=\$?"
sleep 55
kubectl logs othersg -n eks-126 | tee /var/work/tests/artifacts/7/after.txt
```

Теперь запрос проходит (`RC=0`). Значит в режиме `strict` правила SG пода работают и
внутри одной ноды - оба пода на своих branch ENI, и решает именно правило. Собираем
артефакт:

```bash
{
  echo "=== под Deployment с SecurityGroupPolicy secured-sgp (branch ENI) ==="
  kubectl get pod "$APP_POD" -n eks-126 -o wide
  echo
  echo "=== под с ДРУГОЙ security group (other-sgp), та же нода ==="
  kubectl get pod othersg -n eks-126 -o wide
  echo
  echo "=== до правила ==="
  cat /var/work/tests/artifacts/7/before.txt
  echo "=== после правила inbound 8080 от второй SG ==="
  cat /var/work/tests/artifacts/7/after.txt
  echo
  echo "=== где CoreDNS ==="
  kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
  cat <<'TXT'

Вывод по опыту. Режим POD_SECURITY_GROUP_ENFORCING_MODE у нас strict, и в нём правила
security group пода применяются даже к трафику внутри одной ноды: два пода с разными SG на
одной ноде сначала не соединились (download timed out), а после добавления inbound-правила
соединились. То есть диагноз здесь обычный - смотреть правила, а не топологию.

Контраст, о котором надо знать (документация AWS, режим standard): в режиме standard
правила SG пода НЕ применяются к трафику между подами и сервисами на одной ноде, включая
kubelet и nodeLocalDNS, а поды с разными security group на одной ноде не общаются вовсе,
потому что сидят в разных подсетях с отключённой маршрутизацией. Там такую же ситуацию
правилом не починить, лечится только разнесением подов по нодам. Заодно именно поэтому в
standard не воспроизводится симптом заданий 4 и 5: проба kubelet идёт мимо правил SG и
readiness проходит при security group без единого inbound-правила.
TXT
} > /var/work/tests/artifacts/7/same_node_trap.txt
cat /var/work/tests/artifacts/7/same_node_trap.txt
```

## Быстрая проверка

```bash
check_result
```
