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
kubectl get pod no-token -n security-104 -o jsonpath='{.spec.automountServiceAccountToken}'
```

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

Подключитесь к control-plane и измените аргумент static Pod. Не редактируйте объект
Pod через API: kubelet перезапишет такое изменение из манифеста.

```bash
sudo sed -i 's/--anonymous-auth=true/--anonymous-auth=false/' \
  /etc/kubernetes/manifests/kube-apiserver.yaml
```

Kubelet автоматически перезапустит API server. На рабочей машине дождитесь готовности
и проверьте именно неаутентифицированный запрос:

```bash
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 2; done
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/version" # 401
kubectl -n kube-system get pods -l component=kube-apiserver
```

Этот приём безопасен именно в изолированной однонодовой лабе. В production-кластере
блокирующее `--anonymous-auth=false` нельзя применять механически: health probes и
стандартный token-based `kubeadm join` discovery могут зависеть от anonymous-доступа к
конкретным endpoints. Для этого случая используйте `AuthenticationConfiguration` с
`anonymous.conditions`, ограничивающим anonymous-доступ только нужными путями
(`/livez`, `/readyz` и т. п.) - подробности в главах 07 и 12.

В конце выполните `check_result`.

## 6. Secret через env раскрывается в `/proc/1/environ`: рефакторинг на volume

`app-vulnerable` получает `db-creds` через `envFrom`, поэтому значение попадает в
environment процесса PID 1 контейнера. Любой, у кого есть право на `kubectl exec` в этот
Pod, может прочитать секрет напрямую из `/proc`, без обращения к Kubernetes API и без RBAC
на `get secrets`:

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl exec -n security-104 app-vulnerable -- cat /proc/1/environ \
  | tr '\0' '\n' | tee /var/work/tests/artifacts/6/env-leak-before.txt
grep DB_PASSWORD /var/work/tests/artifacts/6/env-leak-before.txt
```

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

Подтверждаем оба итоговых свойства: секрета нет в environment, а файловые права на
смонтированный секрет ограничены владельцем:

```bash
kubectl exec -n security-104 app-vulnerable -- cat /proc/1/environ | tr '\0' '\n' | grep DB_PASSWORD
# ничего не найдено - это ожидаемо

kubectl exec -n security-104 app-vulnerable -- stat -c '%a' /etc/secrets/DB_PASSWORD \
  | tee /var/work/tests/artifacts/6/secret-file-mode.txt
# 400
```

`defaultMode: 0400` защищает от чтения другими UID на этом же Pod (например, соседним
sidecar-container без нужного UID), но не заменяет encryption at rest у etcd и не мешает
процессу, запущенному под ожидаемым UID, прочитать сам файл — mount разрешает именно это.

В конце выполните `check_result`.

## 7. Аудит и отзыв скрытых RBAC-путей privilege escalation

`build-agent-hidden-privesc` не содержит wildcard `*` и на вид ограничен тремя ресурсами,
но `impersonate`/`bind`/`escalate`/CSR-approval — отдельная категория опасных verbs: они
не расширяют список видимых ресурсов, а дают возможность **действовать от чужого имени**
или **выдать себе дополнительные права**. Находим все ClusterRoleBinding, чьи ClusterRole
разрешают любой из этих verbs:

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
`clusterroles`, а отдельное правило на `certificatesigningrequests/approval` и `signers`:

```bash
kubectl get clusterrole -o json \
  | jq -r '.items[] | select([.rules[]? | select(.resources[]? == "certificatesigningrequests/approval")] | length > 0) | .metadata.name' \
  >> /var/work/tests/artifacts/7/dangerous-bindings-before.txt
```

`build-agent-hidden-privesc` должен быть в обоих списках. Удаляем именно этот
ClusterRoleBinding (и ClusterRole, чтобы шаблон не остался для повторного использования),
не трогая `system:*` bindings, которые дают core-компонентам Kubernetes необходимый
`impersonate`/CSR доступ:

```bash
kubectl delete clusterrolebinding build-agent-hidden-privesc
kubectl delete clusterrole build-agent-hidden-privesc
```

Подтверждаем отзыв всех трёх путей:

```bash
kubectl auth can-i impersonate users --as=system:serviceaccount:security-104:build-agent
kubectl auth can-i update certificatesigningrequests/approval --as=system:serviceaccount:security-104:build-agent
kubectl auth can-i escalate clusterroles --as=system:serviceaccount:security-104:build-agent
# no / no / no
```

В конце выполните `check_result`.

## 8. Namespace-level baseline: `default` SA без automount

Задание 3 отключало automount точечно, у конкретного Pod и его собственного SA. Здесь
нужен системный baseline: правим `default` SA namespace **до** создания в нём каких-либо
Pod, чтобы ни один новый workload не получил токен по умолчанию, даже если разработчик
забудет явное поле в манифесте.

```bash
kubectl create namespace security-104-baseline
kubectl -n security-104-baseline patch serviceaccount default \
  -p '{"automountServiceAccountToken":false}'
kubectl -n security-104-baseline get serviceaccount default \
  -o jsonpath='{.automountServiceAccountToken}{"\n"}'
# false
```

Создаём Pod, который **не** задаёт ни `serviceAccountName`, ни `automountServiceAccountToken` -
это самый частый в реальности случай, когда разработчик просто не думает про SA:

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

kubectl exec -n security-104-baseline implicit-default-sa -- \
  cat /var/run/secrets/kubernetes.io/serviceaccount/token
# cat: can't open '/var/run/secrets/kubernetes.io/serviceaccount/token': No such file or directory
```

Значение SA действует, только если Pod не переопределяет его сам. Если тому же namespace
понадобится Pod с API-доступом, добавьте `automountServiceAccountToken: true` явно в
конкретном манифесте после проверки, что доступ действительно нужен - не меняйте baseline
`default` SA обратно на `true` для всего namespace.

В конце выполните `check_result`.

## 9. Интеграционное задание: RBAC-эскалация → audit log → containment

Задания 1-8 закрывали конкретные пути (wildcard, impersonate/bind/escalate, automount).
Здесь нужен способ увидеть **попытку** повторной эскалации, а не только текущий снимок
RBAC. Подключаемся к control-plane по SSH и готовим минимальный audit backend:

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
`volumes`/`volumeMounts` того же манифеста, аналогично тому, как в задании 5 менялся
только аргумент - здесь дополнительно нужен volume, потому что kube-apiserver читает
policy-файл и пишет log-файл на файловой системе ноды). После сохранения kubelet
перезапустит static Pod автоматически.

```bash
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 2; done
kubectl -n kube-system get pods -l component=kube-apiserver
```

Возвращаемся на рабочую машину и симулируем эскалацию, которую audit log должен поймать
как воспроизводимое evidence:

```bash
kubectl create clusterrolebinding incident-simulated-escalation \
  --clusterrole=cluster-admin \
  --serviceaccount=security-104:build-agent
```

Ищем именно это событие в audit log (на control-plane) и сохраняем его целиком:

```bash
mkdir -p /var/work/tests/artifacts/9
ssh control-plane "sudo cat /var/log/kubernetes/audit/audit.log" \
  | jq -c 'select(.verb == "create" and .objectRef.resource == "clusterrolebindings" and .objectRef.name == "incident-simulated-escalation")' \
  | tail -n1 | tee /var/work/tests/artifacts/9/audit-escalation-event.json
jq '.requestObject.subjects' /var/work/tests/artifacts/9/audit-escalation-event.json
```

Containment: удаляем привязку и подтверждаем, что доступ реально отозван, а не просто
объект недоступен для чтения:

```bash
kubectl delete clusterrolebinding incident-simulated-escalation
kubectl auth can-i '*' '*' --as=system:serviceaccount:security-104:build-agent \
  | tee /var/work/tests/artifacts/9/containment-result.txt
# no
```

Разница с заданием 7: там мы находили и отзывали **уже существующий** скрытый путь через
статический анализ RBAC-объектов. Здесь source of truth - **событие во времени** (audit
log), которое доказывает, что попытка эскалации произошла именно в этот момент, кем и с
каким итоговым объектом - это то, что нужно для реального инцидента, когда объект могли
уже удалить сами атакующие после использования.

В конце выполните `check_result`.
