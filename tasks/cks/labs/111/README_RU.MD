# Лаба 111 — анализ образов, статические исправления и supply-chain evidence

## Цель

В этой CKS-лабе вы соберёте воспроизводимые evidence-артефакты для контейнерного
приложения: отчёты уязвимостей и статических анализаторов, безопасные исправления
`Dockerfile` и workload-манифеста, два SBOM, поиск версий зависимостей и проверку
подписи образа. Результат — не просто вывод терминала: каждый отчёт должен быть
сохранён в указанном месте и пригоден для аудита.

Это CKS-задача по security tooling и supply chain, а не упражнение CKA. Не создавайте
Kubernetes-ресурсы: файлы анализируются локально на worker.

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
| Trivy | `0.58.1` | CVE и список пакетов образа |
| kubesec | `2.14.0` | security score Kubernetes YAML |
| kube-linter | `0.7.1` | policy lint Kubernetes YAML |
| Hadolint | `2.12.0` | lint Dockerfile |
| Syft | `1.18.1` | SBOM SPDX JSON |
| bom | `0.7.0` | SBOM CycloneDX JSON |
| Cosign | `2.4.1` | verification подписи OCI-образа |

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

---
| **1** | **Trivy: отчёт об уязвимостях образа** |
| :---: | :--- |
| Что делаем | Просканируйте `nginx:1.27.3-alpine` с Trivy, включая OS и library vulnerabilities, и сохраните структурированный JSON в `/var/work/tests/artifacts/1/trivy-report.json`. |
| Критерии приёмки | Файл непустой, JSON разбирается `jq`, содержит `Results` и имя анализируемого образа. |

---
| **2** | **Исходные отчёты статического анализа** |
| :---: | :--- |
| Что делаем | До исправлений сохраните результаты: Hadolint в `2/hadolint-before.txt`, kubesec JSON в `2/kubesec-before.json`, kube-linter JSON в `2/kube-linter-before.json`. Не скрывайте ошибки через `|| true` в файлах отчётов: ненулевой exit code линтера ожидаем. |
| Критерии приёмки | Все три артефакта существуют; Hadolint содержит findings, kubesec содержит `scoring`, kube-linter — JSON-массив findings. |

---
| **3** | **Исправить Dockerfile по findings** |
| :---: | :--- |
| Что делаем | Исправьте `/home/ubuntu/cks-111/Dockerfile`: закрепите базовый образ как `nginx:1.27.3-alpine`, не используйте `ADD` с URL, не храните token в `ENV`, не устанавливайте `sudo`, добавьте непривилегированного `USER` (uid не `0`). Используйте `COPY` и воспроизводимую установку пакетов только при необходимости. После правки сохраните успешный вывод Hadolint в `3/hadolint-after.txt`. |
| Критерии приёмки | Нет `latest`, удалён remote `ADD`, не осталось `API_TOKEN`/`TOKEN`, есть non-root `USER`; итоговый Hadolint report не содержит `DL3007`, `DL3013`, `DL3020`, `DL3045`. |

---
| **4** | **Исправить workload YAML по kubesec и kube-linter** |
| :---: | :--- |
| Что делаем | Исправьте `deployment.yaml`: образ должен быть `nginx:1.27.3-alpine`; на уровне Pod добавьте `automountServiceAccountToken: false`, `runAsNonRoot: true`, `seccompProfile: RuntimeDefault`; в контейнере задайте `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]`, requests/limits CPU и memory. Удалите `privileged`. Сохраните новые отчёты `4/kubesec-after.json` и `4/kube-linter-after.json`. |
| Критерии приёмки | Требуемые поля действительно присутствуют в YAML; `privileged` отсутствует; оба итоговых отчёта — валидный JSON. |

---
| **5** | **Поиск версий пакетов** |
| :---: | :--- |
| Что делаем | Используйте Trivy в режиме списка всех пакетов для `nginx:1.27.3-alpine`. Сохраните команду, immutable image reference и как минимум три строки `имя=версия` в `/var/work/tests/artifacts/5/version-search.txt`. Не заменяйте поиск ручным списком: в evidence должна быть строка команды с `trivy image --list-all-pkgs`. |
| Критерии приёмки | Артефакт содержит команду, `nginx:1.27.3-alpine`, минимум три пары package/version и упоминание digest из результата inspect. |

---
| **6** | **CycloneDX SBOM через bom** |
| :---: | :--- |
| Что делаем | Сгенерируйте CycloneDX JSON SBOM для `nginx:1.27.3-alpine` инструментом `bom`; сохраните в `/var/work/tests/artifacts/6/bom.cdx.json`. В файл `6/bom-command.txt` запишите выполненную команду. |
| Критерии приёмки | SBOM — валидный JSON, имеет `bomFormat: CycloneDX`, содержит `components`; command evidence использует `bom generate`. |

---
| **7** | **SPDX SBOM через Syft и проверка Cosign** |
| :---: | :--- |
| Что делаем | Сгенерируйте SPDX JSON Syft для `nginx:1.27.3-alpine` в `7/syft.spdx.json`. Затем проверьте подпись публичного образа `gcr.io/distroless/static:nonroot` через keyless Cosign и сохраните полный успешный вывод в `7/cosign-verify.txt`. Для Distroless используйте issuer `https://accounts.google.com` и identity `keyless@distroless.iam.gserviceaccount.com`. |
| Критерии приёмки | Syft SBOM имеет `spdxVersion` и packages; в выводе Cosign есть `Verified OK` и reference `gcr.io/distroless/static:nonroot`. |

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
