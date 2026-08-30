# Лаба 107 — эталонное решение: Pod Security Admission и immutable root filesystem

> Выполняйте команды на рабочей машине. Контекст `cluster1-admin@cluster1` уже
> настроен. Namespace `psa-restricted-107` и `psa-observe-107` созданы стартовым
> скриптом, но намеренно не имеют PSA labels.

## 1. Enforce restricted и проверка отказа

PSA применяет Pod Security Standards по labels namespace. Зафиксируем версию
стандарта, чтобы поведение не менялось с будущим обновлением Kubernetes:

```bash
kubectl label namespace psa-restricted-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36
```

Проверим admission без сохранения опасного объекта. `hostNetwork` запрещён уровнем
`restricted`, поэтому команда обязана завершиться ошибкой `violates PodSecurity`:

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-by-restricted
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
YAML
```

## 2 и 5. Hardened Pod и writable emptyDir

Создайте Pod сразу в окончательной безопасной форме. Уровень `restricted` требует
non-root, seccomp, запрета escalation и сброса capabilities. Read-only root filesystem
уменьшает последствия записи в контейнер; приложению оставлен только `/tmp` в
`emptyDir`.

```yaml
# restricted-app.yaml
apiVersion: v1
kind: Pod
metadata:
  name: restricted-app
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
    volumeMounts:
    - name: writable-tmp
      mountPath: /tmp
  volumes:
  - name: writable-tmp
    emptyDir: {}
```

```bash
kubectl apply -f restricted-app.yaml
kubectl get pod restricted-app -n psa-restricted-107
```

Если `restricted-app` уже создан без read-only filesystem, поле Pod изменять нельзя;
удалите и создайте его повторно:

```bash
kubectl delete pod restricted-app -n psa-restricted-107
kubectl apply -f restricted-app.yaml
```

## 3. Audit и warn для baseline

Эти режимы не запрещают запрос. `warn` возвращает предупреждение клиенту, а `audit`
добавляет annotation в audit event API server. Для поэтапного внедрения не задавайте
`enforce` в namespace наблюдения:

```bash
kubectl label namespace psa-observe-107 \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/audit-version=v1.36 \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/warn-version=v1.36
```

## 4. Убедиться, что warn/audit не блокируют Pod

Этот Pod нарушает baseline из-за `hostNetwork`, но принимается, потому что в namespace
нет `enforce`. `kubectl apply` выведет предупреждение PSA; не игнорируйте его при
миграции production workload.

```yaml
# baseline-audit-sample.yaml
apiVersion: v1
kind: Pod
metadata:
  name: baseline-audit-sample
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f baseline-audit-sample.yaml
kubectl get pod baseline-audit-sample -n psa-observe-107
kubectl get namespace psa-restricted-107 --show-labels
kubectl get namespace psa-observe-107 --show-labels
check_result
```
