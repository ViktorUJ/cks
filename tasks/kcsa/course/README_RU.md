> **Язык:** русский. Переводы будут добавлены после публикации соответствующих файлов.

# KCSA: практический самоучитель по безопасности cloud native и Kubernetes

KCSA (Kubernetes and Cloud Native Security Associate) - associate-уровень, пре-профессиональная и концептуальная сертификация CNCF и Linux Foundation по безопасности cloud native и Kubernetes. Курс занимает место в учебной траектории KCNA (optional) → KCSA → CKA → CKS: KCSA объясняет основы и модели угроз, CKA даёт обязательный для CKS практический фундамент, а CKS развивает security skills hands-on. Формальных пререквизитов нет; достаточно базово понимать, что такое `Pod`, `Deployment`, `Service` и `kubectl`.

> **О ссылках на CKA и CKS.** Самостоятельный архив KCSA не включает каталоги CKA и CKS. Поэтому в standalone-distribution ссылки внутри самого KCSA остаются кликабельными, а cross-course references на CKA/CKS публикуются как обычный текст без относительных URL. В monorepo-build их можно генерировать как рабочие ссылки на соседние курсы или как стабильные absolute URLs.

> **Формат экзамена и версия примеров.** KCSA - экзамен с выбором ответа: около 60 вопросов за 90 минут, hands-on заданий нет. По состоянию на 2026-09-01 LF Multiple Choice FAQ указывает проходной балл `75% or above`; перед регистрацией обязательно повторно проверьте актуальные требования LF. Примеры курса ориентированы на Kubernetes `v1.36`. Актуальные веса, источники и дрейф программы зафиксированы в [политике версий](../VERSION_POLICY.md).

## Как устроен курс

Каждая тема — каталог с номером и русским исходником `ru.md`. Пока опубликована только русская версия, поэтому навигация не показывает несуществующие переводы. Главы сгруппированы по доменам KCSA и помечены цветом:

- 🟦 Overview of Cloud Native Security - 14%
- 🟥 Kubernetes Cluster Component Security - 22%
- 🟩 Kubernetes Security Fundamentals - 22%
- 🟪 Kubernetes Threat Model - 16%
- 🟨 Platform Security - 16%
- 🟫 Compliance and Security Frameworks - 10%
- ⬜ введение, фундамент и подготовка к экзамену

Практика KCSA - это вопросы с выбором ответа и мок-экзамены, а не лабораторные работы. Этот файл содержит единый маршрут подготовки и навигацию по экзамену. Термины собраны в [глоссарии](GLOSSARY_RU.md).

## Официальная программа экзамена

| Домен | Вес |
|---|---:|
| Overview of Cloud Native Security | 14% |
| Kubernetes Cluster Component Security | 22% |
| Kubernetes Security Fundamentals | 22% |
| Kubernetes Threat Model | 16% |
| Platform Security | 16% |
| Compliance and Security Frameworks | 10% |

## Содержание

### Часть 0. Введение и фундамент ⬜

1. [Введение: экзамен KCSA, формат, место в лестнице сертификаций, версии](01/ru.md)
2. [Cloud native и почему безопасность](02/ru.md)

### Часть 1. Overview of Cloud Native Security - 14% 🟦

3. [4C облачной безопасности: Cloud, Cluster, Container, Code](03/ru.md)
4. [Безопасность облачного провайдера и инфраструктуры](04/ru.md)
5. [Средства контроля, фреймворки и техники изоляции](05/ru.md)
6. [Безопасность артефактов, образов и кода](06/ru.md)

### Часть 2. Kubernetes Cluster Component Security - 22% 🟥

7. [Безопасность control plane: API Server, Controller Manager, Scheduler, Etcd](07/ru.md)
8. [Безопасность узла: Kubelet, Container Runtime, KubeProxy](08/ru.md)
9. [Pod, сеть контейнеров, storage и клиентская безопасность](09/ru.md)

### Часть 3. Kubernetes Security Fundamentals - 22% 🟩

10. [Аутентификация и авторизация](10/ru.md)
11. [Pod Security Standards и Pod Security Admission](11/ru.md)
12. [Secrets](12/ru.md)
13. [Network Policy, изоляция и сегментация](13/ru.md)
14. [Audit Logging](14/ru.md)

### Часть 4. Kubernetes Threat Model - 16% 🟪

15. [Границы доверия, потоки данных и модель угроз](15/ru.md)
16. [Категории угроз Kubernetes](16/ru.md)

### Часть 5. Platform Security - 16% 🟨

17. [Supply chain, реестры образов и admission control](17/ru.md)
18. [Observability, PKI, connectivity и service mesh](18/ru.md)

### Часть 6. Compliance and Security Frameworks - 10% 🟫

19. [Комплаенс и фреймворки безопасности](19/ru.md)

### Часть 7. Подготовка к экзамену ⬜

20. [Экзамен KCSA: стратегия, тайм-менеджмент, чеклист](20/ru.md)

## Практика

- 📝 [Мок-экзамены KCSA](../mock) - доступны английские Mock 01 и Mock 02 в формате MCQ для независимых репетиций. Вопросы распределены по весам доменов; лабы terragrunt/bats для KCSA не создаются.

Начните с глав 01-02, затем проходите домены по порядку. Финальная тактика и чеклист собраны в [главе 20](20/ru.md).

## Что читать дальше

- [Официальная документация Kubernetes: Security](https://kubernetes.io/docs/concepts/security/)
- [CNCF Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/v2/cloud-native-security-whitepaper.md)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- Курс CKS - следующий шаг для углубления в практический hardening и расследование.
