# Lab 125 — DNS и CoreDNS в кластере

## Описание

Отдельный тренажёр по DNS в Kubernetes: A-записи обычного Service, множественные записи
**headless**-сервиса, настройка DNS на уровне Pod (`dnsConfig`, `ndots`) и правка
**CoreDNS** (Corefile) для пересылки корпоративного домена. Задания короткие и
независимые, в экзаменационном стиле, с автоматической проверкой `check_result`.

## Цель

Закрепить главу курса:

- [Глава 31. Service изнутри, DNS и CoreDNS](../../course/31/ru.md)

Смежные главы: [Глава 7. Services](../../course/07/ru.md), [Глава 30. Сеть и CNI](../../course/30/ru.md).

## Инфраструктура

| Компонент  | Описание                                                             |
|------------|----------------------------------------------------------------------|
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), Calico, single-node                   |
| `worker`   | Рабочая машина с `kubectl` и `check_result`                          |

Файлы-ответы для JSONPath сохраняются в `/home/ubuntu/answers/`.

## Развёртывание

```bash
TASK=125 make run_cka_task
```

## Задания

Работа ведётся с рабочей машины `worker` (там `kubectl` и `check_result`).

---
|        **1**        | **Namespace и Deployment**                                  |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Создайте namespace с именем `dns`. В этом namespace создайте Deployment с именем `web`, образ контейнера `viktoruj/ping_pong:latest` (учебный HTTP-сервер на порту `8080`), количество реплик — `2`. У Pods должен быть label `app=web` (у Deployment, созданного через `kubectl create deployment`, этот label ставится автоматически). |
| Критерии приёмки    | - namespace `dns` существует;<br>- Deployment `web` в namespace `dns` имеет 2 готовые (ready) реплики. |
---
|        **2**        | **ClusterIP Service (обычная A-запись в DNS)**              |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | В namespace `dns` создайте Service с именем `web-svc` типа **ClusterIP** (тип по умолчанию), который выбирает Pods Deployment `web` по label `app=web`. Порт Service — `80`, `targetPort` (порт на Pods) — `8080` (HTTP-порт приложения ping_pong). Такой Service получит в кластере DNS-имя `web-svc.dns.svc.cluster.local` с одной A-записью на ClusterIP. |
| Критерии приёмки    | - Service `web-svc` в namespace `dns` существует;<br>- его Endpoints не пусты (Service нашёл Pods `web`). |
---
|        **3**        | **Headless Service (A-записи на все Pods)**                 |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | В namespace `dns` создайте **headless** Service с именем `web-h`: поле `clusterIP` должно быть равно `None`, selector — `app=web`, порт `80`. У headless Service нет единого виртуального IP: DNS-запрос к его имени возвращает IP **всех** Pods напрямую (по A-записи на каждый Pod). |
| Критерии приёмки    | - Service `web-h` в namespace `dns` имеет `clusterIP: None`;<br>- его Endpoints не пусты (перечислены IP Pods `web`). |
---
|        **4**        | **Pod с кастомной DNS-настройкой (ndots)**                 |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | В namespace `dns` создайте Pod с именем `client`, образ `viktoruj/ping_pong:alpine` (тег `alpine` — с shell и утилитами, чтобы можно было `exec` внутрь и проверять DNS: `nslookup`, `wget`). В его spec задайте `dnsConfig` с опцией `ndots` равной `2` (то есть `spec.dnsConfig.options` содержит запись `{name: ndots, value: "2"}`). `dnsPolicy` оставьте `ClusterFirst` (по умолчанию). Это уменьшает число лишних DNS-запросов для внешних имён (см. раздел 31.7 главы). |
| Критерии приёмки    | - Pod `client` в namespace `dns` существует;<br>- в его spec задана опция `dnsConfig` `ndots=2`. |
---
|        **5**        | **CoreDNS: пересылка отдельного домена**                   |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Отредактируйте ConfigMap `coredns` в namespace `kube-system` и добавьте в Corefile отдельный блок (stub-домен), который **пересылает** (`forward`) все запросы к домену `mycorp.local` на внешний DNS-сервер с адресом `10.10.0.10`. После правки перезапустите Deployment `coredns` (`kubectl -n kube-system rollout restart deployment coredns`), чтобы изменения применились. |
| Критерии приёмки    | - в Corefile (ConfigMap `coredns`) присутствует домен `mycorp.local` и адрес пересылки `10.10.0.10`. |
---
|        **6**        | **JSONPath: сохранить ClusterIP в файл**                   |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | С помощью `kubectl ... -o jsonpath` получите ClusterIP сервиса `web-svc` (поле `.spec.clusterIP`) и сохраните **только само значение** (без переносов и лишнего текста) в файл `/home/ubuntu/answers/clusterip.txt`. |
| Критерии приёмки    | - содержимое `/home/ubuntu/answers/clusterip.txt` совпадает с `.spec.clusterIP` сервиса `web-svc`. |
---

## Проверка результата

```bash
check_result
```

## Решение

[worker/files/solutions/1.MD](worker/files/solutions/1.MD)

## Покрытие мок-экзаменов

Домен Services & Networking (20% CKA / 20% CKAD) — DNS: записи Service и headless,
`dnsConfig`/`ndots` на уровне Pod, правка CoreDNS (Corefile) для пересылки домена.

## Удаление

```bash
TASK=125 make delete_cka_task
```
