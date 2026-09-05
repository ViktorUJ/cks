# Лаба 108 — эталонное решение: Kyverno admission policies

> Все команды выполняются на рабочей машине. Контекст уже настроен; namespace
> `policy-108` создан стартовым скриптом. Сначала установите Kyverno и дождитесь
> webhook: последующие CEL-based policies иначе не будут проверять admission-запросы.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
```

## 1. Установить Kyverno

На worker подготовлен закреплённый installer: он устанавливает Helm chart Kyverno
`3.9.0` (Kyverno `1.19`) в namespace `kyverno`. Его можно просмотреть перед запуском.

```bash
cat /usr/local/bin/install-kyverno
install-kyverno
kubectl get pods -n kyverno
kubectl get crd validatingpolicies.policies.kyverno.io
kubectl get crd mutatingpolicies.policies.kyverno.io
```

Дождитесь, пока хотя бы один Deployment в `kyverno` имеет `AVAILABLE > 0`.

> **Migration note.** Старые примеры `kyverno.io/v1` `Policy`/`ClusterPolicy` остаются
> полезны только при сопровождении существующих кластеров. В Kyverno `1.19` они deprecated,
> а в `1.20` запланировано удаление. Новые policy в этой лабе используют
> `policies.kyverno.io/v1`.

## 2. Запретить тег `latest`

Создайте `ValidatingPolicy` в режиме `Deny`. Правило проверяет все три списка контейнеров -
`containers`, `initContainers` и `ephemeralContainers`: иначе запрещённый образ легко
протащить через init- или ephemeral-контейнер, а сам Pod всё равно пройдёт admission.

```yaml
# deny-latest-tag.yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: deny-latest-tag
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE, UPDATE]
      resources: [pods, pods/ephemeralcontainers]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  variables:
  - name: images
    expression: >-
      object.spec.containers.map(c, c.image)
      + object.spec.?initContainers.orValue([]).map(c, c.image)
      + object.spec.?ephemeralContainers.orValue([]).map(c, c.image)
  validations:
  - message: Images tagged latest are not allowed.
    expression: variables.images.all(image, !image.endsWith(':latest'))
```

```bash
kubectl apply --context "$CTX" -f deny-latest-tag.yaml
```

## 3. Требовать `runAsNonRoot`

Политика требует значение именно `true` в Pod-level `securityContext`; неявное
значение и `false` не проходят.

```yaml
# require-run-as-non-root.yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-run-as-non-root
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE, UPDATE]
      resources: [pods, pods/ephemeralcontainers]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  validations:
  - message: Pod securityContext.runAsNonRoot must be true.
    expression: >-
      has(object.spec.securityContext) &&
      object.spec.securityContext.?runAsNonRoot.orValue(false)
```

```bash
kubectl apply --context "$CTX" -f require-run-as-non-root.yaml
```

## 4. Разрешить только утверждённые registry

Разрешены `registry.k8s.io` и выделенный организационный путь `ghcr.io/cks-lab`. CEL
объединяет все три container lists и применяет один allowlist к каждому image.

```yaml
# allow-approved-registries.yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: allow-approved-registries
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE, UPDATE]
      resources: [pods, pods/ephemeralcontainers]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  variables:
  - name: images
    expression: >-
      object.spec.containers.map(c, c.image)
      + object.spec.?initContainers.orValue([]).map(c, c.image)
      + object.spec.?ephemeralContainers.orValue([]).map(c, c.image)
  validations:
  - message: Images must come from registry.k8s.io or ghcr.io/cks-lab.
    expression: >-
      variables.images.all(image,
        image.startsWith('registry.k8s.io/') ||
        image.startsWith('ghcr.io/cks-lab/'))
```

```bash
kubectl apply --context "$CTX" -f allow-approved-registries.yaml
```

Проверка без создания Pod и без image pull. Первый Pod нарушает правило основным
контейнером, второй - только `initContainers`; отклониться должны оба:

```bash
kubectl apply --dry-run=server --context "$CTX" -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF

kubectl apply --dry-run=server --context "$CTX" -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-init-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  initContainers:
  - name: init
    image: docker.io/library/busybox:1.36
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
```

Обе команды должны завершиться ошибкой admission policy. Для явной попытки обхода через
`ephemeralContainers` создайте разрешённый Pod, затем выполните `kubectl debug` сначала с
`docker.io/library/busybox:1.36` (ожидается denial), затем с
`registry.k8s.io/e2e-test-images/busybox:1.36-1` (ожидается успех). Именно
`pods/ephemeralcontainers` в `matchConstraints` защищает subresource update.

## 5. Опционально: mutation label

Эта `MutatingPolicy` не отклоняет Pod, а добавляет label через CEL
`ApplyConfiguration`.

```yaml
# add-kyverno-managed-label.yaml
apiVersion: policies.kyverno.io/v1
kind: MutatingPolicy
metadata:
  name: add-kyverno-managed-label
spec:
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE]
      resources: [pods]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  mutations:
  - patchType: ApplyConfiguration
    applyConfiguration:
      expression: >-
        Object{
          metadata: Object.metadata{
            labels: {"security.cks.io/managed-by": "kyverno"}
          }
        }
```

```bash
kubectl apply --context "$CTX" -f add-kyverno-managed-label.yaml
kubectl apply --dry-run=server --context "$CTX" -o json -f - <<'EOF' \
  | jq -r '.metadata.labels["security.cks.io/managed-by"]'
apiVersion: v1
kind: Pod
metadata:
  name: mutation-check
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
# ожидается: kyverno
```

Выполните `check_result`. Этап 5 показан в проверке, но он опционален: отсутствие
mutation policy не должно отменять зачёт первых четырёх этапов.
