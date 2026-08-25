[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 131 - эталонное решение (PDB блокирует drain, topology spread, matchLabelKeys)

Все команды выполняются на рабочей машине (worker) по SSH. kubectl уже настроен на
кластер (kubeconfig собран через `aws eks update-kubeconfig` при загрузке машины).

## Задание 1. Namespace `eks-131`

```bash
kubectl create namespace eks-131
```

## Задание 2. Deployment `web` с topology spread и matchLabelKeys

Кластер лабы поднят в двух зонах (`eu-central-1a` и `eu-central-1b`), приватные подсети
`eks1`/`eks2` под каждую из них. Этого достаточно, чтобы Karpenter разложил ноды по двум
зонам, а `topologySpreadConstraints` развёл по ним поды.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: eks-131
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: web
          matchLabelKeys:
            - pod-template-hash
      containers:
        - name: app
          image: viktoruj/ping_pong:latest
EOF

kubectl rollout status deployment/web -n eks-131
```

Проверяем готовность и раскладку по зонам:

```bash
kubectl get pods -n eks-131 -l app=web -o wide
kubectl get nodes -L topology.kubernetes.io/zone
```

В столбце `NODE` у трёх подов должны быть как минимум две разные ноды, а у этих нод -
разные значения `topology.kubernetes.io/zone`. `matchLabelKeys: [pod-template-hash]`
здесь пока не влияет на первый деплой (ревизия одна), он покажет себя в задании 6.

## Задание 3. Симптом: слишком жёсткий PDB блокирует drain

Создаём PDB, который требует, чтобы доступны были все 3 реплики - бюджет не разрешает
вывести ни одного пода:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-pdb
  namespace: eks-131
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: web
EOF
```

Берём ноду с одной из реплик `web` и пытаемся её вывести:

```bash
NODE=$(kubectl get pod -n eks-131 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
echo "node: $NODE"

mkdir -p /var/work/tests/artifacts/3
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=60s \
  > /var/work/tests/artifacts/3/drain_blocked.txt 2>&1
echo "drain exit code: $?"
cat /var/work/tests/artifacts/3/drain_blocked.txt
```

Команда не проходит: `kubectl drain` пытается вызвать eviction API для пода `web`, но
API отвечает `429` с сообщением про нарушение бюджета, и после `--timeout=60s` drain
завершается ошибкой `global timeout reached`. Причина - PDB `web-pdb` с `minAvailable: 3`
требует 3 доступные реплики, а их всего 3, значит бюджет не разрешает вывести ни одну:
выселение не может продвинуться никогда, drain будет висеть, пока бюджет не ослабят.

Добавляем объяснение в тот же артефакт:

```bash
cat >> /var/work/tests/artifacts/3/drain_blocked.txt <<'EOF'

Объяснение: PDB web-pdb задаёт minAvailable: 3, что равно числу реплик Deployment web.
Бюджет не разрешает вывести ни один под, поэтому eviction API отвечает 429, и kubectl
drain зависает/таймаутится - это симптом слишком жёсткого PDB, не ошибка кластера.
EOF
cat /var/work/tests/artifacts/3/drain_blocked.txt
```

## Задание 4. Лечение: ослабляем PDB и повторяем drain

Сначала возвращаем ноду в работу (drain уже её закордонил):

```bash
kubectl uncordon "$NODE"
```

Ослабляем бюджет: теперь можно выводить одну реплику из трёх (`minAvailable: 2`):

```bash
kubectl patch pdb web-pdb -n eks-131 --type merge -p '{"spec":{"minAvailable":2}}'
kubectl get pdb web-pdb -n eks-131
```

Повторяем drain той же ноды - теперь бюджет разрешает вывести один под, drain проходит:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=120s \
  > /var/work/tests/artifacts/4/drain_ok.txt 2>&1
echo "drain exit code: $?" >> /var/work/tests/artifacts/4/drain_ok.txt

echo "--- pdb status after drain ---" >> /var/work/tests/artifacts/4/drain_ok.txt
kubectl get pdb web-pdb -n eks-131 >> /var/work/tests/artifacts/4/drain_ok.txt
cat /var/work/tests/artifacts/4/drain_ok.txt
```

Возвращаем ноду в работу и ждём, что все 3 реплики снова готовы (замена встала на
другой ноде):

```bash
kubectl uncordon "$NODE"
kubectl rollout status deployment/web -n eks-131
```

## Задание 5. unhealthyPodEvictionPolicy: AlwaysAllow

По умолчанию PDB использует политику `IfHealthyBudget`: нездоровый (не `Ready`) под можно
выселить только если бюджет и без него не нарушен. Если приложение сломано и под завис в
`CrashLoopBackOff`, такой под сам блокирует расчёт бюджета и не даёт провести drain
навсегда. `AlwaysAllow` снимает эту блокировку: нездоровые поды выселяются всегда,
здоровые остаются под защитой бюджета.

```bash
kubectl patch pdb web-pdb -n eks-131 --type merge \
  -p '{"spec":{"unhealthyPodEvictionPolicy":"AlwaysAllow"}}'

kubectl get pdb web-pdb -n eks-131 -o jsonpath='{.spec.unhealthyPodEvictionPolicy}'
echo
```

Сохраняем объяснение в артефакт:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/unhealthy_policy.txt <<'EOF'
unhealthyPodEvictionPolicy: AlwaysAllow добавлен в web-pdb.

По умолчанию (IfHealthyBudget) нездоровый под выселяется только если currentHealthy
не опустится ниже desiredHealthy, поэтому под в CrashLoopBackOff сам считается частью
бюджета и может навсегда заблокировать drain, даже если приложение уже не работает.

AlwaysAllow разрешает выселить нездоровый под независимо от бюджета: сломанный под
в CrashLoopBackOff больше не держит drain, а здоровые реплики остаются защищены PDB.
EOF
cat /var/work/tests/artifacts/5/unhealthy_policy.txt
```

## Задание 6. Rolling update: matchLabelKeys не даёт старым подам мешать раскладке

Обновляем Deployment так, чтобы появилась новая ревизия (новый `pod-template-hash`):
добавляем переменную окружения. Старые и новые поды несут общую метку `app: web`, но
`matchLabelKeys: [pod-template-hash]` в `topologySpreadConstraints` заставляет считать
перекос только внутри своей ревизии, поэтому новые поды не блокируются старыми репликами.

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl set env deployment/web -n eks-131 RELEASE=v2

kubectl rollout status deployment/web -n eks-131 --timeout=180s \
  | tee /var/work/tests/artifacts/6/rollout.txt
```

Проверяем, что нет зависших `Pending` подов и обновление реально применилось:

```bash
kubectl get pods -n eks-131 -l app=web -o wide
kubectl get deploy web -n eks-131 \
  -o jsonpath='{.status.readyReplicas}/{.status.updatedReplicas}'
echo
```

Без `matchLabelKeys: [pod-template-hash]` в подсчёте перекоса участвовали бы и старые, и
новые поды - у них общая метка `app: web`. С ним планировщик добавляет к селектору метку
ревизии и считает распределение только внутри своей ревизии.

Честная оговорка, и её стоит проверить самому, а не принимать на веру. На этом стенде
выкатка проходит УСПЕШНО и без `matchLabelKeys` - проверено опытом: второй Deployment с той
же топологией, но без этого поля, с `maxUnavailable: 0` и `maxSurge: 1` обновился за то же
время, `Pending` держался меньше пяти секунд и был обычным ожиданием планировщика, а не
блокировкой по перекосу. Причина простая: три реплики на две зоны дают раскладку 2 плюс 1, и
дополнительный под всегда помещается в зону с меньшим числом подов, а если места на нодах не
хватает, Karpenter поднимает ещё одну.

Где разница становится настоящей: статичный парк без запаса ёмкости, зон больше двух и
неровная раскладка старой ревизии. Тогда перекос, посчитанный по обеим ревизиям сразу, не
оставляет новому поду допустимой зоны, и он ждёт, пока уйдёт старая реплика - на большом
парке это превращается в медленную выкатку с непонятными `Pending`. Поэтому `matchLabelKeys`
ставят заранее, а не после инцидента. Проверяемый же результат сейчас - что новая ревизия
осталась разложенной по зонам в пределах `maxSkew: 1`:

```bash
HASH=$(kubectl get po -n eks-131 -l app=web \
  -o jsonpath='{.items[0].metadata.labels.pod-template-hash}')
for n in $(kubectl get po -n eks-131 -l app=web,pod-template-hash="$HASH" \
    -o jsonpath='{.items[*].spec.nodeName}'); do
  kubectl get node "$n" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}{"\n"}'
done | sort | uniq -c
```

## Быстрая проверка

```bash
check_result
```
