# Лаба 110 - gVisor RuntimeClass, Cilium WireGuard и Istio mTLS

## Цель

В этой CKS-лабе вы соберёте три независимых слоя защиты workload: sandboxed runtime
**gVisor** через `runsc`, межнодовое шифрование Cilium WireGuard и service-to-service
mTLS Istio. В конце вы не только увидите настройки, но и докажете их наблюдаемыми
результатами: отличием kernel view gVisor, WireGuard-пакетами без HTTP marker и разным
результатом вызова из mesh и plaintext-клиента вне mesh.

## Проверьте себя перед стартом

<details>
<summary>1. Чем userspace kernel gVisor принципиально отличается от guest kernel виртуальной машины?</summary>

gVisor (`runsc`) реализует собственное подмножество Linux syscalls В USERSPACE, перехватывая системные вызовы контейнера и обрабатывая их сам, не передавая их напрямую хостовому ядру - процесс контейнера видит другое "ядро" (другой `uname -r`, другое поведение некоторых syscalls). Guest kernel (например, Kata Containers) запускает ПОЛНОЦЕННОЕ ядро Linux внутри легковесной VM - более сильная изоляция, но с оверхедом полноценной виртуализации, которого нет у gVisor.
</details>

<details>
<summary>2. Что именно аутентифицирует WireGuard peer, и почему это НЕ то же самое, что identity ServiceAccount?</summary>

WireGuard аутентифицирует УЗЛЫ (nodes) кластера через криптографические ключи, сгенерированные Cilium для каждой ноды - шифрование происходит на уровне node-to-node туннеля. Это защищает трафик МЕЖДУ нодами от прослушивания на сетевом уровне, но не имеет отношения к identity конкретного Pod/ServiceAccount внутри этого трафика - Cilium WireGuard не проверяет, "кто" отправитель на уровне приложения, только "какая нода".
</details>

<details>
<summary>3. Почему успешный `curl` с кодом 200 внутри mesh НЕ доказывает, что plaintext client реально был заблокирован?</summary>

Успешный ответ ВНУТРИ mesh доказывает только то, что mTLS-соединение между двумя sidecar-ами работает - это positive control. Чтобы доказать, что STRICT реально блокирует НЕ-mesh трафик, нужен отдельный negative control: клиент БЕЗ sidecar, пытающийся обратиться к тому же сервису, и получающий отказ. Одного успешного теста недостаточно - нужны оба: allowed для mesh identity, denied для plaintext.
</details>

## Связь с курсом

- [Глава 22. Container Runtime Sandbox](../../course/22/ru.md)
- [Глава 23. Pod-to-Pod шифрование и mTLS](../../course/23/ru.md)

## Инфраструктура

Terragrunt создаёт Kubernetes `1.36.0` в `eu-central-1`:

| Компонент | Назначение |
|---|---|
| `k8s-1` control-plane | обычный containerd workload node, Cilium и `tcpdump` для захвата межнодового пакета |
| `k8s-1` worker `gvisor` | отдельная нода с containerd, установленными `runsc` и CRI handler `runsc` |
| CNI | **Cilium**; WireGuard намеренно выключен до задания 4 |
| `worker` | рабочая машина с `kubectl`, `cilium`, `istioctl`, `check_result` и SSH aliases к нодам |

Проверенная 2026-08-31 матрица (сверяйте перед каждой сборкой): Kubernetes обучения
`1.36.0`; Cilium data plane — поддерживаемая lab-сборка, совместимость которой с
Kubernetes `1.36` надо подтвердить по актуальной requirements matrix; Cilium CLI `0.19.7`
(совместим с Cilium `1.17+`); Istio `1.30.4` (ветка `1.30` официально поддерживает Kubernetes
`1.32–1.36`). Версия экзамена здесь не определяет совместимость lab tooling; по данным LF
она сейчас `v1.34` и проверяется отдельно перед экзаменом.

После bootstrap доступны два workload placement label:

```text
lab.cks.io/role=control-plane
sandbox.runtime/gvisor=true,lab.cks.io/role=gvisor
```

Неймспейсы `sandbox-110` и `market` уже существуют. У `market` заранее поставлена
метка `istio-injection=enabled`; Istio control plane не установлен. Для доступа к
sandbox-ноде с worker используйте alias `k8s110_node_gvisor`, к control-plane -
`k8s110_controlPlane_1`.

## Развёртывание

```bash
TASK=110 make run_cks_task
```

Подключитесь к рабочей машине и выберите готовый контекст:

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

Создайте каталог доказательств до начала работы:

```bash
mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6}
```

## Задания

---
| **1** | **Настроить containerd runtime и создать RuntimeClass для runsc** |
| :---: | :--- |
| Что делаем | На `k8s110_node_gvisor` бинарник `runsc` уже установлен, но bootstrap намеренно убрал из `/etc/containerd/config.toml` секцию `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]` с `runtime_type = "io.containerd.runsc.v1"` - это типичная экзаменационная ситуация со сломанным config.toml. Верните эту секцию (резервная копия лежит в `/etc/containerd/config.toml.bak`, либо допишите её вручную) и выполните `sudo systemctl restart containerd`. Затем создайте `RuntimeClass` `gvisor` с точным `handler: runsc`. В `scheduling` задайте `nodeSelector` `sandbox.runtime/gvisor: "true"`, чтобы Pod с этим классом никогда не попал на обычную ноду. |
| Критерии приёмки | На ноде `containerd` активен и `config.toml` содержит рабочую секцию `runtimes.runsc` с `runtime_type = "io.containerd.runsc.v1"`. `kubectl get runtimeclass gvisor` существует, handler равен `runsc`, scheduling selector присутствует. В `/var/work/tests/artifacts/1/runsc-runtime.txt` есть точная строка `RuntimeClass gvisor: handler runsc`. |

<details>
<summary>💡 Подсказка к заданию 1</summary>

Резервная копия `/etc/containerd/config.toml.bak` - самый быстрый путь восстановления, но проверьте её содержимое перед копированием обратно (`diff` с текущим файлом), чтобы понять, что именно отсутствует. После восстановления секции `runtimes.runsc` обязательно `systemctl restart containerd` - простое редактирование файла не применяет изменения к уже работающему процессу.
</details>

---
| **2** | **Pod в sandbox gVisor** |
| :---: | :--- |
| Что делаем | В `sandbox-110` создайте Pod `gvisor-sandbox` с `runtimeClassName: gvisor`, контейнером `app`, образом `busybox:1.36` и HTTP server на `8080`, возвращающим строку `CKS110-WIREGUARD-MARKER`. Создайте Service `gvisor-echo` на `8080`, выбирающий этот Pod. Отключите automount ServiceAccount token. Снимите из Pod `uname -r` и `dmesg` в артефакт: `dmesg` внутри gVisor sandbox начинается строкой `Starting gVisor...` вместо реального лога ядра ноды - это прямое доказательство изоляции, отдельное от разницы `uname -r`. |
| Критерии приёмки | Pod `Running` на ноде `sandbox.runtime/gvisor=true`, Service выбирает его, а `/var/work/tests/artifacts/2/gvisor-kernel.txt` содержит строку `gvisor uname -r: <фактическое значение>` и строку `Starting gVisor` из вывода `dmesg`. |

<details>
<summary>💡 Подсказка к заданию 2</summary>

Если Pod не запускается (CreateContainerError/RuntimeCreateError), скорее всего задание 1 не полностью завершено - RuntimeClass должен реально указывать на работающий containerd handler. `busybox` не имеет встроенного HTTP-сервера - используйте простой трюк вроде `nc -lk -p 8080 -e echo` в цикле, или аналогичный минимальный подход через `sh -c`.
</details>

---
| **3** | **Сравнение с обычным runc Pod** |
| :---: | :--- |
| Что делаем | Создайте `runc-baseline` в `sandbox-110`: `busybox:1.36`, контейнер `app`, `sleep 3600`, без `runtimeClassName`, с nodeSelector `lab.cks.io/role: control-plane` и без SA token. Сравните его `uname -r` с gVisor Pod и сохраните оба результата в `/var/work/tests/artifacts/3/runtime-comparison.txt`. |
| Критерии приёмки | Baseline Pod `Running` на control-plane, не имеет `runtimeClassName`; его release отличается от gVisor release. В артефакте есть обе строки `gvisor uname -r:` и `runc uname -r:` с фактическими значениями. |

<details>
<summary>💡 Подсказка к заданию 3</summary>

Этот Pod специально размещается на ДРУГОЙ ноде (control-plane, не gvisor-нода) через nodeSelector `lab.cks.io/role: control-plane` - это не просто "любой обычный Pod", а контролируемое сравнение с известным местом размещения. Если `uname -r` окажется одинаковым для обоих Pod - проверьте, действительно ли `gvisor-sandbox` использует `runtimeClassName: gvisor`.
</details>

---
| **4** | **Включить Cilium transparent encryption** |
| :---: | :--- |
| Что делаем | Сначала зафиксируйте версии Kubernetes, Cilium agent и Cilium CLI в `/var/work/tests/artifacts/4/tool-versions.txt` и убедитесь, что data plane поддерживает Kubernetes `1.36`. Включите WireGuard через source-of-truth конфигурацию: Helm upgrade с `encryption.enabled=true,encryption.type=wireguard` для Helm-managed установки либо documented ConfigMap key `enable-wireguard: true` с rollout агентов. Не используйте удалённый workflow `cilium encrypt enable`. Сохраните agent-side `cilium-dbg encrypt status` и `cilium-dbg status --all-encryption` в `/var/work/tests/artifacts/4/cilium-encrypt-status.txt`. `cilium-dbg` установлен вместе с Cilium agent и вызывается через `kubectl exec`; локальный `cilium` CLI предназначен для install/cluster-level операций. |
| Критерии приёмки | Version evidence существует; Cilium agents готовы; status показывает WireGuard и не показывает одновременно IPsec; `--all-encryption` содержит evidence peer/allowed-IP (или remote-node) для межнодового состояния; настройка переживает restart агента. |

<details>
<summary>💡 Подсказка к заданию 4</summary>

Используйте именно declared source-of-truth (Helm values или ConfigMap key) для включения WireGuard, а не эфемерную CLI-команду `cilium encrypt enable` - последняя может не переживать restart агента или обновление Helm release, а тест специально проверяет, что настройка survives restart. `cilium-dbg` вызывается ВНУТРИ Pod агента через `kubectl exec`, а не как отдельный локальный бинарник на worker.
</details>

---
| **5** | **Доказать отсутствие plaintext между нодами** |
| :---: | :--- |
| Что делаем | На control-plane запустите ограниченный по времени `tcpdump` UDP-порта WireGuard (`51871`) с `-A` и сохраните его в `/var/work/tests/artifacts/5/wireguard-tcpdump.txt`. Пока захват идёт, из `runc-baseline` запросите `http://gvisor-echo.sandbox-110.svc.cluster.local:8080`; ответ должен содержать `CKS110-WIREGUARD-MARKER`. |
| Критерии приёмки | Вызов между разными нодами успешно получает marker; capture содержит UDP/`51871`, но **не** содержит `CKS110-WIREGUARD-MARKER`. Проверяется именно пакет на physical/node interface, а не трафик внутри Pod. |

<details>
<summary>💡 Подсказка к заданию 5</summary>

Захватывайте трафик на РЕАЛЬНОМ физическом сетевом интерфейсе ноды (например `eth0`), а не на виртуальном интерфейсе Pod/veth - если capture идёт "внутри" пути Pod до шифрования WireGuard, вы увидите plaintext HTTP независимо от того, включено ли шифрование node-to-node. Запускайте `tcpdump` В ФОНЕ ДО того, как выполните HTTP-запрос, не после.
</details>

---
| **6** | **Istio PeerAuthentication STRICT** |
| :---: | :--- |
| Что делаем | Установите закреплённый Istio `1.30.4` из подготовленного `istioctl` (достаточен minimal profile) и зафиксируйте версию control plane. В `market` создайте `market-api` Deployment и Service `market-api`: приложение слушает `8080`; service port назовите `http`. Создайте injected Deployment `market-client` в `market` и plaintext Pod `mesh-outside` в `default`; все три workload должны быть Running. Примените `PeerAuthentication` `market-strict` namespace `market` с `mtls.mode: STRICT`. In-mesh запрос должен получить HTTP 200, а plaintext client без sidecar — не получить успешный application response. Сохраните status/headers/exit code в `artifacts/6/market-inside.txt` и `market-outside.txt`; не сопоставляйте конкретную строку socket error. |
| Критерии приёмки | Namespace сохраняет `istio-injection=enabled`; `PeerAuthentication market-strict` имеет `STRICT`; внутри mesh есть HTTP 200, а plaintext-вызов вне mesh не получает успешный HTTP-ответ (curl падает, нет 2xx) - независимо от точного текста ошибки; оба доказательства сохранены. Не заменяйте plaintext client sidecar-ом: именно отсутствие sidecar доказывает отказ STRICT. |

<details>
<summary>💡 Подсказка к заданию 6</summary>

Service port ДОЛЖЕН называться именно `http` (не `market-api` или что-то другое) - Istio использует named port convention для определения протокола и правильной обработки трафика через sidecar. `market-client` создаётся ПОСЛЕ того, как namespace получил `istio-injection=enabled`, - если Deployment был создан ДО этой метки, sidecar не будет автоматически добавлен, и придётся пересоздать Pod (не Deployment) для инъекции.
</details>

## Проверка

```bash
check_result
```

Проверка содержит `0 Init` и шесть обязательных тестов. Тесты 1-3 проверяют
`RuntimeClass`, placement и реальную разницу `uname`; тесты 4-5 проверяют WireGuard
status, межнодовый запрос и отсутствие marker в tcpdump; тест 6 заново выполняет оба
mTLS-вызова и проверяет артефакты. Если Istio Pods ещё создаются, дождитесь
`kubectl get pods -n market` с `2/2 Running` у injected workload.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Удаление

```bash
TASK=110 make delete_cks_task
```
