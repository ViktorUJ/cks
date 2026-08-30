# Лаба 110 - gVisor RuntimeClass, Cilium WireGuard и Istio mTLS

## Цель

В этой CKS-лабе вы соберёте три независимых слоя защиты workload: sandboxed runtime
**gVisor** через `runsc`, межнодовое шифрование Cilium WireGuard и service-to-service
mTLS Istio. В конце вы не только увидите настройки, но и докажете их наблюдаемыми
результатами: отличием kernel view gVisor, WireGuard-пакетами без HTTP marker и разным
результатом вызова из mesh и plaintext-клиента вне mesh.

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
| **1** | **RuntimeClass для runsc** |
| :---: | :--- |
| Что делаем | Проверьте на `k8s110_node_gvisor`, что `runsc` установлен и containerd активен. Создайте `RuntimeClass` `gvisor` с точным `handler: runsc`. В `scheduling` задайте `nodeSelector` `sandbox.runtime/gvisor: "true"`, чтобы Pod с этим классом никогда не попал на обычную ноду. |
| Критерии приёмки | `kubectl get runtimeclass gvisor` существует, handler равен `runsc`, scheduling selector присутствует. В `/var/work/tests/artifacts/1/runsc-runtime.txt` есть точная строка `RuntimeClass gvisor: handler runsc`. |

---
| **2** | **Pod в sandbox gVisor** |
| :---: | :--- |
| Что делаем | В `sandbox-110` создайте Pod `gvisor-sandbox` с `runtimeClassName: gvisor`, контейнером `app`, образом `busybox:1.36` и HTTP server на `8080`, возвращающим строку `CKS110-WIREGUARD-MARKER`. Создайте Service `gvisor-echo` на `8080`, выбирающий этот Pod. Отключите automount ServiceAccount token. Снимите из Pod `uname -r` и `dmesg` в артефакт. |
| Критерии приёмки | Pod `Running` на ноде `sandbox.runtime/gvisor=true`, Service выбирает его, а `/var/work/tests/artifacts/2/gvisor-kernel.txt` содержит строку `gvisor uname -r: <фактическое значение>`. |

---
| **3** | **Сравнение с обычным runc Pod** |
| :---: | :--- |
| Что делаем | Создайте `runc-baseline` в `sandbox-110`: `busybox:1.36`, контейнер `app`, `sleep 3600`, без `runtimeClassName`, с nodeSelector `lab.cks.io/role: control-plane` и без SA token. Сравните его `uname -r` с gVisor Pod и сохраните оба результата в `/var/work/tests/artifacts/3/runtime-comparison.txt`. |
| Критерии приёмки | Baseline Pod `Running` на control-plane, не имеет `runtimeClassName`; его release отличается от gVisor release. В артефакте есть обе строки `gvisor uname -r:` и `runc uname -r:` с фактическими значениями. |

---
| **4** | **Включить Cilium transparent encryption** |
| :---: | :--- |
| Что делаем | Включите WireGuard через `cilium encrypt enable`. Дождитесь готовности агентов и сохраните результат `cilium encrypt status` в `/var/work/tests/artifacts/4/cilium-encrypt-status.txt`. |
| Критерии приёмки | `cilium encrypt status` либо `cilium status` внутри Cilium agent показывает WireGuard; артефакт содержит `WireGuard`/`Encryption: Wireguard`. Не включайте IPsec одновременно с WireGuard. |

---
| **5** | **Доказать отсутствие plaintext между нодами** |
| :---: | :--- |
| Что делаем | На control-plane запустите ограниченный по времени `tcpdump` UDP-порта WireGuard (`51871`) с `-A` и сохраните его в `/var/work/tests/artifacts/5/wireguard-tcpdump.txt`. Пока захват идёт, из `runc-baseline` запросите `http://gvisor-echo.sandbox-110.svc.cluster.local:8080`; ответ должен содержать `CKS110-WIREGUARD-MARKER`. |
| Критерии приёмки | Вызов между разными нодами успешно получает marker; capture содержит UDP/`51871`, но **не** содержит `CKS110-WIREGUARD-MARKER`. Проверяется именно пакет на physical/node interface, а не трафик внутри Pod. |

---
| **6** | **Istio PeerAuthentication STRICT** |
| :---: | :--- |
| Что делаем | Установите Istio из подготовленного `istioctl` (достаточен minimal profile). В `market` создайте `market-api` Deployment и Service `market-api`: приложение слушает `8080`; service port назовите `http`. Создайте injected Deployment `market-client` в `market` и plaintext Pod `mesh-outside` в `default`; все три workload должны быть Running. Примените `PeerAuthentication` `market-strict` namespace `market` с `mtls.mode: STRICT`. Внутренний вызов из `market-client` к `http://market-api` должен вернуть `HTTP/1.1 200 OK`, plaintext вызов из `mesh-outside` к `market-api.market.svc.cluster.local` - `Connection reset by peer`. Сохраните полный вывод в `artifacts/6/market-inside.txt` и `market-outside.txt`. |
| Критерии приёмки | Namespace сохраняет `istio-injection=enabled`; `PeerAuthentication market-strict` имеет `STRICT`; внутри mesh есть HTTP 200, вне mesh curl завершается ошибкой reset; оба доказательства сохранены. Не заменяйте plaintext client sidecar-ом: именно отсутствие sidecar доказывает отказ STRICT. |

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
