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

TokenRequest volume выдаёт ограниченный по audience и времени токен. Обычный токен
автомонтирования отключён.

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
          audience: kubernetes.default.svc
          expirationSeconds: 3600
```

```bash
kubectl apply -f token-client.yaml
kubectl exec -n security-104 token-client -- \
  ls -l /var/run/secrets/tokens/api-token
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

В конце выполните `check_result`.
