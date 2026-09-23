# Lab 115 - Cilium bootstrap, kube-proxy replacement и Mutual Authentication

> **Advanced / production track. Не входит в формальный CKS Core exam requirement.**
> Эта лаба выходит за рамки экзамена CKS и полезна как production-навык: установка
> Cilium с нуля в роли полной замены kube-proxy, и Cilium Mutual Authentication на
> базе SPIRE. Если вы готовитесь только к экзамену, приоритет - лабы 101-113.

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
|       Что делаем       | Подтвердите текущее состояние кластера, прежде чем что-либо устанавливать. |
| Критерии приёмки | `kube-proxy` DaemonSet отсутствует. |
|        Проверка        | `kubectl -n kube-system get ds kube-proxy` -> `NotFound`. `kubectl get nodes` -> `NotReady` (нет CNI). |

---

|           **2**           | **Установка Cilium как замены kube-proxy**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Что делаем       | Установите Cilium (та же версия, что и на worker CLI) с `kubeProxyReplacement=true` и явно заданными `k8sServiceHost`/`k8sServicePort`, указывающими на настоящий API server (не Service ClusterIP - без kube-proxy кластер не может резолвить `kubernetes.default` до того, как Cilium сам поднимется). |
| Критерии приёмки | `cilium status` -> `KubeProxyReplacement: True/Strict`; node становится `Ready`; ClusterIP Service достижим без kube-proxy. |
|        Проверка        | `cilium status --wait`, затем `kubectl get nodes` -> `Ready`. Из тестового Pod: `curl https://kubernetes.default.svc.cluster.local/` должен получить HTTP response (не connection error). |

---

|           **3**           | **WireGuard transparent encryption**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Что делаем       | Включите `encryption.enabled=true`, `encryption.type=wireguard` поверх уже установленного Cilium (`cilium upgrade`, не переустановка с нуля). |
| Критерии приёмки | `cilium status` -> `Encryption: Wireguard`; путь из задания 2 не регрессировал. |
|        Проверка        | `cilium status` grep `Encryption`. Повторите curl из задания 2 - должен снова получить HTTP response. |

---

|           **4**           | **Cilium Mutual Authentication (SPIRE)**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Что делаем       | Включите встроенную установку SPIRE через сам Cilium helm chart: `authentication.mutual.spire.enabled=true`, `authentication.mutual.spire.install.enabled=true`. |
| Критерии приёмки | `spire-server` и `spire-agent` Pod'ы Ready. |
|        Проверка        | `kubectl get pods -A \| grep spire` - оба типа Pod в состоянии `Running`/`1/1`. |

---

|           **5**           | **CiliumNetworkPolicy с обязательной mutual authentication**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       Что делаем       | Создайте `ingress-115` (client) и `app-115` (backend, label `app=backend`, Service `backend`). Создайте `CiliumNetworkPolicy backend-auth-required` в `app-115`: `endpointSelector` на `app=backend`, ingress только из namespace `ingress-115`, и `authentication.mode: required` на этом ingress-правиле. |
| Критерии приёмки | Policy селектит backend, разрешает только `ingress-115`, требует mutual authentication. |
|        Проверка        | `kubectl -n app-115 get ciliumnetworkpolicy backend-auth-required -o yaml` - проверьте `authentication.mode: required` внутри `ingress[0]`. |

---

|           **6**           | **Positive/negative control: authenticated identity позволена, посторонняя - нет**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Что делаем       | Проверьте эффект policy живым трафиком: клиент из `ingress-115` должен достигать `backend` (после успешного SPIRE-based mutual auth handshake); Pod из "неправильного" namespace (`app-115` сам, не `ingress-115`) должен быть заблокирован. |
| Критерии приёмки | `ingress-115` -> `backend` = allow (до и после применения policy - baseline не был `default-deny`); чужая identity -> `backend` = deny. |
|        Проверка        | `curl` из client-пода в `ingress-115` к `http://backend.app-115.svc.cluster.local/` -> HTTP response. Тот же curl из Pod в `app-115` без label клиента -> connection error. |

## Проверка

```bash
check_result
```

Checker сам временно снимает и возвращает `backend-auth-required`, чтобы живьём доказать
baseline (до policy) и эффект (после), и независимо проверяет `cilium status`,
`spire-server`/`spire-agent` health и Service datapath без kube-proxy.

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Удаление

```bash
TASK=115 make delete_cks_task
```
