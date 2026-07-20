# Глава 48. Экзамен CKA: формат, тайм-менеджмент и стратегия

> 🟦 **Глава для CKA.** Общие приёмы скорости и организации - те же, что для CKAD (глава
> 47); здесь фокус на специфике CKA: troubleshooting (30%), администрирование кластера,
> работа на нодах.
>
> **Что дальше.** Финал курса. У вас есть все знания (главы 1-46) и тактика скорости (глава
> 47). Теперь - как сдать именно CKA: этот экзамен смещён в сторону эксплуатации и
> troubleshooting, требует работы по SSH на нодах и уверенного разбора сбоев кластера.
> Соберём стратегию и карту повторения.

## 48.1. Чем CKA отличается от CKAD по тактике

Формат тот же (2 часа, ~15-20 задач, 66%, документация разрешена, частичные баллы), но
акценты другие (глава 1):

```mermaid
flowchart TB
    subgraph CKAD["CKAD (глава 47)"]
        direction TB
        d1["приложения: манифесты,<br>конфиги, пробы"]
    end
    subgraph CKA["CKA (эта глава)"]
        direction TB
        a1["troubleshooting 30% —<br>чинить кластер, ноды, control plane"]
        a2["установка/обновление kubeadm,<br>etcd backup"]
        a3["работа по SSH на нодах,<br>systemctl/journalctl/crictl"]
    end
    style CKAD fill:#673ab7,color:#fff
    style CKA fill:#0f9d58,color:#fff
    style d1 fill:#9c27b0,color:#fff
    style a1 fill:#3cb371,color:#fff
    style a2 fill:#3cb371,color:#fff
    style a3 fill:#3cb371,color:#fff
```

Главное отличие: **на CKA много работы вне kubectl** - на самих нодах (SSH, системные
сервисы, файлы). Troubleshooting (30%) и установка/обслуживание кластера требуют лезть в
`/etc/kubernetes/`, `systemctl`, `journalctl`, `crictl`, `etcdctl`.

## 48.2. Веса доменов и распределение времени

Распределяйте время по весам (глава 1):

```mermaid
flowchart TB
    t["2 часа"]
    t --> ts["Troubleshooting 30% → ~36 мин"]
    t --> ca["Cluster Arch/Install 25% → ~30 мин"]
    t --> sn["Services & Networking 20% → ~24 мин"]
    t --> ws["Workloads & Scheduling 15% → ~18 мин"]
    t --> st["Storage 10% → ~12 мин"]
    style t fill:#326ce5,color:#fff
    style ts fill:#e74c3c,color:#fff
    style ca fill:#4a90d9,color:#fff
    style sn fill:#2ecc71,color:#fff
    style ws fill:#7b68ee,color:#fff
    style st fill:#e8a838,color:#000
```

Troubleshooting и Cluster Architecture вместе - более половины экзамена. Именно туда стоит
вложить основную подготовку.

## 48.3. Первые минуты: те же настройки + SSH

Настройка окружения - как на CKAD (глава 47): alias, `$do`/`$now`, автодополнение, vim с
expandtab. Плюс специфика CKA:

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
source <(kubectl completion bash); complete -o default -F __start_kubectl k
echo 'set tabstop=2 shiftwidth=2 expandtab' >> ~/.vimrc; export KUBE_EDITOR=vim
```

```mermaid
flowchart LR
    env["стандартная настройка (гл.47)"] --> ssh["готовность работать по SSH:<br>ssh <node>, sudo -i"]
    ssh --> tools["на ноде: systemctl, journalctl,<br>crictl, etcdctl, vim манифестов"]
    style env fill:#326ce5,color:#fff
    style ssh fill:#0f9d58,color:#fff
    style tools fill:#f4b400,color:#000
```

> **Важно для CKA.** Много задач решаются **на ноде**, а не через kubectl. Будьте готовы
> `ssh` на control plane/worker, `sudo`, редактировать файлы в `/etc/kubernetes/`,
> смотреть `journalctl -u kubelet`, `crictl ps`. Не забывайте вернуться на «свою» машину
> после работы на ноде.

## 48.4. Ключевые задания CKA и где повторить

Типовые высокобалльные задания и главы курса:

| Задание | Главы |
|---------|-------|
| установить кластер / добавить ноду (kubeadm) | 35 |
| обновить кластер (upgrade, cordon/drain) | 36 |
| бэкап/восстановление etcd | 37 |
| RBAC: роли и привязки | 38 |
| выдать сертификат через CSR / kubeconfig | 39 |
| починить control plane (static pods) | 15, 45 |
| нода NotReady (kubelet/runtime/CNI) | 45, 30 |
| сервис/DNS не работает (Endpoints, CoreDNS) | 7, 31, 46 |
| NetworkPolicy | 34 |
| Deployment, scheduling, ресурсы | 5, 8, 12-14 |
| PV/PVC, StorageClass | 25-26 |

```mermaid
flowchart TB
    core["Ядро подготовки CKA"]
    core --> tshoot["troubleshooting: приложения (44),<br>control plane/ноды (45), сеть (46)"]
    core --> install["kubeadm (35), upgrade (36), etcd (37)"]
    core --> sec["RBAC (38), сертификаты (39)"]
    style core fill:#326ce5,color:#fff
    style tshoot fill:#e74c3c,color:#fff
    style install fill:#4a90d9,color:#fff
    style sec fill:#0f9d58,color:#fff
```

## 48.5. Стратегия troubleshooting под таймером

Раз troubleshooting - 30%, отработайте алгоритмы до автоматизма (главы 44-46):

```mermaid
flowchart TB
    q["Задача-troubleshooting"]
    q -->|"под не работает"| pod["get→describe→logs --previous→exec (гл.44)"]
    q -->|"kubectl не отвечает / компонент"| cp["на ноде: crictl/journalctl,<br>манифесты в /etc/kubernetes (гл.45)"]
    q -->|"нода NotReady"| node["ssh: systemctl/journalctl kubelet,<br>runtime, CNI, swap (гл.45)"]
    q -->|"сеть/сервис"| net["послойно: IP→DNS→Endpoints→политика (гл.46)"]
    style q fill:#f4b400,color:#000
    style pod fill:#0f9d58,color:#fff
    style cp fill:#326ce5,color:#fff
    style node fill:#673ab7,color:#fff
    style net fill:#db4437,color:#fff
```

Не гадайте - применяйте деревья решений из глав 44-46. Быстрая локализация («какой слой /
компонент») важнее знания редких деталей.

## 48.6. Тайм-менеджмент и правила экзамена

Общая стратегия - как на CKAD (глава 47): три прохода, смотреть вес, не застревать,
оставить время на проверку. Специфика CKA:

- **Тяжёлые задачи (etcd restore, upgrade, установка) занимают много времени** - оцените,
  успеваете ли, и не жертвуйте несколькими лёгкими ради одной сложной.
- **После работы на ноде вернитесь в исходный контекст** - легко забыть и делать
  следующую задачу «не там».
- **Проверяйте деструктивные операции** (restore etcd, drain) - они дороги при ошибке.
- **Документация kubernetes.io разрешена** - держите под рукой страницы про kubeadm
  upgrade, etcd backup, CSR: точные команды удобно копировать.

```mermaid
flowchart LR
    p1["Проход 1: быстрые победы<br>(RBAC, поды, сервисы)"] --> p2["Проход 2: тяжёлые<br>(etcd, upgrade, install)"] --> p3["Проход 3: проверка,<br>особенно деструктивных"]
    style p1 fill:#0f9d58,color:#fff
    style p2 fill:#326ce5,color:#fff
    style p3 fill:#673ab7,color:#fff
```

## 48.7. Топ ошибок на CKA

```mermaid
flowchart TB
    e1["забыл вернуться с ноды →<br>делает задачу не в том контексте"]
    e2["не тот namespace/контекст"]
    e3["застрял на etcd/upgrade, бросил лёгкие"]
    e4["правит не тот манифест / не проверил,<br>что static pod поднялся"]
    e5["деструктив без проверки (restore, drain)"]
    e6["ищет основы в docs вместо знания наизусть"]
    style e1 fill:#db4437,color:#fff
    style e2 fill:#db4437,color:#fff
    style e3 fill:#db4437,color:#fff
    style e4 fill:#db4437,color:#fff
    style e5 fill:#db4437,color:#fff
    style e6 fill:#db4437,color:#fff
```

## 48.8. Финальный чек-лист перед CKA

- [ ] умею kubeadm init/join и знаю шаги подготовки ноды (глава 35);
- [ ] умею upgrade кластера с cordon/drain/uncordon (глава 36);
- [ ] знаю наизусть команды etcd snapshot save/restore (глава 37);
- [ ] уверенно создаю RBAC и проверяю `auth can-i --as` (глава 38);
- [ ] умею CSR approve и настройку kubeconfig (глава 39);
- [ ] чиню control plane через манифесты + crictl/journalctl (главы 15, 45);
- [ ] разбираю NotReady на ноде по SSH (глава 45);
- [ ] отлаживаю сеть послойно и знаю про Endpoints/DNS (глава 46);
- [ ] настроил alias/автодополнение/vim и переключаю контексты рефлекторно (глава 47);
- [ ] прогнал мок-экзамены под таймером.

```mermaid
flowchart LR
    know["знания (главы 1-46)"] --> tactics["тактика (главы 47-48)"] --> mock["моки под таймером"] --> pass["сдача CKA"]
    style know fill:#326ce5,color:#fff
    style tactics fill:#0f9d58,color:#fff
    style mock fill:#f4b400,color:#000
    style pass fill:#673ab7,color:#fff
```

## 48.9. Мини-глоссарий

- **troubleshooting-домен** - 30% CKA, самый весомый; чинить приложения/кластер/сеть.
- **работа на ноде** - SSH + systemctl/journalctl/crictl/etcdctl (специфика CKA).
- **три прохода** - стратегия времени (лёгкие → тяжёлые → проверка).
- **деструктивные операции** - etcd restore, drain: проверять особенно.
- **вернуться в контекст** - после работы на ноде продолжить на исходной машине.
- **мок-экзамен** - репетиция под таймером с автопроверкой.

## 48.10. Итоги главы

- CKA формально как CKAD (2 часа, ~17 задач, 66%, частичные баллы), но смещён в
  troubleshooting (30%) и администрирование - много работы вне kubectl, на нодах по SSH.
- Время - по весам: troubleshooting + cluster architecture это >50% экзамена, туда основной
  фокус.
- Настройка окружения та же (глава 47) + готовность к SSH/systemctl/journalctl/crictl/
  etcdctl на нодах; после работы на ноде возвращаться в исходный контекст.
- Ключевые задания: kubeadm install/upgrade, etcd backup/restore, RBAC, CSR, починка
  control plane и нод, сетевая отладка - повторить по картам 48.4/48.5.
- Troubleshooting решать деревьями решений (главы 44-46), а не гаданием.
- Тайм-менеджмент: три прохода, не застревать на тяжёлых (etcd/upgrade), проверять
  деструктивные операции.

## 48.11. Как это пригодится: на экзамене и в реальной работе

**На экзамене (CKA).** Эта глава - сборка всего в стратегию сдачи: распределение времени по
весам, готовность работать на нодах, деревья troubleshooting и чек-лист. Вместе с главой 47
(общая тактика) и знаниями глав 1-46 это то, что даёт проходной балл.

**В реальной работе.** Навыки CKA - это и есть повседневная работа администратора/SRE:
поднять и обновить кластер, забэкапить etcd, настроить доступы, починить упавший control
plane или ноду, разобрать сетевой инцидент. Экзамен проверяет ровно то, что делают в проде -
поэтому подготовка к CKA напрямую повышает вашу ценность как инженера.

## 48.12. Вопросы для самопроверки

1. Чем тактика CKA отличается от CKAD? Почему важна готовность работать на нодах?
2. Как распределить 2 часа по доменам и куда вложить основную подготовку?
3. Какие инструменты нужны на ноде и почему нельзя забыть вернуться в исходный контекст?
4. Перечислите ключевые высокобалльные задания CKA и главы для их повторения.
5. Как под таймером быстро локализовать troubleshooting-проблему?
6. Почему деструктивные операции (etcd restore, drain) требуют особой проверки?
7. Что в вашем финальном чек-листе ещё не отработано до автоматизма?

## Заключение курса

Поздравляем - вы прошли весь совместный курс CKA + CKAD. Вы разобрали Kubernetes от
архитектуры кластера и рабочих нагрузок до сети, хранилища, безопасности,
администрирования и troubleshooting, и знаете тактику обоих экзаменов. Осталось главное -
**руки**: прогоняйте лабораторные работы и мок-экзамены под таймером, пока команды не
станут рефлексом. Знания + отработанная скорость = сданные CKA и CKAD.

Для точечной подготовки к одному экзамену используйте путеводители:
[CKA](../CKA_RU.md) · [CKAD](../CKAD_RU.md).

🧪 Лаба 119 (дриллы на скорость и JSONPath): [tasks/cka/labs/119](../../labs/119/README_RU.MD)

🧪 Мок-экзамены CKA: [tasks/cka/mock](../../mock)

---
[Оглавление](../README_RU.md) · [Глава 47](../47/ru.md)
