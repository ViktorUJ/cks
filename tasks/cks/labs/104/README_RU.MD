# Лаба 104 — Укрепление доступа к Kubernetes API: RBAC, ServiceAccount и anonymous-auth

## Цель

В этой CKS-лабе вы ограничите доступ к Kubernetes API по принципу наименьших
привилегий. Практика охватывает минимальный namespaced RBAC, современные
короткоживущие токены ServiceAccount, Pod без API-токена, удаление устаревших
избыточных разрешений и отключение анонимного доступа к API server.

Работайте только с объектами, указанными в заданиях. Namespace `security-104` и
намеренно опасная связка `legacy-operator-admin` уже подготовлены стартовым скриптом.
Это учебная конфигурация, а не пример для production.

## Threat model

Предположим, что атакующий уже выполняет код в Pod и пытается использовать identity workload либо отсутствие authentication для движения к Kubernetes API. В таком случае важен не только начальный доступ, но и blast radius после compromise.

Задание 1 закрывает излишний RBAC scope, задание 2 — долгоживущий token, а задание 3 — ненужный API-доступ из Pod. Это уменьшает возможности использовать identity workload после compromise.

Задание 4 устраняет wildcard cluster-wide права, а задание 5 — anonymous access. Каждый из этих путей по отдельности может расширить blast radius до Kubernetes API.

Задание 6 закрывает отдельный путь утечки: секрет, переданный через environment variable, становится частью окружения процесса и может быть прочитан из `/proc/1/environ` любым процессом с доступом на `exec` в контейнер, а также может попасть в application logs, crash dump или другой diagnostic вывод, если сама программа или инструмент диагностики печатает environment. `kubectl describe pod` для `env`/`envFrom` с `secretKeyRef` показывает только ссылку на Secret и его ключ (`<set to the key ... in secret ...>`), а не resolved значение — не путайте эту ссылку с утечкой самого значения. Volume mount с `defaultMode: 0400` не устраняет доступ уполномоченного процесса контейнера к значению, но убирает секрет из окружения процесса и ограничивает файловые права на чтение только владельцем.

Задание 7 закрывает скрытые пути RBAC privilege escalation: `impersonate`, `bind`/`escalate` и CSR approval не расширяют список доступных ресурсов напрямую, а дают возможность действовать от чужого имени или самостоятельно выдать себе более широкие права — это отдельная категория риска от wildcard `*` из задания 4. Задание 8 закрывает системную, а не точечную защиту: automount на уровне namespace/default SA работает даже для Pod, у которого разработчик забыл явно отключить токен.

Задание 9 показывает, что предотвращение (задания 1-8) и обнаружение - разные, взаимодополняющие слои. Даже если конкретный путь эскалации закрыт в задании 7, для будущего инцидента нужен способ увидеть **попытку** повторной эскалации без постоянного ручного `kubectl get`: audit log даёт воспроизводимое forensic evidence, а не просто текущий снимок RBAC-состояния.

ATT&CK T1528 (Steal Application Access Token) и T1613 дают контекст этому сценарию: задания не моделируют отдельную атаку, а ограничивают последствия уже скомпрометированного workload.

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
| Что делаем | Создайте ServiceAccount `api-client` и Pod `token-client` в `security-104`. Не используйте legacy Secret-токен. Отключите обычное автомонтирование токена, а нужный токен смонтируйте через projected volume в `/var/run/secrets/tokens/api-token` с `path: api-token` и `expirationSeconds: 3600` (или меньше). **Не задавайте `audience`**, чтобы kubelet запросил identifier API server по умолчанию. Если приложению необходима отдельная audience, сначала сверьте её с `--api-audiences` (либо default из `--service-account-issuer`) на API server и только затем задавайте явно. |
| Критерии приёмки | Pod использует `api-client`, имеет `automountServiceAccountToken: false`, а projected `serviceAccountToken` без жёстко заданной audience, с указанными path и временем жизни не более часа присутствует в спецификации. TokenReview, выполненный от admin-контекста для смонтированного токена, возвращает `authenticated: true` и имя `system:serviceaccount:security-104:api-client`; отдельная RBAC-проверка подтверждает, что этот ServiceAccount не может удалять `secrets`. |

<details>
<summary>💡 Подсказка к заданию 2</summary>

Самая частая ошибка - явно задать `audience: kubernetes.default.svc`, предполагая, что это стандартное значение. Для kubeadm-кластера это НЕ гарантированный default - если задать audience, которую API server не принимает через `--api-audiences`, TokenReview вернёт `authenticated: false`. Просто не указывайте поле `audience` вообще - kubelet тогда запросит identifier API server по умолчанию, который сервер точно принимает. Также не забудьте `automountServiceAccountToken: false` на самом Pod - иначе Kubernetes добавит ещё и обычный (legacy-стиль) volume токена вдобавок к вашему projected volume.
</details>

---
| **3** | **Pod без токена Kubernetes API** |
| :---: | :--- |
| Что делаем | Создайте ServiceAccount `no-token-sa` с `automountServiceAccountToken: false` и Pod `no-token` в `security-104` с этим ServiceAccount. На самом Pod также явно установите `automountServiceAccountToken: false`. Используйте любой безопасный долгоживущий образ, например `busybox:1.36` с `sleep 3600`. |
| Критерии приёмки | У ServiceAccount и Pod отключено автомонтирование; Pod использует `no-token-sa`; в его спецификации нет автоматически добавленного тома токена ServiceAccount. |

<details>
<summary>💡 Подсказка к заданию 3</summary>

Отличие от задания 8: здесь достаточно отключить automount либо на SA, либо на Pod - но задание требует **оба** уровня одновременно (defence in depth), а не один из них. Проверьте себя: `kubectl get pod no-token -o jsonpath='{.spec.volumes}'` не должен содержать ничего похожего на `kube-api-access-*`. Если том всё же появился - проверьте, что вы отключили automount ДО создания Pod, а не после (изменение SA не влияет на уже созданные Pod).
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
| Что делаем | На control-plane отредактируйте `/etc/kubernetes/manifests/kube-apiserver.yaml`: аргумент API server должен быть `--anonymous-auth=false`. Kubelet перезапустит static Pod автоматически. Дождитесь готовности API server и убедитесь, что запрос `curl -k https://<api-server>/version` без сертификата и bearer token получает `401`. |
| Критерии приёмки | Команда static Pod API server содержит `--anonymous-auth=false`; неаутентифицированный запрос к `/version` возвращает HTTP `401`. |

<details>
<summary>💡 Подсказка к заданию 5</summary>

Не редактируйте объект Pod через `kubectl edit pod` - kubelet следит за файлом манифеста и перезапишет любое изменение, сделанное через API, обратно в исходное состояние. Редактируйте именно файл `/etc/kubernetes/manifests/kube-apiserver.yaml` на диске ноды. После сохранения подождите: kubelet обнаруживает изменение файла не мгновенно, и API server будет недоступен несколько секунд во время перезапуска static Pod - не паникуйте, если `curl` сразу после сохранения файла ничего не возвращает.
</details>

---
| **6** | **Secret через env раскрывается в `/proc/1/environ`: рефакторинг на volume** |
| :---: | :--- |
| Что делаем | Pod `app-vulnerable` в `security-104` получает `db-creds` через `envFrom.secretRef` — значение доступно любому, кто может `kubectl exec` в контейнер (`cat /proc/1/environ`) или прочитать логи/describe при случайном выводе env. Подтвердите эту утечку: выполните `kubectl exec -n security-104 app-vulnerable -- cat /proc/1/environ` и сохраните вывод (с `DB_PASSWORD`) в `/var/work/tests/artifacts/6/env-leak-before.txt`. Затем пересоздайте Pod с тем же именем `app-vulnerable`: удалите `envFrom`/`env` с этим секретом, смонтируйте `db-creds` как volume `db-creds-vol` в `/etc/secrets` **read-only**, с `defaultMode: 0400`. Подтвердите отсутствие переменной `DB_PASSWORD` в новом `/proc/1/environ` и сохраните `stat -c '%a'` смонтированного файла в `/var/work/tests/artifacts/6/secret-file-mode.txt`. |
| Критерии приёмки | `env-leak-before.txt` содержит значение `DB_PASSWORD` из Secret; итоговый Pod `app-vulnerable` не имеет `env`/`envFrom`, ссылающихся на `db-creds`; volume `db-creds-vol` смонтирован в `/etc/secrets` как `readOnly: true` с `defaultMode: 0400` (`256` decimal); `secret-file-mode.txt` содержит `400`; `DB_PASSWORD` отсутствует в `/proc/1/environ` итогового Pod. |

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
должен вернуть `256`, а `stat -c '%a' /etc/secrets/DB_PASSWORD` внутри контейнера - `400`.
</details>

---
| **7** | **Аудит и отзыв скрытых RBAC-путей privilege escalation (`impersonate`, `bind`, `escalate`, CSR approval)** |
| :---: | :--- |
| Что делаем | ClusterRole `build-agent-hidden-privesc` не содержит wildcard `*` (это отдельный, уже устранённый в задании 4 путь) и на первый взгляд выглядит узким, но даёт ServiceAccount `build-agent` из `security-104` три скрытых пути повышения привилегий: `impersonate` над `users`/`groups`/`serviceaccounts` (подмена личности, включая cluster-admin, если такой пользователь известен атакующему), `bind`/`escalate` над `clusterroles` (возможность привязать себе любой ClusterRole или добавить в свой права, которых у него самого нет) и `update` на `certificatesigningrequests/approval` + `approve` на signer `kubernetes.io/kube-apiserver-client` (самостоятельная выдача client-сертификата с произвольной identity). Найдите **все** ClusterRoleBinding, чьи ClusterRole разрешают `impersonate`, `bind` или `escalate` (например, через `kubectl get clusterrole -o json \| jq` по `rules[].verbs`), запишите их в `/var/work/tests/artifacts/7/dangerous-bindings-before.txt`, затем удалите ClusterRoleBinding `build-agent-hidden-privesc` (и, если найдёте другие непреднамеренные — их тоже, но не системные `system:*` ClusterRoleBinding). Подтвердите отзыв через `kubectl auth can-i impersonate users --as=system:serviceaccount:security-104:build-agent` и `kubectl auth can-i update certificatesigningrequests/approval --as=system:serviceaccount:security-104:build-agent` — оба должны вернуть `no`. |
| Критерии приёмки | `dangerous-bindings-before.txt` содержит `build-agent-hidden-privesc` среди найденных; ClusterRoleBinding `build-agent-hidden-privesc` не существует после исправления; `build-agent` не может `impersonate`, `bind`/`escalate` или `update certificatesigningrequests/approval`; системные `system:*` ClusterRoleBinding не тронуты. |

<details>
<summary>💡 Подсказка к заданию 7</summary>

CSR approval - отдельная категория от `impersonate`/`bind`/`escalate`: она не входит в тот же `jq`-фильтр по `verbs`, потому что представляет собой отдельное правило на ресурс `certificatesigningrequests/approval` с verb `update`, плюс `approve` на конкретный `signer`. Если вы отфильтруете только по `impersonate`/`bind`/`escalate`, вы найдёте один путь, но упустите CSR - ищите оба отдельно. Не удаляйте системные `ClusterRoleBinding` с префиксом `system:` - они нужны core-компонентам Kubernetes для легитимного `impersonate` (например, `system:kube-controller-manager`).
</details>

---
| **8** | **Namespace-level baseline: `default` ServiceAccount без automount** |
| :---: | :--- |
| Что делаем | Задание 3 отключало automount точечно, внутри конкретного Pod и его собственного ServiceAccount. Здесь нужен baseline на уровне **namespace**: создайте namespace `security-104-baseline` и сразу после его создания установите `automountServiceAccountToken: false` на его ServiceAccount `default` (`kubectl patch serviceaccount default -n security-104-baseline -p '{"automountServiceAccountToken":false}'`). Создайте в этом namespace Pod `implicit-default-sa` из `busybox:1.36` (`sleep 3600`), **не указывая** ни `serviceAccountName`, ни `automountServiceAccountToken` явно — он должен неявно использовать `default` SA и наследовать его значение. Подтвердите, что в спецификации итогового Pod **нет** автоматически смонтированного тома токена ServiceAccount. |
| Критерии приёмки | ServiceAccount `default` в `security-104-baseline` имеет `automountServiceAccountToken: false`; Pod `implicit-default-sa` использует `serviceAccountName: default` (неявно или явно) и **не имеет** ни явного `automountServiceAccountToken` в своей спецификации, ни автоматически добавленного `projected`/`secret` volume с токеном ServiceAccount; попытка прочитать `/var/run/secrets/kubernetes.io/serviceaccount/token` внутри контейнера завершается ошибкой (файл отсутствует). |

<details>
<summary>💡 Подсказка к заданию 8</summary>

Порядок операций критичен: если вы создадите Pod ДО того, как `patch` применится к `default` SA namespace, Pod получит токен по старому (default `true`) значению. Всегда: сначала `kubectl patch serviceaccount default -n security-104-baseline`, только потом `kubectl apply` на Pod. Задание намеренно не указывает `serviceAccountName` в Pod - это моделирует реальную ситуацию, когда разработчик просто забыл про ServiceAccount, и baseline должен защитить его по умолчанию.
</details>

---
| **9** | **Интеграционное задание: обнаружить RBAC-эскалацию через audit log и локализовать её** |
| :---: | :--- |
| Что делаем | Это задание объединяет RBAC (эта лаба) с audit-логированием (см. [главу 32](../../course/32/ru.md)) - без audit log сам факт эскалации из задания 7 было бы видно только post-hoc через `kubectl get`, а не как воспроизводимое forensic evidence. На control-plane включите минимальный audit backend: создайте `/etc/kubernetes/audit/policy.yaml` с правилом `RequestResponse` для `apiGroups: ["rbac.authorization.k8s.io"]`, ресурсов `clusterroles` и `clusterrolebindings`, и catch-all `Metadata` как fallback. В static manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` добавьте `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`, `--audit-log-path=/var/log/kubernetes/audit/audit.log` и нужные hostPath volume/volumeMount (создайте директории заранее). Дождитесь восстановления API. Создайте ClusterRoleBinding `incident-simulated-escalation`, привязывающий ClusterRole `cluster-admin` к ServiceAccount `build-agent` из `security-104` (симуляция того, что задание 7 не успело закрыть путь эскалации вовремя). Найдите в audit log событие `create` для `clusterrolebindings` с этим именем и `system:serviceaccount:security-104:build-agent` в `requestObject.subjects`, сохраните событие целиком в `/var/work/tests/artifacts/9/audit-escalation-event.json`. Затем выполните containment: удалите `incident-simulated-escalation` и подтвердите через `kubectl auth can-i '*' '*' --as=system:serviceaccount:security-104:build-agent`, что доступ отозван; сохраните итоговый `no` в `/var/work/tests/artifacts/9/containment-result.txt`. |
| Критерии приёмки | Static manifest kube-apiserver содержит `--audit-policy-file` и `--audit-log-path`, API server healthy; `/var/work/tests/artifacts/9/audit-escalation-event.json` - валидный JSON audit event с `verb: create`, `objectRef.resource: clusterrolebindings`, `objectRef.name: incident-simulated-escalation` и упоминанием `build-agent` в `requestObject`; ClusterRoleBinding `incident-simulated-escalation` не существует после containment; `containment-result.txt` содержит `no`. |

<details>
<summary>💡 Подсказка к заданию 9</summary>

Правило `RequestResponse` для `rbac.authorization.k8s.io` должно стоять ПЕРВЫМ в списке правил policy - более специфичное правило должно предшествовать общему `Metadata`-catch-all, иначе catch-all перехватит событие раньше и вы получите только `Metadata`-уровень вместо `RequestResponse` с телом запроса. Создайте `incident-simulated-escalation` ПОСЛЕ того, как API server перезапустился с новым audit backend - иначе событие просто не попадёт в лог. Не забудьте containment: удаление `ClusterRoleBinding` само по себе - половина задачи, вторая половина - доказать через `kubectl auth can-i`, что доступ реально отозван, а не просто объект стал недоступен для чтения.
</details>

## Проверка

На рабочей машине выполните:

```bash
check_result
```

Проверка содержит Init и девять независимых заданий. После изменения API server последний
тест может кратко ждать перезапуска static Pod.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD)

## Удаление

```bash
TASK=104 make delete_cks_task
```
