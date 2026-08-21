[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 121 - эталонное решение (troubleshooting доступа: access entries, IRSA, kubeconfig)

Все команды выполняются на рабочей машине (worker) по SSH. kubectl уже настроен на
кластер, а terraform уже создал бакет S3 и IRSA-роль компонента `eks_irsa_break_demo` -
их имена и ARN лежат в файле-подсказке `/home/ubuntu/lab121_hints.txt`.

```bash
cat ~/lab121_hints.txt
```

Дальше используются переменные из этого файла:

```bash
export BUCKET_NAME=$(grep '^bucket_name' ~/lab121_hints.txt | awk '{print $3}')
export IRSA_ROLE_ARN=$(grep '^irsa_role_arn' ~/lab121_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab121_hints.txt | awk '{print $3}')
```

Лаба разбирает две независимые оси доступа из главы 47: человек/CI не входит в кластер
(задания 1-4) и под получает `AccessDenied` на AWS (задания 5-8).

## Задание 1. Namespace `eks-121`

```bash
kubectl create namespace eks-121
```

## Задание 2. Симптом Unauthorized: роль без access entry

Создаём тестовую IAM-роль без единого access entry. Роль worker-а разрешает управлять
только ролями с `-test-` в имени (см. `iam.tf` модуля `eks_v2_work_pc`), поэтому имя
обязательно должно содержать эту подстроку:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TEST_ROLE_NAME="eks-task121-test-noaccess"

cat > /tmp/trust-worker.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "AWS": "$(aws sts get-caller-identity --query Arn --output text)" },
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role --role-name "$TEST_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust-worker.json

export TEST_ROLE_ARN=$(aws iam get-role --role-name "$TEST_ROLE_NAME" \
  --query 'Role.Arn' --output text)
```

Роль worker-а несёт `sts:AssumeRole` именно на ARN с `-test-` в имени, поэтому можем
принять эту роль напрямую:

Порядок здесь важен. Отдельный kubeconfig готовим **кредами worker-а, до** `assume-role`:
`aws eks update-kubeconfig` вызывает `eks:DescribeCluster`, а у тестовой роли нет ни одной
IAM-политики, поэтому под ней команда упадёт с `AccessDeniedException` и файл не создастся.
Это, кстати, третий тип отказа в этой цепочке: `AccessDenied` от IAM (нет права на AWS API)
отличается и от `Unauthorized` (identity не замаплена в кластер), и от `Forbidden` (RBAC).
Сам `kubectl` потом берёт токен через `aws eks get-token`, и вот он уже пойдёт от той
identity, чьи креды лежат в переменных окружения:

```bash
aws eks update-kubeconfig --name "$CLUSTER_NAME" --kubeconfig /tmp/kubeconfig-test

CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name lab121-noaccess --duration-seconds 900)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')
```

Проверяем доступ этой identity к кластеру - без access entry она не замаплена, поэтому
ждём `Unauthorized` (глава 47, раздел 47.3):

```bash
mkdir -p /var/work/tests/artifacts/2
kubectl --kubeconfig /tmp/kubeconfig-test get pods -A \
  > /var/work/tests/artifacts/2/unauthorized.txt 2>&1
cat /var/work/tests/artifacts/2/unauthorized.txt
```

В файле должна быть строка со словом `Unauthorized` - API-сервер не смог сопоставить эту
IAM identity ни с одним access entry или записью aws-auth.

Возвращаем креды worker-а (сессионные переменные больше не нужны):

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

## Задание 3. Починка Unauthorized: access entry + AmazonEKSViewPolicy

Создаём access entry для тестовой роли и выдаём ей политику доступа `AmazonEKSViewPolicy`
в масштабе всего кластера (глава 47, раздел 47.4):

```bash
aws eks create-access-entry --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$TEST_ROLE_ARN" --type STANDARD

aws eks associate-access-policy --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster
```

Повторяем `assume-role` (первая сессия уже истекла или закончилась) и тот же запрос с тем
же временным kubeconfig - теперь должен вернуться список подов, а не `Unauthorized`:

```bash
CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name lab121-access --duration-seconds 900)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')

mkdir -p /var/work/tests/artifacts/3
kubectl --kubeconfig /tmp/kubeconfig-test get pods -A \
  > /var/work/tests/artifacts/3/authorized.txt 2>&1
cat /var/work/tests/artifacts/3/authorized.txt
```

В файле теперь строки `NAMESPACE ... POD ...` - access entry устранил `Unauthorized`.

## Задание 4. Симптом Forbidden: View-доступ не даёт писать

Роль имеет только `AmazonEKSViewPolicy` (чтение). Пробуем создать namespace тем же
временным kubeconfig - RBAC должен отказать с `Forbidden` (глава 47, раздел 47.3):

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl --kubeconfig /tmp/kubeconfig-test create namespace test-forbidden \
  > /var/work/tests/artifacts/4/forbidden.txt 2>&1
cat /var/work/tests/artifacts/4/forbidden.txt
```

Дописываем в тот же файл объяснение разницы между заданием 2 (`Unauthorized`) и заданием 4
(`Forbidden`):

```bash
cat >> /var/work/tests/artifacts/4/forbidden.txt <<'EOF'

Разница: в задании 2 роль не была замаплена в кластер вовсе - API-сервер не смог доказать
identity, это Unauthorized (провал аутентификации, слой authn). В задании 4 identity уже
доказана и замаплена access entry-ю, но RBAC (AmazonEKSViewPolicy даёт только чтение) не
разрешает create namespace - это Forbidden (провал авторизации, слой authz). Ремонт разный:
Unauthorized чинится в маппинге (access entry / aws-auth), Forbidden - в RBAC (Role,
ClusterRole, привязка политики).
EOF
cat /var/work/tests/artifacts/4/forbidden.txt

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

## Задание 5. ServiceAccount с правильной аннотацией IRSA

Роль `eks_irsa_break_demo` уже создана terraform с trust policy, которая доверяет ровно
`system:serviceaccount:eks-121:demo-reader` (глава 16, глава 47 раздел 47.6):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-reader
  namespace: eks-121
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: irsa-app
  namespace: eks-121
spec:
  serviceAccountName: demo-reader
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/irsa-app -n eks-121 --timeout=120s
```

Проверяем идентичность и читаем объект из S3:

```bash
mkdir -p /var/work/tests/artifacts/5
{
  echo "--- caller identity ---"
  kubectl exec irsa-app -n eks-121 -- aws sts get-caller-identity
  echo "--- s3 object ---"
  kubectl exec irsa-app -n eks-121 -- aws s3 cp "s3://${BUCKET_NAME}/hello.txt" -
} > /var/work/tests/artifacts/5/irsa_ok.txt
cat /var/work/tests/artifacts/5/irsa_ok.txt
```

`Arn` в выводе должен быть вида `assumed-role/<prefix>-irsa-role/...`, а второй блок -
строка `hello from s3` (объект, который положил terraform).

## Задание 6. Симптом AccessDenied: испорченная аннотация в другом namespace

Создаём второй SA с ТОЙ ЖЕ аннотацией на ту же роль, но в namespace `default`. Trust policy
роли ждёт `sub = system:serviceaccount:eks-121:demo-reader`, а у этого SA `sub` будет
`system:serviceaccount:default:demo-reader-broken` - условие не совпадёт (глава 47, раздел
47.6):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-reader-broken
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-app
  namespace: default
spec:
  serviceAccountName: demo-reader-broken
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/broken-app -n default --timeout=120s
```

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl exec broken-app -n default -- aws sts get-caller-identity \
  > /var/work/tests/artifacts/6/broken.txt 2>&1
cat /var/work/tests/artifacts/6/broken.txt
```

Команда должна завершиться ошибкой обмена токена: `AccessDenied` или `WebIdentityErr` (в
зависимости от версии SDK/CLI сообщение отличается, но суть одна - STS отклонил
`sts:AssumeRoleWithWebIdentity`, потому что `sub` в токене не совпал с условием trust
policy).

## Задание 7. Диагностика: сравнение аннотаций и причина по `sub`

Сравниваем аннотацию SA в обоих namespace и объясняем причину:

```bash
mkdir -p /var/work/tests/artifacts/7
{
  echo "--- eks-121/demo-reader ---"
  kubectl get sa demo-reader -n eks-121 \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
  echo
  echo "--- default/demo-reader-broken ---"
  kubectl get sa demo-reader-broken -n default \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
  echo
  echo
  cat <<'TXT'
Обе аннотации указывают на одну и ту же IRSA-роль, но trust policy роли проверяет условие
sub на STS-токене: system:serviceaccount:<namespace>:<serviceaccount>. Для demo-reader это
system:serviceaccount:eks-121:demo-reader - совпадает с условием роли, обмен разрешён. Для
demo-reader-broken токен несёт sub=system:serviceaccount:default:demo-reader-broken - это
другой namespace и другое имя SA, условие StringEquals не совпадает, поэтому
sts:AssumeRoleWithWebIdentity отклоняется независимо от того, что ARN роли в аннотации
тот же самый.
TXT
} > /var/work/tests/artifacts/7/diagnostics.txt
cat /var/work/tests/artifacts/7/diagnostics.txt
```

## Задание 8. Резюме: две оси доступа

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/summary.txt <<'EOF'
Ось человека (задания 2-4) живёт в цепочке kubectl - IAM - EKS authenticator - RBAC:
Unauthorized значит, что IAM identity не удалось доказать или замапить в кластер вообще
(лечится access entry или aws-auth), а Forbidden значит, что identity уже известна, но
RBAC не разрешил конкретное действие (лечится Role/ClusterRoleBinding). Ось пода (задания
5-7) живёт в цепочке под - ServiceAccount - STS - IAM role: AccessDenied или WebIdentityErr
значит, что trust policy роли не совпала с sub токена ServiceAccount (лечится правкой
условия sub в trust policy или аннотации SA). Ключевое отличие: в первой оси ремонт - это
RBAC внутри кластера, во второй оси ремонт - это trust policy IAM-роли в AWS, и путать их
нельзя.
EOF
cat /var/work/tests/artifacts/8/summary.txt
```

## Быстрая проверка

```bash
check_result
```
