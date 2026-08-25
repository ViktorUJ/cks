[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 113 - эталонное решение (апгрейд и откат кластера)

Все команды выполняются на рабочей машине (worker) по SSH. kubectl и aws cli уже настроены
на кластер лабы. Сначала сохраним имя кластера в переменную - оно понадобится почти в
каждой команде:

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
echo "$CLUSTER"
```

## Задание 1. Namespace и стартовая версия кластера

```bash
kubectl create namespace eks-113

aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

Ожидаемый вывод - `"1.35"`. Кластер этой лабы специально стартует на минор ниже текущей
GA-версии `1.36`, чтобы дальше можно было пройти реальный апгрейд и откат.

Дополнительно (не для проверки, но полезно перед апгрейдом): посмотреть, какие `apiVersion`
сейчас обслуживает API-сервер, чтобы позже сравнить с версией после апгрейда:

```bash
kubectl get --raw /apis | grep -o '"groupVersion":"[^"]*"'
```

## Задание 2. Проверка готовности к апгрейду

Upgrade insights - встроенная проверка EKS, которая ищет то, что может помешать апгрейду:
использование API, которые будут удалены в целевой версии, и общее здоровье кластера.
Список insights кластера без `--filter` включает все категории, в том числе апгрейд:

```bash
mkdir -p /var/work/tests/artifacts/2
aws eks list-insights --cluster-name "$CLUSTER" \
  > /var/work/tests/artifacts/2/upgrade_insights.json
cat /var/work/tests/artifacts/2/upgrade_insights.json
```

Проверяем, что среди insights нет статуса `ERROR` (блокирует апгрейд, пока не починить):

```bash
grep '"status"' /var/work/tests/artifacts/2/upgrade_insights.json
```

Если у какого-то insight статус `WARNING` - это не блокер, но стоит прочитать рекомендацию
через `aws eks describe-insight --cluster-name "$CLUSTER" --id <insight-id>`. Если `ERROR`
всё же есть, чинят причину (обычно устаревший `apiVersion` в манифестах) и повторяют
`aws eks list-insights` - EKS обновляет insights раз в 24 часа, форсировать можно через
`aws eks start-insights-refresh --cluster-name "$CLUSTER"`.

## Задание 3. Апгрейд control plane на 1.36

Апгрейд идёт только на один минор за раз: `1.35` -> `1.36`. Запускаем и сохраняем `id`
обновления:

```bash
UPDATE_ID=$(aws eks update-cluster-version --name "$CLUSTER" --kubernetes-version 1.36 \
  --query 'update.id' --output text)
echo "$UPDATE_ID"
```

Обновление control plane идёт в фоне и может занять 20-40 минут. Ждём статус `Successful`:

```bash
while true; do
  status=$(aws eks describe-update --name "$CLUSTER" --update-id "$UPDATE_ID" \
    --query 'update.status' --output text)
  echo "status=$status"
  [[ "$status" == "Successful" || "$status" == "Failed" || "$status" == "Cancelled" ]] && break
  sleep 30
done
```

Подтверждаем новую версию:

```bash
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

Ожидаемый вывод - `"1.36"`. Ноды и аддоны при этом версию пока не меняют - это следующий шаг.

## Задание 4. Апгрейд core-аддонов до версий под 1.36

Control plane обновился, но `kube-proxy` и `coredns` сами за ним не едут - их поднимают
отдельно, до версий, совместимых с новым минором. Точные совместимые версии смотрят так
(если под рукой нет таблицы курса):

```bash
aws eks describe-addon-versions --addon-name kube-proxy --kubernetes-version 1.36 \
  --query 'addons[].addonVersions[].{Version:addonVersion,Default:compatibilities[0].defaultVersion}'
aws eks describe-addon-versions --addon-name coredns --kubernetes-version 1.36 \
  --query 'addons[].addonVersions[].{Version:addonVersion,Default:compatibilities[0].defaultVersion}'
```

Обновляем оба аддона (версии как в лабе 101, где кластер сразу на `1.36`):

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --addon-version v1.36.0-eksbuild.14
aws eks update-addon --cluster-name "$CLUSTER" --addon-name coredns \
  --addon-version v1.14.3-eksbuild.3
```

Дожидаемся `ACTIVE` для каждого:

```bash
for addon in kube-proxy coredns; do
  while true; do
    status=$(aws eks describe-addon --cluster-name "$CLUSTER" --addon-name "$addon" \
      --query 'addon.status' --output text)
    echo "$addon status=$status"
    [[ "$status" == "ACTIVE" || "$status" == "DEGRADED" ]] && break
    sleep 10
  done
done
```

Проверяем итоговые версии:

```bash
aws eks describe-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --query 'addon.addonVersion'
aws eks describe-addon --cluster-name "$CLUSTER" --addon-name coredns \
  --query 'addon.addonVersion'
```

`vpc-cni` и `eks-pod-identity-agent` к минору Kubernetes не привязаны так жёстко, как
`kube-proxy` и `coredns`, поэтому в рамках этой лабы их можно не трогать - но в реальной
эксплуатации их версии тоже стоит сверять через `describe-addon-versions`.

## Задание 5. Проверка готовности к откату

Rollback readiness insights появляются только после апгрейда и живут ровно 7 дней - окно
отката. Смотрим их через фильтр по категории:

```bash
mkdir -p /var/work/tests/artifacts/5
aws eks list-insights --cluster-name "$CLUSTER" \
  --filter '{"categories": ["ROLLBACK_READINESS"]}' \
  > /var/work/tests/artifacts/5/rollback_readiness.json
cat /var/work/tests/artifacts/5/rollback_readiness.json
```

Проверяем статусы - `ERROR` и `UNKNOWN` блокируют откат:

```bash
grep '"status"' /var/work/tests/artifacts/5/rollback_readiness.json
```

Если недавно чинили что-то из блокеров и не хочется ждать суточный refresh:

```bash
aws eks start-insights-refresh --cluster-name "$CLUSTER"
```

## Задание 6. Откат control plane на 1.35

В задании 4 мы подняли `kube-proxy` до версии под `1.36`. Если попытаться откатить control
plane прямо сейчас, EKS пересчитывает rollback readiness insights заново в момент вызова
`update-cluster-version` и находит `ERROR` по проверке `kube-proxy version rollback
compatibility`: `kube-proxy` версии `1.36` после отката control plane на `1.35` окажется
новее control plane, что нарушает политику version skew. Именно поэтому глава 39 говорит
"откатывают ноды/аддоны раньше control plane, если версия аддона обгоняет целевую версию" -
`aws eks list-insights` сразу после апгрейда ещё не покажет эту проблему (insights для
отката пересчитываются заново относительно текущего состояния кластера), но появится, если
запросить их снова после обновления аддона.

Правильный порядок - сначала вернуть `kube-proxy` на версию, совместимую с `1.35`, и только
затем откатывать control plane:

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --addon-version v1.35.3-eksbuild.13

while true; do
  status=$(aws eks describe-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
    --query 'addon.status' --output text)
  echo "kube-proxy status=$status"
  [[ "$status" == "ACTIVE" || "$status" == "DEGRADED" ]] && break
  sleep 10
done
```

Проверяем, что insight по kube-proxy стал `PASSING` (можно форсировать пересчёт, если не
хочется ждать сутки):

```bash
aws eks start-insights-refresh --cluster-name "$CLUSTER"
sleep 30
aws eks list-insights --cluster-name "$CLUSTER" \
  --filter '{"categories": ["ROLLBACK_READINESS"]}' \
  --query 'insights[].{name:name,status:insightStatus.status}'
```

Теперь можно откатывать control plane без `--force` - штатным способом, как и апгрейд, но с
предыдущей версией:

```bash
ROLLBACK_ID=$(aws eks update-cluster-version --name "$CLUSTER" --kubernetes-version 1.35 \
  --query 'update.id' --output text)
echo "$ROLLBACK_ID"

aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
  --query 'update.type'
```

Тип обновления в ответе - `VersionRollback`, а не обычный `VersionUpdate`. Сохраняем это в
артефакт:

```bash
mkdir -p /var/work/tests/artifacts/6
aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
  --query 'update.type' --output text > /var/work/tests/artifacts/6/rollback_update.txt
cat /var/work/tests/artifacts/6/rollback_update.txt
```

Откат тоже идёт в фоне и может занять 20-40 минут. Ждём `Successful`:

```bash
while true; do
  status=$(aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
    --query 'update.status' --output text)
  echo "status=$status"
  [[ "$status" == "Successful" || "$status" == "Failed" || "$status" == "Cancelled" ]] && break
  sleep 30
done
```

Подтверждаем, что control plane вернулся на `1.35`:

```bash
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

Ожидаемый вывод - `"1.35"`. Данные etcd, нагрузки и постоянные тома при откате не трогаются -
откатывается только версия control plane, это не замена бэкапу.

## Быстрая проверка

```bash
check_result
```
