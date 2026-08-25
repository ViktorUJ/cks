[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 112 - эталонное решение (Fargate: профили, ограничения, стоимость)

Все команды выполняются на рабочей машине (worker) по SSH. kubectl уже настроен на
кластер (kubeconfig собран через `aws eks update-kubeconfig` при загрузке машины).
Fargate-профиль `workload` для namespace `eks-112` уже создан инфраструктурой лабы -
студенту нужно только создать namespace и объекты внутри него.

## Задание 1. Namespace `eks-112`

```bash
kubectl create namespace eks-112
```

Профиль `workload` матчит по `namespace = eks-112` без `labels`, поэтому весь namespace
целиком попадает на Fargate - никаких исключений внутри него не будет.

## Задание 2. Guaranteed-под `fg-app` на Fargate

Fargate запускает только поды, у которых `requests` равны `limits` (класс `Guaranteed`).
Создаём Deployment с явно равными значениями:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fg-app
  namespace: eks-112
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fg-app
  template:
    metadata:
      labels:
        app: fg-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "500m"
            memory: "1Gi"
EOF

kubectl rollout status deployment/fg-app -n eks-112
```

Проверяем, что поды идут на Fargate-ноду (имя ноды начинается с `fargate-`, а не `ip-`):

```bash
kubectl get po -n eks-112 -l app=fg-app -o wide
```

## Задание 3. Артефакт: реально выданная ёмкость

Fargate округляет сумму запросов вверх до фиксированной комбинации vCPU/памяти и добавляет
`256 MB` на компоненты Kubernetes (`kubelet`, `kube-proxy`, `containerd`). Реально выданная
ёмкость видна в аннотации `CapacityProvisioned`:

```bash
mkdir -p /var/work/tests/artifacts/3
POD=$(kubectl get po -n eks-112 -l app=fg-app -o jsonpath='{.items[0].metadata.name}')
kubectl get pod "$POD" -n eks-112 \
  -o jsonpath='{.metadata.annotations.CapacityProvisioned}' \
  > /var/work/tests/artifacts/3/capacity.txt
echo >> /var/work/tests/artifacts/3/capacity.txt
cat /var/work/tests/artifacts/3/capacity.txt
```

Для запроса `500m` CPU и `1Gi` памяти плюс `256 MB` служебных Fargate выберет ближайшую
подходящую комбинацию (например `0.5vCPU 1GB` или `0.5vCPU 2GB`, если суммарная память
после добавки превысит `1 GB`) - именно эту строку и покажет `kubectl describe pod`.

## Задание 4. Симптом: privileged-под не запускается

Fargate жёстко запрещает привилегированные контейнеры, DaemonSet, hostNetwork/hostPort,
hostPath и GPU. Пробуем создать privileged-под в `eks-112`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: fg-privileged
  namespace: eks-112
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
    securityContext:
      privileged: true
EOF

kubectl get po fg-privileged -n eks-112
kubectl describe po fg-privileged -n eks-112 | sed -n '/Events/,$p'
```

Под не переходит в `Running`: Fargate отклоняет привилегированные контейнеры на этапе
допуска (admission), это видно в событиях пода. Сохраняем объяснение в артефакт:

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/privileged.txt <<'EOF'
Pod fg-privileged не запускается, потому что просит privileged: true. Fargate не
поддерживает привилегированные контейнеры: это одно из жёстких ограничений режима, наряду
с DaemonSet, hostNetwork/hostPort, hostPath и GPU. Ошибка видна в events пода как отказ
допуска (admission), а не как обычный Pending из-за нехватки ресурсов.
EOF
cat /var/work/tests/artifacts/4/privileged.txt
```

Можно убрать под, чтобы он не мешал последующим проверкам:

```bash
kubectl delete pod fg-privileged -n eks-112
```

## Задание 5. Расширение эфемерного диска до 30Gi

По умолчанию Fargate выдаёт `20 GiB` эфемерного диска, до `175 GiB` через
`ephemeral-storage` в `resources` (requests должны равняться limits, под остаётся
Guaranteed). Обновляем `fg-app`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fg-app
  namespace: eks-112
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fg-app
  template:
    metadata:
      labels:
        app: fg-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
            ephemeral-storage: "30Gi"
          limits:
            cpu: "500m"
            memory: "1Gi"
            ephemeral-storage: "30Gi"
EOF

kubectl rollout status deployment/fg-app -n eks-112
kubectl get po -n eks-112 -l app=fg-app -o wide
```

Под запускается нормально: `30Gi` в пределах разрешённых `175 GiB`, и требование
`requests == limits` выполнено.

## Задание 6. Структура стоимости: Fargate против node group

Ключевая разница - единица тарификации. Fargate считает деньги за vCPU и память
конкретного пода за время его жизни, node group - за целый EC2-инстанс независимо от
того, насколько он загружен:

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/costmodel.txt <<'EOF'
Fargate тарифицирует vCPU и память самого пода за время его выполнения: если под не
запущен, платы нет, и переплаты за простаивающую ёмкость не возникает. Node group,
наоборот, тарифицирует целый инстанс целиком: платить приходится даже за то время, когда
ноды простаивают между подами или недогружены. За единицу ресурса Fargate обычно дороже,
чем эквивалентный ресурс на ноде node group, поэтому итоговая экономика зависит от
утилизации: при высокой и предсказуемой загрузке node group выгоднее, а при рваном или
непредсказуемом спросе Fargate избавляет от переплаты за простаивающие инстансы.
EOF
cat /var/work/tests/artifacts/6/costmodel.txt
```

## Быстрая проверка

```bash
check_result
```
