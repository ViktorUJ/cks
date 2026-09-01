# Политика версий и весов курса KCSA

Последняя проверка: **2026-09-01**.

Контуры KCSA независимы и не должны автоматически выравниваться:

| Контур | Текущее значение | Источник истины |
|---|---|---|
| Учебные примеры | Kubernetes `v1.36` | Согласованная с курсом CKS версия для корректности примеров |
| Экзамен KCSA | Концептуальный, version-light | LF «Domains & Competencies» |
| Программа KCSA (LIVE) | 6 доменов, веса `14/22/22/16/16/10` | LF «Domains & Competencies» |

> **Сопровождение версий.** Последняя проверенная upstream minor-версия Kubernetes — `v1.37`. Примеры намеренно остаются на `v1.36` для согласованности с CKS; пересматривайте это решение при каждом выпуске upstream minor-версии.

KCSA проверяет концепции безопасности cloud native и Kubernetes, поэтому версия Kubernetes влияет на корректность иллюстративных примеров, но не задаёт отдельную версию экзаменационной среды. Перед выпуском курса нужно отдельно проверить актуальную страницу LF и зафиксировать дату проверки.

## Provenance официального curriculum PDF

При проверке 2026-09-01 использовался официальный файл `KCSA Curriculum.pdf`: размер `227288` bytes, SHA-256 `2855eb7db729ab9ad0136b87d002560f82297e66e811026159df946227d5114a`.

При каждой последующей сверке нужно заново скачать именно этот curriculum PDF с официального источника LF, записать дату проверки, имя файла, размер и SHA-256, затем сопоставить его домены и веса с LIVE-страницей LF. Веса `14/22/22/16/16/10` изменяют только если LIVE-страница LF подтверждённо изменилась.

## Текущая программа экзамена

| Домен | Вес |
|---|---:|
| Overview of Cloud Native Security | 14% |
| Kubernetes Cluster Component Security | 22% |
| Kubernetes Security Fundamentals | 22% |
| Kubernetes Threat Model | 16% |
| Platform Security | 16% |
| Compliance and Security Frameworks | 10% |

Веса `14/22/22/16/16/10` нельзя менять без изменения на странице LF. Дрейф версий или вторичные источники сами по себе не являются основанием для изменения структуры курса.

## Дрейф с `cncf/curriculum`

В `cncf/curriculum` master зафиксирована другая редакция из шести доменов:

| Домен ревизии CNCF | Вес |
|---|---:|
| Cloud Native Fundamentals | 16% |
| Kubernetes Security Fundamentals | 20% |
| Container Security Fundamentals | 20% |
| Secure Software Supply Chain | 16% |
| Monitoring, Logging, and Runtime Security | 12% |
| General Security Knowledge | 16% |

Для структуры курса и весов используется LIVE-программа LF. Содержание проектируется как надмножество LIVE-программы LF и ревизии `cncf/curriculum`, чтобы курс сохранял полезность при возможном переходе программы. При следующей проверке необходимо сопоставить оба контура, обновить дату и изменить структуру только после подтверждённого изменения LF.

## Ссылки

- [Linux Foundation KCSA - Domains & Competencies](https://training.linuxfoundation.org/certification/kubernetes-and-cloud-native-security-associate-kcsa/)
- [CNCF curriculum repository](https://github.com/cncf/curriculum)
