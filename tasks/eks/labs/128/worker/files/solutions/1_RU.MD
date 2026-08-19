[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 128 - эталонное решение (Gateway API в AWS: ALB Gateway API и VPC Lattice)

Все команды выполняются на рабочей машине (worker) по SSH. kubectl уже настроен на
кластер. Terraform уже создал IAM-роли для обоих контроллеров (компоненты `eks_lbc_irsa`,
`eks_vpclattice_irsa`) - их ARN лежат в `~/lab128_hints.txt`.

```bash
cat ~/lab128_hints.txt
export CLUSTER=$(kubectl config current-context | sed 's|.*/||')
export LBC_ROLE_ARN=$(grep '^lbc_role_arn' ~/lab128_hints.txt | awk '{print $3}')
export LATTICE_ROLE_ARN=$(grep '^vpclattice_role_arn' ~/lab128_hints.txt | awk '{print $3}')
export NODE_SG=$(grep '^node_sg_id' ~/lab128_hints.txt | awk '{print $3}')
export VPC_ID=$(grep '^vpc_id' ~/lab128_hints.txt | awk '{print $3}')
export ACCOUNT_ID=$(grep '^account_id' ~/lab128_hints.txt | awk '{print $3}')
export REGION=eu-central-1
```

## Задание 1. Gateway API CRD и namespace лабы

```bash
kubectl apply --server-side=true \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

kubectl create namespace eks-128
kubectl create namespace eks-128-backend
```

## Задание 2. AWS Load Balancer Controller и Gateway класса ALB (L7)

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${LBC_ROLE_ARN}
EOF

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${REGION}" \
  --set vpcId="${VPC_ID}"

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
```

`region` и `vpcId` тут обязательны, и это не косметика. Под контроллера попадает в
`kube-system`, а этот namespace накрыт Fargate-профилем, где IMDS нет вовсе. Без флагов
контроллер падает в `CrashLoopBackOff` с
`failed to get VPC ID ... ec2imds: GetMetadata ... context deadline exceeded` (проверено на
стенде). Та же ловушка ждёт любой контроллер, который вы поставите в `kube-system` на
Fargate (главы 15 и 26).

Создаём `GatewayClass` для ALB и сам `Gateway`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: aws-alb
spec:
  controllerName: gateway.k8s.aws/alb
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web
  namespace: eks-128
spec:
  gatewayClassName: aws-alb
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

kubectl get gateway web -n eks-128 -o wide
```

`gateway.k8s.aws/alb` - это тот же AWS Load Balancer Controller, что и в лабах 108/109,
просто вход описан ресурсами Gateway API вместо Ingress: L7-маршруты `HTTPRoute` и
`GRPCRoute` превращаются в listener'ы и правила ALB (глава 28, раздел 28.4).

## Задание 3. HTTPRoute на ALB: прикладная маршрутизация

```bash
kubectl create deployment frontend --image=viktoruj/ping_pong:latest \
  --replicas=2 -n eks-128
kubectl rollout status deployment/frontend -n eks-128
kubectl expose deployment frontend -n eks-128 --port=80 --target-port=8080

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app
  namespace: eks-128
spec:
  parentRefs:
    - kind: Gateway
      name: web
      sectionName: http
  rules:
    - backendRefs:
        - name: frontend
          port: 80
EOF
```

Одного маршрута мало: контроллеру надо сказать, какого типа цели регистрировать. Тип по
умолчанию выводится как `instance`, а `instance` требует Service типа `NodePort` или
`LoadBalancer`. С `ClusterIP` балансировщик остаётся недопрограммированным: `Gateway` уходит
в `Accepted: False` с `reason: Invalid`, а в логе контроллера повторяется
`TargetGroup port is empty. When using Instance targets, your service must be of type
'NodePort' or 'LoadBalancer'` (воспроизведено на стенде). В мире Ingress это лечила аннотация
`alb.ingress.kubernetes.io/target-type: ip`, в Gateway API вместо аннотации отдельный
типизированный объект, и лежать он обязан в namespace своего Service:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.k8s.aws/v1
kind: TargetGroupConfiguration
metadata:
  name: frontend
  namespace: eks-128
spec:
  targetReference:
    name: frontend
  defaultConfiguration:
    targetType: ip
EOF
```

Ждём адрес и подтверждаем через AWS CLI, что это именно ALB:

```bash
for i in $(seq 1 30); do
  ADDR=$(kubectl get gateway web -n eks-128 -o jsonpath='{.status.addresses[0].value}')
  [[ -n "$ADDR" ]] && break
  sleep 10
done
echo "gateway address: $ADDR"

LB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='${ADDR}'].LoadBalancerArn" --output text)

mkdir -p /var/work/tests/artifacts/3
aws elbv2 describe-load-balancers --load-balancer-arns "$LB_ARN" \
  > /var/work/tests/artifacts/3/alb.txt
cat /var/work/tests/artifacts/3/alb.txt
```

В выводе `Type` должен быть `application` - `Gateway` класса `aws-alb` создаёт ALB так
же, как `Ingress` с `ingressClassName: alb` в лабе 109, просто через типизированный
ресурс вместо аннотаций.

Осталось дождаться `Programmed: True` и убедиться, что трафик правда идёт. Балансировщик
внутренний (`internal-...`), поэтому запрос делаем с worker - он в той же VPC:

```bash
for i in $(seq 1 30); do
  p=$(kubectl get gateway web -n eks-128 \
    -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}')
  [[ "$p" == "True" ]] && break
  sleep 10
done
kubectl get gateway web -n eks-128 -o wide

curl -s -o /dev/null -w "http=%{http_code}\n" "http://${ADDR}/"
```

Ответ `http=200` приходит через минуту-две после `Programmed: True`: сначала ALB становится
активным, потом цели проходят health check (состояние целей видно в
`aws elbv2 describe-target-health`).

## Задание 4. AWS Gateway API Controller и Gateway класса VPC Lattice

Сначала открываем SG нод для трафика VPC Lattice - без этого правила поды не получат
трафик от Service Network (глава 28, раздел 28.4 документации по деплою контроллера):

```bash
PREFIX_LIST_ID=$(aws ec2 describe-managed-prefix-lists \
  --query "PrefixLists[?PrefixListName=='com.amazonaws.eu-central-1.vpc-lattice'].PrefixListId" \
  --output text)

aws ec2 authorize-security-group-ingress --group-id "$NODE_SG" \
  --ip-permissions "PrefixListIds=[{PrefixListId=${PREFIX_LIST_ID}}],IpProtocol=-1"
```

Ставим контроллер: namespace, ServiceAccount с ролью, Helm-чарт с параметром
`defaultServiceNetwork` - контроллер сам создаст Service Network `eks-task128-mesh` и
ассоциирует с ней VPC кластера. Чарт и образ лежат в публичном ECR и тянутся анонимно,
`helm registry login` не нужен (у роли worker нет `ecr-public:GetAuthorizationToken`, и это
правильно - публичный реестр читается без токена):

```bash
kubectl create namespace aws-application-networking-system

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gateway-api-controller
  namespace: aws-application-networking-system
  annotations:
    eks.amazonaws.com/role-arn: ${LATTICE_ROLE_ARN}
EOF

helm install gateway-api-controller \
  oci://public.ecr.aws/aws-application-networking-k8s/aws-gateway-controller-chart \
  --version=v1.1.0 \
  --namespace aws-application-networking-system \
  --set=serviceAccount.create=false \
  --set=defaultServiceNetwork=eks-task128-mesh \
  --set=awsRegion="${REGION}" \
  --set=awsAccountId="${ACCOUNT_ID}" \
  --set=clusterVpcId="${VPC_ID}" \
  --set=clusterName="${CLUSTER}"

kubectl rollout status deployment -n aws-application-networking-system --timeout=180s
```

Четыре последних флага обязательны по той же причине, что `region` и `vpcId` у LBC, но
симптом другой и его стоит запомнить. Под этого контроллера стоит на обычной EC2-ноде, то
есть IMDS в принципе есть, однако IMDSv2 идёт с hop limit 1, и запрос из сетевого namespace
пода отбрасывается. Без флагов контроллер падает мгновенно с
`init config failed: vpcId is not specified: EC2MetadataError ... status code: 401`
(проверено на стенде). Ровно этот hop limit разбирается в главах 10 и 19: он защищает креды
роли ноды от подов, а заодно ломает любой контроллер, который надеется на метаданные.

Создаём `GatewayClass` для VPC Lattice и сам `Gateway`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1beta1
kind: GatewayClass
metadata:
  name: amazon-vpc-lattice
spec:
  controllerName: application-networking.k8s.aws/gateway-api-controller
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: eks-task128-mesh
  namespace: eks-128
spec:
  gatewayClassName: amazon-vpc-lattice
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

kubectl get gateway eks-task128-mesh -n eks-128 -o wide
```

Имя `Gateway` здесь не произвольное, и это главная ловушка задания. Контроллер VPC Lattice
ищет Service Network по ИМЕНИ объекта `Gateway`, а не по значению `defaultServiceNetwork`.
Назовите `Gateway` словом `mesh` - и он навсегда останется
`Programmed: False` с сообщением `VPC Lattice Service Network not found`, потому что сеть в
аккаунте называется `eks-task128-mesh` (проверено на стенде: два `Gateway` рядом, с
совпадающим именем `Programmed: True` и ARN сети в сообщении, с несовпадающим - `not found`).
Отсюда правило: имя `Gateway` = имя Service Network.

`Gateway` класса `amazon-vpc-lattice` отображается в Service Network VPC Lattice: это
east-west связь между сервисами кластера, а не вход снаружи, как у `aws-alb` (глава 28,
раздел 28.5).

## Задание 5. Симптом: HTTPRoute без ReferenceGrant

Поднимаем backend в соседнем namespace:

```bash
kubectl create deployment backend --image=viktoruj/ping_pong:latest \
  --replicas=1 -n eks-128-backend
kubectl rollout status deployment/backend -n eks-128-backend
kubectl expose deployment backend -n eks-128-backend --port=80 --target-port=8080

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.k8s.aws/v1
kind: TargetGroupConfiguration
metadata:
  name: backend
  namespace: eks-128-backend
spec:
  targetReference:
    name: backend
  defaultConfiguration:
    targetType: ip
EOF
```

`TargetGroupConfiguration` нужен по той же причине, что в задании 3, и заодно показывает
разделение владения: объект лежит в namespace владельца Service, а не рядом с маршрутом.

Маршрут `rates` живёт в `eks-128`, а ссылается на Service в `eks-128-backend`. Родитель -
`Gateway` `web` класса `aws-alb`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: rates
  namespace: eks-128
spec:
  parentRefs:
    - kind: Gateway
      name: web
      sectionName: http
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /rates
      backendRefs:
        - name: backend
          namespace: eks-128-backend
          port: 80
EOF
```

Тот же самый маршрут, но на `Gateway` класса `amazon-vpc-lattice` - это контрольный опыт,
он нужен для вывода задания:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: rates-lattice
  namespace: eks-128
spec:
  parentRefs:
    - kind: Gateway
      name: eks-task128-mesh
      sectionName: http
  rules:
    - backendRefs:
        - name: backend
          namespace: eks-128-backend
          port: 80
EOF

sleep 25
mkdir -p /var/work/tests/artifacts/5
{
  echo "rates status=$(kubectl get httproute rates -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')"
  echo "rates reason=$(kubectl get httproute rates -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].reason}')"
  echo "rates message=$(kubectl get httproute rates -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].message}')"
  echo "rates-lattice status=$(kubectl get httproute rates-lattice -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')"
  echo "rates-lattice reason=$(kubectl get httproute rates-lattice -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].reason}')"
} > /var/work/tests/artifacts/5/refnotpermitted.txt
cat /var/work/tests/artifacts/5/refnotpermitted.txt
```

Не используем `kubectl -o yaml | grep -A...`: у CRD-объектов (unstructured) поля condition
сериализуются в алфавитном порядке (`reason`, `status` идут раньше `type`), поэтому
надёжнее вытащить нужное условие напрямую через `jsonpath`.

`backendRefs` с полем `namespace` ссылается на Service в чужом namespace - по умолчанию
такая ссылка запрещена, чтобы разработчик из `eks-128` не мог направить трафик на чужой
сервис без разрешения его владельца (глава 28, раздел 28.2). У маршрута `rates` условие
`ResolvedRefs` будет `status: "False"`, `reason: RefNotPermitted`, сообщение
`No explicit ReferenceGrant exists to allow the reference.`

А вот вывод, за которым и стоит контрольный опыт: у `rates-lattice` условие сразу
`ResolvedRefs: True` при том, что никакого `ReferenceGrant` в `eks-128-backend` ещё нет
(проверено на стенде). Правило `ReferenceGrant` - часть спецификации Gateway API, но
СОБЛЮДАЕТ его реализация, а не API-сервер: AWS Load Balancer Controller его проверяет,
контроллер VPC Lattice версии v1.1.0 - нет. Отсюда практический вывод: одинаковый YAML в
двух реализациях Gateway API даёт разную границу доверия между командами, и полагаться на
`ReferenceGrant` как на защиту можно только там, где вы проверили поведение контроллера.

## Задание 6. Fix: ReferenceGrant разрешает кросс-namespace ссылку

`ReferenceGrant` создаёт владелец **целевого** backend - namespace `eks-128-backend`, а
не тот, кто ссылается:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-from-eks-128
  namespace: eks-128-backend
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: eks-128
  to:
    - group: ""
      kind: Service
EOF

sleep 15
mkdir -p /var/work/tests/artifacts/6
{
  echo "ResolvedRefs status=$(kubectl get httproute rates -n eks-128 \
    -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')"
  echo "curl /rates http=$(curl -s -o /dev/null -w '%{http_code}' -m 10 "http://${ADDR}/rates")"
} > /var/work/tests/artifacts/6/resolved.txt
cat /var/work/tests/artifacts/6/resolved.txt
```

Второй строкой артефакта проверяем не статус, а сам трафик: `http=200` от пода `backend`
означает, что цепочка целиком собралась - маршрут разрешён грантом, target group типа `ip`
создана, цели прошли health check. Если `ResolvedRefs` уже `True`, а `curl` отдаёт `503`,
подождите минуту: регистрация целей идёт после появления target group.

После появления `ReferenceGrant` условие `ResolvedRefs` у `rates` меняется на `True` за
считанные секунды - контроллер переоценивает разрешённые ссылки при следующей реконсиляции,
и маршрут начинает резолвить `backend` в соседнем namespace. Обратите внимание, что
разрешение выдаёт namespace-ВЛАДЕЛЕЦ цели: удалите `ReferenceGrant`, и маршрут вернётся в
`RefNotPermitted`, хотя сам маршрут никто не менял.

## Быстрая проверка

```bash
check_result
```
