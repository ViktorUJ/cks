# Лаба 108 — эталонное решение: Kyverno admission policies

> Все команды выполняются на рабочей машине. Контекст уже настроен; namespace
> `policy-108` создан стартовым скриптом. Сначала установите Kyverno и дождитесь
> webhook: последующие `ClusterPolicy` иначе не будут проверять admission-запросы.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
```

## 1. Установить Kyverno

На worker подготовлен закреплённый installer: он устанавливает Helm chart Kyverno
`3.4.2` в namespace `kyverno`. Его можно просмотреть перед запуском.

```bash
cat /usr/local/bin/install-kyverno
install-kyverno
kubectl get pods -n kyverno
kubectl get crd clusterpolicies.kyverno.io
```

Дождитесь, пока хотя бы один Deployment в `kyverno` имеет `AVAILABLE > 0`.

## 2. Запретить тег `latest`

Создайте ClusterPolicy в режиме `Enforce`. Правило применяется к каждому container;
initContainers и ephemeralContainers в этой задаче не требуются.

```yaml
# deny-latest-tag.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: deny-latest-tag
spec:
  validationFailureAction: Enforce
  background: false
  rules:
  - name: reject-latest-image-tag
    match:
      any:
      - resources:
          kinds: [Pod]
          namespaces: [policy-108]
    validate:
      message: Images tagged latest are not allowed.
      foreach:
      - list: request.object.spec.containers[]
        deny:
          conditions:
            any:
            - key: "{{ element.image }}"
              operator: EndsWith
              value: ":latest"
```

```bash
kubectl apply --context "$CTX" -f deny-latest-tag.yaml
```

## 3. Требовать `runAsNonRoot`

Политика требует значение именно `true` в Pod-level `securityContext`; неявное
значение и `false` не проходят.

```yaml
# require-run-as-non-root.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-run-as-non-root
spec:
  validationFailureAction: Enforce
  background: false
  rules:
  - name: pod-must-run-as-non-root
    match:
      any:
      - resources:
          kinds: [Pod]
          namespaces: [policy-108]
    validate:
      message: Pod securityContext.runAsNonRoot must be true.
      pattern:
        spec:
          securityContext:
            runAsNonRoot: true
```

```bash
kubectl apply --context "$CTX" -f require-run-as-non-root.yaml
```

## 4. Разрешить только утверждённые registry

Разрешены `registry.k8s.io` и выделенный организационный путь `ghcr.io/cks-lab`.
Шаблон Kyverno с `|` выражает логическое «или».

```yaml
# allow-approved-registries.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: allow-approved-registries
spec:
  validationFailureAction: Enforce
  background: false
  rules:
  - name: only-approved-container-registries
    match:
      any:
      - resources:
          kinds: [Pod]
          namespaces: [policy-108]
    validate:
      message: Images must come from registry.k8s.io or ghcr.io/cks-lab.
      foreach:
      - list: request.object.spec.containers[]
        pattern:
          image: "registry.k8s.io/* | ghcr.io/cks-lab/*"
```

```bash
kubectl apply --context "$CTX" -f allow-approved-registries.yaml
```

Проверка без создания Pod и без image pull:

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
```

Команда должна завершиться ошибкой admission policy.

## 5. Опционально: mutation label

Эта ClusterPolicy не отклоняет Pod, а добавляет label, только если пользователь не
задал его сам. Оператор `+` делает patch идемпотентным.

```yaml
# add-kyverno-managed-label.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-kyverno-managed-label
spec:
  background: false
  rules:
  - name: add-kyverno-management-label
    match:
      any:
      - resources:
          kinds: [Pod]
          namespaces: [policy-108]
    mutate:
      patchStrategicMerge:
        metadata:
          labels:
            +(security.cks.io/managed-by): kyverno
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
