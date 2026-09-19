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
    emptyDir:
      medium: Memory
```

```bash
kubectl apply -f restricted-app.yaml
kubectl get pod restricted-app -n psa-restricted-107
```

Докажите оба исхода живым вызовом, а не только чтением YAML: контейнер работает под
`runAsUser: 1000` с read-only root, поэтому запись за пределы `/tmp` обязана завершиться
ошибкой файловой системы, а запись в примонтированный `emptyDir` - пройти:

```bash
kubectl exec -n psa-restricted-107 restricted-app -- sh -c 'touch /root-write-test.txt'
# touch: /root-write-test.txt: Read-only file system

kubectl exec -n psa-restricted-107 restricted-app -- sh -c 'echo probe > /tmp/test.txt && cat /tmp/test.txt'
# probe
```

Если `restricted-app` уже создан без read-only filesystem, поле Pod изменять нельзя;
удалите и создайте его повторно:

```bash
kubectl delete pod restricted-app -n psa-restricted-107
kubectl apply -f restricted-app.yaml
```

## 3. Audit и warn для baseline

Эти режимы не запрещают запрос. `warn` возвращает предупреждение клиенту, а `audit`
добавляет в audit event API server annotation
`pod-security.kubernetes.io/audit-violations`. Для поэтапного внедрения не задавайте
`enforce` в namespace наблюдения:

```bash
kubectl label namespace psa-observe-107 \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/audit-version=v1.36 \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/warn-version=v1.36
```

> **Версионная оговорка.** `v1.36` закреплена для Kubernetes 1.36.0 в этой учебной
> инфраструктуре. На 2026-09-06 официальный CKS ориентирован на `v1.35`; это
> forward-looking пример, а при подготовке к экзамену используйте `*-version=v1.35`.

> **Граница доказательства audit.** Лаба не настраивает audit-log sink, поэтому
> `pod-security.kubernetes.io/audit-violations` нельзя извлечь командой `kubectl`.
> Реально проверяемым результатом ниже служит PSA Warning и успешный admission; audit
> annotation объяснена, но не является проверяемым артефактом этой инфраструктуры.

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
```

## 6. Native ValidatingAdmissionPolicy без Kyverno/Gatekeeper

PSA `restricted` уже требует `allowPrivilegeEscalation: false` и `capabilities.drop`
содержащий `ALL` - задание 2 показывает именно это, и это встроенная часть Pod Security
Standard, а не пробел. Но PSS `restricted` **не проверяет** `automountServiceAccountToken`:
Pod может тихо получить смонтированный ServiceAccount token и полностью пройти PSA. Для
этого отдельного, реально не покрытого control уместен именно custom `ValidatingAdmissionPolicy`.

```yaml
# require-no-automount-token.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-no-automount-token
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  validations:
  - expression: >-
      has(object.spec.automountServiceAccountToken) &&
      object.spec.automountServiceAccountToken == false
    message: "spec.automountServiceAccountToken must be explicitly set to false"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-no-automount-token-binding
spec:
  policyName: require-no-automount-token
  validationActions: [Deny]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: psa-restricted-107
```

```bash
kubectl apply -f require-no-automount-token.yaml
kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding
```

Докажите оба исхода через server-side dry-run, не сохраняя постоянный Pod. Первый Pod
полностью соответствует PSA `restricted` (non-root, seccomp, `allowPrivilegeEscalation:
false`, `capabilities.drop: ["ALL"]`) - PSA сам его принял бы, поэтому отказ должен
прийти именно от новой policy, а не от `violates PodSecurity`:

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: vap-unsafe-check
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
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
YAML
# Error from server: ... require-no-automount-token: spec.automountServiceAccountToken must be explicitly set to false
```

Тот же Pod с добавленным `automountServiceAccountToken: false` должен пройти:

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: vap-safe-check
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
YAML
```

`Binding.matchResources.namespaceSelector` ограничивает policy только `psa-restricted-107`:
Pod в других namespace (например `psa-observe-107`) не проверяется этим правилом и не
получает лишний Deny.

```bash
check_result
```
