# Лаба 104 — Укрепление доступа к Kubernetes API: RBAC, ServiceAccount и anonymous-auth

## Цель

В этой CKS-лабе вы ограничите доступ к Kubernetes API по принципу наименьших
привилегий. Практика охватывает минимальный namespaced RBAC, современные
короткоживущие токены ServiceAccount, Pod без API-токена, удаление устаревших
избыточных разрешений и отключение анонимного доступа к API server.

Работайте только с объектами, указанными в заданиях. Namespace `security-104` и
намеренно опасная связка `legacy-operator-admin` уже подготовлены стартовым скриптом, как
и fixtures для заданий 10-12: Secret `legacy-config`, namespace `rbac-a`/`rbac-b` и
namespace `development`. Это учебная конфигурация, а не пример для production.

## Threat model

Предположим, что атакующий уже выполняет код в Pod и пытается использовать identity workload либо отсутствие authentication для движения к Kubernetes API. В таком случае важен не только начальный доступ, но и blast radius после compromise.

Задание 1 закрывает излишний RBAC scope, задание 2 — долгоживущий token, а задание 3 — ненужный API-доступ из Pod. Это уменьшает возможности использовать identity workload после compromise.

Задание 4 устраняет wildcard cluster-wide права, а задание 5 — anonymous access. Каждый из этих путей по отдельности может расширить blast radius до Kubernetes API.

Задание 6 закрывает отдельный путь утечки: секрет, переданный через environment variable, становится частью окружения процесса и может быть прочитан из `/proc/1/environ` любым процессом с доступом на `exec` в контейнер, а также может попасть в application logs, crash dump или другой diagnostic вывод, если сама программа или инструмент диагностики печатает environment. `kubectl describe pod` для `env`/`envFrom` с `secretKeyRef` показывает только ссылку на Secret и его ключ (`<set to the key ... in secret ...>`), а не resolved значение — не путайте эту ссылку с утечкой самого значения. Volume mount с `defaultMode: 0400` не устраняет доступ уполномоченного процесса контейнера к значению, но убирает секрет из окружения процесса и ограничивает файловые права на чтение только владельцем.

Задание 7 закрывает скрытые пути RBAC privilege escalation: `impersonate`, `bind`/`escalate` и CSR approval не расширяют список доступных ресурсов напрямую, а дают возможность действовать от чужого имени или самостоятельно выдать себе более широкие права — это отдельная категория риска от wildcard `*` из задания 4. Задание 8 закрывает системную, а не точечную защиту: automount на уровне namespace/default SA работает даже для Pod, у которого разработчик забыл явно отключить токен.

Задание 9 показывает, что предотвращение (задания 1-8) и обнаружение - разные, взаимодополняющие слои. Даже если конкретные пути эскалации закрыты в задании 7, для будущего инцидента нужен способ увидеть **опасное RBAC-изменение** (например, ошибочную или злонамеренную выдачу `cluster-admin` кому-либо) без постоянного ручного `kubectl get`: audit log даёт воспроизводимое forensic evidence о том, кто именно инициировал изменение, а не просто текущий снимок RBAC-состояния.

ATT&CK T1528 (Steal Application Access Token) и T1613 дают контекст этому сценарию: задания не моделируют отдельную атаку, а ограничивают последствия уже скомпрометированного workload.

Задания 10-12 закрывают три базовых, часто встречающихся на экзамене workflow, а не новые угрозы: задание 10 — безопасное повторное использование существующего секрета без case-by-case hardcoding значений в манифестах; задание 11 — точечный ремонт избыточного Role и корректное cross-namespace RBAC-связывание, где легко ошибиться со scope; задание 12 — полный onboarding нового пользователя через сертификат, от private key до проверяемого доступа, а не просто разбор уже готового kubeconfig.

## Проверьте себя перед стартом

Прежде чем открывать `check_result`, убедитесь, что вы уверенно ответите на эти вопросы. Если нет - вернитесь к [главе 10](../../course/10/ru.md) (RBAC), [главе 11](../../course/11/ru.md) (ServiceAccounts) и [главе 12](../../course/12/ru.md) (ограничение доступа к API).

<details>
<summary>1. Чем `Role`+`RoleBinding` отличаются от `ClusterRole`+`ClusterRoleBinding` в контексте задания 1?</summary>

`Role` действует только в одном namespace, но её `RoleBinding` МОЖЕТ ссылаться на субъект (например ServiceAccount) из ЛЮБОГО другого namespace - Kubernetes официально поддерживает `subjects[].namespace`, отличный от namespace самого `RoleBinding`. Что остаётся фиксированным - это SCOPE выдаваемых прав: права действуют только в namespace, где создан `RoleBinding`, независимо от того, откуда субъект. `RoleBinding` также может ссылаться на `ClusterRole` (а не только на `Role`) - в этом случае получаются права из cluster-wide шаблона, но выданные только в namespace конкретного `RoleBinding`. `ClusterRole`+`ClusterRoleBinding` даёт доступ на весь кластер. Задание 1 требует минимальный **namespaced** доступ, поэтому `Role`, а не `ClusterRole`, - иначе scope шире, чем требуется.
</details>

<details>
<summary>2. Почему bound projected token (задание 2) считается безопаснее legacy Secret-based token?</summary>

Bound projected token короткоживущий (задаётся `expirationSeconds`), автоматически истекает и ротируется kubelet, и привязан к конкретному Pod - при удалении Pod токен становится недействительным. Legacy Secret-token не имеет expiration, хранится как обычный `Secret` в etcd и остаётся валидным неограниченно долго, даже если Pod уже не существует.
</details>

<details>
<summary>3. В чём разница между тем, что `automountServiceAccountToken: false` даёт на уровне Pod и на уровне ServiceAccount?</summary>

На уровне ServiceAccount - это baseline: значение применяется ко всем Pod, использующим этот SA, если Pod не переопределяет его явно. На уровне Pod - это override: явное поле в Pod spec имеет приоритет перед значением SA. Задание 8 специально проверяет baseline на уровне SA/namespace, а задания 2-3 - явную настройку на уровне конкретного Pod.
</details>

<details>
<summary>4. Почему `impersonate`/`bind`/`escalate` (задание 7) не входят в тот же класс риска, что wildcard `*` (задание 4)?</summary>

Wildcard `*` в `resources`/`verbs` напрямую расширяет **список доступных операций и ресурсов**. `impersonate`/`bind`/`escalate` не дают доступа к новым ресурсам сами по себе - они дают возможность **действовать от чужого имени** (`impersonate`) или **самостоятельно выдать себе права, которых у вас изначально не было** (`bind`/`escalate`). Это отдельная категория privilege escalation, которую легко упустить при аудите RBAC, если смотреть только на `verbs`/`resources` без учёта этих трёх особых глаголов.
</details>

## Инфраструктура

Окружение разворачивается через Terragrunt в AWS `eu-central-1`:

| Компонент | Назначение |
|---|---|
| `vpc` | VPC `10.10.0.0/16` с публичными подсетями |
| `ssh-keys` | ключи для доступа к нодам |
| `k8s-1` | одноузловой kubeadm-кластер Kubernetes `1.36.0`, containerd и **Calico** |
| `worker` | рабочая машина с настроенным `kubectl` и `check_result` |

Control-plane разрешает запуск обычных Pod, поэтому отдельный worker-узел не нужен.
Для задания 5 потребуется SSH-доступ к control-plane: именно там расположен манифест
static Pod API server.

## Развёртывание

```bash
TASK=104 make run_cks_task
```

Подключитесь по SSH к рабочей машине. Контекст `cluster1-admin@cluster1` уже настроен.

```bash
time_left
check_result
```

## Задания

---
| **1** | **Минимальный RBAC для чтения Pod** |
| :---: | :--- |
| Что делаем | В namespace `security-104` создайте ServiceAccount `auditor`, Role `pod-observer` и RoleBinding `auditor-pod-observer`. Role должна разрешать **только** `get`, `list`, `watch` ресурса `pods` core API. Свяжите её только с ServiceAccount `auditor`. |
| Критерии приёмки | Role содержит ровно одно правило для `pods` с глаголами `get`, `list`, `watch`; RoleBinding ссылается на эту Role и ServiceAccount `auditor`; от имени `auditor` нельзя удалять `secrets`. |

<details>
<summary>💡 Подсказка к заданию 1</summary>

Частая ошибка - добавить лишние глаголы (например, `create` "на всякий случай") или использовать `ClusterRole` вместо `Role`. Проверьте себя: `kubectl auth can-i list pods -n security-104 --as=system:serviceaccount:security-104:auditor` должен вернуть `yes`, а `kubectl auth can-i delete secrets -n security-104 --as=system:serviceaccount:security-104:auditor` - `no`. Если Role и RoleBinding в разных namespace, привязка не подействует - `RoleBinding` должен быть в том же namespace, что и `Role`, и субъект в нём должен точно совпадать по `name`/`namespace`.
</details>

---
| **2** | **Короткоживущий projected ServiceAccount token** |
| :---: | :--- |
| Что делаем | Создайте ServiceAccount `api-client` и Pod `token-client` в `security-104`. Не используйте legacy Secret-токен. Отключите обычное автомонтирование токена, а нужный токен смонтируйте через **ровно один** projected `serviceAccountToken` source в `/var/run/secrets/tokens/api-token` с `path: api-token` и `expirationSeconds` от `600` до `3600` включительно - не добавляйте никаких дополнительных `serviceAccountToken` source в тот же (или другой) projected volume. **Не задавайте `audience`**, чтобы kubelet запросил identifier API server по умолчанию. Если приложению необходима отдельная audience, сначала сверьте её с `--api-audiences` (либо default из `--service-account-issuer`) на API server и только затем задавайте явно. |
| Критерии приёмки | Pod использует `api-client`, имеет `automountServiceAccountToken: false`, и содержит **ровно один** projected `serviceAccountToken` source во всей спецификации Pod - без жёстко заданной audience, с указанными path и `expirationSeconds` в диапазоне `600`-`3600` (обе границы включительно). TokenReview, выполненный от admin-контекста для смонтированного токена, возвращает `authenticated: true` и имя `system:serviceaccount:security-104:api-client`; отдельная RBAC-проверка подтверждает, что этот ServiceAccount не может удалять `secrets`. |

<details>
<summary>💡 Подсказка к заданию 2</summary>

Самая частая ошибка - явно задать `audience: kubernetes.default.svc`, предполагая, что это стандартное значение. Для kubeadm-кластера это НЕ гарантированный default - если задать audience, которую API server не принимает через `--api-audiences`, TokenReview вернёт `authenticated: false`. Просто не указывайте поле `audience` вообще - kubelet тогда запросит identifier API server по умолчанию, который сервер точно принимает. Также не забудьте `automountServiceAccountToken: false` на самом Pod - иначе Kubernetes добавит ещё и обычный (legacy-стиль) volume токена вдобавок к вашему projected volume. Ещё одна частая ошибка - выбрать слишком маленький `expirationSeconds` (например `300`): Kubernetes API требует минимум `600` секунд для `serviceAccountToken` projected volume - меньшее значение не соответствует API contract, даже если manifest применяется без явной ошибки на этапе `kubectl apply`.
</details>

---
| **3** | **Pod без токена Kubernetes API** |
| :---: | :--- |
| Что делаем | Создайте ServiceAccount `no-token-sa` с `automountServiceAccountToken: false` и Pod `no-token` в `security-104` с этим ServiceAccount. На самом Pod также явно установите `automountServiceAccountToken: false`. Используйте любой безопасный долгоживущий образ, например `busybox:1.36` с `sleep 3600`. Не монтируйте отдельно никакой Secret с токеном ServiceAccount вручную - у Pod не должно быть вообще никакого API-токена, ни через automount, ни через явно смонтированный legacy Secret. |
| Критерии приёмки | У ServiceAccount и Pod отключено автомонтирование; Pod использует `no-token-sa`; в его спецификации нет автоматически добавленного тома токена ServiceAccount и нет вручную смонтированного Secret типа `kubernetes.io/service-account-token`; попытка прочитать `/var/run/secrets/kubernetes.io/serviceaccount/token` внутри контейнера завершается ошибкой (файл отсутствует), при этом сам `kubectl exec` должен выполниться успешно. |

<details>
<summary>💡 Подсказка к заданию 3</summary>

Отличие от задания 8: здесь достаточно отключить automount либо на SA, либо на Pod - но задание требует **оба** уровня одновременно (defence in depth), а не один из них. Проверьте себя: `kubectl get pod no-token -o jsonpath='{.spec.volumes}'` не должен содержать ничего похожего на `kube-api-access-*`. Если том всё же появился - проверьте, что вы отключили automount ДО создания Pod, а не после (изменение SA не влияет на уже созданные Pod). Отключённый automount не мешает вручную смонтировать старый (legacy) `Secret` с `type: kubernetes.io/service-account-token` через `volumes[].secret` - если вы сделаете это, Pod формально не имеет automounted-тома, но фактически всё равно получит валидный API-токен. Задание требует полного отсутствия токена, а не только отсутствия automount.
</details>

---
| **4** | **Удалить избыточные cluster-wide права** |
| :---: | :--- |
| Что делаем | В кластере намеренно оставлены ClusterRole `legacy-operator-admin` с wildcard-правами и ClusterRoleBinding с тем же именем для ServiceAccount `legacy-operator` из `security-104`. Удалите **оба** объекта. Не заменяйте wildcard-доступ на другой широкий ClusterRole. |
| Критерии приёмки | `legacy-operator-admin` не существует ни как ClusterRole, ни как ClusterRoleBinding; ServiceAccount `legacy-operator` больше не может читать `secrets` в `security-104`. |

<details>
<summary>💡 Подсказка к заданию 4</summary>

Удаление только `ClusterRoleBinding` без удаления `ClusterRole` оставляет опасный шаблон в кластере - кто-то может создать новую привязку к нему позже. Удаляйте оба объекта. Проверьте себя двумя отдельными командами: `kubectl get clusterrole legacy-operator-admin` и `kubectl get clusterrolebinding legacy-operator-admin` - оба должны вернуть `NotFound`.
</details>

---
| **5** | **Отключить anonymous access к API server** |
| :---: | :--- |
| Что делаем | На control-plane создайте файл `/etc/kubernetes/authentication-config.yaml` с `AuthenticationConfiguration`, который отключает anonymous access ко всем endpoint, кроме `/livez`, `/readyz` и `/healthz` - именно эти пути kubeadm использует для HTTPS liveness/readiness/startup probes static Pod API server, и полное `--anonymous-auth=false` ломает сами probes, а не только доступ атакующего. Подключите файл через `hostPath` volume и аргумент `--authentication-config=<путь-в-контейнере>` в `/etc/kubernetes/manifests/kube-apiserver.yaml`, и **удалите** существующий `--anonymous-auth=true` - оба способа настройки anonymous access взаимно исключают друг друга, и kube-apiserver не запустится, если заданы оба. Kubelet перезапустит static Pod автоматически. Дождитесь готовности API server (Pod остаётся Running/Ready) и убедитесь, что: неаутентифицированный запрос к `/version` получает `401`, а к `/livez` и `/readyz` - `200`. Дополнительно проверьте, что effective `--authorization-mode` содержит `Node,RBAC` и **не** содержит `AlwaysAllow` (аутентификация без ограничивающей авторизации бессмысленна). Затем проаудируйте ClusterRoleBinding, чьи subjects — `system:anonymous`/группа `system:unauthenticated`: в кластере намеренно оставлена одна опасная (lab-owned) такая привязка, `lab104-unintended-anonymous-access`, удалите её вместе с её ClusterRole. **Не трогайте** штатный kubeadm-биндинг `system:public-info-viewer` — он тоже привязан к `system:unauthenticated`, но даёт доступ только к non-resource URL `/healthz`/`/version`, это нормальная часть bootstrap, а не находка для этого задания. |
| Критерии приёмки | Static Pod API server использует `--authentication-config`, ссылающийся на `AuthenticationConfiguration` с `anonymous.enabled: true` и `conditions`, включающими ровно `/livez`, `/readyz`, `/healthz`; аргумент `--anonymous-auth` отсутствует; kube-apiserver Pod остаётся `Running`/`Ready` после перезапуска; неаутентифицированный `GET /version` возвращает `401`; неаутентифицированные `GET /livez` и `GET /readyz` возвращают `200`; аутентифицированный запрос к `/readyz` (с валидными credentials) также работает; effective `--authorization-mode` содержит `Node,RBAC` и не содержит `AlwaysAllow`; ClusterRole/ClusterRoleBinding `lab104-anonymous-debug-access`/`lab104-unintended-anonymous-access` удалены; штатный `system:public-info-viewer` остался нетронутым; группа `system:unauthenticated` не может читать `pods`/`secrets`/`configmaps` ни в одном namespace. |

<details>
<summary>💡 Подсказка к заданию 5</summary>

Не редактируйте объект Pod через `kubectl edit pod` - kubelet следит за файлом манифеста и перезапишет любое изменение, сделанное через API, обратно в исходное состояние. Редактируйте именно файл `/etc/kubernetes/manifests/kube-apiserver.yaml` на диске ноды. После сохранения подождите: kubelet обнаруживает изменение файла не мгновенно, и API server будет недоступен несколько секунд во время перезапуска static Pod - не паникуйте, если `curl` сразу после сохранения файла ничего не возвращает.

Простое `--anonymous-auth=false` здесь **не подходит**: kubeadm `release-1.36` генерирует kube-apiserver static Pod с HTTPS liveness/readiness/startup probes именно на `/livez` и `/readyz`, а kubelet HTTP probes не передают client credentials - при полном отключении anonymous access эти запросы получают `401`, kubelet считает контейнер нездоровым и может перезапускать kube-apiserver в цикле, что ломает не только это задание, но и последующее задание 9. Правильный путь - `AuthenticationConfiguration` с `anonymous.enabled: true` и `anonymous.conditions`, ограничивающими anonymous access только нужными health-путями:

```yaml
# /etc/kubernetes/authentication-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt: []
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
```

`--authentication-config` и `--anonymous-auth` нельзя задавать одновременно - kube-apiserver не запустится, если оба аргумента присутствуют в манифесте. Убедитесь, что вы удалили `--anonymous-auth=true` полностью, а не просто заменили значение на `false`.

Для аудита анонимных ClusterRoleBinding: `kubectl get clusterrolebinding -o json | jq -r
'.items[] | select([.subjects[]? | select(.name == "system:anonymous" or .name ==
"system:unauthenticated")] | length > 0) | .metadata.name'`. Вы увидите как минимум ДВЕ
привязки - штатный `system:public-info-viewer` (не трогайте) и lab-owned
`lab104-unintended-anonymous-access` (удалите вместе с её ClusterRole
`lab104-anonymous-debug-access`). Отличить их можно по имени ClusterRole, на который они
ссылаются: `kubectl get clusterrolebinding system:public-info-viewer -o
jsonpath='{.roleRef.name}'` покажет `system:public-info-viewer` - это ClusterRole,
ограниченная non-resource URL, а не обычными resources.
</details>

---
| **6** | **Secret через env раскрывается в `/proc/1/environ`: рефакторинг на volume** |
| :---: | :--- |
| Что делаем | Pod `app-vulnerable` в `security-104` получает `db-creds` через `envFrom.secretRef` — значение доступно любому, кто может `kubectl exec` в контейнер (`cat /proc/1/environ`) или прочитать логи/describe при случайном выводе env. Подтвердите эту утечку: выполните `kubectl exec -n security-104 app-vulnerable -- cat /proc/1/environ` и сохраните вывод (с `DB_PASSWORD`) в `/var/work/tests/artifacts/6/env-leak-before.txt`. Затем пересоздайте Pod с тем же именем `app-vulnerable`: удалите `envFrom`/`env` с этим секретом, смонтируйте `db-creds` как volume `db-creds-vol` в `/etc/secrets` **read-only**, с `defaultMode: 0400`. Подтвердите отсутствие переменной `DB_PASSWORD` в новом `/proc/1/environ` и сохраните `stat -L -c '%a'` смонтированного файла (флаг `-L` обязателен - секрет монтируется через симлинк-цепочку `..data`, без `-L` `stat` покажет режим самого симлинка, а не реального файла) в `/var/work/tests/artifacts/6/secret-file-mode.txt`. |
| Критерии приёмки | `env-leak-before.txt` содержит РЕАЛЬНОЕ значение `DB_PASSWORD` из Secret `db-creds` (не просто слово `DB_PASSWORD`); итоговый Pod `app-vulnerable` не имеет `env`/`envFrom`, ссылающихся на `db-creds`, и не имеет второго способа монтирования того же Secret; volume `db-creds-vol` смонтирован в `/etc/secrets` как `readOnly: true` с `defaultMode: 0400` (`256` decimal) - checker сам проверяет `stat -L -c %a` внутри контейнера и требует точно `400`; `DB_PASSWORD` отсутствует в `/proc/1/environ` итогового Pod (при успешно выполненном `exec` - неудачный `exec` не считается доказательством); процесс приложения при этом всё ещё может реально прочитать значение секрета из `/etc/secrets/DB_PASSWORD` (positive control). |

<details>
<summary>💡 Подсказка к заданию 6</summary>

```text
[FAIL] defaultMode для Secret Volume указан неверно.
💡 Вы указали defaultMode: 400 (десятичное 400).
   YAML поддерживает восьмеричный литерал с ведущим нулём (0400), который Kubernetes
   интерпретирует как обычные Unix-права; без ведущего нуля 400 читается как десятичное
   число 400, а не как права 0400 (это десятичное 256).
```

Это самая частая ошибка этого задания: `defaultMode` - числовое поле с POSIX mode bits, и
Kubernetes YAML поддерживает для него как восьмеричную, так и десятичную запись - в отличие
от JSON, где допустима только десятичная. Если вы напишете `defaultMode: 400` (без ведущего
нуля), Kubernetes воспримет это как **десятичное** 400, а не как привычные Unix-права
`0400`. Правильный способ - либо написать `defaultMode: 0400` (с ведущим нулём, YAML
распознает восьмеричный литерал), либо явно указать десятичный эквивалент `256`. Проверьте
себя: `kubectl get pod app-vulnerable -o jsonpath='{.spec.volumes[0].secret.defaultMode}'`
должен вернуть `256`, а `stat -L -c '%a' /etc/secrets/DB_PASSWORD` внутри контейнера - `400`.
</details>

---
| **7** | **Аудит и отзыв скрытых RBAC-путей privilege escalation (`impersonate`, `bind`, `escalate`, CSR approval)** |
| :---: | :--- |
| Что делаем | ClusterRole `build-agent-hidden-privesc` не содержит wildcard `*` (это отдельный, уже устранённый в задании 4 путь), но даёт ServiceAccount `build-agent` из `security-104` три реально эксплуатируемых пути повышения привилегий: `impersonate` над `users`/`groups`/`serviceaccounts` (подмена личности, включая cluster-admin, если такой пользователь известен атакующему); `create`/`update`/`bind`/`escalate` над `clusterroles` и `create`/`update` над `clusterrolebindings` (базовые verbs дают возможность создавать/менять сами объекты, а `bind`/`escalate` обходят встроенную RBAC-проверку, которая иначе запрещала бы выдать/привязать права шире собственных — без базовых `create`/`update` одних `bind`/`escalate` недостаточно для реальной эскалации); и `update` на `certificatesigningrequests/approval` + `approve` на signer `kubernetes.io/kube-apiserver-client` (возможность одобрить CSR с произвольной identity - но сама по себе эта ClusterRole не даёт `create certificatesigningrequests`: чтобы довести атаку до выпуска сертификата, identity также нужна отдельная возможность создать CSR, например через другую скомпрометированную роль или compromised automation, которая уже умеет отправлять CSR). Найдите **все** ClusterRoleBinding, чьи ClusterRole разрешают `impersonate`, `bind` или `escalate` (например, через `kubectl get clusterrole -o json \| jq` по `rules[].verbs`), запишите их в `/var/work/tests/artifacts/7/dangerous-bindings-before.txt`, затем удалите ClusterRoleBinding `build-agent-hidden-privesc` **и** ClusterRole `build-agent-hidden-privesc` (и, если найдёте другие непреднамеренные — их тоже, но не системные `system:*` ClusterRoleBinding). Подтвердите отзыв через `kubectl auth can-i` для ВСЕХ найденных прав: `impersonate users`, `bind clusterroles`, `escalate clusterroles`, `update certificatesigningrequests/approval`, а также `approve` на signer `kubernetes.io/kube-apiserver-client` — все должны вернуть `no`. |
| Критерии приёмки | `dangerous-bindings-before.txt` содержит `build-agent-hidden-privesc` среди найденных как ClusterRoleBinding (а не имя ClusterRole, если они не совпадают); ClusterRoleBinding **и** ClusterRole `build-agent-hidden-privesc` не существуют после исправления; `build-agent` не может `impersonate`, `bind`, `escalate`, `update certificatesigningrequests/approval`, а также не может выполнить `approve` на signer `kubernetes.io/kube-apiserver-client`; системные `system:*` ClusterRoleBinding не тронуты. |

<details>
<summary>💡 Подсказка к заданию 7</summary>

CSR approval - отдельная категория от `impersonate`/`bind`/`escalate`: она не входит в тот же `jq`-фильтр по `verbs`, потому что представляет собой отдельное правило на ресурс `certificatesigningrequests/approval` с verb `update`, плюс `approve` на конкретный `signer`. Если вы отфильтруете только по `impersonate`/`bind`/`escalate`, вы найдёте один путь, но упустите CSR - ищите оба отдельно, и для каждого сохраняйте именно имя **ClusterRoleBinding**, а не ClusterRole, к которому он ссылается (в этой лабе имена совпадают, но в общем случае это не гарантировано). Не удаляйте системные `ClusterRoleBinding` с префиксом `system:` - они нужны core-компонентам Kubernetes для легитимного `impersonate` (например, `system:kube-controller-manager`).
</details>

---
| **8** | **Namespace-level baseline: `default` ServiceAccount без automount** |
| :---: | :--- |
| Что делаем | Задание 3 отключало automount точечно, внутри конкретного Pod и его собственного ServiceAccount. Здесь нужен baseline на уровне **namespace**: создайте namespace `security-104-baseline`, дождитесь появления автоматически создаваемого ServiceAccount `default` в нём (создание ServiceAccount происходит асинхронно отдельным контроллером, а не одновременно с самим namespace) и только затем установите `automountServiceAccountToken: false` на этот ServiceAccount (`kubectl patch serviceaccount default -n security-104-baseline -p '{"automountServiceAccountToken":false}'`). Создайте в этом namespace Pod `implicit-default-sa` из `busybox:1.36` (`sleep 3600`), **не указывая** ни `serviceAccountName`, ни `automountServiceAccountToken` явно — он должен неявно использовать `default` SA и наследовать его значение. Подтвердите, что в спецификации итогового Pod поле `automountServiceAccountToken` отсутствует (а не равно `false`), тома токена нет, и попытка прочитать файл токена внутри контейнера завершается именно ошибкой отсутствия файла (сам `kubectl exec` должен при этом успешно выполниться). |
| Критерии приёмки | ServiceAccount `default` в `security-104-baseline` имеет `automountServiceAccountToken: false`; Pod `implicit-default-sa` использует `serviceAccountName: default` (неявно или явно) и в его спецификации **отсутствует** поле `automountServiceAccountToken` (не установлено явно ни в `true`, ни в `false`), нет автоматически добавленного `projected`/`secret` volume с токеном ServiceAccount и нет вручную смонтированного legacy `Secret` типа `kubernetes.io/service-account-token`; `kubectl exec ... test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token` завершается успешно (exit code `0`), подтверждая отсутствие файла именно через успешный exec, а не через произвольную ошибку. |

<details>
<summary>💡 Подсказка к заданию 8</summary>

Порядок операций критичен: если вы создадите Pod ДО того, как `patch` применится к `default` SA namespace, Pod получит токен по старому (default `true`) значению. Также не патчьте `default` SA СРАЗУ после `kubectl create namespace` без проверки - ServiceAccount `default` создаётся отдельным контроллером и может ещё не существовать в первые доли секунды после создания namespace; дождитесь его появления (`kubectl get serviceaccount default -n security-104-baseline`), только потом патчите. Задание намеренно не указывает `serviceAccountName` в Pod - это моделирует реальную ситуацию, когда разработчик просто забыл про ServiceAccount, и baseline должен защитить его по умолчанию. Явное `automountServiceAccountToken: false` НА САМОМ Pod доказывало бы только точечную настройку (как в задании 3) - здесь нужно оставить поле полностью не указанным, чтобы доказать именно наследование от SA/namespace.
</details>

---
| **9** | **Интеграционное задание: обнаружить RBAC-эскалацию через audit log и локализовать её** |
| :---: | :--- |
| Что делаем | Это задание объединяет RBAC (эта лаба) с audit-логированием (см. [главу 32](../../course/32/ru.md)) - без audit log сам факт опасного RBAC-изменения было бы видно только post-hoc через `kubectl get`, а не как воспроизводимое forensic evidence. На control-plane включите минимальный audit backend: создайте `/etc/kubernetes/audit/policy.yaml` с правилом `RequestResponse` для `apiGroups: ["rbac.authorization.k8s.io"]`, ресурсов `clusterroles` и `clusterrolebindings`, и catch-all `Metadata` как fallback. В static manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` добавьте `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`, `--audit-log-path=/var/log/kubernetes/audit/audit.log` и нужные hostPath volume/volumeMount (создайте директории заранее). Дождитесь восстановления API. От имени администратора (`cluster1-admin`) создайте ClusterRoleBinding `incident-simulated-escalation`, привязывающий ClusterRole `cluster-admin` к ServiceAccount `build-agent` из `security-104` - это **не** попытка эскалации со стороны самого `build-agent` (задание 7 уже отозвало у него реальные пути повышения привилегий), а моделируемое администратором опасное RBAC-изменение: реальный сценарий, когда кто-то (человек-оператор, скрипт, скомпрометированный CI/CD) по ошибке или злонамеренно выдаёт `cluster-admin` ServiceAccount, и задача SOC/security-инженера - обнаружить именно такое событие через audit log, а не через постоянный ручной `kubectl get`. Найдите в audit log событие `create` для `clusterrolebindings` с этим именем, `requestObject.roleRef` на `cluster-admin` и `system:serviceaccount:security-104:build-agent` в `requestObject.subjects`, сохраните событие целиком (включая `user.username` - того, кто реально инициировал запрос) в `/var/work/tests/artifacts/9/audit-escalation-event.json`. Затем выполните containment: удалите `incident-simulated-escalation` и подтвердите через `kubectl auth can-i '*' '*' --as=system:serviceaccount:security-104:build-agent`, что доступ отозван; сохраните итоговый `no` в `/var/work/tests/artifacts/9/containment-result.txt`. |
| Критерии приёмки | Static manifest kube-apiserver содержит `--audit-policy-file` и `--audit-log-path`, API server healthy; `/var/work/tests/artifacts/9/audit-escalation-event.json` - валидный JSON audit event с `verb: create`, `objectRef.resource: clusterrolebindings`, `objectRef.name: incident-simulated-escalation`, `requestObject.roleRef.name: cluster-admin` и ServiceAccount `build-agent` из `security-104` среди `requestObject.subjects`; ClusterRoleBinding `incident-simulated-escalation` не существует после containment; `containment-result.txt` содержит `no`. |

<details>
<summary>💡 Подсказка к заданию 9</summary>

Правило `RequestResponse` для `rbac.authorization.k8s.io` должно стоять ПЕРВЫМ в списке правил policy - более специфичное правило должно предшествовать общему `Metadata`-catch-all, иначе catch-all перехватит событие раньше и вы получите только `Metadata`-уровень вместо `RequestResponse` с телом запроса. Создайте `incident-simulated-escalation` ПОСЛЕ того, как API server перезапустился с новым audit backend - иначе событие просто не попадёт в лог. Это задание проверяет обнаружение опасного RBAC-изменения per se, а не то, что именно `build-agent` его совершил - в audit log поле `user.username` покажет реального инициатора (администратора), а не `build-agent`; `build-agent` в этом событии фигурирует только как получатель прав (`requestObject.subjects`). `audit-escalation-event.json` должен быть **реальной** записью, скопированной из `/var/log/kubernetes/audit/audit.log` (включая её `auditID`) - вручную собранный JSON с несколькими совпадающими строками не пройдёт проверку, потому что self-check сам читает лог на control-plane и сверяет `auditID`. Не забудьте containment: удаление `ClusterRoleBinding` само по себе - половина задачи, вторая половина - доказать через `kubectl auth can-i`, что доступ реально отозван, а не просто объект стал недоступен для чтения.
</details>

---
| **10** | **Decode, create and mount a Secret** |
| :---: | :--- |
| Что делаем | В `security-104` уже существует Opaque Secret `legacy-config` с двумя ключами: `SERVICE_USER` и `SERVICE_TOKEN`. Прочитайте его через API и декодируйте оба значения из base64. Создайте новый generic Secret `rehydrated-config` из literal-значений (`kubectl create secret generic ... --from-literal=...`), с ТЕМИ ЖЕ именами ключей и ТЕМИ ЖЕ декодированными значениями. Создайте Pod `secret-workflow` из `busybox:1.36` (`sleep 3600`), который монтирует `rehydrated-config` как **read-only** volume в `/etc/rehydrated`. Подтвердите, что оба файла внутри контейнера реально читаются и содержат ожидаемые значения. |
| Критерии приёмки | `rehydrated-config` существует и его декодированные `SERVICE_USER`/`SERVICE_TOKEN` совпадают с исходным `legacy-config`; Pod `secret-workflow` монтирует именно этот Secret в `/etc/rehydrated` с `readOnly: true`; `kubectl exec` внутри контейнера читает оба файла с правильным содержимым. |

<details>
<summary>💡 Подсказка к заданию 10</summary>

`kubectl get secret legacy-config -o jsonpath='{.data.SERVICE_USER}' \| base64 -d` даёт вам
реальное значение - не пишите произвольную строку в новый Secret, checker сам заново
декодирует оригинал и сравнивает. `kubectl create secret generic rehydrated-config
--from-literal=SERVICE_USER=... --from-literal=SERVICE_TOKEN=...` кодирует значения
автоматически - не нужно самостоятельно base64-encode при создании через `--from-literal`.
Не забудьте `readOnly: true` на volumeMount - смонтированный, но writable Secret не
проходит критерий приёмки буквально по флагу, даже если сам Pod работает корректно.
</details>

---
| **11** | **Repair existing Role and bind it to an SA from another namespace** |
| :---: | :--- |
| Что делаем | В namespace `rbac-a` уже существуют ServiceAccount `dev`, Role `pod-role` и RoleBinding `pod-role-binding`. Role сейчас разрешает `get`, `list`, `delete` на `pods` - `delete` здесь лишний (уберите), а `watch` отсутствует, хотя нужен (добавьте). Исправьте именно существующий Role, не создавайте новый. Отдельно, в namespace `rbac-b` уже существует ConfigMap `shared-config`. Создайте в `rbac-b` новый Role и RoleBinding, дающие ServiceAccount `dev` **из namespace `rbac-a`** доступ `get`/`list` (и только его) на `configmaps` в `rbac-b`. Создайте Pod в `rbac-a` с `serviceAccountName: dev`. |
| Критерии приёмки | Role `pod-role` в `rbac-a` разрешает ровно `get`, `list`, `watch` на `pods`; `dev` не может `delete pods` в `rbac-a`; `dev` может `get`/`list configmaps` в `rbac-b`, но не может `delete configmaps` и не может читать `secrets` там же; в `rbac-a` существует Pod, использующий ServiceAccount `dev`. |

<details>
<summary>💡 Подсказка к заданию 11</summary>

`RoleBinding` может ссылаться на субъект (`ServiceAccount`) из ЛЮБОГО другого namespace -
Kubernetes официально это поддерживает через `subjects[].namespace`. Но сам `RoleBinding`,
и связанные с ним права, всегда действуют только в namespace, где создан ОН САМ - поэтому
новый Role+RoleBinding нужно создавать именно В `rbac-b`, а не в `rbac-a`. Проверьте себя:
`kubectl auth can-i get configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev` должен
вернуть `yes`, а `kubectl auth can-i get secrets -n rbac-b --as=system:serviceaccount:rbac-a:dev` -
`no`.
</details>

---
| **12** | **Client certificate user via CSR + namespaced RBAC** |
| :---: | :--- |
| Что делаем | Создайте нового Kubernetes-пользователя `john`, аутентифицируемого клиентским сертификатом: сгенерируйте private key, затем CSR (`openssl req -new`) с `CN=john`; отправьте его как Kubernetes `CertificateSigningRequest` `john-csr` с `signerName: kubernetes.io/kube-apiserver-client`; одобрите CSR (`kubectl certificate approve`); извлеките выданный сертификат из `status.certificate` (base64-decode) и сохраните его вместе с private key в `/var/work/tests/artifacts/12/john.crt` и `.../john.key`. В namespace `development` (уже создан) создайте Role, разрешающую `create`/`list`/`get` на `pods`, и RoleBinding на subject `{kind: User, name: john}`. Подтвердите живыми `kubectl auth can-i --as=john` проверками: John может `create`/`list`/`get` pods в `development`, не может `delete` их там же и не имеет тех же прав в другом namespace. |
| Критерии приёмки | `john-csr` использует правильный signer и `Approved`; выданный сертификат имеет `CN=john` и реально проверяется против CA этого кластера; Role+RoleBinding в `development` дают John ровно `create`/`list`/`get` на `pods`; John не может `delete` pods там же и не имеет доступа в других namespace; сохранённые `john.crt`/`john.key` реально принимаются API server при прямом TLS-запросе (а не только через `--as=john` impersonation). |

<details>
<summary>💡 Подсказка к заданию 12</summary>

Не путайте это задание с Lab 114: там вы разбираете УЖЕ существующий сертификат из
kubeconfig, а здесь нужно выпустить полностью новую, реально рабочую identity с нуля.
RBAC для сертификат-based пользователя связывается через `subjects: [{kind: User, name:
john}]`, а не `ServiceAccount` - у `User` в Kubernetes нет отдельного API-объекта, его
"существование" полностью определяется тем, что CN в клиентском сертификате совпадает с
`name` в binding. `--as=john` в `kubectl auth can-i` проверяет только RBAC-логику
(impersonation), но не доказывает, что сертификат реально валиден - отдельно убедитесь,
что `openssl verify` против `/etc/kubernetes/pki/ca.crt` на control-plane возвращает `OK`.
</details>

## Проверка

На рабочей машине выполните:

```bash
check_result
```

Проверка содержит Init и двенадцать независимых заданий. После изменения API server
некоторые тесты могут кратко ждать перезапуска static Pod.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD)

## Удаление

```bash
TASK=104 make delete_cks_task
```
