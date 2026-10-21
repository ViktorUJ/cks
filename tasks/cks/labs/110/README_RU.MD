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
| CNI | **Cilium** (установлен через Cilium CLI с Helm release `cilium`); WireGuard намеренно выключен до задания 4 |
| `worker` | рабочая машина с `kubectl`, `cilium`, `istioctl`, `check_result` и SSH aliases к нодам |

Проверенная 2026-08-31 матрица (сверяйте перед каждой сборкой): Kubernetes обучения
`1.36.0`; Cilium data plane - поддерживаемая lab-сборка, совместимость которой с
Kubernetes `1.36` надо подтвердить по актуальной requirements matrix; Cilium CLI `0.19.7`
(совместим с Cilium `1.17+`); Istio `1.30.4` (ветка `1.30` официально поддерживает Kubernetes
`1.32–1.36`). Версия экзамена здесь не определяет совместимость lab tooling; по данным LF
она сейчас `v1.34` и проверяется отдельно перед экзаменом.

После bootstrap доступны два workload placement label:

```text
lab.cks.io/role=control-plane
sandbox.runtime/gvisor=true,lab.cks.io/role=gvisor
```

Control-plane доступен для обычных Pod без tolerations. gVisor-нода дополнительно помечена taint
`sandbox.runtime/gvisor=true:NoSchedule`: на неё попадают только Pod, которые этот taint терпят
(Pod с `RuntimeClass gvisor` получают нужный toleration из `scheduling.tolerations` класса).

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
| Что делаем | • На `k8s110_node_gvisor` бинарник `runsc` уже установлен, но bootstrap намеренно убрал из `/etc/containerd/config.toml` секцию `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]` с `runtime_type = "io.containerd.runsc.v1"` - это типичная экзаменационная ситуация со сломанным config.toml.<br/>• Верните эту секцию (резервная копия лежит в `/etc/containerd/config.toml.bak`, либо допишите её вручную) и выполните `sudo systemctl restart containerd`.<br/>• Создайте `RuntimeClass` `gvisor` с точным `handler: runsc`.<br/>• В `scheduling` задайте `nodeSelector` `sandbox.runtime/gvisor: "true"`, чтобы Pod с этим классом никогда не попал на обычную ноду, и `tolerations` для taint gVisor-ноды (`sandbox.runtime/gvisor=true:NoSchedule`), иначе Pod туда не попадёт. |
| Критерии приёмки | • На ноде `containerd` активен и `config.toml` содержит рабочую секцию `runtimes.runsc` с `runtime_type = "io.containerd.runsc.v1"`<br/>• `kubectl get runtimeclass gvisor` существует, handler равен `runsc`, в `scheduling` есть `nodeSelector` и `tolerations` для taint gVisor-ноды<br/>• В `/var/work/tests/artifacts/1/runsc-runtime.txt` есть точная строка `RuntimeClass gvisor: handler runsc` |

<details>
<summary>💡 Подсказка к заданию 1</summary>

Резервная копия `/etc/containerd/config.toml.bak` - самый быстрый путь восстановления, но проверьте её содержимое перед копированием обратно (`diff` с текущим файлом), чтобы понять, что именно отсутствует. После восстановления секции `runtimes.runsc` обязательно `systemctl restart containerd` - простое редактирование файла не применяет изменения к уже работающему процессу.
</details>

---
| **2** | **Pod в sandbox gVisor** |
| :---: | :--- |
| Что делаем | • В `sandbox-110` создайте Pod `gvisor-sandbox` с `runtimeClassName: gvisor`, контейнером `app` и образом `busybox:1.36`.<br/>• Укажите в Pod явно `nodeSelector` `sandbox.runtime/gvisor: "true"` и `tolerations` для taint gVisor-ноды (то же, что в `scheduling` RuntimeClass; без них Kubernetes добавит их из RuntimeClass сам, но в манифесте этого не будет видно).<br/>• Запустите в контейнере HTTP server на `8080`, возвращающий строку `CKS110-WIREGUARD-MARKER`.<br/>• Создайте Service `gvisor-echo` на `8080`, выбирающий этот Pod.<br/>• Отключите automount ServiceAccount token.<br/>• Снимите из Pod `uname -r` и `dmesg` в артефакт: `dmesg` внутри gVisor sandbox начинается строкой `Starting gVisor...` вместо реального лога ядра ноды - это прямое доказательство изоляции, отдельное от разницы `uname -r`. |
| Критерии приёмки | • Pod `Running` на ноде `sandbox.runtime/gvisor=true`, Service выбирает его, а `/var/work/tests/artifacts/2/gvisor-kernel.txt` содержит строку `gvisor uname -r: <фактическое значение>` и строку `Starting gVisor` из вывода `dmesg` |

<details>
<summary>💡 Подсказка к заданию 2</summary>

Если Pod не запускается (CreateContainerError/RuntimeCreateError), скорее всего задание 1 не полностью завершено - RuntimeClass должен реально указывать на работающий containerd handler. В используемом `busybox:1.36` есть applet `httpd` - используйте `httpd -f -p 8080 -h /www` для минимального HTTP server (проверить наличие applet можно через `busybox --list | grep '^httpd$'`).
</details>

---
| **3** | **Сравнение с обычным runc Pod** |
| :---: | :--- |
| Что делаем | • Создайте `runc-baseline` в `sandbox-110`: `busybox:1.36`, контейнер `app`, `sleep 3600`.<br/>• Без `runtimeClassName`, с nodeSelector `lab.cks.io/role: control-plane` и без SA token.<br/>• Сравните его `uname -r` с gVisor Pod и сохраните оба результата в `/var/work/tests/artifacts/3/runtime-comparison.txt`. |
| Критерии приёмки | • Baseline Pod `Running` на control-plane, не имеет `runtimeClassName`<br/>• Его release отличается от gVisor release<br/>• В артефакте есть обе строки `gvisor uname -r:` и `runc uname -r:` с фактическими значениями |

<details>
<summary>💡 Подсказка к заданию 3</summary>

Этот Pod специально размещается на ДРУГОЙ ноде (control-plane, не gvisor-нода) через nodeSelector `lab.cks.io/role: control-plane` - это не просто "любой обычный Pod", а контролируемое сравнение с известным местом размещения. Если `uname -r` окажется одинаковым для обоих Pod - проверьте, действительно ли `gvisor-sandbox` использует `runtimeClassName: gvisor`.
</details>

---
| **4** | **Включить Cilium transparent encryption** |
| :---: | :--- |
| Что делаем | • Сначала зафиксируйте версии Kubernetes, Cilium agent и Cilium CLI в `/var/work/tests/artifacts/4/tool-versions.txt` и убедитесь, что data plane поддерживает Kubernetes `1.36`.<br/>• Включите WireGuard в существующем Helm release, созданном `cilium install`: `cilium upgrade --version 1.20.1 --set encryption.enabled=true --set encryption.type=wireguard --wait`.<br/>• Перезапустите агентов (`kubectl -n kube-system rollout restart daemonset/cilium`): Helm меняет только ConfigMap, а шаблон DaemonSet остаётся прежним.<br/>• Проверьте `cilium-config` (`enable-wireguard: "true"`) и готовность обоих Cilium agents.<br/>• Прямой ConfigMap patch допустим только как кратковременная учебная baseline-проба с обязательным подтверждённым rollback. Не используйте удалённый workflow `cilium encrypt enable`.<br/>• Сохраните agent-side `cilium-dbg encrypt status` и `cilium-dbg debuginfo --output json` в `/var/work/tests/artifacts/4/cilium-encrypt-status.txt` (у `cilium-dbg status` нет флага `--all-encryption`). |
| Критерии приёмки | • Version evidence существует и совпадает с реальным образом DaemonSet `kube-system/cilium`<br/>• Cilium agents (DaemonSet) полностью Ready<br/>• Status показывает WireGuard и не показывает одновременно IPsec<br/>• Debuginfo JSON содержит evidence peer/allowed-IP (или remote-node) для межнодового состояния<br/>• ConfigMap `kube-system/cilium-config` содержит `enable-wireguard: "true"` как применённую effective-конфигурацию из Helm values<br/>• Настройка переживает restart одного agent Pod (checker перезапускает Pod и повторно проверяет статус) |

<details>
<summary>💡 Подсказка к заданию 4</summary>

Используйте Helm values существующего release `cilium` как долговременный source-of-truth для включения WireGuard, а не эфемерную CLI-команду `cilium encrypt enable` - последняя может не переживать restart агента или обновление Helm release, а тест специально проверяет, что настройка survives restart. `cilium-dbg` вызывается ВНУТРИ Pod агента через `kubectl exec`, а не как отдельный локальный бинарник на worker. У `cilium-dbg status` НЕТ флага `--all-encryption` - для подробного peer/allowed-IP evidence используйте `cilium-dbg debuginfo --output json`.
</details>

---
| **5** | **Доказать отсутствие plaintext между нодами** |
| :---: | :--- |
| Что делаем | • Постройте baseline-доказательство ДО/ПОСЛЕ по одному и тому же межнодовому flow.<br/>• **Baseline (WireGuard выключен):** на control-plane запустите `tcpdump` по IP удалённой ноды (`host <remote-node-ip>`, без предварительного фильтра по `udp port 51871`); временно отключите WireGuard (`enable-wireguard: "false"` в `cilium-config`, `rollout restart daemonset/cilium`); выполните запрос `runc-baseline -> gvisor-echo`; сохраните этот baseline-capture и убедитесь, что в нём виден plaintext `CKS110-WIREGUARD-MARKER`.<br/>• **После (WireGuard включён):** восстановите `enable-wireguard: "true"`, дождитесь Ready и повторите ТОТ ЖЕ запрос с ТЕМ ЖЕ scope захвата (`host <remote-node-ip>`, без фильтра по порту).<br/>• Capture снимается на control-plane (в файл на узле), затем копируется `scp` на рабочую машину в `/var/work/tests/artifacts/5/wireguard-tcpdump.txt`: в нём теперь должен быть виден только WireGuard UDP/`51871`, без plaintext marker. |
| Критерии приёмки | • Итоговый (post-change) capture по тому же peer/interface scope содержит UDP/`51871`, но **не** содержит `CKS110-WIREGUARD-MARKER`<br/>• Вызов между разными нодами успешно получает marker в HTTP-ответе<br/>• Checker самостоятельно повторяет post-change capture по тому же peer/interface scope (не ограничиваясь заранее только `udp port 51871`), а также самостоятельно временно отключает и восстанавливает WireGuard для получения собственного baseline-подтверждения того, что тот же flow в plaintext-состоянии действительно раскрывает marker на wire |

<details>
<summary>💡 Подсказка к заданию 5</summary>

Захватывайте трафик на РЕАЛЬНОМ физическом сетевом интерфейсе ноды (например `eth0`), а не на виртуальном интерфейсе Pod/veth или внутреннем Cilium-интерфейсе `cilium_wg0` - `cilium_wg0` по конструкции WireGuard-туннеля несёт УЖЕ РАСШИФРОВАННЫЙ трафик (это и есть его назначение), поэтому захват на `any` увидит marker там даже при исправно работающем шифровании на физическом NIC. Определите конкретный физический интерфейс через `ip route get <remote-node-ip>` и используйте именно его. Если capture идёт "внутри" пути Pod до шифрования WireGuard, вы увидите plaintext HTTP независимо от того, включено ли шифрование node-to-node. Запускайте `tcpdump` В ФОНЕ ДО того, как выполните HTTP-запрос, не после. Фильтр захвата ТОЛЬКО по `udp port 51871` заранее исключает plaintext TCP из результата и поэтому НЕ доказывает его отсутствие - используйте `host <remote-node-ip>` без port-фильтра, чтобы один и тот же scope мог реально показать разницу до/после включения WireGuard. Checker выполняет собственный `tcpdump` одновременно со своим запросом (включая baseline-пробу с временным отключением WireGuard и проверенным последующим восстановлением) - ваш artifact учебно полезен, но не является единственным доказательством: если шифрование реально не работает в момент проверки, checker-овский live capture это обнаружит независимо от содержимого вашего файла.
</details>

---
| **6** | **Istio PeerAuthentication STRICT** |
| :---: | :--- |
| Что делаем | • Установите закреплённый Istio `1.30.4` из подготовленного `istioctl` (достаточен minimal profile) и зафиксируйте версию control plane.<br/>• В `market` создайте `market-api` Deployment и Service `market-api`: приложение слушает `8080`, service port назовите `http`. `market-api` должен работать на gVisor-ноде: `nodeSelector` `lab.cks.io/role: gvisor` и toleration для её taint (`sandbox.runtime/gvisor=true:NoSchedule`).<br/>• Создайте injected Deployment `market-client` в `market` и plaintext Pod `mesh-outside` в `default`; все три workload должны быть Running - **без** `PeerAuthentication` STRICT.<br/>• **Baseline:** тот же outside plaintext-запрос к `market-api` должен получить HTTP 200 (mTLS ещё не требуется); сохраните этот baseline-ответ отдельно.<br/>• Примените `PeerAuthentication` `market-strict` namespace `market` с `mtls.mode: STRICT` и повторите ТОТ ЖЕ outside-запрос: plaintext client без sidecar не должен получить успешный application response, а in-mesh запрос должен получить HTTP 200.<br/>• Сохраните status/headers/exit code в `artifacts/6/market-inside.txt` и `market-outside.txt` (в конец `market-outside.txt` допишите строку `exit_code=<код завершения curl>`); не сопоставляйте конкретную строку socket error. |
| Критерии приёмки | • Namespace сохраняет `istio-injection=enabled`<br/>• `PeerAuthentication market-strict` имеет `STRICT`<br/>• Внутри mesh есть HTTP 200, а plaintext-вызов вне mesh не получает успешный HTTP-ответ (curl падает, нет 2xx, `exit_code` в файле non-zero) - независимо от точного текста ошибки<br/>• Оба доказательства сохранены, `market-inside.txt` содержит `exit_code=0`<br/>• Не заменяйте plaintext client sidecar-ом: именно отсутствие sidecar доказывает отказ STRICT.<br/>• Checker дополнительно самостоятельно повторяет ДО/ПОСЛЕ: временно переключает ту же policy в `PERMISSIVE`, повторяет тот же plaintext-запрос и требует 200 - это доказывает, что предыдущий отказ был вызван именно STRICT mTLS, а не независимой DNS/network-проблемой<br/>• Затем checker восстанавливает `STRICT` |

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
