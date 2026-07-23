# Lab 109 — Наблюдаемость и обслуживание: пробы, логи, отладка, deprecations

## Описание

Практическая работа по домену Observability and Maintenance. Вы настроите проверки
здоровья контейнера — **startupProbe**, **readinessProbe** и **livenessProbe** (пробы
старта, готовности и живости), в том числе на примере медленно стартующего приложения,
научитесь выгружать логи Pod (под) в файл, писать CLI-команды для мониторинга
(`kubectl top`, события) и чинить манифест с устаревшей версией API (deprecations,
устаревание) — типовая задача перед обновлением кластера.

Все задания оформлены в экзаменационном стиле (как реальные вопросы CKA/CKAD) с
автоматической проверкой командой `check_result`. Pod с пробой удобнее описать манифестом
(`--dry-run=client -o yaml` как заготовка), а логи и команды мониторинга — императивно
через `kubectl logs`/`kubectl top`.

## Цель

Закрепить материал глав курса:

- [Глава 27. Проверки состояния: liveness, readiness, startup](../../course/27/ru.md) — три пробы (startup/readiness/liveness), тайминги `periodSeconds`/`failureThreshold`, startupProbe против `initialDelaySeconds`
- [Глава 28. Логирование и мониторинг](../../course/28/ru.md) — `kubectl logs`, `kubectl top`, события кластера
- [Глава 29. Отладка приложений и устаревание API](../../course/29/ru.md) — диагностика Pod и переход с устаревших версий API

## Что мы создаём и зачем

В этой лабе мы отрабатываем набор операций сопровождения приложений: от настройки пробы до
починки устаревшего манифеста. Каждый шаг решает свою задачу:

| Объект | Что это | Зачем в этой лабе |
|--------|---------|-------------------|
| **Pod `app1233`** с livenessProbe | Pod с проверкой живости | учимся настраивать exec-пробу с таймингом (глава 27) |
| **Pod `web-probes`** (медленный старт) | все три пробы сразу | startupProbe + readinessProbe + livenessProbe на приложении с `DELAY_START`; кейс startupProbe против `initialDelaySeconds` (глава 27) |
| **Выгрузка логов** сид-Pod `app-xyz3322` | логи в файл | тренируем `kubectl logs` в файл и поиск Pod по namespaces (глава 28) |
| **CLI-скрипты** (top, events) | команды мониторинга | сохраняем правильные команды `top`/events в файлы (глава 28) |
| **Починка `app-old.yaml`** | устаревший apiVersion | обновляем `apps/v1beta1` → `apps/v1` и деплоим (глава 29) |

Итоговая картина того, что будет развёрнуто:

```mermaid
flowchart TB
    a["Pod app1233<br>livenessProbe: exec<br>ls /etc"]
    e["Pod web-probes<br>DELAY_START=30<br>startup + readiness + liveness"]
    b["kubectl logs app-xyz3322<br>→ /opt/logs/app-xyz123.log"]
    c["top.sh / events.sh<br>CLI-команды мониторинга"]
    d["app-old.yaml apps/v1beta1<br>→ apps/v1<br>→ Deployment app-21 Ready"]
    a ~~~ e
    e ~~~ b
    b ~~~ c
    c ~~~ d
    style a fill:#0f9d58,color:#fff
    style e fill:#3cb371,color:#fff
    style b fill:#326ce5,color:#fff
    style c fill:#673ab7,color:#fff
    style d fill:#db4437,color:#fff
```

## Инфраструктура

Окружение разворачивается в AWS (`eu-central-1`) через Terragrunt и состоит из:

| Компонент  | Описание                                                    |
|------------|-------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` с публичными подсетями                    |
| `ssh-keys` | SSH-ключи для доступа к нодам                                |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server; создаёт сид-Pod `app-xyz3322` в namespace `app-logs` |
| `worker`   | Рабочая машина с `kubectl` и `check_result`; при старте создаёт `/var/work/109/app-old.yaml` и рабочие каталоги |

Инстансы: `t3.medium` (master) Ubuntu `22.04`. Кластер одноузловой — master «разтейнчен»
(снят taint `control-plane`), поэтому поды планируются прямо на него.

## Развёртывание

```bash
TASK=109 make run_cka_task
```

После создания подключитесь к рабочей машине (worker) по SSH и выполняйте задания оттуда.
`kubectl` уже настроен на контекст `cluster1-admin@cluster1`.

Полезные команды на рабочей машине:

```bash
time_left       # сколько осталось времени
check_result    # проверить решение
```

## Задания

---
|        **1**        | **livenessProbe: проверка живости контейнера**               |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | В namespace `web-ns` создайте Pod `app1233` (образ `viktoruj/ping_pong:alpine`) с livenessProbe (проба живости) типа `exec`, которая выполняет `ls /etc`. Задайте тайминги: `initialDelaySeconds: 10` (пауза перед первой проверкой) и `periodSeconds: 60` (интервал между проверками). livenessProbe отвечает на вопрос «жив ли контейнер»: если команда возвращает ненулевой код, kubelet перезапускает контейнер. |
| Критерии приёмки    | - namespace `web-ns`;<br/>- Pod `app1233`, образ `viktoruj/ping_pong:alpine`;<br/>- livenessProbe: exec `ls /etc`, `initialDelaySeconds` `10`, `periodSeconds` `60`. |
---
|        **2**        | **Три пробы для медленно стартующего приложения**            |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | В namespace `web-ns` создайте Pod `web-probes` (образ `viktoruj/ping_pong:latest`, порт `8080`) с переменной окружения `DELAY_START="30"` — приложение начинает слушать `:8080` только через `30` секунд (имитация долгого старта). Навесьте **все три** пробы через `httpGet` на `/` порт `8080`:<br/>• **startupProbe** (проба старта): `periodSeconds: 5`, `failureThreshold: 12` — даёт до `60` секунд на запуск;<br/>• **readinessProbe** (проба готовности): `periodSeconds: 10` — не пускает трафик, пока приложение не готово;<br/>• **livenessProbe**: `periodSeconds: 10` — перезапускает зависший контейнер. Пока startupProbe не прошла, readiness и liveness не выполняются — контейнер спокойно стартует свои `30` секунд. |
| Критерии приёмки    | - Pod `web-probes` в namespace `web-ns`, образ `viktoruj/ping_pong:latest`;<br/>- заданы **startupProbe**, **readinessProbe** и **livenessProbe** типа `httpGet` на порт `8080`;<br/>- Pod дошёл до состояния Ready (startupProbe прошла). |
---
|        **3**        | **Выгрузить логи пода в файл**                               |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Найдите сид-Pod `app-xyz3322` (он лежит в одном из namespaces — ищите через `kubectl get po -A`) и выгрузите его логи в файл `/opt/logs/app-xyz123.log`. Файл должен быть непустым. |
| Критерии приёмки    | - логи Pod `app-xyz3322` сохранены в `/opt/logs/app-xyz123.log` (файл не пуст). |
---
|        **4**        | **Написать CLI-команды мониторинга**                         |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Сохраните готовые команды мониторинга в скрипты. В `/var/work/artifact/top.sh` — вывод потребления ресурсов Pods с сортировкой по CPU (`kubectl top pods` с `--sort-by=cpu`). В `/var/work/artifact/events.sh` — события кластера, отсортированные по времени (`kubectl get events` с `--sort-by`). |
| Критерии приёмки    | - `/var/work/artifact/top.sh`: `top` Pods, сортировка по CPU;<br/>- `/var/work/artifact/events.sh`: события, отсортированные по времени (`--sort-by`). |
---
|        **5**        | **Починить устаревший манифест и задеплоить**               |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Манифест `/var/work/109/app-old.yaml` использует удалённую версию API `apps/v1beta1` и не содержит обязательного `selector`. Приведите его к актуальной `apps/v1` (добавьте `spec.selector.matchLabels`, согласованный с label шаблона Pod) и примените. Deployment `app-21` должен развернуться и стать Ready. |
| Критерии приёмки    | - манифест `/var/work/109/app-old.yaml` приведён к `apps/v1`;<br/>- Deployment `app-21` развёрнут и Ready (≥ 1 реплика). |
---

## Практический кейс: startupProbe против initialDelaySeconds

Приложение из задания 2 стартует долго и непредсказуемо (`DELAY_START=30`). Разберём два
способа это пережить.

**Наивный способ — только livenessProbe с большим `initialDelaySeconds`:**

```yaml
livenessProbe:
  httpGet: { path: /, port: 8080 }
  initialDelaySeconds: 40   # угадываем «худший случай» старта
  periodSeconds: 10
```

Минусы:
- `initialDelaySeconds` — это **фиксированная догадка**. Заложили `40` секунд, а старт занял
  `50` → kubelet убьёт контейнер и уронит его в CrashLoop. Заложили с запасом (`120`) —
  зря ждём.
- Эта пауза применяется к liveness **всегда**: если контейнер зависнет уже после старта,
  быстро реагировать не получится, пока не подберёшь тайминги под «худший случай».
- Один и тот же тайминг обслуживает и «медленный старт», и «быстрое обнаружение зависания» —
  а это противоречивые требования.

**Правильный способ — startupProbe + отдельные liveness/readiness:**

```yaml
startupProbe:                 # работает только на этапе запуска
  httpGet: { path: /, port: 8080 }
  periodSeconds: 5
  failureThreshold: 12        # запас 5 × 12 = 60 c на старт
livenessProbe:                # включится только ПОСЛЕ успешной startupProbe
  httpGet: { path: /, port: 8080 }
  periodSeconds: 10
readinessProbe:
  httpGet: { path: /, port: 8080 }
  periodSeconds: 10
```

Почему лучше:
- Пока startupProbe не прошла, liveness и readiness **не выполняются** — медленный старт не
  приводит к преждевременному перезапуску.
- Запас на старт задаётся честно: `failureThreshold × periodSeconds` (здесь до `60` с) и легко
  тюнится, не завися от кода приложения.
- После готовности liveness работает с **маленьким** `periodSeconds` — зависание ловится
  быстро. То есть «долгий старт» и «быстрое обнаружение сбоя» разведены по разным пробам,
  а не втиснуты в один `initialDelaySeconds`.

Проверить на Pod `web-probes`: сразу после создания он `0/1` (идёт startupProbe), а примерно
через `30` секунд, когда приложение поднимет `:8080`, startupProbe проходит и Pod становится
`Ready`:

```bash
kubectl -n web-ns get pod web-probes -w
kubectl -n web-ns describe pod web-probes | grep -A1 -E "Startup|Liveness|Readiness"
```

## Проверка результата

На рабочей машине запустите автоматическую проверку:

```bash
check_result
```

Скрипт прогонит тесты и покажет, сколько заданий выполнено.

## Решение

Эталонное решение: [worker/files/solutions/1.MD](worker/files/solutions/1.MD)

## Покрытие мок-экзаменов

Лаба закрывает задания моков по наблюдаемости и обслуживанию: CKA mock 02 (№16 — events
sorted, №17 — api-resources), CKAD mock 01 (№8 — логи в файл, №12 — livenessProbe, №17 —
top), CKAD mock 02 (№12 — логи, №13 — livenessProbe, №17 — логи, №21 — deprecations).
Задание 2 дополнительно охватывает startupProbe и readinessProbe и разбирает кейс
startupProbe против `initialDelaySeconds` (глава 27).

## Удаление кластера и ресурсов

```bash
TASK=109 make delete_cka_task
```
