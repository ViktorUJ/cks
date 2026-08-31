[Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Лаба 103 - CIS/kube-bench, Secure Ingress TLS и проверка бинарников

## Описание

В этой лабораторной работе вы настраиваете одноузловой Kubernetes-кластер как инженер
по безопасности: фиксируете исходную картину CIS Benchmark, исправляете небезопасные
параметры kubelet и kube-apiserver, публикуете Ingress только по TLS, ограничиваете TLS
control plane и подтверждаете целостность установленных Kubernetes-бинарников.

Это не повторение базовой настройки Kubernetes из CKA. Здесь важны места применения
настроек: `KubeletConfiguration`, static Pod manifests control plane, TLS-параметры etcd
и проверяемые артефакты работы. Работайте с узлом control plane через SSH-имя
`control-plane`, подготовленное на worker.

## Цель

Закрепить материал глав курса:

- [Глава 07. CIS Benchmark и kube-bench](../../course/07/ru.md)
- [Глава 08. Secure Ingress с TLS](../../course/08/ru.md)
- [Глава 09. Небезопасные аргументы компонентов и проверка бинарников](../../course/09/ru.md)

## Что мы создаём и зачем

| Объект или артефакт | Что это | Зачем в этой лабе |
|---|---|---|
| Отчёт `kube-bench` | снимок CIS-проверок control-plane | фиксирует исходные рекомендации и служит основанием для hardening |
| Kubelet configuration | настройки kubelet на ноде | отключает read-only endpoint и anonymous access |
| Static Pod manifest apiserver | декларация kube-apiserver | отключает profiling и задаёт строгий TLS |
| TLS Secret и Ingress | TLS termination для приложения | исключает передачу HTTP-трафика к Ingress без сертификата |
| Static Pod manifest etcd | декларация локального etcd | ограничивает допустимые TLS cipher suites |
| SHA-256 артефакт | результат сверки `kubelet` и `kubectl` | подтверждает целостность бинарников относительно хешей релиза |

```mermaid
flowchart TB
    W["worker"] -->|"SSH"| CP["control-plane"]
    W -->|"kubectl"| API["kube-apiserver"]
    CP --> K["kubelet config\nreadOnlyPort=0\nanonymous=false"]
    CP --> A["static Pod kube-apiserver\nprofiling=false\nTLS 1.3"]
    CP --> E["static Pod etcd\ncipher suites"]
    API --> I["Ingress + TLS Secret"]
    W --> R["artifacts\nkube-bench / TLS / SHA-256"]
    style W fill:#326ce5,color:#fff
    style CP fill:#db4437,color:#fff
    style API fill:#673ab7,color:#fff
    style I fill:#0f9d58,color:#fff
    style R fill:#f4b400,color:#000
```

## Инфраструктура

Окружение разворачивается в AWS (`eu-central-1`) через Terragrunt.

| Компонент | Описание |
|---|---|
| `vpc` | VPC `10.103.0.0/16` с публичными подсетями |
| `ssh-keys` | SSH-ключи для доступа к нодам |
| `k8s-1` | Одноузловой Kubernetes `1.36.0` (kubeadm), containerd и Calico |
| `worker` | Рабочая машина с `kubectl`, `kube-bench`, SSH-доступом и `check_result` |

Control-plane разтаинчен, поэтому при необходимости на нём можно запустить учебный Pod.
Для заданий 2, 3 и 5 static Pods автоматически пересоздаются kubelet после сохранения
изменённого манифеста или конфигурации. Не удаляйте control-plane Pods вручную.

## Развёртывание

```bash
TASK=103 make run_cks_task
```

Подключитесь к worker по SSH. Контекст уже настроен:

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

Адрес control-plane можно получить и проверить так:

```bash
kubectl get nodes -o wide
ssh control-plane sudo hostname
```

## Задания

---
| **1** | **Отчёт CIS Benchmark** |
| :---: | :--- |
| Что делаем | На узле `control-plane` прогоните `kube-bench` для Kubernetes `1.36.0`. Сохраните полный evidence в `/var/work/tests/artifacts/1/kube-bench.txt`: `kubernetes_version`, `kube_bench_version`, выбранный `benchmark`, `mapping_status`, затем сам отчёт. Установленный на worker `kube-bench` можно скопировать на узел; проверяться должен именно узел. На дату проверки официальный mapping kube-bench заканчивается Kubernetes `1.35` (`cis-2.0` покрывает `1.34–1.35`), поэтому запуск `cis-2.0` на `1.36` помечайте `forced-approximate`, а не authoritative compliance. |
| Критерии приёмки | - evidence содержит все четыре version/mapping поля;<br>- `mapping_status=forced-approximate` явно объясняет отсутствие официального покрытия `1.36`;<br>- в отчёте есть `[PASS]`, `[WARN]` или `[FAIL]`;<br>- текст не выдаёт результат за authoritative CIS compliance для Kubernetes `1.36`. |
---
| **2** | **Hardening kubelet: read-only port и anonymous auth** |
| :---: | :--- |
| Что делаем | На control-plane исправьте kubelet configuration: установите `readOnlyPort: 0` и `authentication.anonymous.enabled: false` в `/var/lib/kubelet/config.yaml`. Перезапустите kubelet и дождитесь готовности ноды. Не подменяйте проверку текстовым артефактом: настройки должны быть применены на ноде. |
| Критерии приёмки | - в действующей kubelet configuration есть `readOnlyPort: 0`;<br>- anonymous authentication kubelet отключён;<br>- нода `Ready` после перезапуска. |
---
| **3** | **Hardening kube-apiserver: отключить profiling** |
| :---: | :--- |
| Что делаем | В static Pod manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` добавьте `--profiling=false`. Дождитесь пересоздания kube-apiserver и убедитесь, что API готов. |
| Критерии приёмки | - в manifest kube-apiserver есть `--profiling=false`;<br>- `kubectl get --raw='/readyz'` возвращает успешный результат;<br>- static Pod kube-apiserver запущен. |
---
| **4** | **Secure Ingress с TLS** |
| :---: | :--- |
| Что делаем | Создайте namespace `cks-103` и TLS-Secret `secure-ingress-tls` типа `kubernetes.io/tls` для хоста `secure.cks.local`. Создайте Service `secure-app` и Ingress `secure-ingress` с `ingressClassName: nginx`, TLS-секцией для этого хоста и ссылкой на Secret. Включите аннотацию `nginx.ingress.kubernetes.io/ssl-redirect: "true"`. Для проверки сертификата допустим самоподписанный сертификат. NGINX Ingress Controller здесь - экзаменационный fixture; сам проект retired (см. [главу 08](../../course/08/ru.md)), навык же `spec.tls` + TLS Secret универсален. |
| Критерии приёмки | - Secret `secure-ingress-tls` в `cks-103` имеет тип `kubernetes.io/tls` и поля `tls.crt`, `tls.key`;<br>- Ingress `secure-ingress` содержит `spec.tls`, хост `secure.cks.local` и ссылку на `secure-ingress-tls`;<br>- Ingress направляет `HTTPS`-хост на Service `secure-app`. |
---
| **5** | **TLS hardening control plane** |
| :---: | :--- |
| Что делаем | В `/etc/kubernetes/manifests/kube-apiserver.yaml` задайте `--tls-min-version=VersionTLS13` и `--tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384`. В `/etc/kubernetes/manifests/etcd.yaml` задайте `--cipher-suites` с тем же набором. После пересоздания компонентов подтвердите, что согласуется `TLSv1.3` (`openssl s_client -tls1_3`) и что `TLSv1.2` отклоняется (`openssl s_client -tls1_2` завершается ошибкой handshake), и сохраните вывод в `/var/work/tests/artifacts/5/tls13.txt`. Важно понимать семантику: в Go флаг `--tls-cipher-suites` действует только для TLS ≤ 1.2, а при `--tls-min-version=VersionTLS13` конкретные TLS 1.3 cipher suites этим флагом не настраиваются (Go выбирает их сам). Поэтому для kube-apiserver фактическую защиту здесь даёт именно min-version 1.3; cipher-suites значимы там, где допускается TLS 1.2 (например, для etcd). |
| Критерии приёмки | - оба требуемых TLS-флага есть в manifest kube-apiserver;<br>- cipher suites есть в manifest etcd;<br>- kube-apiserver и etcd здоровы;<br>- артефакт TLS содержит подтверждение `TLSv1.3`. |
---
| **6** | **Проверка целостности kubelet и kubectl** |
| :---: | :--- |
| Что делаем | Сверьте SHA-256 установленных `kubelet` на control-plane и `kubectl` на worker с опубликованными checksum Kubernetes `v1.36.0`. Сохраните команды и итог `sha256sum -c` в `/var/work/tests/artifacts/6/binaries.sha256.txt`. Не используйте хеши, вычисленные из проверяемого файла, как эталон. |
| Критерии приёмки | - артефакт существует;<br>- в нём есть отдельные успешные результаты для `kubelet` и `kubectl` (`OK`);<br>- эталонные суммы получены из официального release `v1.36.0`. |
---

## Проверка результата

На worker запустите:

```bash
check_result
```

Проверка содержит Init и шесть независимых заданий. Системные задания проверяются по
состоянию узла control plane через SSH и по артефактам, а не только по объектам API.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Удаление кластера и ресурсов

```bash
TASK=103 make delete_cks_task
```
