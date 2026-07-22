# CKA + CKAD: практический самоучитель по Kubernetes

Совместный практический курс по подготовке к двум сертификациям CNCF и Linux
Foundation одновременно:

- **CKA** (Certified Kubernetes Administrator) - администрирование кластера:
  установка, обслуживание, сеть, хранилища, безопасность, troubleshooting.
- **CKAD** (Certified Kubernetes Application Developer) - разработка и запуск
  приложений в Kubernetes: рабочие нагрузки, конфигурация, наблюдаемость,
  сервисы.

Экзамены сильно пересекаются (рабочие нагрузки, сервисы, конфигурация, хранилища,
наблюдаемость), поэтому изучать их вместе эффективнее, чем по отдельности. Общее
ядро проходится один раз, а специфика каждого экзамена вынесена в отдельные части.
Курс привязан к лабораторным работам в `tasks/cka/labs`.

> **Версия Kubernetes.** Курс ориентирован на актуальную версию экзаменов -
> Kubernetes `v1.35` (программы CKA и CKAD 2025-2026). Оба экзамена -
> практические, в живом кластере из командной строки: CKA - 2 часа, CKAD - 2
> часа, проходной балл 66%.

## Как устроен курс

Каждая тема - папка с номером. Внутри лежат локализованные файлы. Основной язык -
русский (`ru.md`), с него делаются переводы. Переводы на английский, испанский,
французский и немецкий будут добавлены после того, как русская версия будет
готова целиком.

Каждая глава помечена, к какому экзамену она относится:

- 🟦 **CKA** - только для администратора
- 🟩 **CKAD** - только для разработчика
- 🟪 **CKA + CKAD** - общая тема для обоих экзаменов

В конце курса есть два отдельных путеводителя, которые собирают главы и лабы под
конкретный экзамен:

- [Программа и лабы для CKA](CKA_RU.md)
- [Программа и лабы для CKAD](CKAD_RU.md)

Все термины курса собраны в едином справочнике:

- [Глоссарий курса](GLOSSARY_RU.md) — все термины по главам со ссылками

## Официальные программы экзаменов

CKA (домены и вес):

| Домен | Вес |
|-------|-----|
| Cluster Architecture, Installation & Configuration | 25% |
| Workloads & Scheduling | 15% |
| Storage | 10% |
| Services & Networking | 20% |
| Troubleshooting | 30% |

CKAD (домены и вес):

| Домен | Вес |
|-------|-----|
| Application Design and Build | 20% |
| Application Deployment | 20% |
| Application Observability and Maintenance | 15% |
| Application Environment, Configuration and Security | 25% |
| Services and Networking | 20% |

## Содержание

### Часть 0. Фундамент для новичков (необязательная) 🟪 CKA + CKAD

Подготовительная часть для тех, кто приходит без крепкой базы по сетям, DNS, TLS,
контейнерам, Linux и YAML. Если вы уверенно владеете этими темами - можно сразу
переходить к Части 1. Отдельных лаб у этой части нет: это фундамент, на который
опираются остальные главы (навыки из 0.5-0.7 прямо применяются в нодовых и сетевых
лабах).

- 0.1. [Сеть с нуля: IP, порты, CIDR и NAT](00-1-net/ru.md)
- 0.2. [DNS с нуля: как имена превращаются в адреса](00-2-dns/ru.md)
- 0.3. [TLS и сертификаты с нуля: HTTPS, ключи и центры сертификации](00-3-tls/ru.md)
- 0.4. [Контейнеры и Docker с нуля: образы, слои, реестры и runtime](00-4-containers/ru.md)
- 0.5. [Linux и инструменты ноды с нуля: SSH, sudo, systemd, логи, файлы](00-5-linux/ru.md)
- 0.6. [YAML с нуля: отступы, списки, словари и манифесты](00-6-yaml/ru.md)
- 0.7. [Linux-сеть под капотом: network namespaces, veth и маршрутизация](00-7-netns/ru.md)
- 0.8. [vim за 15 минут: выжить и настроить под YAML](00-8-vim/ru.md)

### Часть 1. Основы Kubernetes 🟪 CKA + CKAD

1. [Введение: Kubernetes, экзамены CKA и CKAD, устройство курса](01/ru.md)
2. [Архитектура Kubernetes: control plane и worker-ноды](02/ru.md)
3. [Работа с kubectl: императивный и декларативный подходы](03/ru.md)
4. [Поды: жизненный цикл, создание и конфигурирование](04/ru.md)
5. [ReplicaSet и Deployment](05/ru.md)
6. [Namespaces, метки, селекторы и аннотации](06/ru.md)
7. [Services: ClusterIP, NodePort, LoadBalancer, Endpoints](07/ru.md)

### Часть 2. Рабочие нагрузки и планирование 🟪 CKA + CKAD

8. [Deployment: rolling update и rollback](08/ru.md)
9. [Стратегии развёртывания: blue/green и canary](09/ru.md) 🟩 CKAD
10. [Jobs и CronJobs](10/ru.md)
11. [DaemonSet и StatefulSet](11/ru.md)
12. [Планирование подов: nodeName, nodeSelector, affinity](12/ru.md)
13. [Taints и tolerations](13/ru.md)
14. [Ресурсы: requests, limits, LimitRange, ResourceQuota](14/ru.md)
15. [Static Pods, PriorityClass, несколько планировщиков](15/ru.md)
16. [Автомасштабирование нагрузок: HPA](16/ru.md)

### Часть 3. Конфигурация и безопасность приложений 🟪 CKA + CKAD

17. [Команды, аргументы и переменные окружения](17/ru.md)
18. [ConfigMap](18/ru.md)
19. [Secret](19/ru.md)
20. [SecurityContext и capabilities](20/ru.md)
21. [ServiceAccount; аутентификация, авторизация, admission](21/ru.md)

### Часть 4. Дизайн и сборка приложений 🟩 CKAD

22. [Multi-container поды: sidecar, adapter, ambassador, init](22/ru.md)
23. [Образы контейнеров: сборка, Dockerfile, оптимизация](23/ru.md)
24. [Тома для приложений: emptyDir и эфемерные тома](24/ru.md)

### Часть 5. Хранение данных 🟪 CKA + CKAD

25. [Volumes, PersistentVolume и PersistentVolumeClaim](25/ru.md)
26. [StorageClass, динамический провижининг, хранение в StatefulSet](26/ru.md)

### Часть 6. Наблюдаемость и обслуживание 🟪 CKA + CKAD

27. [Проверки состояния: liveness, readiness, startup probes](27/ru.md)
28. [Логирование и мониторинг: logs, metrics-server, kubectl top](28/ru.md)
29. [Отладка приложений и устаревание API](29/ru.md)

### Часть 7. Сервисы и сеть 🟪 CKA + CKAD

30. [Сетевая модель Kubernetes, сеть подов и CNI](30/ru.md)
31. [Service изнутри, DNS и CoreDNS](31/ru.md)
32. [Ingress и Ingress-контроллеры](32/ru.md)
33. [Gateway API](33/ru.md)
34. [NetworkPolicy](34/ru.md)

### Часть 8. Архитектура кластера, установка и настройка 🟦 CKA

35. [Установка кластера с помощью kubeadm](35/ru.md)
- 35A. [Высокая доступность (HA): несколько control-plane нод, etcd-топологии и балансировщик](35-2-ha/ru.md) 🟦 CKA
- 35B. [Проектирование и сайзинг кластера: инфраструктура, топология, IaC](35-3-design/ru.md) 🟦 CKA
36. [Обновление кластера (lifecycle)](36/ru.md)
37. [Резервное копирование и восстановление etcd](37/ru.md)
38. [RBAC: Role, ClusterRole и binding'и](38/ru.md)
39. [TLS-сертификаты, kubeconfig и CSR API](39/ru.md)
40. [Интерфейсы расширения: CNI, CSI, CRI](40/ru.md)
41. [CRD и операторы](41/ru.md)
42. [Helm](42/ru.md)
43. [Kustomize](43/ru.md)

### Часть 9. Troubleshooting 🟦 CKA

44. [Отладка сбоев приложений](44/ru.md)
45. [Отладка control plane и worker-нод](45/ru.md)
46. [Отладка сервисов и сети](46/ru.md)

### Часть 10. Подготовка к экзаменам

47. [Экзамен CKAD: формат, тайм-менеджмент, JSONPath и продуктивность kubectl](47/ru.md) 🟩 CKAD
48. [Экзамен CKA: формат, тайм-менеджмент и стратегия](48/ru.md) 🟦 CKA
