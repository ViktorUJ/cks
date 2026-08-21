[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 123 - эталонное решение (Karpenter: NodePool, consolidation, StatefulSet)

Все команды выполняются на рабочей машине (worker) по SSH. kubectl уже настроен на
кластер (kubeconfig собран через `aws eks update-kubeconfig` при загрузке машины).

## Задание 1. Namespace `eks-123`

```bash
kubectl create namespace eks-123
```

## Задание 2. Инвентаризация NodePool, EC2NodeClass, NodeClaim

Смотрим, какие пулы уже настроены в кластере: дефолтный `default` (spot и on-demand) и
новый `stateful` (только on-demand, taint `dedicated=stateful`):

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "=== nodepools ==="
  kubectl get nodepools -o wide
  echo "=== ec2nodeclasses ==="
  kubectl get ec2nodeclasses
  echo "=== nodeclaims ==="
  kubectl get nodeclaims
} > /var/work/tests/artifacts/2/inventory.txt

cat /var/work/tests/artifacts/2/inventory.txt
```

В выводе должны быть строки с именами `default` и `stateful` - это два независимых
NodePool, каждый со своим `EC2NodeClass` (глава 12.2-12.3).

## Задание 3. StatefulSet `db` на пуле `stateful`

Пул `stateful` закрыт taint'ом `dedicated=stateful:NoSchedule`, поэтому под нужен
toleration. Тома здесь не обязательны для целей лабы - фокус на disruption, а не на EBS
(том StatefulSet со своим PVC разбирается в главе 23):

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
  namespace: eks-123
spec:
  serviceName: db
  replicas: 3
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      tolerations:
        - key: dedicated
          operator: Equal
          value: stateful
          effect: NoSchedule
      containers:
        - name: app
          image: viktoruj/ping_pong:latest
          resources:
            requests:
              cpu: "250m"
              memory: "128Mi"
EOF

kubectl rollout status statefulset/db -n eks-123
```

Проверяем, что все реплики попали на пул `stateful` (метка ноды `work_type=stateful`):

```bash
kubectl get po -n eks-123 -l app=db -o wide
kubectl get nodes -L work_type
```

## Задание 4. PodDisruptionBudget `db-pdb`

`maxUnavailable: 1` - основной тормоз добровольного выселения. Karpenter дренирует через
Eviction API, поэтому PDB не даст вытеснить больше одной реплики одновременно:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: db-pdb
  namespace: eks-123
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: db
EOF

kubectl get pdb db-pdb -n eks-123
```

## Задание 5. Симптом: PDB без права на выселение блокирует консолидацию

Ноды пула `stateful` уже недогружены: три реплики по `250m` разъехались на две ноды
`m6g.medium`, и Karpenter с `consolidateAfter: 30s` постоянно пробует их уплотнить.
Форсировать нагрузкой ничего не нужно - нужно посмотреть, что мешает уплотнению.

Важно: при `maxUnavailable: 1` PDB НЕ блокирует консолидацию. Он разрешает одно выселение
за раз (`ALLOWED DISRUPTIONS=1`), Karpenter дренирует ноду по одной реплике и спокойно её
удаляет. Блокировка возникает только тогда, когда PDB не разрешает ни одного выселения.
Затягиваем защиту до сплошной - `minAvailable: 3` при трёх репликах:

```bash
kubectl patch pdb db-pdb -n eks-123 --type=merge \
  -p '{"spec":{"maxUnavailable":null,"minAvailable":3}}'

kubectl get pdb db-pdb -n eks-123
```

В колонке `ALLOWED DISRUPTIONS` теперь `0`. Через 1-2 минуты на нодах пула появляется
событие блокировки. Обратите внимание: это НЕ `Unconsolidatable`, а отдельный
`DisruptionBlocked`:

```bash
for n in $(kubectl get nodes -l work_type=stateful -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== $n ==="
  kubectl describe node "$n" | grep -A2 DisruptionBlocked
done
```

Ожидаемая строка: `Pdb prevents pod evictions (PodDisruptionBudget=[eks-123/db-pdb])`.
Логи самого контроллера лежат в namespace `karpenter` (не в `kube-system` - там только
аддоны, а Karpenter развёрнут отдельным релизом на Fargate-профиле):

```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=500 \
  | grep -i "disrupting node"
```

Сохраняем наблюдение в артефакт - вывод `get pdb` плюс реальное событие ноды:

```bash
mkdir -p /var/work/tests/artifacts/5
{
  echo "Симптом: PDB, не разрешающий ни одного выселения, блокирует консолидацию."
  echo "db-pdb затянут до minAvailable=3 при 3 репликах -> ALLOWED DISRUPTIONS=0."
  kubectl get pdb db-pdb -n eks-123
  echo
  echo "=== события нод пула stateful ==="
  for n in $(kubectl get nodes -l work_type=stateful -o jsonpath='{.items[*].metadata.name}'); do
    kubectl describe node "$n" | grep -E "DisruptionBlocked|Unconsolidatable" | sed "s|^|$n |"
  done
} > /var/work/tests/artifacts/5/consolidation.txt

cat /var/work/tests/artifacts/5/consolidation.txt
```

Возвращаем PDB к рабочему виду, иначе задание 4 не пройдёт, а нода пула не сможет уйти
никогда:

```bash
kubectl patch pdb db-pdb -n eks-123 --type=merge \
  -p '{"spec":{"minAvailable":null,"maxUnavailable":1}}'

kubectl get pdb db-pdb -n eks-123
```

`ALLOWED DISRUPTIONS` снова `1`. Вывод для эксплуатации: `minAvailable`, равный числу
реплик (или `maxUnavailable: 0`), останавливает не только consolidation, но и любой drain -
значит, и обновление нод, и апгрейд кластера (глава 12.6, глава 40).

## Задание 6. Починка: точечный `do-not-disrupt`

Правильная защита StatefulSet - это связка трёх частей (глава 12.7), не одна аннотация на
всё подряд. PDB (задание 4) уже даёт поштучное выселение. Disruption budget пула
`stateful` (`nodes: 50%` в `eks_karpenter_stateful_vng/terragrunt.hcl`) ограничивает темп,
чтобы Karpenter не тронул все ноды пула разом. Третья часть - `do-not-disrupt` точечно,
только на реплику, где прерывание сейчас недопустимо (например `db-0` держит лидерство
или долгую операцию), а не на весь StatefulSet:

```bash
kubectl annotate pod db-0 -n eks-123 karpenter.sh/do-not-disrupt=true
kubectl get po db-0 db-1 db-2 -n eks-123 \
  -o custom-columns=NAME:.metadata.name,DO_NOT_DISRUPT:'.metadata.annotations.karpenter\.sh/do-not-disrupt'
```

`db-1` и `db-2` аннотации не получают - иначе защита стала бы сплошной и заблокировала
бы не только consolidation, но и drift (обновление AMI), как описано в главе 12.8.

Что аннотация действительно работает, видно тем же механизмом, что и PDB в задании 5 -
Karpenter пишет на ноду с `db-0` отдельное событие:

```bash
NODE=$(kubectl get po db-0 -n eks-123 -o jsonpath='{.spec.nodeName}')
kubectl describe node "$NODE" | grep -A1 'do-not-disrupt'
```

Ожидаемая строка: `DisruptionBlocked ... Pod has "karpenter.sh/do-not-disrupt" annotation
(Pod=eks-123/db-0)`. То есть точечная аннотация останавливает уплотнение только той ноды,
на которой лежит защищённая реплика, а остальные ноды пула Karpenter трогать может.

Сохраняем объяснение в артефакт:

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/fix.txt <<'EOF'
Правильная защита StatefulSet db при консолидации - это три независимые части, а не одна
сплошная аннотация:

1. PDB db-pdb (maxUnavailable: 1) - поштучное выселение, кворум не теряется. Именно это
   значение оставляет ALLOWED DISRUPTIONS=1. Сплошная защита (minAvailable=3 при трёх
   репликах) даёт ALLOWED DISRUPTIONS=0 и событие DisruptionBlocked "Pdb prevents pod
   evictions" - навсегда, до правки самого PDB (задание 5).
2. Disruption budget пула stateful (nodes: 50%) - ограничивает, сколько нод пула Karpenter
   может тронуть одновременно, не даёт уплотнить весь пул разом.
3. karpenter.sh/do-not-disrupt=true точечно на db-0 - защищает конкретную реплику, где
   прерывание сейчас недопустимо, а не весь StatefulSet.

Если бы do-not-disrupt стоял на db-0, db-1 и db-2 одновременно, это заблокировало бы не
только consolidation, но и drift: при выходе нового AMI ноды пула stateful не смогли бы
обновиться, и накопился бы долг по CVE (глава 12.8). Поэтому аннотация ставится только на
одну реплику и снимается, когда критичная операция завершена.
EOF

cat /var/work/tests/artifacts/6/fix.txt
```

## Быстрая проверка

```bash
check_result
```
