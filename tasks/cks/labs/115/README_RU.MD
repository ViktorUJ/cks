[Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 115 - Cilium bootstrap, kube-proxy replacement и Mutual Authentication

> **Advanced / production track. Не входит в формальный CKS Core exam requirement.**
> Эта лаба выходит за рамки экзамена CKS и полезна как production-навык: установка
> Cilium с нуля в роли полной замены kube-proxy, и Cilium Mutual Authentication на
> базе SPIRE. Если вы готовитесь только к экзамену, приоритет - лабы 101-114.

## Описание

Control-plane этой лабы поднят через `kubeadm init --skip-phases=addon/kube-proxy` - без
`kube-proxy` DaemonSet и **без установленного CNI**. Node остаётся `NotReady`, пока вы не
установите Cilium сами. Это осознанно: лаба целиком про ручную установку Cilium в роли
полной замены kube-proxy (`kubeProxyReplacement`), инкрементальное включение WireGuard
transparent encryption и Cilium Mutual Authentication на базе SPIRE - каждый шаг
устанавливается и проверяется отдельно, а не выдаётся уже готовым.

`cilium`/`hubble` CLI уже установлены на worker и указывают на реальный кластер
(`~/.kube/config`), но саму установку Cilium в кластер вы выполняете сами.

## Развёртывание

```bash
TASK=115 make run_cks_task
```

После развёртывания подключитесь по SSH командой из вывода Terraform (`worker_pc_ssh`).
Node будет `NotReady` сразу после логина - это ожидаемый baseline, а не ошибка.

## Цель

Установить Cilium как полную замену kube-proxy на уже поднятом kube-proxy-free
kubeadm-кластере, включить WireGuard encryption, включить Cilium Mutual Authentication
(SPIRE), и написать `CiliumNetworkPolicy`, требующую успешной mutual authentication между
двумя namespace.

## Инфраструктура

| Компонент | Назначение |
| --- | --- |
| control-plane EC2 | kubeadm-кластер без kube-proxy и без CNI на момент выдачи лабы |
| `ingress-115` | namespace клиента, который должен пройти mutual authentication |
| `app-115` | namespace backend, защищённого CiliumNetworkPolicy с `authentication.mode: required` |
| worker EC2 | `cilium`/`hubble` CLI, настроенный kubeconfig |

## Задания

---

|           **1**           | **Baseline: kube-proxy-free, без CNI**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Что делаем       | • Подтвердите текущее состояние кластера, прежде чем что-либо устанавливать |
| Критерии приёмки | • `kube-proxy` DaemonSet отсутствует<br/>• Первоначальный `NotReady` наблюдается перед установкой Cilium<br/>• Checker после выполнения всех заданий подтверждает отсутствие kube-proxy и доступность API, а не исторический `NotReady` |
|        Проверка        | `kubectl -n kube-system get ds kube-proxy` -> `NotFound`. `kubectl get nodes` -> `NotReady` (нет CNI). |

---

|           **2**           | **Установка Cilium как замены kube-proxy**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Что делаем       | • Установите Cilium agent/chart версии `1.20.1` через установленный на worker `cilium` CLI версии `v0.19.7`, с `kubeProxyReplacement=true` и явно заданными `k8sServiceHost`/`k8sServicePort`, указывающими на настоящий API server (не Service ClusterIP - без kube-proxy трафик на ClusterIP `kubernetes.default` не доходит до API server, пока сам Cilium не поднимется) |
| Критерии приёмки | • `KubeProxyReplacement: True/Strict` (в `cilium-dbg status` агента)<br/>• Node становится `Ready`<br/>• ClusterIP Service достижим без kube-proxy |
|        Проверка        | `cilium status --wait`, `kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status \| grep KubeProxyReplacement`, затем `kubectl get nodes` -> `Ready`. Из тестового Pod: `curl https://kubernetes.default.svc.cluster.local/` должен получить HTTP response (не connection error). |

---

|           **3**           | **WireGuard transparent encryption**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Что делаем       | • Включите `encryption.enabled=true`, `encryption.type=wireguard` поверх уже установленного Cilium (`cilium upgrade`, не переустановка с нуля) |
| Критерии приёмки | • `Encryption: Wireguard` в `cilium-dbg status` и `enable-wireguard: "true"` в Cilium ConfigMap<br/>• Путь из задания 2 не регрессировал<br/>• Одноузловой стенд подтверждает включённую конфигурацию WireGuard, но не доказывает зашифрованный межузловой трафик (Peers: 0) |
|        Проверка        | `kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status \| grep Encryption`. Повторите curl из задания 2 - должен снова получить HTTP response. |

---

|           **4**           | **Cilium Mutual Authentication (SPIRE)**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Что делаем       | • Включите встроенную установку SPIRE через сам Cilium helm chart: `authentication.mutual.spire.enabled=true`, `authentication.mutual.spire.install.enabled=true` |
| Критерии приёмки | • `spire-server` StatefulSet и `spire-agent` DaemonSet имеют все запрошенные Ready-реплики в namespace `cilium-spire` |
|        Проверка        | `kubectl get pods -A \| grep spire` - оба типа Pod в состоянии `Running` и Ready. |

> **Особенности стенда.** В кластере нет StorageClass, поэтому SPIRE-серверу нужно эфемерное
> хранилище (`authentication.mutual.spire.install.server.dataStorage.enabled=false`). Образ
> `spire-server` работает от uid 1000 и не может создать сокет в hostPath-каталоге `root:755` -
> запустите его от root (`authentication.mutual.spire.install.server.securityContext.runAsUser=0`).
> Также chart требует `authentication.enabled=true`. Детали - в эталонном решении.

---

|           **5**           | **CiliumNetworkPolicy с обязательной mutual authentication**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       Что делаем       | • Создайте `ingress-115` (client) и `app-115` (backend, label `app=backend`, Service `backend`)<br/>• Создайте `CiliumNetworkPolicy backend-auth-required` в `app-115`: `endpointSelector` на `app=backend`, ingress только из namespace `ingress-115`, и `authentication.mode: required` на этом ingress-правиле |
| Критерии приёмки | • Policy точно селектит backend, содержит одно ingress-правило из `ingress-115` на TCP/80 с `authentication.mode: required`<br/>• Дополнительных ingress-правил и путей обхода нет<br/>• В изолированном стенде Lab 115 нет других namespaced/global network policies, влияющих на backend<br/>• Service `backend` направлен на Ready Pod `backend` |
|        Проверка        | `kubectl -n app-115 get ciliumnetworkpolicy backend-auth-required -o yaml` - проверьте `authentication.mode: required` внутри `ingress[0]`. |

---

|           **6**           | **Positive/negative control: authenticated identity разрешена, посторонняя - нет**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Что делаем       | • Проверьте эффект policy живым трафиком: клиент из `ingress-115` должен достигать `backend` (после успешного SPIRE-based mutual auth handshake)<br/>• Отдельный Pod из "неправильного" namespace (`app-115`, не `ingress-115`; трафик backend к самому себе Cilium всегда пропускает) должен быть заблокирован |
| Критерии приёмки | • В изолированном зеркальном backend baseline разрешает оба клиента, после применения копии policy разрешён только `ingress-115`<br/>• Действующий backend отвечает разрешённому клиенту, отклоняет клиентов из `app-115` и нового независимого namespace<br/>• Cilium BPF auth map содержит `spire` для точной пары identity клиента/backend |
|        Проверка        | `curl` из client-пода в `ingress-115` к `http://backend.app-115.svc.cluster.local/` -> HTTP response. Тот же curl из Pod в `app-115` без label клиента -> connection error. |

## Проверка

```bash
check_result
```

Checker **никогда не снимает действующую** `app-115/backend-auth-required`. Для проверки baseline он создаёт временный зеркальный backend и Service в одноразовом namespace `cks-115-*`, сначала проверяет разрешённый трафик без policy, затем применяет копию проверенной CiliumNetworkPolicy только к зеркальному backend. Отдельно проверяются реальный backend, EndpointSlice, точные пары SPIRE identities в BPF auth map и запрет клиентов из посторонних namespace. Все созданные Pod, Service, policy и временный namespace удаляются с проверкой cleanup.

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Удаление

```bash
TASK=115 make delete_cks_task
```
