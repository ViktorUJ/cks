# Глава 6. Namespaces, labels, selectors и annotations

> **Что дальше.** Мы уже несколько раз натыкались на labels (метки) и namespace, но
> использовали их походя. Пора разобраться основательно: это сквозные механизмы, на
> которых держится вся организация ресурсов в кластере. **Namespace** (неймспейс)
> логически делит кластер на группы ресурсов (это организация, а не изоляция сама по
> себе). **Labels и selectors (селекторы)** связывают объекты между собой (Service
> находит поды, ReplicaSet - свои реплики, NetworkPolicy - кого пускать). **Annotations
> (аннотации)** хранят вспомогательные данные. На экзамене эти темы вплетены почти в
> каждую задачу: «создай в namespace X», «выбери поды с label Y».

## 6.1. Namespace (неймспейс): разделение кластера

**Namespace** - это виртуальный раздел внутри одного физического кластера. Он позволяет
разным командам, приложениям или окружениям сосуществовать в одном кластере, не мешая
друг другу: имена объектов уникальны в пределах namespace, а не всего кластера.

```mermaid
flowchart TB
    subgraph Cluster["Один физический кластер"]
        direction LR
        subgraph ns1["namespace: dev"]
            d1["Deployment web"]
            s1["Service web"]
        end
        subgraph ns2["namespace: prod"]
            d2["Deployment web"]
            s2["Service web"]
        end
        subgraph ns3["namespace: team-b"]
            d3["Deployment api"]
        end
    end
    style Cluster fill:#eeeeee,color:#000
    style ns1 fill:#0f9d58,color:#fff
    style ns2 fill:#326ce5,color:#fff
    style ns3 fill:#673ab7,color:#fff
```

Обратите внимание: в `dev` и `prod` есть Deployment с одинаковым именем `web` - и это
не конфликт, потому что они в разных namespace. Имя объекта должно быть уникально только
внутри своего namespace.

Зачем нужны namespace:

- **Разделение имён (scoping).** Имена объектов уникальны в пределах namespace, поэтому
  команды и окружения не пересекаются по именам.
- **Точка приложения политик.** Namespace сам по себе ничего не изолирует, но служит
  границей, к которой **привязывают** механизмы изоляции: RBAC-права, квоты, сетевые
  политики (см. три пункта ниже).
- **Управление доступом.** RBAC (глава 38) часто выдаёт права на конкретный namespace.
- **Квоты ресурсов.** ResourceQuota и LimitRange (глава 14) ограничивают потребление
  на уровне namespace.
- **Порядок.** Проще ориентироваться, чем в тысяче объектов в одной куче.

> **Важно: namespace ≠ изоляция.** По умолчанию namespace не изолирует ни сеть, ни
> ресурсы: под из одного namespace свободно ходит по IP к поду в другом, и они делят
> общие ресурсы нод. Реальную изоляцию дают **отдельные** механизмы, которые вешают
> *на* namespace: **NetworkPolicy** (сеть, глава 34), **ResourceQuota/LimitRange**
> (ресурсы, глава 14), **RBAC** (доступ, глава 38). Namespace - это область имён и
> удобная граница для этих политик, а не сама изоляция.

## 6.2. Системные namespace

При создании кластера уже есть несколько namespace. Их надо знать.

| Namespace | Назначение |
|-----------|-----------|
| `default` | Куда попадают объекты, если namespace не указан |
| `kube-system` | Системные компоненты: CoreDNS, kube-proxy, CNI и т.д. |
| `kube-public` | Публично читаемые данные (редко используется) |
| `kube-node-lease` | Heartbeat-объекты нод (lease) для отслеживания их жизни |

> **Осторожно с `kube-system`.** Там живут критичные компоненты кластера. На экзамене
> туда лезут только по прямому заданию (например, поправить CoreDNS). Случайно удалить
> что-то в `kube-system` - способ сломать кластер.

## 6.3. Работа с namespace

```bash
# Посмотреть
kubectl get namespaces           # или ns
kubectl get ns

# Создать
kubectl create namespace dev

# Создать объект в namespace
kubectl run nginx --image=nginx -n dev
kubectl apply -f pod.yaml -n dev

# Посмотреть объекты в конкретном namespace / во всех
kubectl get pods -n dev
kubectl get pods -A              # --all-namespaces

# Удалить namespace (вместе со ВСЕМ содержимым!)
kubectl delete namespace dev
```

> **Важно.** `kubectl delete namespace` удаляет **всё** внутри него - все поды,
> сервисы, конфиги. Это необратимо. В проде это операция с высоким риском.

Чтобы не писать `-n dev` в каждой команде, можно назначить namespace по умолчанию для
текущего контекста:

```bash
kubectl config set-context --current --namespace=dev
```

Это сильно ускоряет работу на экзамене, если много задач в одном namespace.

```mermaid
flowchart LR
    a["Задача в namespace dev"] --> b["config set-context<br>--current --namespace=dev"]
    b --> c["теперь k get po<br>= k get po -n dev"]
    style a fill:#f4b400,color:#000
    style b fill:#326ce5,color:#fff
    style c fill:#0f9d58,color:#fff
```

## 6.4. Namespaced и cluster-scoped объекты

Не все объекты живут в namespace. Есть два класса:

- **Namespaced (в namespace):** поды, Deployment, Service, ConfigMap, Secret, PVC,
  Role и большинство рабочих объектов.
- **Cluster-scoped (общие для кластера):** ноды (Node), PersistentVolume, StorageClass,
  ClusterRole, сам Namespace, IngressClass.

```mermaid
flowchart TB
    subgraph NSscoped["В namespace"]
        direction TB
        n1["Pod, Deployment, ReplicaSet"] --> n2["Service, Ingress"] --> n3["ConfigMap, Secret"] --> n4["PVC, Role, RoleBinding"]
    end
    subgraph ClusterScoped["На уровне кластера"]
        direction TB
        c1["Node"] --> c2["PersistentVolume, StorageClass"] --> c3["Namespace"] --> c4["ClusterRole, ClusterRoleBinding"]
    end
    style NSscoped fill:#0f9d58,color:#fff
    style ClusterScoped fill:#326ce5,color:#fff
    style n1 fill:#3cb371,color:#fff
    style n2 fill:#3cb371,color:#fff
    style n3 fill:#3cb371,color:#fff
    style n4 fill:#3cb371,color:#fff
    style c1 fill:#5a8de0,color:#fff
    style c2 fill:#5a8de0,color:#fff
    style c3 fill:#5a8de0,color:#fff
    style c4 fill:#5a8de0,color:#fff
```

Проверить, какой объект в namespace, а какой нет:

```bash
kubectl api-resources --namespaced=true      # в namespace
kubectl api-resources --namespaced=false     # cluster-scoped
```

Это объясняет, почему `kubectl get nodes -n dev` игнорирует namespace: ноды - это
объекты уровня кластера.

## 6.5. Labels: как связываются объекты

**Label** - это пара ключ-значение, прикреплённая к объекту. Labels - главный
способ группировать и находить объекты в Kubernetes. Именно по labels:

- ReplicaSet/Deployment находят свои поды (глава 5);
- Service направляет трафик на нужные поды (глава 7);
- NetworkPolicy определяет, кого пускать (глава 34);
- вы сами фильтруете вывод `kubectl`.

```yaml
metadata:
  labels:
    app: web
    tier: frontend
    env: prod
    version: v2
```

```mermaid
flowchart TB
    svc["Service<br>selector: app=web"]
    np["NetworkPolicy<br>selector: app=web"]
    rs["ReplicaSet<br>selector: app=web"]
    pod["Pod<br>labels:<br>app=web<br>tier=frontend<br>env=prod"]
    svc -->|"app=web"| pod
    np -->|"app=web"| pod
    rs -->|"app=web"| pod
    style svc fill:#326ce5,color:#fff
    style np fill:#673ab7,color:#fff
    style rs fill:#0f9d58,color:#fff
    style pod fill:#f4b400,color:#000
```

Одна и та же label `app=web` связывает под сразу с несколькими объектами. Это и есть
сила labels: слабая, гибкая связь через совпадение, а не жёсткие ссылки по именам.

## 6.6. Работа с labels

```bash
# Показать labels
kubectl get pods --show-labels

# Добавить/изменить label живому объекту
kubectl label pod nginx env=prod
kubectl label pod nginx env=stage --overwrite   # перезаписать

# Удалить label (знак «минус» после ключа)
kubectl label pod nginx env-

# Фильтр по labels через selector
kubectl get pods -l app=web
kubectl get pods -l 'env in (prod,stage)'
kubectl get pods -l app=web,tier=frontend       # И (запятая = AND)
kubectl get pods -l '!version'                  # у кого НЕТ label version
```

## 6.7. Selectors: равенство и множества

Selector - это условие отбора по labels. Есть два вида.

**Equality-based (по равенству):** `=`, `==`, `!=`.

```yaml
selector:
  matchLabels:            # неявное И между условиями
    app: web
    tier: frontend
```

**Set-based (по множествам):** `in`, `notin`, `exists`.

```yaml
selector:
  matchExpressions:
  - {key: env, operator: In, values: [prod, stage]}
  - {key: tier, operator: NotIn, values: [test]}
  - {key: version, operator: Exists}
```

```mermaid
flowchart TB
    sel["Selector"]
    sel --> eq["Equality-based<br>matchLabels<br>app=web, tier=frontend"]
    sel --> set["Set-based<br>matchExpressions<br>env In (prod, stage)"]
    eq --> use1["Service, ReplicaSet<br>(простые случаи)"]
    set --> use2["Deployment, NetworkPolicy<br>(гибкие условия)"]
    style sel fill:#f4b400,color:#000
    style eq fill:#326ce5,color:#fff
    style set fill:#0f9d58,color:#fff
    style use1 fill:#5a8de0,color:#fff
    style use2 fill:#3cb371,color:#fff
```

Разные объекты используют разные виды: старые (Service, ReplicationController) - только
equality-based; более новые (Deployment, ReplicaSet, NetworkPolicy) поддерживают и
matchExpressions. На экзамене чаще всего достаточно `matchLabels`.

## 6.8. Annotations: метаданные не для отбора

**Annotation** - тоже пара ключ-значение, но с другой целью. Labels нужны
для **отбора** (по ним фильтруют и связывают), а annotations - для **хранения
вспомогательной информации**, по которой не отбирают.

| | Labels | Annotations |
|---|----------------|-------------------------|
| Назначение | отбор и группировка | хранение доп. данных |
| Используются selectors | да | нет |
| Типичные значения | короткие (`app=web`) | любые, вплоть до длинных |
| Примеры | `app`, `env`, `tier` | контакт владельца, git-commit, конфиг ingress-контроллера, чексуммы |

```bash
kubectl annotate pod nginx owner="team-web@corp.com"
kubectl annotate pod nginx description="temporary test pod"
kubectl annotate pod nginx owner-      # удалить annotation
```

Многие инструменты и контроллеры читают именно annotations: ingress-nginx настраивается
annotations на Ingress, различные операторы хранят в них своё состояние. Но для
selectors annotations недоступны - по ним нельзя выбрать объекты.

## 6.9. Практический кейс: namespace, labels и selectors вживую

Соберём концепции главы в одном коротком сценарии - его стоит прогнать руками, чтобы
увидеть, как namespace изолирует имена, а labels связывают объекты.

**1. Создаём namespace и делаем его текущим.**

```bash
kubectl create namespace shop
kubectl config set-context --current --namespace=shop   # больше не пишем -n shop
```

**2. Запускаем поды с разными labels.**

```bash
kubectl run web-1 --image=nginx --labels="app=web,tier=frontend"
kubectl run web-2 --image=nginx --labels="app=web,tier=frontend"
kubectl run api-1 --image=nginx --labels="app=api,tier=backend"
kubectl get pods --show-labels
```

Три пода в namespace `shop`, у первых двух `app=web`, у третьего `app=api`.

**3. Отбираем поды selector'ом.**

```bash
kubectl get pods -l app=web                 # только web-1, web-2
kubectl get pods -l tier=backend            # только api-1
kubectl get pods -l 'app in (web,api)'      # все три (set-based)
kubectl get pods -l app=web,tier=frontend   # И: оба условия сразу
```

Это тот самый механизм, по которому Service и ReplicaSet находят «свои» поды - вы
только что проделали то же самое руками.

**4. Меняем label и смотрим, как меняется отбор.**

```bash
kubectl label pod api-1 app=web --overwrite   # переклеили api-1 в группу web
kubectl get pods -l app=web                   # теперь три пода
```

Никаких жёстких ссылок - принадлежность к группе определяется только совпадением label.

**5. Вешаем annotation (не для отбора, а для данных).**

```bash
kubectl annotate pod web-1 owner="team-web@corp.com"
kubectl get pod web-1 -o jsonpath='{.metadata.annotations}'
kubectl get pods -l owner=team-web@corp.com   # НЕ сработает: по annotations не отбирают
```

Последняя команда ничего не найдёт - и это ожидаемо: selectors работают по labels, а не
по annotations.

**6. Проверяем изоляцию имён и убираем за собой.**

```bash
kubectl run web-1 --image=nginx -n default    # то же имя, но в другом namespace — ОК
kubectl delete namespace shop                 # удалит все поды внутри shop разом
kubectl config set-context --current --namespace=default
```

Одинаковое имя `web-1` спокойно живёт в `shop` и `default` - имена уникальны только
внутри своего namespace. А удаление namespace каскадно уносит всё его содержимое.

## 6.10. Как это применяют в продакшене

- **Namespace как граница команд и окружений.** В проде namespace - это единица
  организации, к которой привязывают политики: по ним нарезают RBAC-доступы, вешают
  ResourceQuota и NetworkPolicy, разделяют команды. Сам по себе namespace не изолирует -
  изоляцию дают эти политики поверх него. Часто структура такая: namespace на команду
  или на приложение, а окружения (dev/stage/prod) разносят по разным кластерам.
- **Единая схема labels - признак зрелости.** Рекомендованные labels Kubernetes
  (`app.kubernetes.io/name`, `app.kubernetes.io/version`, `app.kubernetes.io/component`,
  `app.kubernetes.io/part-of`) применяют, чтобы мониторинг, дашборды и политики работали
  единообразно. Хаос в labels → хаос в наблюдаемости и политиках.
- **Labels - основа маршрутизации, политик и стоимости.** По ним Service находит поды,
  NetworkPolicy ограничивает трафик, Prometheus группирует метрики, а FinOps-инструменты
  считают затраты (`team`, `cost-center`). Одна и та же label работает на всех уровнях.
- **Annotations для интеграций.** В проде annotations несут конфиг ingress-контроллеров,
  cert-manager, external-dns, Argo CD и др. - это стандартный способ «донастроить»
  объект под конкретный инструмент.
- **Удаление namespace - опасная операция.** Снос namespace уносит всё внутри. В проде
  это делают крайне осторожно, часто namespace защищают от случайного удаления.

## 6.11. Мини-глоссарий

- **Namespace (неймспейс)** - раздел кластера; имена объектов уникальны внутри него.
- **default / kube-system / kube-public / kube-node-lease** - системные namespace.
- **Namespaced-объект** - живёт в namespace (Pod, Deployment, Service, ...).
- **Cluster-scoped объект** - на уровне кластера (Node, PV, StorageClass, ClusterRole).
- **Label (метка)** - пара ключ-значение для отбора и связывания объектов.
- **Selector (селектор)** - условие отбора по labels (equality- или set-based).
- **matchLabels / matchExpressions** - две формы selector.
- **Annotation (аннотация)** - пара ключ-значение для доп. данных, не для отбора.

## 6.12. Итоги главы

- Namespace логически делит кластер на группы ресурсов (область имён), а не изолирует
  их сам по себе; имена уникальны в пределах namespace, поэтому одинаковые имена в
  разных namespace не конфликтуют. Изоляцию дают NetworkPolicy/ResourceQuota/RBAC поверх.
- Системные namespace: `default` (по умолчанию), `kube-system` (компоненты),
  `kube-public`, `kube-node-lease`. В `kube-system` лезть осторожно.
- Namespace по умолчанию для контекста ставится через `config set-context --current
  --namespace=` - экономит время.
- Объекты бывают namespaced (Pod, Deployment...) и cluster-scoped (Node, PV,
  ClusterRole...); проверка - `kubectl api-resources --namespaced`.
- Labels - главный механизм связи: по ним работают Service, ReplicaSet, NetworkPolicy,
  фильтрация `kubectl -l`.
- Selectors бывают equality-based (`matchLabels`) и set-based (`matchExpressions`).
- Annotations хранят вспомогательные данные и не используются selectors; их читают
  многие инструменты и контроллеры.

## 6.13. Как это пригодится: на экзамене и в реальной работе

**На экзамене.** Почти каждое задание указывает namespace («создай в `web-ns`») -
забыть про `-n` значит сделать не там и потерять баллы. Работа с labels и selectors
встречается постоянно: связать Service с подами, отфильтровать `kubectl get -l`,
настроить selector деплоя или NetworkPolicy. `kubectl label`/`annotate` - базовые
императивные операции.

**В реальной работе.** Namespace - это граница, к которой привязывают модель доступов,
квот и сетевых политик (сам он ничего не изолирует, изоляцию дают RBAC/ResourceQuota/NetworkPolicy).
Labels - это «клей» всей системы: маршрутизация, сетевые политики, мониторинг и учёт
затрат держатся на них, поэтому продуманная схема labels критична. Annotations -
стандартный способ интеграции с ingress-контроллерами, cert-manager, GitOps-инструментами.

## 6.14. Вопросы для самопроверки

1. Зачем нужны namespace и почему одинаковые имена объектов в разных namespace не
   конфликтуют?
2. Назовите системные namespace и что лежит в `kube-system`.
3. Как задать namespace по умолчанию, чтобы не писать `-n` каждый раз?
4. Чем namespaced-объекты отличаются от cluster-scoped? Приведите примеры каждого.
5. Как labels связывают под с Service, ReplicaSet и NetworkPolicy одновременно?
6. В чём разница между `matchLabels` и `matchExpressions`?
7. Чем annotations отличаются от labels и почему по annotations нельзя отбирать объекты?

## Практика

Мы разобрались, как организованы и связаны ресурсы. В главе 7 применим labels на деле -
свяжем Service с подами по selector. Namespaces, labels, selectors, поды и Deployment
сойдутся в первой объединённой лабораторной работе.

🧪 Лаба 101 (namespaces, labels, selectors): [tasks/cka/labs/101](../../labs/101/README_RU.MD)

---
[Оглавление](../README_RU.md) · [Глава 5](../05/ru.md) · [Глава 7](../07/ru.md)
