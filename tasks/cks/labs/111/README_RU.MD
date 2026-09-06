# Лаба 111 — анализ образов, статические исправления и supply-chain evidence

## Цель

В этой CKS-лабе вы соберёте воспроизводимые evidence-артефакты для контейнерного
приложения: отчёты уязвимостей и статических анализаторов, безопасные исправления
`Dockerfile` и манифеста рабочей нагрузки, два SBOM, поиск версий зависимостей и проверку
подписи образа. Результат — не просто вывод терминала: каждый отчёт должен быть
сохранён в указанном месте и пригоден для аудита.

Это CKS-задача по security tooling и supply chain, а не упражнение CKA. Большинство
артефактов анализируются локально на worker; единственное исключение — задание 4, где
нужно применить hardened Deployment для проверки Ready/Available и HTTP smoke test.

## Threat model

Лаба моделирует доверие к supply chain через несколько независимых угроз. Вредоносный
код или известные слабости в image обнаруживаются сканерами Trivy, kubesec,
kube-linter и Hadolint на соответствующих уровнях образа, Dockerfile и манифестов.

Секреты и токены, случайно оставленные в layer, требуют отдельной проверки: secret
scanning (например Trivy secret scanning) и inspection history образа (`docker history`,
извлечение слоёв). SBOM решает другую задачу - инвентаризацию компонентов и версий
пакетов; он помогает supply-chain investigation (например, найти уязвимую библиотеку),
но не является надёжным механизмом поиска секретов в истории слоёв и не заменяет secret
scanning. Даже если рабочая конфигурация уже не содержит секрет, он может остаться
доступным в истории слоёв.

Угроза mutable-tag tampering состоит в том, что после деплоя по неизменённой ссылке с
тегом можно подставить другой, вредоносный image. Именно поэтому digest pinning важен в
заданиях 3–5: он фиксирует конкретное содержимое образа, а не только его имя и тег.

Проверка подписи в задании 7 доказывает provenance, тогда как Trivy scan в задании 1
доказывает отсутствие известных уязвимостей. Это разные оси защиты: ни одна из них не
заменяет другую, поскольку vulnerability != provenance.

## Инфраструктура

Окружение создаётся Terragrunt в AWS `eu-central-1`.

| Компонент | Назначение |
|---|---|
| `vpc` | VPC `10.111.0.0/16` с публичными подсетями |
| `ssh-keys` | доступ к ноде |
| `k8s-1` | одноузловой kubeadm Kubernetes `1.36.0`, containerd и **Calico** |
| `worker` | рабочая станция для анализа, `kubectl`, `check_result` и security tools |

Инфраструктура CKA-style: единственная control-plane-нода разрешена для workload и
помечена `cks.io/lab=111`. Однако задания выполняются на worker; кластер существует
для единообразного экзаменационного окружения, а не для деплоя приложения.

На worker заранее доступны ровно эти фиксированные версии:

| Инструмент | Версия | Назначение |
|---|---:|---|
| Trivy | `0.74.0` | CVE и список пакетов образа |
| kubesec | `2.14.0` | security score Kubernetes YAML |
| kube-linter | `0.8.3` | policy lint Kubernetes YAML |
| Hadolint | `2.12.0` | lint Dockerfile |
| Syft | `1.51.0` | SBOM CycloneDX JSON |
| bom | `0.7.0` | SBOM SPDX JSON (нативный формат `bom`) |
| Cosign | `3.0.6` | verification подписи OCI-образа |

## Развёртывание

```bash
TASK=111 make run_cks_task
```

Подключитесь к worker и выберите контекст:

```bash
kubectl config use-context cluster1-admin@cluster1
cd /home/ubuntu/cks-111
check_result
```

Исходно `Dockerfile` и `deployment.yaml` намеренно небезопасны. Рабочие артефакты
создавайте только в `/var/work/tests/artifacts/<номер>/`.

## Задания

`nginx:1.27.3-alpine` — mutable tag, а не закреплённая ссылка. Сначала получите канонический registry manifest digest из `Metadata.RepoDigests[0]` Trivy JSON и используйте immutable reference `nginx:1.27.3-alpine@sha256:<manifest-digest>` (далее `$IMAGE`). Для собственного hardened image сначала соберите и опубликуйте image в registry, доступный кластеру, затем используйте его manifest digest; локальный image ID и layer DiffID не являются registry manifest digest.

---
| **1** | **Trivy: отчёт об уязвимостях образа** |
| :---: | :--- |
| Что делаем | Просканируйте immutable `$IMAGE` с Trivy, включая OS и library vulnerabilities, и сохраните структурированный JSON в `/var/work/tests/artifacts/1/trivy-report.json`. |
| Критерии приёмки | Файл непустой, JSON разбирается `jq`, содержит `Results` и immutable reference анализируемого образа. |

---
| **2** | **Исходные отчёты статического анализа** |
| :---: | :--- |
| Что делаем | До исправлений сохраните результаты: Hadolint в `2/hadolint-before.txt`, kubesec JSON в `2/kubesec-before.json`, kube-linter JSON в `2/kube-linter-before.json`. Не скрывайте ошибки через `|| true` в файлах отчётов: ненулевой exit code линтера ожидаем. |
| Критерии приёмки | Все три артефакта существуют; Hadolint содержит findings, kubesec содержит `scoring`, kube-linter — JSON-массив findings. |

---
| **3** | **Исправить Dockerfile по findings** |
| :---: | :--- |
| Что делаем | Исправьте `/home/ubuntu/cks-111/Dockerfile`: закрепите базовый образ immutable reference `nginx:1.27.3-alpine@sha256:<manifest-digest>`, не используйте `ADD` с URL, не храните token в `ENV`, не устанавливайте `sudo`, добавьте непривилегированного `USER` (uid не `0`). Используйте `COPY` и воспроизводимую установку пакетов только при необходимости. После правки сохраните успешный вывод Hadolint в `3/hadolint-after.txt`. |
| Критерии приёмки | Нет `latest`, удалён remote `ADD`, не осталось `API_TOKEN`/`TOKEN`, есть non-root `USER`; итоговый Hadolint report не содержит `DL3007`, `DL3013`, `DL3020`, `DL3045`. |

---
| **4** | **Исправить workload YAML по kubesec и kube-linter** |
| :---: | :--- |
| Что делаем | Сначала соберите и опубликуйте hardened image из задания 3, затем укажите в `deployment.yaml` его immutable manifest reference `registry/.../catalog@sha256:<manifest-digest>` (не upstream nginx). На уровне Pod добавьте `automountServiceAccountToken: false`, `runAsNonRoot: true`, `seccompProfile: RuntimeDefault`; в контейнере задайте `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]`, requests/limits CPU и memory. Для nginx смонтируйте writable `emptyDir`/tmpfs в temp, pid/run, cache и config paths и подготовьте config до старта. Удалите `privileged`, примените Deployment, подтвердите Ready/Available и успешный HTTP request. Сохраните новые отчёты `4/kubesec-after.json` и `4/kube-linter-after.json`. |
| Критерии приёмки | YAML использует digest-pinned hardened image с `USER 101`, а не upstream nginx; требуемые поля и writable mounts присутствуют; `privileged` отсутствует; Deployment Available и HTTP request успешен; оба итоговых отчёта — валидный JSON. |

---
| **5** | **Поиск версий пакетов** |
| :---: | :--- |
| Что делаем | Используйте Trivy в режиме списка всех пакетов для `$IMAGE`. Сохраните команду, immutable image reference, канонический `nginx@sha256:<manifest-digest>` из `Metadata.RepoDigests[0]` и как минимум три строки `имя=версия` в `/var/work/tests/artifacts/5/version-search.txt`. Не заменяйте поиск ручным списком: в evidence должна быть строка команды с `trivy image --list-all-pkgs`. |
| Критерии приёмки | Артефакт содержит команду, immutable `nginx:1.27.3-alpine@sha256:...`, `repo_digest=nginx@sha256:...` из Trivy и минимум три пары package/version. |

---
| **6** | **SPDX SBOM через bom** |
| :---: | :--- |
| Что делаем | Сгенерируйте SPDX JSON SBOM для `nginx:1.27.3-alpine` инструментом `bom` (его нативный формат — SPDX); сохраните в `/var/work/tests/artifacts/6/bom.spdx.json`. В файл `6/bom-command.txt` запишите выполненную команду. |
| Критерии приёмки | SBOM — валидный JSON, имеет `spdxVersion`, содержит массив `packages`; command evidence использует `bom generate`. |

---
| **7** | **CycloneDX SBOM через Syft и проверка Cosign** |
| :---: | :--- |
| Что делаем | Сгенерируйте CycloneDX JSON SBOM Syft для `nginx:1.27.3-alpine` в `7/syft.cdx.json`. Затем проверьте подпись публичного образа `gcr.io/distroless/static:nonroot` через keyless Cosign и сохраните полный успешный вывод в `7/cosign-verify.txt`. Для Distroless используйте issuer `https://accounts.google.com` и identity `keyless@distroless.iam.gserviceaccount.com`. |
| Критерии приёмки | Syft SBOM имеет `bomFormat: CycloneDX` и `components`; в выводе Cosign есть `Verified OK` и reference `gcr.io/distroless/static:nonroot`. |

## Проверка

```bash
check_result
```

Проверка содержит `Init` и семь независимых тестов. Она проверяет содержимое файлов и
JSON, а не только наличие имён. Внешние registry-запросы требуются для Trivy, SBOM и
Cosign; если registry временно недоступен, повторите именно соответствующую команду.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Удаление

```bash
TASK=111 make delete_cks_task
```
