# Глава 8. Deployment: rolling update и rollback

> **Что дальше.** В главе 5 мы поняли, что Deployment управляет ReplicaSet'ами и умеет
> обновлять приложение. Теперь разберём это умение детально: как Deployment плавно
> выкатывает новую версию без простоя (rolling update), как настраивается скорость и
> «безопасность» раскатки (maxSurge/maxUnavailable), как приостановить и откатить
> релиз. Это ядро домена Workloads (обоих экзаменов) и Application Deployment (CKAD).
> Понимание rollout - то, что отличает уверенного инженера от «запустил и молюсь».

## 8.1. Зачем нужны плавные обновления

Обновить приложение можно наивно: убить все старые Pods и поднять новые. Но тогда между
«убили» и «подняли» будет простой - пользователи получают ошибки. В проде это
недопустимо. Нужен способ заменять Pods **постепенно**, чтобы часть старых всегда
обслуживала трафик, пока поднимаются новые.

```mermaid
flowchart LR
    subgraph Bad["Наивно (Recreate): простой"]
        direction TB
        b1["убить все v1"] --> b2["ПРОСТОЙ"] --> b3["поднять все v2"]
    end
    subgraph Good["RollingUpdate: без простоя"]
        direction TB
        g1["3×v1"] --> g2["2×v1 + 1×v2"] --> g3["1×v1 + 2×v2"] --> g4["3×v2"]
    end
    style Bad fill:#db4437,color:#fff
    style Good fill:#0f9d58,color:#fff
    style b2 fill:#c0392b,color:#fff
    style g1 fill:#3cb371,color:#fff
    style g2 fill:#3cb371,color:#fff
    style g3 fill:#3cb371,color:#fff
    style g4 fill:#3cb371,color:#fff
```

Именно это делает стратегия **RollingUpdate** - и она стоит по умолчанию.

## 8.2. Две стратегии: RollingUpdate и Recreate

У Deployment есть поле `spec.strategy.type` с двумя вариантами.

| Стратегия | Как работает | Простой | Когда |
|-----------|--------------|---------|-------|
| **RollingUpdate** (по умолчанию) | постепенно заменяет Pods партиями | нет | почти всегда |
| **Recreate** | убивает все старые, потом создаёт новые | да | когда версии не могут сосуществовать (например, несовместимая схема БД) |

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%          # насколько можно превысить желаемое число Pods
      maxUnavailable: 25%    # сколько Pods можно временно «потерять»
```

## 8.3. maxSurge и maxUnavailable: управляем раскаткой

Два параметра точно настраивают ход rolling update. Их часто спрашивают.

- **`maxSurge`** - сколько Pods **сверх** желаемого можно создать во время выката.
  Больше surge → быстрее выкатка, но нужно больше ресурсов.
- **`maxUnavailable`** - сколько Pods из желаемого числа может быть **недоступно** в
  процессе. Больше → быстрее, но меньше запас мощности во время релиза.

Оба задаются числом или процентом.

```mermaid
flowchart TB
    d["Deployment: replicas=4<br>maxSurge=1, maxUnavailable=1"]
    d --> state["В любой момент раскатки:<br>минимум 3 доступных (4−1)<br>максимум 5 всего (4+1)"]
    style d fill:#326ce5,color:#fff
    style state fill:#0f9d58,color:#fff
```

Крайние настройки:

- `maxUnavailable: 0` + `maxSurge: 1` - самый безопасный вариант: сначала поднимается
  новый Pod, только потом гасится старый. Никогда не теряем мощность, но нужен запас
  ресурсов на +1 Pod.
- `maxUnavailable: 25%` + `maxSurge: 25%` (по умолчанию) - баланс скорости и
  безопасности.

## 8.4. Как запустить обновление

Обновление Deployment запускается любым изменением его **шаблона Pod** (`spec.template`).
Чаще всего меняют образ:

```bash
# Сменить образ — самый частый триггер rollout
kubectl set image deployment/web nginx=nginx:1.28

# Или отредактировать шаблон целиком
kubectl edit deployment web

# Или применить обновлённый манифест
kubectl apply -f deploy.yaml
```

Что происходит под капотом (вспомним иерархию из главы 5):

```mermaid
sequenceDiagram
    participant U as kubectl
    participant D as Deployment
    participant RSold as ReplicaSet v1
    participant RSnew as ReplicaSet v2
    U->>D: set image nginx=nginx:1.28
    D->>RSnew: создать новый ReplicaSet (v2), replicas растут
    D->>RSold: replicas старого уменьшаются
    Note over RSnew,RSold: партиями, по maxSurge/maxUnavailable
    RSnew-->>D: все новые Pods Ready
    D->>RSold: replicas = 0 (но ReplicaSet сохранён для отката)
    D-->>U: rollout завершён
```

Ключевое: старый ReplicaSet **не удаляется**, а остаётся с нулём реплик. Именно
поэтому возможен мгновенный откат.

## 8.5. Наблюдение за раскаткой

```bash
# Следить за ходом выката
kubectl rollout status deployment/web

# История ревизий
kubectl rollout history deployment/web

# Детали конкретной ревизии
kubectl rollout history deployment/web --revision=2

# Видно оба ReplicaSet: старый (0 Pods) и новый
kubectl get rs
```

`kubectl rollout status` блокируется до завершения выката и показывает прогресс - удобно
понимать, «доехало» ли обновление. Если выкат «застрял» (новые Pods не проходят
readiness), status это покажет.

## 8.6. Rollback: откат на предыдущую версию

Раскатили плохую версию - откатываемся. Так как старый ReplicaSet жив, откат почти
мгновенный: Deployment просто снова наращивает старый ReplicaSet и гасит новый.

```bash
# Откатить на предыдущую ревизию
kubectl rollout undo deployment/web

# Откатить на конкретную ревизию
kubectl rollout undo deployment/web --to-revision=2
```

```mermaid
flowchart TB
    bad["Выкачена v2 —<br>оказалась битой"] --> undo["kubectl rollout undo"]
    undo --> back["ReplicaSet v1<br>наращивается<br>до replicas,<br>v2 гасится"]
    back --> ok["снова работает v1"]
    style bad fill:#db4437,color:#fff
    style undo fill:#326ce5,color:#fff
    style back fill:#f4b400,color:#000
    style ok fill:#0f9d58,color:#fff
```

> **Про историю ревизий.** Чтобы в истории было видно, *что* менялось, полезно писать
> причину изменения. Раньше для этого был флаг `--record` (сейчас устарел); теперь
> используют аннотацию `kubernetes.io/change-cause`. Глубину истории задаёт
> `spec.revisionHistoryLimit` (по умолчанию 10 старых ReplicaSet хранятся).

Как правильно добавлять причину в историю сейчас - через аннотацию
`kubernetes.io/change-cause`. Есть два способа.

**Способ 1: аннотировать после изменения (быстро, императивно).**

```bash
# делаем изменение
kubectl set image deployment/web nginx=nginx:1.28
# сразу проставляем причину этой ревизии
kubectl annotate deployment/web kubernetes.io/change-cause="update nginx to 1.28" --overwrite
```

**Способ 2: задать аннотацию прямо в манифесте (декларативно, для GitOps).**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  annotations:
    kubernetes.io/change-cause: "update nginx to 1.28"   # причина попадёт в историю
spec:
  # ...
```

После этого причина видна в колонке `CHANGE-CAUSE`:

```bash
kubectl rollout history deployment/web
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         update nginx to 1.28
```

> **Нюанс.** Аннотацию `change-cause` надо ставить **на каждое** новое изменение
> (перезаписывая `--overwrite` или правя манифест) - она описывает текущую ревизию, а не
> копится сама. Если её не обновить, новая ревизия унаследует старую причину.

## 8.7. Пауза и возобновление раскатки

Иногда нужно внести несколько изменений и выкатить их разом, а не запускать rollout на
каждое. Для этого раскатку можно приостановить:

```bash
kubectl rollout pause deployment/web     # заморозить выкаты
kubectl set image deployment/web nginx=nginx:1.28
kubectl set resources deployment/web -c nginx --limits=cpu=200m,memory=128Mi
kubectl rollout resume deployment/web    # применить всё разом одним выкатом
```

Пока Deployment на паузе, изменения шаблона копятся, но не выкатываются. `resume`
запускает один общий rolling update со всеми накопленными правками. Полезно, чтобы не
плодить лишние ревизии.

## 8.8. Диагностика застрявшего выката

Выкат может «зависнуть» - новые Pods не становятся готовыми. Типичные причины:

```mermaid
flowchart LR
    stuck["rollout завис<br>(status не<br>завершается)"]
    stuck --> c1["битый образ /<br>опечатка в теге<br>→ ImagePullBackOff"]
    stuck --> c2["падает при старте<br>→ CrashLoopBackOff"]
    stuck --> c3["не проходит readiness<br>→ Pod не Ready,<br>нет в Endpoints"]
    stuck --> c4["мало ресурсов/квоты<br>→ Pods Pending"]
    style stuck fill:#db4437,color:#fff
    style c1 fill:#e8a838,color:#000
    style c2 fill:#e8a838,color:#000
    style c3 fill:#e8a838,color:#000
    style c4 fill:#e8a838,color:#000
```

Порядок разбора (используем навыки главы 4):

```bash
kubectl rollout status deployment/web        # видим, что застряло
kubectl get pods                              # какие STATUS у новых Pods
kubectl describe pod <новый-Pod>              # Events: причина
kubectl logs <новый-Pod> --previous           # если падает
kubectl rollout undo deployment/web           # если нужно быстро вернуться
```

Хорошая новость: при застрявшем rolling update старые Pods остаются работать (в пределах
maxUnavailable), поэтому сервис обычно продолжает отвечать - есть время разобраться или
откатиться.

## 8.9. Практический кейс

### Часть 1. Rolling update и rollback вживую

Прогоните сценарий руками, чтобы увидеть, как Deployment переносит Pods со старого
ReplicaSet на новый и как работает мгновенный откат.

```bash
# 1. Разворачиваем v1
kubectl create deployment web --image=nginx:1.27 --replicas=4
kubectl rollout status deployment/web

# 2. Запускаем обновление на v2 и следим за раскаткой
kubectl set image deployment/web nginx=nginx:1.28
kubectl rollout status deployment/web
kubectl get rs                        # два ReplicaSet: старый с 0, новый с 4

# 3. История ревизий
kubectl rollout history deployment/web

# 4. Ломаем выкат заведомо битым образом — увидим «застрявший» rollout
kubectl set image deployment/web nginx=nginx:does-not-exist
kubectl rollout status deployment/web --timeout=30s   # не завершится
kubectl get pods                      # новый Pod в ImagePullBackOff, старые ещё работают

# 5. Откатываемся на прошлую рабочую версию
kubectl rollout undo deployment/web
kubectl rollout status deployment/web

# 6. Уборка
kubectl delete deployment web
```

Обратите внимание на шаг 4: пока новый Pod не может подняться, старые остаются в работе
(в пределах `maxUnavailable`) - сервис продолжает отвечать, и есть время откатиться.

### Часть 2. Экзаменационный кейс: 10% Pods на новой версии (ручной canary)

**Условие (частый тип задания).** Есть Deployment `web` с образом `myapp:1` и `10`
репликами, перед ним - Service, выбирающий Pods по label `app=web`. Нужно, чтобы **10%
Pods** обслуживались новой версией `myapp:2`, а остальные 90% остались на `myapp:1`.

**Идея решения.** 10% от 10 Pods - это 1 Pod. Rolling update здесь не подходит (он
заменит *все* Pods на новую версию). Нужен **ручной canary**: держать две параллельные
рабочие нагрузки за одним Service. Для этого создаём **второй** Deployment на базе
первого - с образом `myapp:2` и `1` репликой, - а у основного уменьшаем реплики до `9`.
Оба набора Pods сохраняют общий label `app=web`, поэтому Service балансирует трафик на
все 10 Pods, и примерно 10% попадает на v2.

```mermaid
flowchart TB
    svc["Service web<br>selector: app=web"]
    subgraph stable["Deployment web (stable)"]
        s["9 × Pod<br>myapp:1<br>app=web, track=stable"]
    end
    subgraph canary["Deployment web-canary"]
        c["1 × Pod<br>myapp:2<br>app=web, track=canary"]
    end
    svc --> s
    svc --> c
    style svc fill:#326ce5,color:#fff
    style stable fill:#0f9d58,color:#fff
    style canary fill:#673ab7,color:#fff
    style s fill:#3cb371,color:#fff
    style c fill:#9c27b0,color:#fff
```

**Важная тонкость с labels.** Service выбирает Pods по **общему** label `app=web` - он
должен быть у Pods обоих Deployment, иначе Service их не увидит. При этом у каждого
Deployment свой `selector` должен уникально описывать *его* Pods, поэтому добавляем
различающий label (`track`): `track=stable` у основного и `track=canary` у второго.

**Шаги решения.**

```bash
# Дано (для воспроизведения): основной Deployment на 10 реплик v1
kubectl create deployment web --image=myapp:1 --replicas=10
kubectl label deployment web track=stable            # различающий label (при необходимости)

# 1. Уменьшаем основной Deployment: 10 → 9 реплик (это будущие 90%)
kubectl scale deployment web --replicas=9

# 2. Делаем манифест canary на основе первого
kubectl get deployment web -o yaml > canary.yaml
```

В `canary.yaml` меняем:

- `metadata.name`: `web` → `web-canary`;
- `spec.replicas`: `1`;
- образ контейнера: `myapp:1` → `myapp:2`;
- в `spec.selector.matchLabels` и `spec.template.metadata.labels` добавляем
  `track: canary` (и **оставляем** общий `app: web`);
- удаляем из файла `status`, `metadata.uid`, `resourceVersion`, `creationTimestamp`.

```yaml
# ключевые поля canary.yaml (сокращённо)
metadata:
  name: web-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web            # общий label — по нему выбирает Service
      track: canary       # различающий label — уникальный selector этого Deployment
  template:
    metadata:
      labels:
        app: web
        track: canary
    spec:
      containers:
      - name: myapp
        image: myapp:2
```

```bash
# 3. Применяем canary
kubectl apply -f canary.yaml

# 4. Проверяем: всего 10 Pods, из них 1 на v2 (10%)
kubectl get pods -l app=web -o wide
kubectl get pods -l app=web,track=canary        # ровно 1 Pod v2
kubectl get endpoints web                        # Service видит все 10 Pods
```

Итог: за одним Service работают 9 Pods `myapp:1` и 1 Pod `myapp:2` - ровно 10% трафика
уходит на новую версию. Долю меняют, просто масштабируя два Deployment (например, 8+2 =
20%). Убедившись, что v2 здорова, доводят canary до полного объёма и убирают старый
Deployment - это ручной аналог того, что автоматизируют Argo Rollouts/Flagger (раздел
8.10).

## 8.10. Как это применяют в продакшене

- **RollingUpdate - стандарт, но с настройкой.** В проде почти всегда rolling update,
  но параметры подбирают под сервис: для критичных ставят `maxUnavailable: 0`
  (не терять мощность), для менее важных допускают более быструю раскатку.
- **readiness-пробы обязательны для безопасного выката.** Без корректной readiness-пробы
  Kubernetes считает Pod готовым сразу и может увести трафик на ещё не прогретое
  приложение. Rolling update по-настоящему безопасен только с правильными пробами
  (глава 27).
- **Автоматизация и прогрессивная доставка.** Ручной `set image` в проде - редкость.
  Обычно выкат идёт через CI/CD и GitOps (Argo CD/Flux), а для более тонких сценариев -
  через canary/blue-green (глава 9) и инструменты вроде Argo Rollouts/Flagger, которые
  сами следят за метриками и откатывают при деградации.
- **Откат - часть плана релиза.** Опытные команды заранее знают команду отката и держат
  `revisionHistoryLimit` достаточным, чтобы откатиться на несколько версий назад. Быстрый
  `rollout undo` - страховка на случай плохого релиза.
- **change-cause для аудита.** В истории ревизий фиксируют причину изменения, чтобы при
  разборе инцидента понимать, что и зачем выкатывали.

## 8.11. Мини-глоссарий

- **RollingUpdate** - стратегия постепенной замены Pods без простоя (по умолчанию).
- **Recreate** - стратегия «убить все, потом создать»; с простоем.
- **maxSurge** - сколько Pods можно создать сверх желаемого во время выката.
- **maxUnavailable** - сколько Pods можно временно потерять во время выката.
- **rollout** - процесс выката новой версии Deployment.
- **Ревизия (revision)** - зафиксированная версия шаблона Deployment в истории.
- **rollback** - откат на предыдущую ревизию (`rollout undo`).
- **revisionHistoryLimit** - сколько старых ReplicaSet хранить для отката.
- **change-cause** - аннотация с причиной изменения для истории.

## 8.12. Итоги главы

- Наивная замена «убить все / поднять новые» даёт простой; RollingUpdate заменяет Pods
  постепенно, без простоя (стратегия по умолчанию).
- Recreate нужен, когда версии не могут сосуществовать; ценой простоя.
- `maxSurge` (сколько сверх желаемого) и `maxUnavailable` (сколько можно потерять)
  управляют скоростью и безопасностью выката; `maxUnavailable: 0` + `maxSurge: 1` -
  самый безопасный вариант.
- Rollout запускается изменением шаблона Pod (чаще всего `set image`); Deployment
  создаёт новый ReplicaSet и гасит старый, оставляя его для отката.
- Наблюдение: `rollout status`, `rollout history`, `get rs`.
- Откат почти мгновенный (`rollout undo`), потому что старый ReplicaSet сохранён.
- Раскатку можно приостановить (`pause`) и применить накопленные изменения разом
  (`resume`).
- Застрявший выкат разбирают через describe/logs новых Pods; старые Pods при этом
  обычно продолжают обслуживать трафик.

## 8.13. Как это пригодится: на экзамене и в реальной работе

**На экзамене.** Прямые задания: «обнови образ деплоя», «откати на предыдущую версию»,
«настрой maxSurge/maxUnavailable», «почему выкат не завершается». Команды `set image`,
`rollout status/history/undo`, `rollout pause/resume` - обязательный минимум домена
Workloads/Deployment. Диагностика застрявшего rollout опирается на навыки отладки Pods.

**В реальной работе.** Rolling update - то, как ежедневно выкатывают новые версии без
простоя. Понимание maxSurge/maxUnavailable и роли readiness-проб определяет, будет ли
релиз безопасным. Быстрый откат - страховка при плохом релизе, а прогрессивная доставка
(canary/blue-green, Argo Rollouts) строится поверх этих же механизмов.

## 8.14. Вопросы для самопроверки

1. Чем RollingUpdate отличается от Recreate и когда оправдан каждый?
2. Что задают `maxSurge` и `maxUnavailable`? Какая их комбинация самая безопасная?
3. Какое действие запускает rollout Deployment? Что происходит со старым ReplicaSet?
4. Как посмотреть ход выката и историю ревизий?
5. Почему откат (`rollout undo`) выполняется почти мгновенно?
6. Зачем нужны `rollout pause`/`resume`?
7. Назовите частые причины застрявшего выката и порядок их диагностики.
8. Есть Deployment с 10 репликами v1 за одним Service. Как сделать, чтобы 10% Pods
   работали на v2, не переводя на неё весь Deployment? Почему тут не подходит обычный
   rolling update и какую роль играют labels?

## Практика

Мы умеем безопасно обновлять и откатывать приложения. В главе 9 (CKAD) разберём более
продвинутые стратегии - canary и blue/green - которые строятся поверх этих механизмов.
Обновления и откаты Deployment отрабатываются в лабах по рабочим нагрузкам.

🧪 Лаба 102 (rolling update и rollback): [tasks/cka/labs/102](../../labs/102/README_RU.MD)

---
[Оглавление](../README_RU.md) · [Глава 7](../07/ru.md) · [Глава 9](../09/ru.md)
