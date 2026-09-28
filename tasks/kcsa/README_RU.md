[Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# KCSA: Kubernetes and Cloud Native Security Associate - учебные материалы

Полная подготовка к сертификации **Kubernetes and Cloud Native Security Associate (KCSA)**: самоучитель и полные мок-экзамены - всё в одном месте.

KCSA - associate-уровень, пре-профессиональная и концептуальная сертификация CNCF и Linux Foundation по безопасности cloud native и Kubernetes. Курс занимает место в учебной траектории KCNA (optional) → KCSA → CKA → CKS: KCSA объясняет основы и модели угроз, CKA даёт обязательный для CKS практический фундамент, а CKS развивает security skills hands-on. Формальных пререквизитов нет; достаточно базово понимать, что такое `Pod`, `Deployment`, `Service` и `kubectl`.

## Что внутри

| Раздел | Путь | Что это |
|------|------|-----------|
| **Курс** | [`course/`](course/README_RU.md) | 20 глав самоучителя, охватывающих все 6 официальных доменов KCSA |
| **Мок-экзамены** | [`mock/`](mock/README.md) | 2 полных мок-экзамена по 60 вопросов в формате MCQ |

Практика KCSA - это вопросы с выбором ответа и мок-экзамены, а не лабораторные работы. Рекомендуемый маршрут: пройти главы курса по порядку, затем сдать оба мок-экзамена в условиях, близких к реальному экзамену по времени.

## Курс

Курс ([`course/README_RU.md`](course/README_RU.md)) состоит из 20 глав, каждая опубликована на 8 языках: английский (`README.md`), русский (`ru.md`, канонический исходник), испанский (`es.md`), французский (`fr.md`), немецкий (`de.md`), грузинский (`ge.md`), традиционный китайский (`tw.md`) и японский (`jp.md`). Главы сгруппированы по официальным доменам KCSA:

| Домен | Вес |
|---|---:|
| Overview of Cloud Native Security | 14% |
| Kubernetes Cluster Component Security | 22% |
| Kubernetes Security Fundamentals | 22% |
| Kubernetes Threat Model | 16% |
| Platform Security | 16% |
| Compliance and Security Frameworks | 10% |

Термины собраны в [глоссарии](course/GLOSSARY_RU.md). Главы 1-2 знакомят с экзаменом и cloud native безопасностью; глава 20 содержит финальную стратегию сдачи экзамена, тайм-менеджмент и чеклист.

## Мок-экзамены

Два полных мок-экзамена ([`mock/`](mock/README.md)) моделируют реальный экзамен KCSA:

- **Mock 01** ([`mock/01`](mock/01/README.md)) - 60 вопросов, распределённых по доменам.
- **Mock 02** ([`mock/02`](mock/02/README.md)) - независимый набор из 60 вопросов с тем же распределением.

Проходите каждый мок в режиме closed-book за 90 минут: без документации, поиска, заметок, инструментов и внешних сайтов. На момент последней проверки LF Multiple Choice FAQ указывает проходной балл 75% или выше; перед регистрацией на KCSA сверьтесь с актуальными требованиями Linux Foundation.

## Формат экзамена и версия курса

KCSA - экзамен с выбором ответа: 60 вопросов, 90 минут, 75% для прохождения, без hands-on заданий (перед регистрацией проверьте актуальные параметры у Linux Foundation, так как они могут измениться). Примеры курса ориентированы на Kubernetes `v1.36`. Актуальные веса, источники и дрейф программы зафиксированы в [политике версий](VERSION_POLICY.md).

## Что читать дальше

- [Официальная документация Kubernetes: Security](https://kubernetes.io/docs/concepts/security/)
- [CNCF Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/v2/cloud-native-security-whitepaper.md)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- Курс CKS - следующий шаг для углубления в практический hardening и расследование.
