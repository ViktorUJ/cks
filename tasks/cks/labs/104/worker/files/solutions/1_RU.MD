# Лаба 104 — эталонное решение: RBAC, ServiceAccount token и anonymous API

> Выполняйте команды с рабочей машины, если в шаге не указано иное. Namespace
> `security-104` уже существует.

## 1. Минимальный доступ `auditor` только к Pod

Создадим ServiceAccount, одно точное правило и namespaced binding:

```yaml
# auditor-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: auditor
  namespace: security-104
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-observer
  namespace: security-104
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: auditor-pod-observer
  namespace: security-104
subjects:
- kind: ServiceAccount
  name: auditor
  namespace: security-104
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-observer
```

```bash
kubectl apply -f auditor-rbac.yaml
kubectl auth can-i list pods -n security-104 \
  --as=system:serviceaccount:security-104:auditor
kubectl auth can-i delete secrets -n security-104 \
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

```yaml
# token-client.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-client
  namespace: security-104
---
apiVersion: v1
kind: Pod
metadata:
  name: token-client
  namespace: security-104
spec:
  serviceAccountName: api-client
  automountServiceAccountToken: false
  containers:
  - name: client
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: api-token
      mountPath: /var/run/secrets/tokens
      readOnly: true
  volumes:
  - name: api-token
    projected:
      sources:
      - serviceAccountToken:
          path: api-token
          expirationSeconds: 3600
```

```bash
kubectl apply -f token-client.yaml
kubectl wait -n security-104 --for=condition=Ready pod/token-client --timeout=120s
kubectl exec -n security-104 token-client -- \
  ls -l /var/run/secrets/tokens/api-token

# Это реальный запрос к API TokenReview с токеном из volume; он должен подтвердить
# именно ServiceAccount api-client, а не только наличие поля в YAML.
TOKEN=$(kubectl exec -n security-104 token-client -- cat /var/run/secrets/tokens/api-token)
jq -n --arg token "$TOKEN" \
  '{apiVersion:"authentication.k8s.io/v1", kind:"TokenReview", spec:{token:$token}}' \
  | kubectl create -f - -o json \
  | jq '{authenticated: .status.authenticated, username: .status.user.username}'
# {"authenticated": true, "username": "system:serviceaccount:security-104:api-client"}

# Это отдельная authorization-проверка: аутентифицированный токен не получает
# избыточное RBAC-разрешение.
kubectl auth can-i delete secrets -n security-104 \
  --as=system:serviceaccount:security-104:api-client
# no
```

## 3. Pod без токена API

Отключаем автомонтирование и на ServiceAccount, и на Pod: это защищает от последующих
изменений шаблона или ServiceAccount.

```yaml
# no-token.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: no-token-sa
  namespace: security-104
automountServiceAccountToken: false
---
apiVersion: v1
kind: Pod
metadata:
  name: no-token
  namespace: security-104
spec:
  serviceAccountName: no-token-sa
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f no-token.yaml
kubectl wait -n security-104 --for=condition=Ready pod/no-token --timeout=60s
kubectl get pod no-token -n security-104 -o jsonpath='{.spec.automountServiceAccountToken}'

# Подтверждаем на уровне runtime, а не только на уровне YAML-спецификации: в
# контейнере действительно нет файла токена.
kubectl exec -n security-104 no-token -- \
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
kubectl delete clusterrolebinding legacy-operator-admin
kubectl delete clusterrole legacy-operator-admin
kubectl auth can-i get secrets -n security-104 \
  --as=system:serviceaccount:security-104:legacy-operator # должно быть no
```

## 5. Отключение anonymous-auth

Подключитесь к control-plane. Простое `--anonymous-auth=false` здесь не подходит: kubeadm
`release-1.36` генерирует kube-apiserver static Pod с HTTPS liveness/readiness/startup
probes на `/livez` и `/readyz`, а kubelet HTTP probes не передают client credentials -
при полном отключении anonymous access эти запросы получат `401`, и kubelet начнёт
считать kube-apiserver нездоровым (что в свою очередь ломает и задание 9, зависящее от
стабильно работающего API server). Вместо этого используем `AuthenticationConfiguration`
с `anonymous.conditions`, ограничивающими anonymous access только тремя health-путями:

```bash
sudo tee /etc/kubernetes/authentication-config.yaml >/dev/null <<'EOF'
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
рядом с `--authentication-config` - kube-apiserver откажется стартовать, если заданы оба)
и добавляем `--authentication-config`, а также `hostPath` volume/volumeMount для нового
файла конфигурации, аналогично тому, как задание 9 добавляет volume для audit policy -
kube-apiserver читает `authentication-config.yaml` с файловой системы ноды, поэтому файл
должен быть виден внутри container через volumeMount, а не только лежать на хосте:

```bash
sudo sed -i \
  -e '\#--anonymous-auth=#d' \
  -e '/- kube-apiserver/a\    - --authentication-config=/etc/kubernetes/authentication-config.yaml' \
  /etc/kubernetes/manifests/kube-apiserver.yaml

sudo python3 - <<'EOF'
import yaml
path = "/etc/kubernetes/manifests/kube-apiserver.yaml"
with open(path) as f:
    manifest = yaml.safe_load(f)
container = manifest["spec"]["containers"][0]
container.setdefault("volumeMounts", []).append({
    "name": "authentication-config",
    "mountPath": "/etc/kubernetes/authentication-config.yaml",
    "readOnly": True,
})
manifest["spec"].setdefault("volumes", []).append({
    "name": "authentication-config",
    "hostPath": {"path": "/etc/kubernetes/authentication-config.yaml", "type": "File"},
})
with open(path, "w") as f:
    yaml.safe_dump(manifest, f)
EOF
```

Kubelet автоматически перезапустит API server. На рабочей машине дождитесь готовности
(Pod должен остаться `Running`/`Ready`, а не попасть в цикл перезапуска) и проверьте все
три поведения: `/version` отклоняет анонимные запросы, а `/livez`/`/readyz` - принимают:

```bash
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 2; done
kubectl -n kube-system get pods -l component=kube-apiserver
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/version" # 401 - anonymous access закрыт
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/livez"   # 200 - health probe работает
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/readyz"  # 200 - health probe работает
```

Аутентифицированный запрос к `/readyz` (через уже настроенный kubectl context)
продолжает работать точно так же - `AuthenticationConfiguration.anonymous.conditions`
только РАСШИРЯЕТ доступ для anonymous-запросов на конкретные пути, но не сужает доступ
для уже аутентифицированных клиентов:

```bash
kubectl get --raw=/readyz # ok
```

В конце выполните `check_result`.

## 6. Secret через env раскрывается в `/proc/1/environ`: рефакторинг на volume

`app-vulnerable` получает `db-creds` через `envFrom`, поэтому значение попадает в
environment процесса PID 1 контейнера. Любой, у кого есть право на `kubectl exec` в этот
Pod, может прочитать секрет напрямую из `/proc`, без обращения к Kubernetes API и без RBAC
на `get secrets`:

```bash
mkdir -p /var/work/tests/artifacts/6
EXPECTED_PASSWORD=$(kubectl get secret db-creds -n security-104 \
  -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)
kubectl exec -n security-104 app-vulnerable -- cat /proc/1/environ \
  | tr '\0' '\n' | tee /var/work/tests/artifacts/6/env-leak-before.txt
grep -F "DB_PASSWORD=$EXPECTED_PASSWORD" /var/work/tests/artifacts/6/env-leak-before.txt
```

Сохраняем именно строку с реальным значением секрета, а не просто слово `DB_PASSWORD` -
checker сверяет artifact с фактическим значением из Secret `db-creds`, поэтому файл,
содержащий только имя переменной без значения, не будет принят как доказательство утечки.

Пересоздаём Pod с тем же именем: убираем `envFrom`, монтируем тот же Secret как volume
`db-creds-vol` в `/etc/secrets`, read-only, с `defaultMode: 0400` (`256` в decimal, как его
показывает `kubectl get pod -o json`). `0400` — это read-only только для владельца файла
внутри контейнера; сам процесс приложения всё равно должен запускаться под этим UID, иначе
он не сможет прочитать файл.

```yaml
# app-vulnerable-fixed.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-vulnerable
  namespace: security-104
spec:
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: db-creds-vol
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: db-creds-vol
    secret:
      secretName: db-creds
      defaultMode: 0400
```

Поле - неизменяемое; Pod нужно удалить и создать заново с тем же именем:

```bash
kubectl delete pod app-vulnerable -n security-104
kubectl apply -f app-vulnerable-fixed.yaml
kubectl wait -n security-104 --for=condition=Ready pod/app-vulnerable --timeout=120s
```

Подтверждаем три итоговых свойства, а не только «секрета нет в environment»: файловые
права точно `400` (а не просто где-то содержат подстроку `400`), и, что важнее, приложение
всё ещё РЕАЛЬНО может прочитать значение секрета - иначе hardening мог бы незаметно
сломать саму функциональность приложения:

```bash
kubectl exec -n security-104 app-vulnerable -- cat /proc/1/environ | tr '\0' '\n' | grep DB_PASSWORD
# ничего не найдено - это ожидаемо

kubectl exec -n security-104 app-vulnerable -- stat -c '%a' /etc/secrets/DB_PASSWORD \
  | tee /var/work/tests/artifacts/6/secret-file-mode.txt
# 400 - именно это значение, а не произвольный текст, где-то содержащий "400"

# Positive control: процесс приложения должен реально мочь прочитать значение секрета.
kubectl exec -n security-104 app-vulnerable -- cat /etc/secrets/DB_PASSWORD
# должно совпадать с $EXPECTED_PASSWORD выше
```

`defaultMode: 0400` защищает от чтения другими UID на этом же Pod (например, соседним
sidecar-container без нужного UID), но не заменяет encryption at rest у etcd и не мешает
процессу, запущенному под ожидаемым UID, прочитать сам файл — mount разрешает именно это.
Убедитесь также, что `db-creds` не смонтирован каким-то ВТОРЫМ способом одновременно
(например, ещё и через `projected` volume) - должен остаться ровно один volume,
монтирующий этот Secret.

В конце выполните `check_result`.

## 7. Аудит и отзыв скрытых RBAC-путей privilege escalation

`build-agent-hidden-privesc` не содержит wildcard `*`, но `impersonate`/`bind`/`escalate`/
CSR-approval — отдельная категория опасных verbs: они не расширяют список видимых
ресурсов, а дают возможность **действовать от чужого имени** или **выдать себе
дополнительные права**. В этой версии fixture ClusterRole также содержит базовые
`create`/`update` на `clusterroles`/`clusterrolebindings` - без них `bind`/`escalate`
были бы неполными escalation primitives (RBAC требует ЛИБО уже иметь права из роли, ЛИБО
явно иметь `escalate`/`bind` НА ФОНЕ попытки реально создать/обновить Role/Binding).
Находим все ClusterRoleBinding, чьи ClusterRole разрешают любой из опасных verbs:

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl get clusterrole -o json \
  | jq '[.items[] | select([.rules[]?.verbs[]?] | any(. == "impersonate" or . == "bind" or . == "escalate")) | .metadata.name]' \
  > /tmp/dangerous-clusterroles.json
cat /tmp/dangerous-clusterroles.json

kubectl get clusterrolebinding -o json \
  | jq -r --slurpfile roles /tmp/dangerous-clusterroles.json \
    '.items[] | select(.roleRef.kind == "ClusterRole" and (.roleRef.name | IN($roles[0][]))) | .metadata.name' \
  | tee /var/work/tests/artifacts/7/dangerous-bindings-before.txt
```

Отдельно фиксируем CSR-approval - это не в `verbs` того же ClusterRole по имени ресурса
`clusterroles`, а отдельное правило на `certificatesigningrequests/approval` и `signers`.
**Важно**: находим сначала опасные ClusterRole, а затем - ClusterRoleBinding, которые НА
НИХ ССЫЛАЮТСЯ, а не сами имена ClusterRole (имя ClusterRole и имя ClusterRoleBinding могут
не совпадать - в этой лабе они случайно совпадают, но полагаться на это нельзя):

```bash
kubectl get clusterrole -o json \
  | jq '[.items[] | select([.rules[]? | select(.resources[]? == "certificatesigningrequests/approval")] | length > 0) | .metadata.name]' \
  > /tmp/dangerous-csr-clusterroles.json
cat /tmp/dangerous-csr-clusterroles.json

kubectl get clusterrolebinding -o json \
  | jq -r --slurpfile roles /tmp/dangerous-csr-clusterroles.json \
    '.items[] | select(.roleRef.kind == "ClusterRole" and (.roleRef.name | IN($roles[0][]))) | .metadata.name' \
  >> /var/work/tests/artifacts/7/dangerous-bindings-before.txt
```

`build-agent-hidden-privesc` должен быть в итоговом файле (как имя ClusterRoleBinding,
не ClusterRole). Удаляем именно этот ClusterRoleBinding (и ClusterRole, чтобы шаблон не
остался для повторного использования), не трогая `system:*` bindings, которые дают
core-компонентам Kubernetes необходимый `impersonate`/CSR доступ:

```bash
kubectl delete clusterrolebinding build-agent-hidden-privesc
kubectl delete clusterrole build-agent-hidden-privesc
```

Подтверждаем отзыв ВСЕХ заявленных опасных прав, а не только части из них:

```bash
kubectl auth can-i impersonate users --as=system:serviceaccount:security-104:build-agent
kubectl auth can-i bind clusterroles --as=system:serviceaccount:security-104:build-agent
kubectl auth can-i escalate clusterroles --as=system:serviceaccount:security-104:build-agent
kubectl auth can-i update certificatesigningrequests/approval --as=system:serviceaccount:security-104:build-agent
kubectl auth can-i approve signers/kubernetes.io/kube-apiserver-client --as=system:serviceaccount:security-104:build-agent
# no / no / no / no / no
```

В конце выполните `check_result`.

## 8. Namespace-level baseline: `default` SA без automount

Задание 3 отключало automount точечно, у конкретного Pod и его собственного SA. Здесь
нужен системный baseline: правим `default` SA namespace **до** создания в нём каких-либо
Pod, чтобы ни один новый workload не получил токен по умолчанию, даже если разработчик
забудет явное поле в манифесте.

```bash
kubectl create namespace security-104-baseline

# ServiceAccount 'default' создаётся отдельным контроллером асинхронно после появления
# Namespace - patch сразу после create может ударить в несуществующий объект. Дожидаемся
# его появления, прежде чем патчить.
until kubectl -n security-104-baseline get serviceaccount default >/dev/null 2>&1; do
  sleep 1
done

kubectl -n security-104-baseline patch serviceaccount default \
  -p '{"automountServiceAccountToken":false}'
kubectl -n security-104-baseline get serviceaccount default \
  -o jsonpath='{.automountServiceAccountToken}{"\n"}'
# false
```

Создаём Pod, который **не** задаёт ни `serviceAccountName`, ни `automountServiceAccountToken` -
это самый частый в реальности случай, когда разработчик просто не думает про SA. Поле
`automountServiceAccountToken` должно ОТСУТСТВОВАТЬ в спеке Pod - явное указание `false`
доказывало бы только точечную настройку самого Pod (как в задании 3), а не то, что
namespace-level baseline реально работает:

```yaml
# implicit-default-sa.yaml
apiVersion: v1
kind: Pod
metadata:
  name: implicit-default-sa
  namespace: security-104-baseline
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f implicit-default-sa.yaml
kubectl wait -n security-104-baseline --for=condition=Ready pod/implicit-default-sa --timeout=60s
kubectl get pod implicit-default-sa -n security-104-baseline -o jsonpath='{.spec.serviceAccountName}{"\n"}'
# default

kubectl get pod implicit-default-sa -n security-104-baseline \
  -o jsonpath='{.spec.automountServiceAccountToken}{"\n"}'
# пустой вывод - поле отсутствует в спеке, а не установлено в false

kubectl exec -n security-104-baseline implicit-default-sa -- \
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
Подключаемся к control-plane по SSH и готовим минимальный audit backend:

```bash
ssh control-plane
sudo mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit
```

```yaml
# /etc/kubernetes/audit/policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: RequestResponse
  resources:
  - group: "rbac.authorization.k8s.io"
    resources: ["clusterroles", "clusterrolebindings"]
- level: Metadata
```

Правило RBAC стоит первым - более специфичное правило должно предшествовать общему
catch-all, иначе `Metadata` перехватит событие раньше. Правим static manifest API server:

```bash
sudo sed -i \
  -e '/- kube-apiserver/a\    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml\n    - --audit-log-path=/var/log/kubernetes/audit/audit.log' \
  /etc/kubernetes/manifests/kube-apiserver.yaml
```

Добавляем hostPath volume/volumeMount для каталогов policy и логов (редактируем секции
`volumes`/`volumeMounts` того же манифеста, тем же способом, каким в задании 5 уже
добавлялся `hostPath` volume/volumeMount для `authentication-config.yaml` - здесь
дополнительно нужен volume, потому что kube-apiserver читает policy-файл и пишет
log-файл на файловой системе ноды). После сохранения kubelet
перезапустит static Pod автоматически.

```bash
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 2; done
kubectl -n kube-system get pods -l component=kube-apiserver
```

Возвращаемся на рабочую машину (от имени администратора `cluster1-admin`) и создаём
опасную привязку - это **не** попытка эскалации со стороны `build-agent` (у него уже нет
реальных путей к этому после задания 7), а моделируемое администраторское действие,
которое audit log должен поймать как воспроизводимое evidence о том, кто именно это
сделал и кому именно были выданы права:

```bash
kubectl create clusterrolebinding incident-simulated-escalation \
  --clusterrole=cluster-admin \
  --serviceaccount=security-104:build-agent
```

Ищем именно это событие в audit log (на control-plane) и сохраняем его целиком:

```bash
mkdir -p /var/work/tests/artifacts/9
ssh control-plane "sudo cat /var/log/kubernetes/audit/audit.log" \
  | jq -c 'select(
      .verb == "create" and
      .stage == "ResponseComplete" and
      .objectRef.resource == "clusterrolebindings" and
      .objectRef.name == "incident-simulated-escalation" and
      .responseStatus.code == 201
    )' \
  | tail -n1 | tee /var/work/tests/artifacts/9/audit-escalation-event.json
jq '{initiator: .user.username, roleRef: .requestObject.roleRef, subjects: .requestObject.subjects, auditID: .auditID}' \
  /var/work/tests/artifacts/9/audit-escalation-event.json
```

Фильтруем именно `stage == "ResponseComplete"` с `responseStatus.code == 201` - при
`RequestResponse` level policy один и тот же request может дать несколько записей в
log (`ResponseStarted`/`ResponseComplete`), и нам нужна именно финальная запись с успешным
кодом ответа и полным `requestObject`, а не промежуточная. Сохраняем событие **целиком**,
как оно реально лежит в audit log (включая `auditID`) - не переписываем и не собираем
JSON вручную, иначе artifact не будет совпадать с реальной записью в логе при верификации.

Containment: удаляем привязку и подтверждаем, что доступ реально отозван, а не просто
объект недоступен для чтения:

```bash
kubectl delete clusterrolebinding incident-simulated-escalation
kubectl auth can-i '*' '*' --as=system:serviceaccount:security-104:build-agent \
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
