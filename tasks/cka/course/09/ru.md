# Глава 9. Стратегии развёртывания: blue/green и canary

> 🟩 **Это глава для CKAD** (домен Application Deployment). Для CKA она полезна как
> общее понимание, но прямых заданий там обычно нет.
>
> **Что дальше.** В главе 8 мы освоили встроенный rolling update. Но иногда нужен более
> тонкий контроль над релизом: выпустить новую версию на маленькую долю пользователей и
> посмотреть на метрики (**canary**), или держать две полные среды и переключиться
> мгновенно (**blue/green**). Важный момент: у Kubernetes **нет** отдельных объектов
> «CanaryDeployment» или «BlueGreenDeployment» - эти стратегии собираются из уже
> знакомых кирпичей (Deployment, Service, labels). CKAD как раз проверяет умение
> реализовать их примитивами.

## 9.1. Зачем нужны стратегии сверх rolling update

Rolling update плавно заменяет Pods, но у него ограниченный контроль: вы не можете
сказать «пусти ровно 5% трафика на новую версию и подержи так час». Все запросы во время
выката случайно попадают то на старые, то на новые Pods. Для рискованных релизов этого
мало - хочется:

- **проверить новую версию на реальном, но маленьком трафике** перед полной раскаткой
  (canary);
- **иметь возможность мгновенно переключиться туда и обратно** между версиями
  (blue/green).

```mermaid
flowchart TB
    q["Как выкатывать?"]
    q -->|"постепенно заменить,<br>без тонкого контроля"| ru["RollingUpdate<br>(встроено, глава 8)"]
    q -->|"обкатать на малой доле<br>трафика, затем расширять"| can["Canary"]
    q -->|"две полные среды,<br>мгновенное переключение"| bg["Blue/Green"]
    style q fill:#f4b400,color:#000
    style ru fill:#0f9d58,color:#fff
    style can fill:#326ce5,color:#fff
    style bg fill:#673ab7,color:#fff
```

## 9.2. Ключевая идея: Service выбирает Pods по labels

Всё строится на механизме из глав 6-7: **Service направляет трафик на Pods, чьи labels
совпадают с его selector**. Значит, управляя labels Pods и selector Service, мы
управляем тем, куда идёт трафик. Это и есть рычаг для обеих стратегий.

```mermaid
flowchart TB
    svc["Service<br>selector: app=web"]
    v1["Pods<br>app=web<br>version=v1"]
    v2["Pods<br>app=web<br>version=v2"]
    svc -->|"app=web"| v1
    svc -->|"app=web"| v2
    note["Selector смотрит<br>только на app=web,<br>поэтому ловит<br>ОБЕ версии"]
    style svc fill:#326ce5,color:#fff
    style v1 fill:#0f9d58,color:#fff
    style v2 fill:#673ab7,color:#fff
    style note fill:#f4b400,color:#000
```

Если selector Service шире (`app=web`), а версии различаются доп. label
(`version=v1`/`v2`), то один Service распределяет трафик по обеим версиям пропорционально
числу их Pods. Если selector узкий (`app=web,version=v1`), Service бьёт строго в одну
версию. На этом и играют стратегии.

## 9.3. Canary: обкатка на малой доле трафика

**Canary** («канарейка» - как птица, которую брали в шахту для проверки воздуха) - это
выпуск новой версии для небольшой части трафика. Смотрим на ошибки и задержки; если всё
хорошо - постепенно наращиваем долю новой версии и убираем старую.

Простейшая реализация примитивами: один Service с широким selector и два Deployment
(старый и новый) с общим label, но разным `version`. Доля трафика ≈ доля Pods.

```mermaid
flowchart TB
    svc["Service selector: app=web"]
    subgraph stable["web-stable v1"]
        s1["Pod"]
        s2["Pod"]
        s3["Pod"]
    end
    subgraph canary["web-canary v2"]
        c1["Pod"]
    end
    svc -->|"≈75% (3 из 4)"| stable
    svc -->|"≈25% (1 из 4)"| canary
    style svc fill:#326ce5,color:#fff
    style stable fill:#0f9d58,color:#fff
    style canary fill:#673ab7,color:#fff
    style s1 fill:#3cb371,color:#fff
    style s2 fill:#3cb371,color:#fff
    style s3 fill:#3cb371,color:#fff
    style c1 fill:#9c27b0,color:#fff
```

Оба Deployment имеют у Pods label `app: web` (его ловит Service) и различаются label
`version`:

```yaml
# web-stable: 3 реплики, version=v1
# web-canary: 1 реплика, version=v2   → ~25% трафика
```

Продвижение canary - это управление числом реплик: наращиваем canary, уменьшаем stable,
пока canary не станет 100%. Затем canary становится новым stable.

```mermaid
flowchart TB
    a["stable=3, canary=1 → 25% на v2"] --> b["stable=2, canary=2 → 50%"] --> c["stable=1, canary=3 → 75%"] --> d["stable=0, canary=4 → 100% на v2"]
    style a fill:#0f9d58,color:#fff
    style b fill:#0f9d58,color:#fff
    style c fill:#0f9d58,color:#fff
    style d fill:#673ab7,color:#fff
```

> **Ограничение примитивов.** Доля трафика тут завязана на *число Pods*, а не на точный
> процент запросов. Точное «5% запросов по заголовку» дают service mesh (Istio, курс
> ICA) или Ingress с canary-аннотациями/Gateway API. Но на CKAD ожидается именно
> реализация примитивами - через число реплик и labels.

## 9.4. Blue/Green: две среды и мгновенное переключение

**Blue/green** - держим одновременно две полные версии: **blue** (текущая, в
проде) и **green** (новая). Трафик идёт только на одну из них. Развернули green,
проверили её отдельно, затем **переключили Service** с blue на green одним движением -
сменой selector. Если что-то не так - так же мгновенно переключаемся обратно.

```mermaid
flowchart TB
    subgraph Before["До переключения"]
        svcB["Service<br>selector:<br>version=blue"]
        blueB["Deployment<br>blue (v1)"]
        greenB["Deployment green (v2)<br>развёрнут,<br>но без трафика"]
        svcB --> blueB
    end
    subgraph After["После переключения"]
        svcA["Service<br>selector:<br>version=green"]
        blueA["Deployment blue (v1)<br>ещё жив,<br>для отката"]
        greenA["Deployment<br>green (v2)"]
        svcA --> greenA
    end
    Before -->|"сменили selector<br>blue → green"| After
    style Before fill:#4a90d9,color:#fff
    style After fill:#0f9d58,color:#fff
    style svcB fill:#326ce5,color:#fff
    style svcA fill:#326ce5,color:#fff
    style blueB fill:#5a8de0,color:#fff
    style greenB fill:#9e9e9e,color:#fff
    style blueA fill:#9e9e9e,color:#fff
    style greenA fill:#2e7d32,color:#fff
```

Переключение - это одно изменение selector Service:

```bash
# было: selector version=blue → стало version=green
kubectl patch service web -p '{"spec":{"selector":{"version":"green"}}}'
```

Откат так же мгновенен - вернуть selector на `blue`. Blue остаётся развёрнутым до тех
пор, пока не убедимся в стабильности green.

## 9.5. Canary против blue/green: сравнение

```mermaid
flowchart TB
    subgraph Canary["Canary"]
        direction TB
        ca1["часть трафика<br>на новую версию"] --> ca2["постепенное<br>наращивание"] --> ca3["нужно немного<br>ресурсов сверх"]
    end
    subgraph BG["Blue/Green"]
        direction TB
        bg1["весь трафик разом<br>переключается"] --> bg2["мгновенный<br>откат"] --> bg3["нужно 2× ресурсов<br>(две среды)"]
    end
    style Canary fill:#326ce5,color:#fff
    style BG fill:#673ab7,color:#fff
    style ca1 fill:#5a8de0,color:#fff
    style ca2 fill:#5a8de0,color:#fff
    style ca3 fill:#5a8de0,color:#fff
    style bg1 fill:#9c27b0,color:#fff
    style bg2 fill:#9c27b0,color:#fff
    style bg3 fill:#9c27b0,color:#fff
```

| Критерий | Canary | Blue/Green |
|----------|--------|------------|
| Доля трафика на новую версию | растёт постепенно | 0%, потом сразу 100% |
| Скорость отката | наращивание обратно | мгновенно (смена selector) |
| Расход ресурсов | небольшой избыток | ~двойной (две полные среды) |
| Риск на пользователей | ограничен долей canary | весь трафик разом (но проверено заранее) |
| Сложность | среднее (управление репликами) | простое переключение, но дорого по ресурсам |

## 9.6. Практический кейс

### Часть 1. Canary примитивами

Соберём canary руками: один Service на обе версии и два Deployment с общим label
`app=web`, но разным `version`.

```bash
# 0. namespace для чистоты
kubectl create namespace rel && kubectl config set-context --current --namespace=rel

# 1. Service, который смотрит ТОЛЬКО на app=web (ловит обе версии)
kubectl create service clusterip web --tcp=80:80
kubectl patch svc web -p '{"spec":{"selector":{"app":"web"}}}'

# 2. stable-версия: 3 реплики v1 (label app=web, version=v1)
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata: {name: web-stable, namespace: rel}
spec:
  replicas: 3
  selector: {matchLabels: {app: web, version: v1}}
  template:
    metadata: {labels: {app: web, version: v1}}
    spec:
      containers:
      - {name: web, image: nginx:1.27}
EOF

# 3. canary-версия: 1 реплика v2 (label app=web, version=v2) → ~25% трафика
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata: {name: web-canary, namespace: rel}
spec:
  replicas: 1
  selector: {matchLabels: {app: web, version: v2}}
  template:
    metadata: {labels: {app: web, version: v2}}
    spec:
      containers:
      - {name: web, image: nginx:1.28}
EOF
```

Проверяем, что Service видит все 4 Pod (3 stable + 1 canary):

```bash
kubectl get pods -l app=web --show-labels        # 4 Pod, у одного version=v2
kubectl get endpoints web                         # 4 адреса за Service
```

Продвижение canary - просто меняем число реплик, пока v2 не станет 100%:

```bash
kubectl scale deployment web-canary --replicas=2   # ~50%
kubectl scale deployment web-stable --replicas=2
kubectl scale deployment web-canary --replicas=4   # 100% на v2
kubectl scale deployment web-stable --replicas=0
```

### Часть 2. Blue/Green переключением selector

```bash
# 1. blue (текущая) и green (новая) — две полные версии, различаются label version
kubectl create deployment blue  --image=nginx:1.27 -n rel
kubectl create deployment green --image=nginx:1.28 -n rel
kubectl patch deployment blue  -n rel --type=merge \
  -p '{"spec":{"template":{"metadata":{"labels":{"version":"blue"}}}}}'
kubectl patch deployment green -n rel --type=merge \
  -p '{"spec":{"template":{"metadata":{"labels":{"version":"green"}}}}}'

# 2. Service сначала смотрит только на blue
kubectl create service clusterip bg --tcp=80:80 -n rel
kubectl patch svc bg -n rel -p '{"spec":{"selector":{"version":"blue"}}}'
kubectl get endpoints bg                          # только Pod blue

# 3. Переключаем трафик на green ОДНИМ движением
kubectl patch svc bg -n rel -p '{"spec":{"selector":{"version":"green"}}}'
kubectl get endpoints bg                          # теперь только Pod green

# 4. Откат так же мгновенен
kubectl patch svc bg -n rel -p '{"spec":{"selector":{"version":"blue"}}}'
```

Уборка:

```bash
kubectl delete namespace rel
```

Обратите внимание: в blue/green трафик в каждый момент идёт строго на одну версию
(переключает `selector` Service), а в canary - на обе сразу, в пропорции числа Pods.

## 9.7. Как это применяют в продакшене

- **Примитивы - только основа.** В реальном проде «ручные» canary/blue-green на числе
  реплик применяют редко: доля трафика неточная, а управлять руками неудобно. Обычно
  берут инструменты, которые делают это автоматически и по метрикам.
- **Прогрессивная доставка.** Argo Rollouts и Flagger вводят объект Rollout с встроенными
  стратегиями canary/blue-green: они сами меняют веса, следят за метриками (ошибки,
  задержки из Prometheus) и **автоматически откатывают** при деградации. Это стандарт
  зрелых команд.
- **Точный трафик - через mesh/ingress.** Точное «5% запросов» или «canary по заголовку
  для тестировщиков» делают на уровне Ingress (canary-аннотации nginx), Gateway API
  (веса) или service mesh (Istio - отдельный курс ICA). Там доля не зависит от числа
  Pods.
- **Blue/green для рискованных миграций.** Когда нельзя, чтобы версии сосуществовали,
  или нужен мгновенный полный откат, выбирают blue/green - ценой удвоенных ресурсов на
  время релиза.
- **Стоимость против безопасности.** Выбор стратегии - всегда компромисс: canary дешевле
  по ресурсам, но сложнее в оркестрации; blue/green проще и безопаснее по переключению,
  но дороже.

## 9.8. Мини-глоссарий

- **Canary** - выпуск новой версии для небольшой доли трафика с постепенным наращиванием.
- **Blue/Green** - две полные среды (текущая и новая) с мгновенным переключением трафика.
- **Blue** - текущая рабочая версия; **Green** - новая, готовящаяся к переключению.
- **Прогрессивная доставка** - автоматизированные canary/blue-green по метрикам (Argo
  Rollouts, Flagger).
- **Переключение selector** - смена `selector` Service для мгновенного перевода трафика
  на другую версию (основа blue/green).

## 9.9. Итоги главы

- В Kubernetes нет отдельных объектов для canary/blue-green - они собираются из
  Deployment, Service и labels.
- Рычаг обеих стратегий: Service направляет трафик по совпадению labels, а мы управляем
  labels Pods и selector Service.
- Canary: широкий selector Service + два Deployment (stable/canary) с общим label и
  разным `version`; доля трафика ≈ доля Pods; продвижение - изменение числа реплик.
- Blue/green: две полные среды; переключение и откат - сменой selector Service, почти
  мгновенно; цена - двойные ресурсы.
- Примитивами доля трафика привязана к числу Pods; точный процент дают mesh/ingress.
- В проде используют Argo Rollouts/Flagger (автооткат по метрикам) и mesh/Gateway API
  для точного распределения.

## 9.10. Как это пригодится: на экзамене и в реальной работе

**На экзамене (CKAD).** Типовое задание домена Application Deployment - «реализуй canary»
или «переключи трафик на новую версию» именно примитивами: создать два Deployment с
нужными labels, настроить selector Service, поменять число реплик или selector.
Понимание, что всё держится на labels, - ключ к решению.

**В реальной работе.** Эти стратегии - основа безопасных релизов рискованных изменений.
Даже если в проде вы используете Argo Rollouts или mesh, они внутри опираются на ту же
идею (labels + маршрутизация), поэтому понимание примитивов делает работу с продвинутыми
инструментами осознанной, а не «по кнопке».

## 9.11. Вопросы для самопроверки

1. Почему в Kubernetes нет отдельного объекта для canary/blue-green и из чего они
   собираются?
2. Как labels Pods и selector Service позволяют управлять распределением трафика?
3. Как реализовать canary примитивами и как продвигать новую версию до 100%?
4. Как устроен blue/green и что именно меняется при переключении трафика?
5. В чём главные различия canary и blue/green по трафику, откату и ресурсам?
6. Почему примитивами нельзя задать точный процент запросов и чем это решают в проде?

## Практика

Мы разобрали, как управлять релизами тонко. Дальше (глава 10) перейдём к другому классу
рабочих нагрузок - разовым и периодическим задачам (Job и CronJob). Стратегии релизов
отрабатываются в лабах по рабочим нагрузкам вместе с Deployment и Service.

🧪 Лаба 102 (canary и blue/green): [tasks/cka/labs/102](../../labs/102/README_RU.MD)

---
[Оглавление](../README_RU.md) · [Глава 8](../08/ru.md) · [Глава 10](../10/ru.md)
