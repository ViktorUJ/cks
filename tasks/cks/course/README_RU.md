[Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# CKS: практический самоучитель по безопасности Kubernetes

Практический курс подготовки к **CKS (Certified Kubernetes Security Specialist)** - сертификации CNCF и Linux Foundation по защите Kubernetes. Это продолжение [курса CKA + CKAD](../../cka/course/README_RU.md): предполагается, что вы уже умеете администрировать кластер, работать с `kubectl`, RBAC, NetworkPolicy, SecurityContext, kubeadm и TLS. CKS не повторяет эту базу, а применяет её к моделям угроз, hardening и расследованию инцидентов.

> **Версия Kubernetes и экзамен.** Материалы и лабы курса построены на Kubernetes `v1.36` - это **версия обучения**, на которой всё проверено. На дату проверки 2026-08-31 LF указывает Kubernetes `v1.34` для экзамена, а актуальная программа CNCF - `CKS Curriculum v1.34`; эти три версии поддерживаются независимо. Перед экзаменом перепроверьте LF. Подробный release-процесс описан в [политике версий](../VERSION_POLICY.md), русский стиль - в [STYLE_RU.md](../STYLE_RU.md).

## Как устроен курс

Каждая тема - каталог с номером и русским исходником `ru.md`. Переводы появятся в `README.md`, `es.md`, `fr.md`, `de.md`, `ge.md`, `tw.md` и `jp.md`; переключатель языков расположен в первой строке файлов. Главы сгруппированы по доменам CKS и помечены цветом:

- 🟦 Cluster Setup - 15%
- 🟥 Cluster Hardening - 15%
- 🟧 System Hardening - 10%
- 🟩 Minimize Microservice Vulnerabilities - 20%
- 🟪 Supply Chain Security - 20%
- 🟨 Monitoring, Logging & Runtime Security - 20%
- ⬜ фундамент и подготовка к экзамену

Для маршрута по экзамену используйте [путеводитель CKS](CKS_RU.md). Термины будут собраны в [глоссарии](GLOSSARY_RU.md).

## Официальная программа экзамена

| Домен | Вес |
|-------|-----|
| Cluster Setup | 15% |
| Cluster Hardening | 15% |
| System Hardening | 10% |
| Minimize Microservice Vulnerabilities | 20% |
| Supply Chain Security | 20% |
| Monitoring, Logging and Runtime Security | 20% |

## Содержание

### Часть 0. Фундамент безопасности (необязательная) ⬜

1. [Введение: экзамен CKS, отличия от CKA, устройство курса](01/ru.md)
2. [Модель безопасности Kubernetes: 4C, поверхность атаки, фазы атаки](02/ru.md)
3. [Linux-механизмы безопасности под капотом](03/ru.md)

### Часть 1. Cluster Setup - 15% 🟦

4. [NetworkPolicy для безопасности: default deny, ingress/egress, изоляция pod-to-pod](04/ru.md)
5. [Защита node metadata и endpoints сетевыми политиками](05/ru.md)
6. [Cilium NetworkPolicy: L3/L4/L7, DNS и Hubble](06/ru.md)
7. [CIS Benchmark и kube-bench](07/ru.md)
8. [Secure Ingress с TLS](08/ru.md)
9. [Небезопасные аргументы компонентов, TLS-хардненинг и проверка бинарников](09/ru.md)

### Часть 2. Cluster Hardening - 15% 🟥

10. [RBAC для минимизации доступа](10/ru.md)
11. [ServiceAccounts: минимизация и токены](11/ru.md)
12. [Ограничение доступа к Kubernetes API](12/ru.md)
13. [Обновление Kubernetes для устранения уязвимостей](13/ru.md)

### Часть 3. System Hardening - 10% 🟧

14. [Минимизация footprint хостовой ОС и безопасность runtime-демона](14/ru.md)
15. [Least-privilege на хосте и минимизация внешнего доступа к сети](15/ru.md)
16. [AppArmor](16/ru.md)
17. [seccomp](17/ru.md)

### Часть 4. Minimize Microservice Vulnerabilities - 20% 🟩

18. [SecurityContext углублённо](18/ru.md)
19. [Pod Security Standards и Pod Security Admission](19/ru.md)
20. [Admission-контроллеры и policy-движки: OPA/Gatekeeper и Kyverno](20/ru.md)
21. [Управление секретами Kubernetes](21/ru.md)
22. [Изоляция и sandboxed containers: gVisor и Kata](22/ru.md)
23. [Pod-to-Pod шифрование и mTLS: Cilium и Istio](23/ru.md)

### Часть 5. Supply Chain Security - 20% 🟪

24. [Минимизация базового образа](24/ru.md)
25. [Понимание supply chain: SBOM, CI/CD, artifact repositories](25/ru.md)
26. [Защита supply chain: реестры, подпись и валидация артефактов](26/ru.md)
27. [Статический анализ нагрузок и образов](27/ru.md)
28. [Сканирование образов на известные уязвимости](28/ru.md)

### Часть 6. Monitoring, Logging & Runtime Security - 20% 🟨

29. [Поведенческий анализ во время выполнения: Falco](29/ru.md)
30. [Обнаружение угроз и расследование фаз атаки](30/ru.md)
31. [Иммутабельность контейнеров в runtime](31/ru.md)
32. [Audit-логи Kubernetes](32/ru.md)

### Часть 7. Подготовка к экзамену ⬜

33. [Экзамен CKS: формат, тайм-менеджмент, разрешённая документация, чеклист](33/ru.md)

## Практика

- 🧪 [Лабораторные работы CKS](../labs) - план из 12 лабораторных работ с автоматической проверкой `check_result`, от NetworkPolicy до Falco и audit-логов.
- 🧪 [Мок-экзамены CKS](../mock) - каталог для репетиций под таймером; новые русские материалы будут добавлены отдельно.

Начинайте с глав 01-03, затем проходите домены вместе с соответствующими лабами. Финальную репетицию и чеклист соберёт [глава 33](33/ru.md).

## Что читать дальше

- B. Muschko, **Certified Kubernetes Security Specialist (CKS) Study Guide**, O'Reilly.
- [Официальная документация Kubernetes](https://kubernetes.io/docs/) - первоисточник по API и hardening.
- [Falco](https://falco.org/docs/), [Trivy](https://trivy.dev/latest/docs/), [Cilium](https://docs.cilium.io/), [Kyverno](https://kyverno.io/docs/) - документация практических инструментов курса.
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes) - рекомендации по безопасной конфигурации компонентов.
