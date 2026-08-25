[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 105 - эталонное решение (секреты: KMS envelope encryption, External Secrets)

Все команды выполняются на рабочей машине (worker) по SSH. kubectl уже настроен на
кластер, а terraform уже создал секрет Secrets Manager и роль IRSA для контроллера ESO -
их имена и ARN лежат в файле-подсказке `/home/ubuntu/lab105_hints.txt`.

```bash
cat ~/lab105_hints.txt
```

Переменные из файла-подсказки для дальнейших команд:

```bash
export SECRET_NAME=$(grep '^secret_name' ~/lab105_hints.txt | awk '{print $3}')
export ROLE_ARN=$(grep '^role_arn' ~/lab105_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab105_hints.txt | awk '{print $3}')
```

## Задание 1. Namespace `eks-105`

```bash
kubectl create namespace eks-105
```

## Задание 2. Слой 1: проверка KMS envelope encryption

Начиная с Kubernetes 1.28, EKS шифрует все объекты API (включая `Secret`) ключом AWS по
умолчанию, без каких-либо действий с вашей стороны. Проверяем конфигурацию шифрования
кластера:

```bash
mkdir -p /var/work/tests/artifacts/2
aws eks describe-cluster --name "${CLUSTER_NAME}" --query 'cluster.encryptionConfig' \
  > /var/work/tests/artifacts/2/encryption_config.txt
cat /var/work/tests/artifacts/2/encryption_config.txt
```

В выводе элемент списка содержит `"resources": ["secrets"]` - это и подтверждает, что
слой 1 (envelope encryption секретов в etcd) включён. Если вместо AWS owned key нужен свой
customer managed key (CMK), это делается отдельной командой `aws eks
associate-encryption-config` - но включить свой CMK можно, а отключить шифрование
нельзя (это необратимая операция), поэтому здесь остаёмся на дефолтном ключе AWS.

## Задание 3. Установка External Secrets Operator через Helm

Роль `role_arn` уже создана terraform с trust policy, которая доверяет ровно SA
`external-secrets` в namespace `external-secrets` (глава 16, IRSA). Ставим ESO через Helm
и сразу привязываем роль аннотацией на ServiceAccount:

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets --create-namespace \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${ROLE_ARN}"

kubectl rollout status deployment/external-secrets -n external-secrets
kubectl get pods -n external-secrets
```

Проверяем, что аннотация встала на SA контроллера:

```bash
kubectl get sa external-secrets -n external-secrets -o yaml | grep -A1 annotations
```

## Задание 4. SecretStore и ExternalSecret

Создаём `SecretStore` (namespace-scoped - изоляция по командам, глава 18.5), затем
`ExternalSecret`, который ссылается на демо-секрет из terraform:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-sm
  namespace: eks-105
spec:
  provider:
    aws:
      service: SecretsManager
      region: eu-central-1
EOF

cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: eks-105
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: aws-sm
    kind: SecretStore
  target:
    name: db-credentials
  data:
    - secretKey: password
      remoteRef:
        key: ${SECRET_NAME}
        property: password
EOF
```

Ждём синхронизации и проверяем нативный `Secret`:

```bash
kubectl wait --for=jsonpath='{.status.conditions[0].reason}'=SecretSynced \
  externalsecret/db-credentials -n eks-105 --timeout=120s

kubectl get externalsecret db-credentials -n eks-105
kubectl get secret db-credentials -n eks-105 -o jsonpath='{.data.password}' | base64 -d
echo
```

Значение должно совпасть с паролем, который terraform положил в Secrets Manager
(`S3cr3tPass123`). `refreshInterval: 1m` выбран небольшим намеренно - в задании 6 нам
нужно быстро увидеть пересинхронизацию после ручного изменения секрета в AWS.

## Задание 5. Под с томом: устойчивый путь синхронизации

Монтируем `Secret` как том (volumeMount), а не через env - именно так рекомендует глава
18.5 для значений, которые должны обновляться без пересоздания пода (kubelet сам обновляет
файлы в томе при изменении `Secret`):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: vol-reader
  namespace: eks-105
spec:
  containers:
  - name: app
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
    volumeMounts:
    - name: db-creds
      mountPath: /etc/db-creds
      readOnly: true
  volumes:
  - name: db-creds
    secret:
      secretName: db-credentials
EOF

kubectl wait --for=condition=Ready pod/vol-reader -n eks-105 --timeout=120s
```

Читаем значение из файла в томе:

```bash
mkdir -p /var/work/tests/artifacts/5
kubectl exec vol-reader -n eks-105 -- cat /etc/db-creds/password \
  > /var/work/tests/artifacts/5/volume_password.txt
echo >> /var/work/tests/artifacts/5/volume_password.txt
cat /var/work/tests/artifacts/5/volume_password.txt
```

## Задание 6. Под с env: симптом устаревшего значения

Создаём второй под, который читает тот же `Secret`, но через переменную окружения:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: env-reader
  namespace: eks-105
spec:
  containers:
  - name: app
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
EOF

kubectl wait --for=condition=Ready pod/env-reader -n eks-105 --timeout=120s
kubectl exec env-reader -n eks-105 -- printenv DB_PASSWORD
```

Меняем значение секрета прямо в Secrets Manager (не через Kubernetes):

```bash
aws secretsmanager put-secret-value --secret-id "${SECRET_NAME}" \
  --secret-string '{"username":"appuser","password":"RotatedPass456"}'
```

Ждём `refreshInterval` (в задании 4 задали `1m`) плюс запас и проверяем, что ESO
пересинхронизировал нативный `Secret`:

```bash
sleep 90
kubectl get secret db-credentials -n eks-105 -o jsonpath='{.data.password}' | base64 -d
echo
```

Значение в `Secret` уже новое (`RotatedPass456`) - ESO сделал свою работу. Теперь смотрим
на под с env, который был создан до ротации:

```bash
kubectl exec env-reader -n eks-105 -- printenv DB_PASSWORD
```

Под всё ещё показывает старое значение (`S3cr3tPass123`). Причина: переменные окружения
контейнера фиксируются при старте процесса, поэтому обновление `Secret` в etcd на них не
влияет - под должен быть пересоздан (`kubectl rollout restart` для Deployment, или ручное
удаление и создание для одиночного Pod), чтобы получить новое значение через env. Это не
баг ESO, а особенность работы env в Kubernetes - в отличие от тома, который kubelet
обновляет на диске без пересоздания пода (задание 5).

Фиксируем наблюдение в артефакт:

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/rotation.txt <<'EOF'
После put-secret-value в Secrets Manager и пересинхронизации ExternalSecret нативный
Secret db-credentials в etcd обновился новым значением пароля - ESO сработал штатно.

Под env-reader читает пароль через env (secretKeyRef), а переменные окружения
контейнера фиксируются один раз при старте процесса. Значение env не обновляется
после изменения Secret без пересоздания пода - это не сбой ESO, а особенность env в
Kubernetes. Под vol-reader (задание 5) читает тот же Secret через volumeMount - такой
том kubelet обновляет на диске автоматически, без пересоздания пода.
EOF
cat /var/work/tests/artifacts/7/rotation.txt
```

## Быстрая проверка

```bash
check_result
```
