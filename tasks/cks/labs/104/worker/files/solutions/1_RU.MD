# Лаба 104 - эталонное решение: RBAC, ServiceAccount token и anonymous API

> Выполняйте команды с рабочей машины, если в шаге не указано иное. Namespace
> `security-104` уже существует.
>
> На экзамене `k` (`alias k=kubectl`) и bash-completion для него уже настроены на SSH-хосте -
> не тратьте время на их настройку, просто используйте `k` (см. главу 33.6).

## 1. Минимальный доступ `auditor` только к Pod

На экзамене писать полный YAML для типового RBAC-объекта вручную - потеря времени:
`kubectl create` генерирует ServiceAccount/Role/RoleBinding одной командой каждый:

```bash
k create sa auditor -n security-104
k create role pod-observer -n security-104 --resource=pods --verb=get,list,watch
k create rolebinding auditor-pod-observer -n security-104 \
  --role=pod-observer --serviceaccount=security-104:auditor

k auth can-i list pods -n security-104 \
  --as=system:serviceaccount:security-104:auditor
k auth can-i delete secrets -n security-104 \
  --as=system:serviceaccount:security-104:auditor # должно быть no
```

## 2. Projected токен ServiceAccount

TokenRequest volume выдаёт короткоживущий токен; обычное автомонтирование отключено.
Не фиксируем `audience: kubernetes.default.svc`: для kubeadm это не гарантированно
значение, принимаемое API server. Если `audience` опущена, kubelet использует identifier
API server по умолчанию. Отдельную audience допустимо указать только после проверки
`--api-audiences` (либо default из `--service-account-issuer`) на control-plane.
`expirationSeconds` обязан быть в диапазоне `600`-`3600` включительно - Kubernetes API
отклоняет как invalid любое значение меньше `600` секунд для `serviceAccountToken`
projected source, независимо от того, что написано в манифесте.

Точный синтаксис `projected.sources[].serviceAccountToken` по памяти на экзамене
вспоминать не нужно - на `kubernetes.io/docs` он есть в разделе Concepts → Storage →
[Projected Volumes](https://kubernetes.io/docs/concepts/storage/projected-volumes/), под
заголовком **"serviceAccountToken projected volumes"** (там готовый пример Pod с этим
volume - берите структуру оттуда, а не пишите с нуля). `kubectl run` не умеет добавлять
такой volume через флаги - генерируем скелет Pod через `--dry-run=client -o yaml` и
дописываем в `vim` только нужные поля, скопированные из примера в документации:

```bash
k create sa api-client -n security-104
k run token-client -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > token-client.yaml
vim token-client.yaml
```

```yaml
# В spec Pod добавьте (containers/image/command уже сгенерированы kubectl run):
spec:
  serviceAccountName: api-client              # добавить
  automountServiceAccountToken: false         # добавить
  containers:
  - name: token-client
    volumeMounts:                             # добавить
    - name: api-token                         # добавить
      mountPath: /var/run/secrets/tokens       # добавить
      readOnly: true                          # добавить
    ...
  volumes:                                    # добавить
  - name: api-token                           # добавить
    projected:                                # добавить
      sources:                                # добавить
      - serviceAccountToken:                  # добавить
          path: api-token                     # добавить
          expirationSeconds: 3600             # добавить
```

```bash
k apply -f token-client.yaml
k wait -n security-104 --for=condition=Ready po/token-client --timeout=120s
k exec -n security-104 token-client -- \
  ls -l /var/run/secrets/tokens/api-token
# файл есть - если манифест совпадает с примером из документации, kubelet его выпустил

k auth can-i delete secrets -n security-104 \
  --as=system:serviceaccount:security-104:api-client
# no
```

## 3. Pod без токена API

Отключаем автомонтирование и на ServiceAccount, и на Pod: это защищает от последующих
изменений шаблона или ServiceAccount.

`kubectl create serviceaccount` не имеет флага для `automountServiceAccountToken` - создаём
и сразу патчим:

```bash
k create sa no-token-sa -n security-104
k patch sa no-token-sa -n security-104 -p '{"automountServiceAccountToken":false}'
k run no-token -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > no-token.yaml
vim no-token.yaml
```

```yaml
# В spec Pod добавьте:
spec:
  serviceAccountName: no-token-sa       # добавить
  automountServiceAccountToken: false   # добавить
  containers:
  - name: no-token
    ...
```

```bash
k apply -f no-token.yaml
k wait -n security-104 --for=condition=Ready po/no-token --timeout=60s
k get po no-token -n security-104 -o jsonpath='{.spec.automountServiceAccountToken}'

# Подтверждаем на уровне runtime, а не только на уровне YAML-спецификации: в
# контейнере действительно нет файла токена.
k exec -n security-104 no-token -- \
  test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token
echo "exit code: $?"
# exit code: 0 - файла нет, exec сам отработал успешно
```

Не монтируйте отдельно и legacy `Secret` с `type: kubernetes.io/service-account-token` -
даже при выключенном automount такой Secret можно смонтировать вручную через
`volumes[].secret`, и тогда Pod формально "без токена" по automount-полю, но фактически
всё равно имеет валидный API-токен внутри контейнера.

## 4. Удаление wildcard-прав

Удаляем и binding (субъект больше не получает доступ), и сам ClusterRole (опасный
шаблон не останется для повторного использования):

```bash
k delete clusterrolebinding legacy-operator-admin
k delete clusterrole legacy-operator-admin
k auth can-i get secrets -n security-104 \
  --as=system:serviceaccount:security-104:legacy-operator # должно быть no
```

## 5. Отключение anonymous-auth

Простое `--anonymous-auth=false` здесь не подходит: kubeadm `release-1.36` генерирует
kube-apiserver static Pod с HTTPS liveness/readiness/startup probes на `/livez` и
`/readyz`, а kubelet HTTP probes не передают client credentials - при полном отключении
anonymous access эти запросы получат `401`, и kubelet начнёт считать kube-apiserver
нездоровым (что в свою очередь ломает и задание 9, зависящее от стабильно работающего API
server). Вместо этого используем `AuthenticationConfiguration` с `anonymous.conditions`,
ограничивающими anonymous access только тремя health-путями. На экзамене не префиксите
каждую команду `sudo` - один раз станьте root (`sudo -i`), это быстрее:

```bash
ssh control-plane
sudo -i
cat > /etc/kubernetes/authentication-config.yaml <<'EOF'
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt: []
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
EOF
```

Правим static manifest: убираем `--anonymous-auth=true` полностью (нельзя оставлять
рядом с `--authentication-config` - kube-apiserver откажется стартовать, если заданы оба),
добавляем `--authentication-config`, а также `hostPath` volume/volumeMount для нового
файла конфигурации - kube-apiserver читает `authentication-config.yaml` с файловой
системы ноды, поэтому файл должен быть виден внутри container через volumeMount, а не
только лежать на хосте:

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/5-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# В массиве command:
# - удалите строку "- --anonymous-auth=true"
# - добавьте строку с тем же отступом, что у остальных аргументов:
#   - --authentication-config=/etc/kubernetes/authentication-config.yaml
# В volumeMounts контейнера (тот же отступ, что у соседних элементов):
#   - mountPath: /etc/kubernetes/authentication-config.yaml
#     name: authentication-config
#     readOnly: true
# В volumes Pod (тот же отступ, что у соседних элементов):
#   - hostPath:
#       path: /etc/kubernetes/authentication-config.yaml
#       type: File
#     name: authentication-config
systemctl restart kubelet
exit
exit
```

`systemctl restart kubelet` форсирует немедленную пересборку static Pod - на экзамене
быстрее, чем ждать, пока kubelet сам заметит изменение файла (обычно секунды, но не
гарантированно мгновенно):

```bash
k get po -n kube-system -l component=kube-apiserver
# STATUS должен стать Running - если ещё нет, подождите пару секунд и повторите
```

Проверьте все три поведения: `/version` отклоняет анонимные запросы, а `/livez`/`/readyz`
- принимают:

```bash
SERVER=$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}')
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/version" # 401 - anonymous access закрыт
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/livez"   # 200 - health probe работает
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/readyz"  # 200 - health probe работает
```

Аутентифицированный запрос к `/readyz` (через уже настроенный kubectl context)
продолжает работать точно так же - `AuthenticationConfiguration.anonymous.conditions`
только РАСШИРЯЕТ доступ для anonymous-запросов на конкретные пути, но не сужает доступ
для уже аутентифицированных клиентов:

```bash
k get --raw=/readyz # ok
```

Аутентификация без ограничивающей авторизации бессмысленна - проверьте, что
`--authorization-mode` на static Pod всё ещё `Node,RBAC` и не содержит `AlwaysAllow`
(kubeadm задаёт это по умолчанию, но стоит убедиться, что ничего не поменяло флаг):

```bash
k get po -n kube-system -l component=kube-apiserver \
  -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | grep authorization-mode
# --authorization-mode=Node,RBAC
```

Отдельно аудируем ClusterRoleBinding, чьи subjects указывают на анонимного пользователя
или группу - в кластере намеренно оставлена одна такая lab-owned привязка:

```bash
k get clusterrolebinding -o json | jq -r \
  '.items[] | select([.subjects[]? | select(.name == "system:anonymous" or .name == "system:unauthenticated")] | length > 0) | .metadata.name'
# system:public-info-viewer
# lab104-unintended-anonymous-access
```

`system:public-info-viewer` - штатная kubeadm-привязка: она тоже целится в
`system:unauthenticated`, но её ClusterRole разрешает read-only `GET` только к
non-resource URL `/livez`, `/readyz`, `/healthz`, `/version`, `/version/`, а не к обычным
Kubernetes-ресурсам - это default Kubernetes RBAC, требуемая часть bootstrap, не трогайте
её. Это не то же самое, что `anonymous.conditions` из этого же задания: тот список
ограничивает, на каких путях запрос вообще получает anonymous identity на этапе
authentication (там только `/livez`/`/readyz`/`/healthz`) - `/version` анонимно возвращает
`401` именно потому, что anonymous identity туда не назначается, а не потому что у
`system:public-info-viewer` там не хватает прав. `lab104-unintended-anonymous-access` -
намеренная lab-owned находка: её ClusterRole `lab104-anonymous-debug-access` даёт
полноценный RBAC `get`/`list` на `pods`/`secrets`/`configmaps` кластерно, то есть ЛЮБОЙ
анонимный запрос может их читать. Удаляем оба объекта, как и в заданиях 4/7:

```bash
k delete clusterrolebinding lab104-unintended-anonymous-access
k delete clusterrole lab104-anonymous-debug-access
```

Подтверждаем отзыв реальным негативным контролем от имени именно неаутентифицированной
идентичности, а не просто отсутствием объекта:

```bash
k auth can-i get pods -A --as=system:anonymous --as-group=system:unauthenticated --as-group=system:authenticated
k auth can-i get secrets -A --as=system:anonymous --as-group=system:unauthenticated --as-group=system:authenticated
k auth can-i get configmaps -A --as=system:anonymous --as-group=system:unauthenticated --as-group=system:authenticated
# no / no / no
```

Второй `--as-group=system:authenticated` нужен только чтобы impersonated-идентичность вообще
могла выполнить сам запрос `can-i` (SelfSubjectAccessReview); без него `system:anonymous`
получит `Forbidden` вместо `no`, что не доказывает отзыв прав. Эта группа не даёт доступа к
Pod/Secret/ConfigMap - если бы lab-owned binding остался, ответ был бы `yes`.

В конце выполните `check_result`.

## 6. Утечка Secret через env в `/proc/1/environ`: переход на volume

`app-vulnerable` получает `db-creds` через `envFrom`, поэтому значение попадает в
environment процесса PID 1 контейнера. Любой, у кого есть право на `kubectl exec` в этот
Pod, может прочитать секрет напрямую из `/proc`, без обращения к Kubernetes API и без RBAC
на `get secrets`:

```bash
mkdir -p /var/work/tests/artifacts/6
k exec -n security-104 app-vulnerable -- cat /proc/1/environ \
  | tr '\0' '\n' | grep DB_PASSWORD | tee /var/work/tests/artifacts/6/env-leak-before.txt
```

Сохраняем именно строку `DB_PASSWORD=<реальное значение>` из окружения процесса, а не
просто слово `DB_PASSWORD` без значения - checker сам сверит её с фактическим значением
из Secret `db-creds`, отдельно вычислять и сравнивать значение самим не нужно.

Пересоздаём Pod с тем же именем: убираем `envFrom`, монтируем тот же Secret как volume
`db-creds-vol` в `/etc/secrets`, read-only, с `defaultMode: 0400` (`256` в decimal, как его
показывает `kubectl get pod -o json`). `0400` - это read-only только для владельца файла
внутри контейнера; сам процесс приложения всё равно должен запускаться под этим UID, иначе
он не сможет прочитать файл.

Поле - неизменяемое; Pod нужно удалить и создать заново с тем же именем. Снова дешевле
сгенерировать скелет через `--dry-run` и дописать volume в `vim`, чем писать весь YAML:

```bash
k run app-vulnerable -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > app-vulnerable-fixed.yaml
vim app-vulnerable-fixed.yaml
```

```yaml
# В spec Pod добавьте:
spec:
  automountServiceAccountToken: false     # добавить
  containers:
  - name: app-vulnerable
    volumeMounts:                         # добавить
    - name: db-creds-vol                  # добавить
      mountPath: /etc/secrets             # добавить
      readOnly: true                      # добавить
    ...
  volumes:                                # добавить
  - name: db-creds-vol                    # добавить
    secret:                               # добавить
      secretName: db-creds                # добавить
      defaultMode: 0400                   # добавить
```

```bash
k delete pod app-vulnerable -n security-104
k apply -f app-vulnerable-fixed.yaml
k wait -n security-104 --for=condition=Ready po/app-vulnerable --timeout=120s
```

Подтверждаем три итоговых свойства, а не только «секрета нет в environment»: файловые
права точно `400` (а не просто где-то содержат подстроку `400`), и, что важнее, приложение
всё ещё РЕАЛЬНО может прочитать значение секрета - иначе hardening мог бы незаметно
сломать саму функциональность приложения:

```bash
k exec -n security-104 app-vulnerable -- cat /proc/1/environ | tr '\0' '\n' | grep DB_PASSWORD
# ничего не найдено - это ожидаемо

k exec -n security-104 app-vulnerable -- stat -L -c '%a' /etc/secrets/DB_PASSWORD \
  | tee /var/work/tests/artifacts/6/secret-file-mode.txt
# 400 - именно это значение, а не произвольный текст, где-то содержащий "400". Флаг -L
# обязателен: секретный volume монтируется через цепочку симлинков ("..data"), и без -L
# stat покажет режим самого симлинка (всегда 777 в Linux), а не реального файла.

# Positive control: процесс приложения должен реально мочь прочитать значение секрета.
k exec -n security-104 app-vulnerable -- cat /etc/secrets/DB_PASSWORD
# должно совпадать со значением, которое было в env-leak-before.txt до фикса
```

`defaultMode: 0400` защищает от чтения другими UID на этом же Pod (например, соседним
sidecar-container без нужного UID), но не заменяет encryption at rest у etcd и не мешает
процессу, запущенному под ожидаемым UID, прочитать сам файл - mount разрешает именно это.
Убедитесь также, что `db-creds` не смонтирован каким-то ВТОРЫМ способом одновременно
(например, ещё и через `projected` volume) - должен остаться ровно один volume,
монтирующий этот Secret.

В конце выполните `check_result`.

## 7. Аудит и отзыв скрытых RBAC-путей privilege escalation

`build-agent-hidden-privesc` не содержит wildcard `*`, но `impersonate`/`bind`/`escalate`/
CSR-approval - отдельная категория опасных verbs: они не расширяют список видимых
ресурсов, а дают возможность **действовать от чужого имени** или **выдать себе
дополнительные права**. В этой версии fixture ClusterRole также содержит базовые
`create`/`update` на `clusterroles`/`clusterrolebindings` - без них `bind`/`escalate`
были бы неполными escalation primitives (RBAC требует ЛИБО уже иметь права из роли, ЛИБО
явно иметь `escalate`/`bind` НА ФОНЕ попытки реально создать/обновить Role/Binding).
Находим все ClusterRoleBinding, чьи ClusterRole разрешают любой из опасных verbs. Идём не
от ClusterRole (их в кластере десятки, включая штатные `system:*`), а от
ClusterRoleBinding - `kubectl get clusterrolebinding` уже по умолчанию показывает колонку
`ROLE` (формат `ClusterRole/<имя>`), а `-o wide` добавляет ещё `USERS`/`GROUPS`/
`SERVICEACCOUNTS` - ни custom-columns, ни YAML не нужны:

```bash
mkdir -p /var/work/tests/artifacts/7
k get clusterrolebinding -o wide | grep -v system:
# build-agent-hidden-privesc   ClusterRole/build-agent-hidden-privesc   ...   security-104/build-agent
```

Для каждого кандидата смотрим его ClusterRole человекочитаемо, без `jq`/`grep` по YAML -
`kubectl describe` сам печатает verbs таблицей, там сразу видно `impersonate`/`bind`/
`escalate` и отдельное правило на `certificatesigningrequests/approval`:

```bash
k describe clusterrole build-agent-hidden-privesc
# Verbs в PolicyRule-таблице покажут impersonate / bind / escalate / update
# (на certificatesigningrequests/approval) - глазами видно, что роль опасна
```

Сохраняем имя ClusterRoleBinding (не ClusterRole - они могут не совпадать, в этой лабе
совпали случайно) в artifact:

```bash
echo build-agent-hidden-privesc > /var/work/tests/artifacts/7/dangerous-bindings-before.txt
cat /var/work/tests/artifacts/7/dangerous-bindings-before.txt
```

`build-agent-hidden-privesc` должен быть в итоговом файле (как имя ClusterRoleBinding,
не ClusterRole). Удаляем именно этот ClusterRoleBinding (и ClusterRole, чтобы шаблон не
остался для повторного использования), не трогая `system:*` bindings, которые дают
core-компонентам Kubernetes необходимый `impersonate`/CSR доступ:

```bash
k delete clusterrolebinding build-agent-hidden-privesc
k delete clusterrole build-agent-hidden-privesc
```

Подтверждаем отзыв ВСЕХ заявленных опасных прав, а не только части из них. Два нюанса:
fixture даёт `impersonate` сразу на три типа ресурса (`users`/`groups`/`serviceaccounts`) -
проверка только `users` не доказывает отзыв остальных двух; а `TYPE/NAME` в `kubectl auth
can-i` - это resourceName, а не subresource (`kubectl auth can-i --help` прямо показывает
пример "jobs.batch/bar" - проверка объекта, буквально названного `bar`), поэтому для
`certificatesigningrequests/approval` нужен отдельный флаг `--subresource=approval`, а не
слэш:

```bash
k auth can-i impersonate users --as=system:serviceaccount:security-104:build-agent
k auth can-i impersonate groups --as=system:serviceaccount:security-104:build-agent
k auth can-i impersonate serviceaccounts -n security-104 --as=system:serviceaccount:security-104:build-agent
k auth can-i bind clusterroles --as=system:serviceaccount:security-104:build-agent
k auth can-i escalate clusterroles --as=system:serviceaccount:security-104:build-agent
k auth can-i update certificatesigningrequests --subresource=approval --as=system:serviceaccount:security-104:build-agent
k auth can-i approve signers/kubernetes.io/kube-apiserver-client --as=system:serviceaccount:security-104:build-agent
# no / no / no / no / no / no / no
```

В конце выполните `check_result`.

## 8. Namespace-level baseline: `default` SA без automount

Задание 3 отключало automount точечно, у конкретного Pod и его собственного SA. Здесь
нужен системный baseline: правим `default` SA namespace **до** создания в нём каких-либо
Pod, чтобы ни один новый workload не получил токен по умолчанию, даже если разработчик
забудет явное поле в манифесте.

ServiceAccount `default` создаётся отдельным контроллером асинхронно после появления
Namespace - `kubectl wait` умеет ждать именно появления объекта (`--for=create`), не
только его condition, поэтому не нужен ни ручной retry, ни самодельный цикл:

```bash
k create namespace security-104-baseline
k wait -n security-104-baseline --for=create sa/default --timeout=30s

k -n security-104-baseline patch sa default \
  -p '{"automountServiceAccountToken":false}'
k -n security-104-baseline get sa default \
  -o jsonpath='{.automountServiceAccountToken}{"\n"}'
# false
```

Создаём Pod, который **не** задаёт ни `serviceAccountName`, ни `automountServiceAccountToken` -
это самый частый в реальности случай, когда разработчик просто не думает про SA. Поле
`automountServiceAccountToken` должно ОТСУТСТВОВАТЬ в спеке Pod - явное указание `false`
доказывало бы только точечную настройку самого Pod (как в задании 3), а не то, что
namespace-level baseline реально работает:

Здесь не нужен даже `--dry-run` - раз в Pod не добавляется ни одного поля про SA/automount,
`kubectl run` без флагов создаёт ровно то, что нужно, напрямую:

```bash
k run implicit-default-sa -n security-104-baseline --image=busybox:1.36 --command -- sh -c "sleep 3600"
k wait -n security-104-baseline --for=condition=Ready po/implicit-default-sa --timeout=60s
k get po implicit-default-sa -n security-104-baseline -o jsonpath='{.spec.serviceAccountName}{"\n"}'
# default

k get po implicit-default-sa -n security-104-baseline \
  -o jsonpath='{.spec.automountServiceAccountToken}{"\n"}'
# пустой вывод - поле отсутствует в спеке, а не установлено в false

k exec -n security-104-baseline implicit-default-sa -- \
  test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token
echo "exit code: $?"
# exit code: 0 - файла нет, и сам exec отработал успешно (в отличие от банального
# "cat" на несуществующий файл, exit code которого cat-а тоже ненулевой, но по другой
# причине - test ! -e делает именно ту проверку, которая нужна, и её собственный успех
# нужно требовать отдельно, а не просто "любая ошибка = файла нет")
```

Значение SA действует, только если Pod не переопределяет его сам. Если тому же namespace
понадобится Pod с API-доступом, добавьте `automountServiceAccountToken: true` явно в
конкретном манифесте после проверки, что доступ действительно нужен - не меняйте baseline
`default` SA обратно на `true` для всего namespace. Также не монтируйте вручную старый
(legacy) `Secret` с `type: kubernetes.io/service-account-token` через `volumes[].secret` -
это дало бы Pod валидный API-токен независимо от настроек automount.

В конце выполните `check_result`.

## 9. Интеграционное задание: обнаружение опасного RBAC-изменения → audit log → containment

Задания 1-8 закрывали конкретные пути повышения привилегий, доступные самому `build-agent`
(wildcard, impersonate/bind/escalate, automount). Здесь нужен другой слой защиты -
обнаружение **опасного RBAC grant, выданного администратором** (по ошибке, из-за
скомпрометированной автоматизации, или злонамеренно), а не только текущий снимок RBAC.
Подключаемся к control-plane и готовим минимальный audit backend:

```bash
ssh control-plane
sudo -i
mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit
cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
- level: RequestResponse
  resources:
  - group: "rbac.authorization.k8s.io"
    resources: ["clusterroles", "clusterrolebindings"]
- level: Metadata
EOF
```

Правило RBAC стоит первым - более специфичное правило должно предшествовать общему
catch-all, иначе `Metadata` перехватит событие раньше. `omitStages: [RequestReceived]`
на уровне всей policy убирает лишнюю запись до обработки запроса - у неё нет
`requestObject`/`responseStatus`, которые всё равно фильтрует checker (`stage ==
"ResponseComplete"`), а с catch-all `Metadata`-правилом на ВСЕ остальные запросы кластера
эта стадия удваивала бы объём audit.log без пользы.

Правим static manifest: добавляем `--audit-policy-file`/`--audit-log-path` и hostPath
volume/volumeMount для каталогов policy и логов - тем же приёмом, что и в задании 5 для
`authentication-config.yaml`:

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/9-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# В массиве command добавьте строки с тем же отступом, что у остальных аргументов:
#   - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
#   - --audit-log-path=/var/log/kubernetes/audit/audit.log
# В volumeMounts контейнера (тот же отступ, что у соседних элементов):
#   - mountPath: /etc/kubernetes/audit
#     name: audit-policy
#     readOnly: true
#   - mountPath: /var/log/kubernetes/audit
#     name: audit-log
# В volumes Pod (тот же отступ, что у соседних элементов):
#   - hostPath:
#       path: /etc/kubernetes/audit
#       type: Directory
#     name: audit-policy
#   - hostPath:
#       path: /var/log/kubernetes/audit
#       type: DirectoryOrCreate
#     name: audit-log
systemctl restart kubelet
exit
exit
```

`systemctl restart kubelet` форсирует немедленную пересборку static Pod - так же, как в
задании 5, быстрее ждать не нужно:

```bash
k get po -n kube-system -l component=kube-apiserver
# STATUS должен стать Running - если ещё нет, подождите пару секунд и повторите
```

Возвращаемся на рабочую машину (от имени администратора `cluster1-admin`) и создаём
опасную привязку - это **не** попытка эскалации со стороны `build-agent` (у него уже нет
реальных путей к этому после задания 7), а моделируемое администраторское действие,
которое audit log должен поймать как воспроизводимое evidence о том, кто именно это
сделал и кому именно были выданы права:

```bash
k create clusterrolebinding incident-simulated-escalation \
  --clusterrole=cluster-admin \
  --serviceaccount=security-104:build-agent
```

Сначала просто убеждаемся глазами, что audit-правило реально работает и событие попало в
лог - на экзамене обычно нужна именно эта проверка, а не готовый artifact:

```bash
ssh control-plane
sudo cat /var/log/kubernetes/audit/audit.log | jq . | grep -A 30 incident-simulated-escalation
exit
```

`jq .` печатает каждую запись лога человекочитаемо (по одному полю на строку), `grep -A 30`
показывает найденную строку с именем и 30 строк ПОСЛЕ неё - этого достаточно, чтобы увидеть
`stage`, `user.username` (реальный инициатор), `requestObject.roleRef`,
`requestObject.subjects` глазами, без специального jq-синтаксиса.

Этого достаточно для реального экзамена, но эта лаба дополнительно требует artifact-файл с
событием - не потому что чекеру мало знать, что правило работает (он сам, независимо,
читает `audit.log` на control-plane через SSH), а чтобы проверить отдельный навык:
извлечь и сохранить именно РЕАЛЬНУЮ запись как forensic evidence, а не пересказать её
своими словами (checker сверяет `auditID` вашего файла с `auditID` реальной записи в логе).
`/var/work/tests/artifacts/9/` - путь на РАБОЧЕЙ машине, а не на control-plane, поэтому
сохраняем с рабочей машины через `ssh control-plane "..."`, той же связкой grep по обычным
подстрокам (имя события + `ResponseComplete`, чтобы не попасть на промежуточную
`ResponseStarted` запись того же request):

```bash
mkdir -p /var/work/tests/artifacts/9
ssh control-plane "sudo cat /var/log/kubernetes/audit/audit.log" \
  | grep incident-simulated-escalation | grep ResponseComplete \
  | tail -n1 > /var/work/tests/artifacts/9/audit-escalation-event.json
```

Сохраняем событие **целиком**, как оно реально лежит в audit log (включая `auditID`) - не
переписываем и не собираем JSON вручную, иначе artifact не будет совпадать с реальной
записью в логе при верификации.

Containment: удаляем привязку и подтверждаем, что доступ реально отозван, а не просто
объект недоступен для чтения. `can-i` без `-n`/`-A` проверяет только текущий namespace
kubeconfig-контекста, а не весь кластер - для namespaced RoleBinding в `security-104`
(в отличие от уже удалённого cluster-wide ClusterRoleBinding) это меняет результат,
поэтому указываем namespace явно:

```bash
k delete clusterrolebinding incident-simulated-escalation
k auth can-i '*' '*' -n security-104 --as=system:serviceaccount:security-104:build-agent \
  | tee /var/work/tests/artifacts/9/containment-result.txt
# no
```

Разница с заданием 7: там мы находили и отзывали **уже существующий** скрытый путь через
статический анализ RBAC-объектов, принадлежащий самому workload (`build-agent`). Здесь
source of truth - **событие во времени** (audit log), которое доказывает, кто именно
(поле `user.username` - реальный инициатор запроса, в данном случае администратор, а не
`build-agent`) выдал опасные права и кому именно - это то, что нужно для реального
инцидента, когда сам объект могли уже удалить после использования, а `build-agent` в
событии фигурирует только как получатель прав, а не как автор запроса.

В конце выполните `check_result`.

## 10. Decode, create and mount a Secret

`legacy-config` уже существует. Читаем оба значения через API, а не гадаем:

```bash
mkdir -p /var/work/tests/artifacts/10
SERVICE_USER=$(k get secret legacy-config -n security-104 -o jsonpath='{.data.SERVICE_USER}' | base64 -d)
SERVICE_TOKEN=$(k get secret legacy-config -n security-104 -o jsonpath='{.data.SERVICE_TOKEN}' | base64 -d)
printf 'SERVICE_USER=%s\nSERVICE_TOKEN=%s\n' "$SERVICE_USER" "$SERVICE_TOKEN" \
  | tee /var/work/tests/artifacts/10/decoded-values.txt
```

Создаём новый generic Secret с теми же именами ключей и теми же значениями -
`--from-literal` сам кодирует значение в base64, вручную это делать не нужно:

```bash
k create secret generic rehydrated-config -n security-104 \
  --from-literal=SERVICE_USER="$SERVICE_USER" \
  --from-literal=SERVICE_TOKEN="$SERVICE_TOKEN"
```

Монтируем его как read-only volume в Pod - снова dry-run + точечная правка в `vim`:

```bash
k run secret-workflow -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > secret-workflow.yaml
vim secret-workflow.yaml
```

```yaml
# В spec Pod добавьте:
spec:
  automountServiceAccountToken: false      # добавить
  containers:
  - name: secret-workflow
    volumeMounts:                          # добавить
    - name: rehydrated-config-vol          # добавить
      mountPath: /etc/rehydrated           # добавить
      readOnly: true                       # добавить
    ...
  volumes:                                 # добавить
  - name: rehydrated-config-vol            # добавить
    secret:                                # добавить
      secretName: rehydrated-config        # добавить
```

```bash
k apply -f secret-workflow.yaml
k wait -n security-104 --for=condition=Ready po/secret-workflow --timeout=60s
k exec -n security-104 secret-workflow -- cat /etc/rehydrated/SERVICE_USER
k exec -n security-104 secret-workflow -- cat /etc/rehydrated/SERVICE_TOKEN
# должны совпасть с $SERVICE_USER / $SERVICE_TOKEN выше
```

В конце выполните `check_result`.

## 11. Repair existing Role and bind it to an SA from another namespace

Существующий Role `pod-role` в `rbac-a` разрешает `get`, `list`, `delete` - убираем
лишний `delete`, добавляем нужный `watch`:

```bash
k patch role pod-role -n rbac-a --type=json -p \
  '[{"op":"replace","path":"/rules/0/verbs","value":["get","list","watch"]}]'
k auth can-i delete pods -n rbac-a --as=system:serviceaccount:rbac-a:dev # no
k auth can-i watch pods -n rbac-a --as=system:serviceaccount:rbac-a:dev  # yes
```

`shared-config` уже существует в `rbac-b`. Создаём НОВЫЙ Role+RoleBinding именно в
`rbac-b` - RoleBinding поддерживает subject из другого namespace, но сами права
действуют только в namespace самого RoleBinding:

```bash
k create role configmap-reader -n rbac-b --resource=configmaps --verb=get,list
k create rolebinding configmap-reader-binding -n rbac-b \
  --role=configmap-reader --serviceaccount=rbac-a:dev

k auth can-i get configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev    # yes
k auth can-i delete configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev # no
k auth can-i get secrets -n rbac-b --as=system:serviceaccount:rbac-a:dev       # no
```

Создаём Pod в `rbac-a`, который реально использует `dev`:

```bash
k run rbac-a-workload -n rbac-a --image=busybox:1.36 \
  --overrides='{"spec":{"serviceAccountName":"dev"}}' -- sh -c "sleep 3600"
```

В конце выполните `check_result`.

## 12. Client certificate user via CSR + namespaced RBAC

Генерируем private key и CSR с `CN=john` - RBAC для сертификат-based пользователя
связывается через `kind: User`, а не `ServiceAccount`, и у `User` нет собственного API
объекта: его identity полностью определяется тем, что CN в клиентском сертификате
совпадает с `name` в binding.

```bash
mkdir -p /var/work/tests/artifacts/12
openssl genrsa -out /var/work/tests/artifacts/12/john.key 2048
openssl req -new -key /var/work/tests/artifacts/12/john.key \
  -out /tmp/john.csr -subj "/CN=john"
```

Отправляем как Kubernetes `CertificateSigningRequest` с тем же signer, что уже
используется в задании 7 для одобрения CSR (`kubernetes.io/kube-apiserver-client` -
корректный signer именно для client-auth сертификата, который будет аутентифицировать
запросы к API server):

```bash
cat > john-csr.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: john-csr
spec:
  request: $(base64 -w0 /tmp/john.csr)
  signerName: kubernetes.io/kube-apiserver-client
  usages: ["client auth"]
EOF
k apply -f john-csr.yaml
k certificate approve john-csr
k get csr john-csr -o jsonpath='{.status.certificate}' \
  | base64 -d > /var/work/tests/artifacts/12/john.crt
```

Проверяем, что сертификат реально подписан этим кластером, не только что поле
`status.certificate` непустое:

```bash
openssl verify -CAfile <(ssh control-plane sudo cat /etc/kubernetes/pki/ca.crt) \
  /var/work/tests/artifacts/12/john.crt
# /var/work/tests/artifacts/12/john.crt: OK
openssl x509 -in /var/work/tests/artifacts/12/john.crt -noout -subject
# subject=CN = john
```

RBAC: Role в `development`, RoleBinding на `kind: User, name: john` - `--user=john` в
`kubectl create rolebinding` сам проставляет `kind: User`, писать YAML не нужно:

```bash
k create role john-pod-access -n development --resource=pods --verb=create,list,get
k create rolebinding john-pod-access-binding -n development \
  --role=john-pod-access --user=john

k auth can-i create pods -n development --as=john  # yes
k auth can-i list pods -n development --as=john    # yes
k auth can-i get pods -n development --as=john     # yes
k auth can-i delete pods -n development --as=john  # no
k auth can-i create pods -n security-104 --as=john # no
```

`--as=john` доказывает только RBAC-логику (impersonation, доступную любому admin
независимо от того, выпущен ли реальный сертификат). Отдельно доказываем, что именно
ВЫПУЩЕННЫЙ сертификат реально принимается API server через настоящий TLS client-auth
запрос:

```bash
SERVER=$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}')
ssh control-plane sudo cat /etc/kubernetes/pki/ca.crt > /tmp/cluster-ca.crt
curl -s -o /dev/null -w '%{http_code}\n' --cacert /tmp/cluster-ca.crt \
  --cert /var/work/tests/artifacts/12/john.crt --key /var/work/tests/artifacts/12/john.key \
  "$SERVER/api/v1/namespaces/development/pods"     # 200
curl -s -o /dev/null -w '%{http_code}\n' --cacert /tmp/cluster-ca.crt \
  --cert /var/work/tests/artifacts/12/john.crt --key /var/work/tests/artifacts/12/john.key \
  "$SERVER/api/v1/namespaces/security-104/pods"     # 403
```

То же самое доказательство, но через привычный `kubectl`, а не `curl` - собираем John отдельный
kubeconfig из уже выпущенного сертификата (`set-credentials` с `--client-certificate`/
`--client-key`, а не `--token`, потому что identity здесь именно client-cert, а не
ServiceAccount token):

```bash
k config set-cluster cluster1 --server="$SERVER" \
  --certificate-authority=/tmp/cluster-ca.crt --embed-certs=true \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config set-credentials john \
  --client-certificate=/var/work/tests/artifacts/12/john.crt \
  --client-key=/var/work/tests/artifacts/12/john.key --embed-certs=true \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config set-context john@cluster1 --cluster=cluster1 --user=john \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config use-context john@cluster1 \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n development
# работает - RBAC пропускает

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n security-104
# Error from server (Forbidden) - тот же 403, что и в curl-проверке выше

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig auth whoami
# Username: john - подтверждает, что kubeconfig реально аутентифицируется именно как
# john, а не просто случайно даёт нужные коды ответа
```

В конце выполните `check_result`.
