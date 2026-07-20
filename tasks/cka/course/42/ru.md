# Глава 42. Helm

> 🟦 **Глава для CKA** (домен Cluster Architecture: «использовать Helm и Kustomize для
> установки компонентов»). Тема есть и в CKAD (использование пакетов).
>
> **Что дальше.** Мы установили много всего через `kubectl apply -f`. Но реальное
> приложение - это десятки манифестов (Deployment, Service, ConfigMap, Ingress...), да ещё
> с разными значениями для dev/prod. Управлять ими по отдельности тяжело. **Helm** - это
> «менеджер пакетов для Kubernetes»: он упаковывает манифесты в переиспользуемый
> шаблонизируемый пакет (chart) и управляет его установкой как единым целым.

## 42.1. Проблема, которую решает Helm

Без Helm каждое приложение - это россыпь YAML-файлов, которые надо применять,
версионировать и параметризовать вручную под каждую среду.

```mermaid
flowchart TB
    subgraph Without["Без Helm"]
        direction TB
        w1["deployment.yaml + service.yaml +<br>configmap.yaml + ingress.yaml + ..."] --> w2["копировать и править<br>под каждую среду вручную"]
    end
    subgraph With["С Helm"]
        direction TB
        h1["один chart (шаблоны)"] --> h2["values под среду →<br>установка одной командой"]
    end
    Without --> With
    style Without fill:#db4437,color:#fff
    style With fill:#0f9d58,color:#fff
    style w1 fill:#e57373,color:#000
    style w2 fill:#e57373,color:#000
    style h1 fill:#3cb371,color:#fff
    style h2 fill:#3cb371,color:#fff
```

Helm даёт: упаковку набора манифестов в **chart**, **шаблонизацию** (одни шаблоны -
разные значения для сред), управление **релизами** (установка/обновление/откат как единым
целым) и **репозитории** готовых пакетов.

## 42.2. Ключевые понятия Helm

```mermaid
flowchart TB
    chart["Chart<br>пакет: шаблоны + значения по умолчанию"]
    values["Values<br>значения для подстановки в шаблоны"]
    release["Release<br>установленный экземпляр chart в кластере"]
    repo["Repository<br>хранилище чартов"]
    repo --> chart
    chart --> release
    values --> release
    style chart fill:#326ce5,color:#fff
    style values fill:#0f9d58,color:#fff
    style release fill:#673ab7,color:#fff
    style repo fill:#f4b400,color:#000
```

| Понятие | Что это |
|---------|---------|
| **Chart** | пакет Helm: шаблоны манифестов + значения по умолчанию + метаданные |
| **Values** | параметры, подставляемые в шаблоны (переопределяют значения по умолчанию) |
| **Release** | конкретная установка chart в кластере (с именем и историей ревизий) |
| **Repository** | хранилище чартов (как реестр образов, но для чартов) |

Ключевая идея: **один chart → много releases** с разными values (один chart PostgreSQL
можно установить как `db-dev` и `db-prod` с разными настройками).

## 42.3. Структура chart

Chart - это каталог заданной структуры:

```
mychart/
├── Chart.yaml          # метаданные: имя, версия
├── values.yaml         # значения по умолчанию
├── templates/          # шаблоны манифестов
│   ├── deployment.yaml
│   ├── service.yaml
│   └── _helpers.tpl    # вспомогательные шаблоны
└── charts/             # зависимости (вложенные чарты)
```

Шаблоны используют переменные из values через синтаксис Go-шаблонов:

```yaml
# templates/deployment.yaml
spec:
  replicas: {{ .Values.replicaCount }}      # подставится из values
  template:
    spec:
      containers:
      - image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
```

```yaml
# values.yaml (значения по умолчанию)
replicaCount: 3
image:
  repository: nginx
  tag: "1.27"
```

```mermaid
flowchart LR
    tmpl["шаблон<br>replicas: {{ .Values.replicaCount }}"] --> render["Helm рендерит"]
    vals["values.yaml<br>replicaCount: 3"] --> render
    render --> yaml["готовый манифест<br>replicas: 3"]
    style tmpl fill:#326ce5,color:#fff
    style vals fill:#0f9d58,color:#fff
    style render fill:#f4b400,color:#000
    style yaml fill:#673ab7,color:#fff
```

## 42.4. Основные команды Helm

```bash
# Репозитории
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo nginx                 # найти chart

# Установка / обновление
helm install my-release bitnami/nginx                    # установить
helm install my-release bitnami/nginx --set replicaCount=5   # с параметром
helm install my-release bitnami/nginx -f my-values.yaml      # со своим values
helm upgrade my-release bitnami/nginx -f my-values.yaml      # обновить

# Просмотр и управление
helm list                              # установленные releases
helm status my-release
helm history my-release                # история ревизий
helm rollback my-release 1             # откат на ревизию
helm uninstall my-release              # удалить

# Полезно для отладки — что реально применится
helm template my-release bitnami/nginx -f my-values.yaml   # отрендерить локально
```

```mermaid
flowchart LR
    install["helm install"] --> up["helm upgrade"] --> rb["helm rollback"] --> un["helm uninstall"]
    hist["helm history — все ревизии"]
    style install fill:#0f9d58,color:#fff
    style up fill:#326ce5,color:#fff
    style rb fill:#f4b400,color:#000
    style un fill:#db4437,color:#fff
    style hist fill:#673ab7,color:#fff
```

## 42.5. Переопределение values

Значения по умолчанию из `values.yaml` переопределяются двумя способами (по возрастанию
приоритета):

| Способ | Пример | Когда |
|--------|--------|-------|
| свой values-файл | `-f prod-values.yaml` | много параметров, среды |
| `--set` в командной строке | `--set replicaCount=5` | точечное переопределение |

```mermaid
flowchart LR
    def["values.yaml<br>(по умолчанию)"] --> f["-f my-values.yaml<br>(переопределяет)"] --> set["--set key=value<br>(переопределяет всё)"]
    style def fill:#326ce5,color:#fff
    style f fill:#0f9d58,color:#fff
    style set fill:#673ab7,color:#fff
```

Так один chart адаптируют под среды: `-f dev-values.yaml` и `-f prod-values.yaml` с
разными репликами, ресурсами, хостами.

## 42.6. Helm и релизы: install/upgrade/rollback

Helm управляет приложением как **единым релизом** с историей - похоже на Deployment (глава
8), но на уровне всего набора манифестов:

```mermaid
flowchart LR
    v1["helm install → ревизия 1"] --> v2["helm upgrade → ревизия 2"] --> v3["upgrade → ревизия 3<br>(что-то сломалось)"] --> rb["helm rollback 2<br>вернуться к рабочей"]
    style v1 fill:#0f9d58,color:#fff
    style v2 fill:#0f9d58,color:#fff
    style v3 fill:#db4437,color:#fff
    style rb fill:#326ce5,color:#fff
```

Helm хранит историю ревизий релиза (в Secret'ах кластера), поэтому `helm rollback` может
вернуть весь набор объектов к предыдущему состоянию одной командой - удобно при неудачном
обновлении.

## 42.7. Как это применяют в продакшене

- **Helm - стандарт установки готового ПО.** Ingress-контроллеры, cert-manager, Prometheus,
  БД, операторы (глава 41) почти всегда ставят Helm-чартами: одна команда вместо десятков
  манифестов, с параметрами под свою среду.
- **Values под среды + GitOps.** В проде values-файлы (dev/stage/prod) хранят в git, а
  применяет их GitOps-инструмент (Argo CD/Flux, глава 3) - часто Argo CD рендерит Helm-
  чарты сам. Так один chart обслуживает все среды воспроизводимо.
- **Свои чарты для своих приложений.** Команды упаковывают свои сервисы в чарты (или общий
  «библиотечный» chart), чтобы единообразно катить десятки похожих сервисов.
- **Осторожность с helm upgrade.** Неаккуратный upgrade может пересоздать ресурсы или
  задеть данные (например, PVC). В проде перед upgrade смотрят `helm diff`/`helm template`,
  чтобы понять, что именно изменится.
- **Helm vs Kustomize.** Helm силён шаблонизацией и экосистемой готовых чартов; для более
  простого «наложения изменений» на базовые манифесты используют Kustomize (глава 43).
  Часто их сочетают.

## 42.8. Мини-глоссарий

- **Helm** - менеджер пакетов для Kubernetes.
- **Chart** - пакет: шаблоны манифестов + values + метаданные.
- **Values** - параметры для подстановки в шаблоны.
- **Release** - установленный экземпляр chart (с историей ревизий).
- **Repository** - хранилище чартов.
- **helm install/upgrade/rollback/uninstall** - жизненный цикл релиза.
- **--set / -f** - переопределение values в CLI / файлом.
- **helm template** - локальный рендер чарта в манифесты (для проверки).

## 42.9. Итоги главы

- Helm - менеджер пакетов Kubernetes: упаковывает набор манифестов в шаблонизируемый chart
  и управляет им как единым релизом.
- Понятия: Chart (пакет), Values (параметры), Release (установка), Repository (хранилище);
  один chart → много releases с разными values.
- Chart - каталог с `Chart.yaml`, `values.yaml`, `templates/`; шаблоны подставляют
  значения через `{{ .Values.* }}`.
- Команды: repo add/update, install, upgrade, rollback, uninstall, list, history; `helm
  template` рендерит локально для проверки.
- Values переопределяют файлом (`-f`) и `--set` (высший приоритет) - так адаптируют под
  среды.
- Helm ведёт историю ревизий релиза, поэтому `helm rollback` откатывает весь набор
  объектов одной командой.

## 42.10. Как это пригодится: на экзамене и в реальной работе

**На экзамене.** Программа CKA включает использование Helm. Ожидаются задания «установи
компонент Helm-чартом», «обнови/откати релиз», «переопредели значение через --set/values».
Нужно знать команды install/upgrade/rollback/list и как передавать values. Глубокого
написания чартов обычно не требуют.

**В реальной работе.** Helm - основной способ ставить готовое ПО и катить свои сервисы:
одна команда, параметры под среду, откат релиза. В связке с GitOps (values в git, Argo CD)
это фундамент воспроизводимой доставки. Понимание релизов и осторожность с upgrade -
повседневные навыки эксплуатации.

## 42.11. Вопросы для самопроверки

1. Какую проблему решает Helm по сравнению с `kubectl apply -f`?
2. Что такое chart, values и release? Как из одного chart получаются разные установки?
3. Из чего состоит каталог chart и как шаблоны используют values?
4. Как переопределить значения при установке и какой приоритет у `--set` и `-f`?
5. Как посмотреть историю релиза и откатить его?
6. Зачем нужен `helm template` перед установкой/обновлением?
7. Чем Helm отличается от Kustomize по подходу?

## Практика

Мы освоили упаковку и установку через Helm. В главе 43 - альтернативный подход к настройке
манифестов без шаблонов: Kustomize. Helm отрабатывается в лабах по администрированию (в
т.ч. при установке компонентов кластера).

🧪 Лаба 115 (Helm): [tasks/cka/labs/115](../../labs/115/README_RU.MD)

---
[Оглавление](../README_RU.md) · [Глава 41](../41/ru.md) · [Глава 43](../43/ru.md)
