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

Проверка подписи в задании 7 доказывает, что конкретный digest подписан доверенным
key/identity (signature integrity), тогда как Trivy scan в задании 1 не обнаруживает
известных уязвимостей, попадающих в его detection coverage при текущей vulnerability DB
(сам Trivy документирует trade-off в пользу precision, при котором возможны false
negatives - "0 findings" не равно formal proof отсутствия уязвимостей). Это разные оси
защиты: ни одна из них не заменяет другую, поскольку vulnerability != signature. Подпись -
это НЕ то же самое, что provenance/attestation
(например SLSA-style build metadata о том, из чего и как собран artifact): `cosign
verify` подтверждает подлинность подписи, а не полную историю сборки - для attestation
Sigstore предоставляет отдельные команды `cosign attest`/`cosign verify-attestation`, не
задействованные в этой лабе.

Локальная `cosign verify` (задание 7) сама по себе не является enforcement: она доказывает
подпись конкретного image reference на момент проверки, но не мешает кому-то запустить
неподписанный или иначе подписанный образ прямым `kubectl apply`, минуя CI. Только
admission-time проверка (задание 9a-9c) делает подпись обязательным условием для допуска
Pod в кластер - это разница между «мы проверили подпись» и «кластер не запустит
неподписанный образ».

Доказательство этого свойства требует аккуратности: повторный `kubectl apply` уже
существующего Deployment не создаёт новый Pod, если template не изменился, поэтому
`Running` может означать «старый Pod, созданный до policy», а не «policy допустила
именно этот образ» (задание 9b проверяет `creationTimestamp` явно). Аналогично unsigned
DENY доказывает свойство только если проверяемый digest реально существует и pullable в
том же repository, что подписанный образ (задание 9c) - иначе admission может отказать
из-за отсутствующего в registry manifest, а не из-за отсутствия подписи.

## Проверьте себя перед стартом

<details>
<summary>1. Почему SBOM не является надёжным механизмом поиска секретов, оставленных в image layer?</summary>

SBOM решает задачу инвентаризации КОМПОНЕНТОВ и версий пакетов (что установлено, какая версия) - это структурный анализ метаданных пакетного менеджера, а не поиск произвольных строк/секретов в содержимом файлов слоёв. Секрет, оставленный, например, в переменной окружения ENV или временном файле во время сборки, может остаться в истории слоёв даже после того, как финальный слой его не содержит - для этого нужен отдельный инструмент (secret scanning, `docker history`, извлечение слоёв), а не SBOM.
</details>

<details>
<summary>2. В чём разница между тем, что доказывает Trivy scan (задание 1), и тем, что доказывает подпись Cosign (задание 9a-9c)?</summary>

На момент проверки, при текущей vulnerability DB и логике детектирования Trivy, скан НЕ ОБНАРУЖИЛ известных уязвимостей, попадающих в его detection coverage - это про качество/безопасность содержимого образа в той мере, в которой Trivy способен его увидеть. Сама документация Trivy прямо описывает trade-off в пользу precision (минимизация false positives), при котором возможны false negatives - то есть "0 findings" не эквивалентно формальному доказательству полного отсутствия уязвимостей. Подпись Cosign доказывает SIGNATURE INTEGRITY - что конкретный digest подписан доверенным ключом/identity, то есть кто-то авторизованный подтвердил, что это именно тот artifact, который должен быть развёрнут. Это НЕ то же самое, что provenance/attestation (полная история сборки - из чего, кем и как собран artifact): для attestation в Sigstore есть отдельные команды (`cosign attest`/`cosign verify-attestation`), не используемые в этой лабе. Образ может быть полностью безопасен (0 CVE) и при этом не подписан - или подписан, но содержать неизвестную уязвимость. Это две независимые оси защиты.
</details>

<details>
<summary>3. Почему `cosign verify` локально в CI не мешает кому-то развернуть неподписанный образ через `kubectl apply`?</summary>

`cosign verify`, выполненный локально (например, в CI pipeline), - это просто одна команда, которая проверяет подпись и возвращает результат тому, кто её вызвал. Она не встроена в путь admission Kubernetes API - ничто не мешает кому-то с доступом к кластеру просто выполнить `kubectl apply` с ЛЮБЫМ образом, минуя CI полностью. Только admission-time проверка (задание 9a-9c), встроенная в сам кластер как policy, делает подпись ОБЯЗАТЕЛЬНЫМ условием допуска - это разница между "мы проверили" и "кластер физически не пропустит".
</details>

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
| Cosign | `3.1.3` | signing и verification подписи OCI-образа |

Helm и `install-kyverno` также доступны на worker, но Kyverno намеренно **не установлен**:
его установка - часть задания 9, как в лабе 108.

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

<details>
<summary>💡 Подсказка к заданию 1</summary>

`$IMAGE` строится в два шага: сначала сканируете `nginx:1.27.3-alpine` (обычный tag) и достаёте `Metadata.RepoDigests[0]` из ЭТОГО первого JSON-отчёта, затем пересобираете команду с `nginx:1.27.3-alpine@sha256:<digest>` и сканируете уже immutable-ссылку - именно этот второй отчёт нужно сохранить как финальный. Не используйте `ImageID`/`DiffID` из вывода Trivy как замену registry digest - это ЛОКАЛЬНЫЕ идентификаторы, не совпадающие с manifest digest в registry.
</details>

---
| **2** | **Исходные отчёты статического анализа** |
| :---: | :--- |
| Что делаем | До исправлений сохраните результаты: Hadolint в `2/hadolint-before.txt`, kubesec JSON в `2/kubesec-before.json`, kube-linter JSON в `2/kube-linter-before.json`. Не скрывайте ошибки через `|| true` в файлах отчётов: ненулевой exit code линтера ожидаем. |
| Критерии приёмки | Все три артефакта существуют; Hadolint содержит findings, kubesec содержит `scoring`, kube-linter — JSON-массив findings. |

<details>
<summary>💡 Подсказка к заданию 2</summary>

Ненулевой exit code от линтера при обнаружении проблем - это ОЖИДАЕМОЕ поведение, не ошибка вашей команды. Если вы оборачиваете вызов в `|| true` только чтобы скрипт не остановился с `set -e`, убедитесь, что при этом вывод команды всё равно сохраняется в файл (через `tee` или редирект ДО `|| true`), а не теряется.
</details>

---
| **3** | **Исправить Dockerfile по findings** |
| :---: | :--- |
| Что делаем | Исправьте `/home/ubuntu/cks-111/Dockerfile`: закрепите базовый образ immutable reference `nginx:1.27.3-alpine@sha256:<manifest-digest>`, не используйте `ADD` с URL, не храните token в `ENV`, не устанавливайте `sudo`, добавьте непривилегированного `USER` (uid не `0`). Используйте `COPY` и воспроизводимую установку пакетов только при необходимости. Добавьте `ARG CKS_SIGNATURE_TEST=signed` и `LABEL cks.signature-test=$CKS_SIGNATURE_TEST` рядом с остальными инструкциями - это единственная точка контролируемого отличия образа, которая понадобится в задании 9c, чтобы гарантировать другой digest без изменения проверенных здесь security-свойств. После правки сохраните успешный вывод Hadolint в `3/hadolint-after.txt`. |
| Критерии приёмки | Нет `latest`, удалён remote `ADD`, не осталось `API_TOKEN`/`TOKEN`, есть non-root `USER`, есть `ARG CKS_SIGNATURE_TEST` и `LABEL cks.signature-test`; итоговый Hadolint report не содержит `DL3007`, `DL3013`, `DL3020`, `DL3045`. |

<details>
<summary>💡 Подсказка к заданию 3</summary>

`ARG`/`LABEL` для `CKS_SIGNATURE_TEST` может показаться не связанным с текущими findings Hadolint - это специально добавляется здесь заранее, чтобы задание 9c (гораздо позже) могло собрать физически другой образ через `--build-arg`, не переписывая Dockerfile повторно. Добавьте эти две строки сейчас, даже если их польза станет понятна только в 9c.
</details>

---
| **4** | **Исправить workload YAML по kubesec и kube-linter** |
| :---: | :--- |
| Что делаем | Сначала соберите и опубликуйте hardened image из задания 3, затем укажите в `deployment.yaml` его immutable manifest reference `registry/.../catalog@sha256:<manifest-digest>` (не upstream nginx). На уровне Pod добавьте `automountServiceAccountToken: false`, `runAsNonRoot: true`, `seccompProfile: RuntimeDefault`; в контейнере задайте `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]`, requests/limits CPU и memory. Для nginx смонтируйте writable `emptyDir`/tmpfs в temp, pid/run, cache и config paths и подготовьте config до старта. Удалите `privileged`, примените Deployment, подтвердите Ready/Available и успешный HTTP request. Сохраните новые отчёты `4/kubesec-after.json` и `4/kube-linter-after.json`. |
| Критерии приёмки | YAML использует digest-pinned hardened image с `USER 101`, а не upstream nginx; требуемые поля и writable mounts присутствуют; `privileged` отсутствует; Deployment Available и HTTP request успешен; оба итоговых отчёта — валидный JSON. |

<details>
<summary>💡 Подсказка к заданию 4</summary>

`readOnlyRootFilesystem: true` требует writable путей для КАЖДОЙ директории, в которую nginx обычно пишет: `/tmp`, `/var/run` (PID-файл), `/var/cache/nginx` (кэш) и `/etc/nginx/conf.d` (если config генерируется на старте). Если пропустить хоть один - контейнер запустится, но упадёт при первой попытке nginx туда что-то записать. Init container `prepare-nginx-config` нужен для копирования дефолтного конфига в отдельный writable volume ДО старта основного контейнера - именно поэтому упомянут отдельно в критериях приёмки.
</details>

---
| **5** | **Поиск версий пакетов** |
| :---: | :--- |
| Что делаем | Используйте Trivy в режиме списка всех пакетов для `$IMAGE`. Сохраните команду, immutable image reference, канонический `nginx@sha256:<manifest-digest>` из `Metadata.RepoDigests[0]` и как минимум три строки `имя=версия` в `/var/work/tests/artifacts/5/version-search.txt`. Не заменяйте поиск ручным списком: в evidence должна быть строка команды с `trivy image --list-all-pkgs`. |
| Критерии приёмки | Артефакт содержит команду, immutable `nginx:1.27.3-alpine@sha256:...`, `repo_digest=nginx@sha256:...` из Trivy и минимум три пары package/version. |

<details>
<summary>💡 Подсказка к заданию 5</summary>

Флаг называется именно `--list-all-pkgs`, а не `--list-packages` или похожий вариант - проверьте точное имя флага в `trivy image --help`, если команда не срабатывает. Сохраняйте РЕАЛЬНЫЙ вывод команды в файл (например через `tee`), не переписывайте несколько строк package=version вручную "по памяти" - тест ищет строку с самой командой как доказательство, что данные пришли от инструмента.
</details>

---
| **6** | **SPDX SBOM через bom** |
| :---: | :--- |
| Что делаем | Сгенерируйте SPDX JSON SBOM для `nginx:1.27.3-alpine` инструментом `bom` (его нативный формат — SPDX); сохраните в `/var/work/tests/artifacts/6/bom.spdx.json`. В файл `6/bom-command.txt` запишите выполненную команду. |
| Критерии приёмки | SBOM — валидный JSON, имеет `spdxVersion`, содержит массив `packages`; command evidence использует `bom generate`. |

<details>
<summary>💡 Подсказка к заданию 6</summary>

Команда `bom generate -o <output.json> -i <image>` - обязательно с флагом `-o` для указания выходного файла, иначе вывод пойдёт в stdout. Формат вывода `bom` - его СОБСТВЕННЫЙ SPDX JSON, отличающийся по деталям от SPDX, который может генерировать Syft - не путайте эти два разных инструмента при генерации одного и того же формата стандарта.
</details>

---
| **7** | **CycloneDX SBOM через Syft и проверка Cosign** |
| :---: | :--- |
| Что делаем | Сгенерируйте CycloneDX JSON SBOM Syft для `nginx:1.27.3-alpine` в `7/syft.cdx.json`. Затем проверьте подпись публичного образа `gcr.io/distroless/static:nonroot` через keyless Cosign и сохраните полный успешный вывод в `7/cosign-verify.txt`. Для Distroless используйте issuer `https://accounts.google.com` и identity `keyless@distroless.iam.gserviceaccount.com`. |
| Критерии приёмки | Syft SBOM имеет `bomFormat: CycloneDX` и `components`; в выводе Cosign есть `Verified OK` и reference `gcr.io/distroless/static:nonroot`. |

<details>
<summary>💡 Подсказка к заданию 7</summary>

Syft генерирует CycloneDX через флаг `-o cyclonedx-json` (не путать с SPDX-выводом того же инструмента). Для keyless verification Distroless НЕ нужен ни ключ, ни `cosign generate-key-pair` - используйте `cosign verify --certificate-identity <identity> --certificate-oidc-issuer <issuer>` с ТОЧНЫМИ issuer/identity строками, указанными в задании - опечатка в любой из них даст ошибку верификации.
</details>

---
| **8** | **`trivy sbom`: сканирование готового SBOM-файла на уязвимости** |
| :---: | :--- |
| Что делаем | SBOM из задания 6 (`6/bom.spdx.json`) описывает состав image, но сам по себе не содержит вывода об уязвимостях. Просканируйте именно этот SBOM-файл (не image напрямую) инструментом `trivy sbom` и сохраните структурированный JSON в `/var/work/tests/artifacts/8/sbom-scan.json`. Команда должна явно принимать SBOM-файл как вход, а не пересканировать `$IMAGE`. |
| Критерии приёмки | Файл непустой, JSON разбирается `jq`, содержит `Results`; evidence содержит команду `trivy sbom` с путём к `bom.spdx.json` из задания 6. |

<details>
<summary>💡 Подсказка к заданию 8</summary>

Команда - `trivy sbom <путь-к-файлу-sbom>`, а НЕ `trivy image <путь-к-файлу>` - это разные субкоманды с разной логикой ввода. Если вы случайно передадите путь SBOM-файла в `trivy image`, Trivy попытается интерпретировать его как имя image reference и завершится ошибкой или неожиданным поведением.
</details>

---
| **9a** | **Kyverno: установить и создать `ImageValidatingPolicy` на trusted signature** |
| :---: | :--- |
| Что делаем | Установите Kyverno через `install-kyverno` и дождитесь готовности `admission controller`. Сгенерируйте локальную пару ключей `cosign generate-key-pair` (учебная пара, не production key). Подпишите **собственный** hardened image из задания 4 (`$HARDENED_IMAGE`, не upstream nginx) вашим private key и сохраните вывод `cosign sign` в `9a/cosign-sign.txt`. Создайте `ImageValidatingPolicy` `require-signed-catalog-images`, которая проверяет `verifyImageSignatures` вашим public key для всех Pod с image в repository вашего `$HARDENED_IMAGE`, и **отклоняет** (`validationActions: [Deny]`) unsigned/невалидно подписанные образы. |
| Критерии приёмки | Kyverno установлен и его admission controller `Available`; `9a/cosign-sign.txt` содержит успешный вывод подписи именно `$HARDENED_IMAGE`; реальная команда `cosign verify --key cosign.pub "$HARDENED_IMAGE"` завершается успешно; применённая `ImageValidatingPolicy require-signed-catalog-images` существует, имеет `apiVersion: policies.kyverno.io/v1`, `validationActions: [Deny]`, public key и `verifyImageSignatures`, а её `matchImageReferences` ограничены именно `$HARDENED_REPO:*` и `$HARDENED_REPO@*`, а не небезопасным префиксом `$HARDENED_REPO*`. |

<details>
<summary>💡 Подсказка к заданию 9a</summary>

`cosign generate-key-pair` создаёт `cosign.key`/`cosign.pub` в текущей директории - учебная пара, не привязанная ни к какому OIDC issuer, в отличие от keyless verification из задания 7. `matchImageReferences` в policy должен ограничивать её действие ИМЕННО вашим repository (`$HARDENED_REPO`), а не всем кластером - иначе policy заблокирует ВСЕ Pod без подписи, включая системные компоненты Kubernetes.
</details>

---
| **9b** | **Fresh signed ALLOW: новый Pod после создания policy** |
| :---: | :--- |
| Что делаем | Policy из задания 9a должна допустить подписанный `$HARDENED_IMAGE` - но повторный `kubectl apply` уже существующего Deployment **не доказывает** это: если template не изменился, новый ReplicaSet/Pod может не создаться, и `Running` окажется просто старым Pod, созданным до policy. Создайте **новый**, ранее не существовавший объект: `kubectl run signed-admission-check -n cks-111 --image="$HARDENED_IMAGE" --restart=Never --command -- sleep 300`. Сохраните `creationTimestamp` этого Pod, `creationTimestamp` policy из 9a, и итоговый `status.phase`/`Ready` condition в `9b/signed-admission-check.json`. |
| Критерии приёмки | Pod `signed-admission-check` существует, использует именно `$HARDENED_IMAGE`, для него успешно выполняется `cosign verify --key cosign.pub "$HARDENED_IMAGE"`, `status.phase` не `Failed`, а `Ready` условие достигает `True`; `9b/signed-admission-check.json` содержит этот image и `creationTimestamp` Pod **позже**, чем `creationTimestamp` `ImageValidatingPolicy require-signed-catalog-images` - это доказывает fresh post-policy admission именно верифицируемо подписанного image, а не переживший policy старый Pod. |

<details>
<summary>💡 Подсказка к заданию 9b</summary>

Не переиспользуйте Deployment `catalog` из задания 4 для этой проверки - используйте буквально новый `kubectl run` с новым именем Pod, как указано в задании. Оба timestamp (Pod и policy) - строки ISO8601 в UTC, их можно сравнивать лексикографически как обычные строки (`"2026-09-06T10:05:00Z" > "2026-09-06T10:00:00Z"` в bash работает корректно для этого формата).
</details>

---
| **9c** | **Signature-specific DENY: unsigned digest, реально существующий в том же repository** |
| :---: | :--- |
| Что делаем | Соберите и опубликуйте **второй** tag в том же repository, что и `$HARDENED_IMAGE` (например, `${HARDENED_TAG%:*}:unsigned-1.0`), не подписывая его. Этот образ должен быть **физически другим artifact**, а не тем же digest, что уже подписанный `$HARDENED_IMAGE` - если собрать тот же `Dockerfile`/context без изменений, reproducible/cached build может дать идентичный digest, и тогда "unsigned" тег на самом деле укажет на уже подписанный artifact, а `cosign verify` неожиданно пройдёт. Внесите контролируемое отличие через build-arg (например `--build-arg CKS_SIGNATURE_TEST=unsigned-1` с соответствующим `ARG`/`LABEL` в Dockerfile) и явно сохраните доказательство `$UNSIGNED_DIGEST != $HARDENED_DIGEST` в `9c/digest-comparison.txt`. Получите registry manifest digest тем же способом, что в задании 3 (`docker buildx imagetools inspect`), сформируйте `$UNSIGNED_IMAGE` в том же repository. Явно докажите, что этот digest **существует и pullable** (`docker buildx imagetools inspect "$UNSIGNED_IMAGE"` успешен) и **не имеет** валидной подписи вашим ключом (`cosign verify --key cosign.pub "$UNSIGNED_IMAGE"` завершается ошибкой) - сохраните оба вывода в `9c/unsigned-exists.txt` и `9c/unsigned-not-signed.txt`. Затем создайте Pod `catalog-unsigned-probe` с этим `$UNSIGNED_IMAGE` и сохраните admission denial в `9c/admission-deny.txt`. |
| Критерии приёмки | `9c/digest-comparison.txt` подтверждает `$UNSIGNED_DIGEST != $HARDENED_DIGEST`; `9c/unsigned-exists.txt` подтверждает, что `$UNSIGNED_IMAGE` находится в том же repository, что `$HARDENED_IMAGE`, и успешно разрешается registry; `9c/unsigned-not-signed.txt` подтверждает отсутствие валидной подписи; Pod `catalog-unsigned-probe` не создан; `9c/admission-deny.txt` содержит denial, специфичный для проверки подписи (упоминает `ImageValidatingPolicy`/`require-signed-catalog-images`/`signature`/`attestor`), а не любую admission-ошибку (`manifest unknown`/registry lookup недостаточны). |

<details>
<summary>💡 Подсказка к заданию 9c</summary>

Порядок доказательств здесь важен для их достоверности: сначала докажите, что `$UNSIGNED_IMAGE` СУЩЕСТВУЕТ и PULLABLE (иначе последующий denial может быть просто "manifest unknown", а не про подпись), потом докажите ОТСУТСТВИЕ подписи, и только ПОСЛЕ этого пытайтесь создать Pod. Если сравнение digest в `digest-comparison.txt` показывает совпадение - добейтесь реального отличия content (например, измените `CKS_SIGNATURE_TEST` build-arg на другое значение и пересоберите).
</details>

## Проверка

```bash
check_result
```

Проверка содержит `Init` и одиннадцать независимых тестов (задание 9 разделено на 9a/9b/9c). Она проверяет содержимое файлов и
JSON, а не только наличие имён. Внешние registry-запросы требуются для Trivy, SBOM и
Cosign; если registry временно недоступен, повторите именно соответствующую команду.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Удаление

```bash
TASK=111 make delete_cks_task
```
