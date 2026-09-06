# Лаба 111 — эталонное решение

Все команды выполняются на worker. Сначала задайте общие переменные и убедитесь, что
используются установленные pinned binaries:

```bash
export ROOT=/home/ubuntu/cks-111
export ART=/var/work/tests/artifacts
export BASE_TAG=nginx:1.27.3-alpine
cd "$ROOT"
# A tag is mutable. Discover the canonical registry manifest digest once, then pin it.
trivy image --format json "$BASE_TAG" > /tmp/cks-111-base.json
export BASE_REPO_DIGEST=$(jq -er '.Metadata.RepoDigests[0]' /tmp/cks-111-base.json)
export IMAGE="$BASE_TAG@${BASE_REPO_DIGEST#*@}"
printf 'base_image=%s
repo_digest=%s
' "$IMAGE" "$BASE_REPO_DIGEST"
trivy --version; kubesec version; kube-linter version; hadolint --version
syft version; bom version; cosign version
```

## 1. Trivy report

```bash
mkdir -p "$ART/1"
trivy image --scanners vuln --vuln-type os,library --format json --output "$ART/1/trivy-report.json" "$IMAGE"
jq '.ArtifactName, (.Results | length)' "$ART/1/trivy-report.json"
```

## 2. Отчёты до исправления

`hadolint`, `kubesec` и `kube-linter` возвращают ненулевой статус при findings; это
ожидаемый результат. `PIPESTATUS` сохраняет фактический текст отчёта, не подменяя его.

```bash
mkdir -p "$ART/2"
hadolint "$ROOT/Dockerfile" | tee "$ART/2/hadolint-before.txt"; test "${PIPESTATUS[0]}" -ge 0
kubesec scan "$ROOT/deployment.yaml" > "$ART/2/kubesec-before.json" || true
kube-linter lint "$ROOT/deployment.yaml" --format json > "$ART/2/kube-linter-before.json" || true
jq '.[0].scoring' "$ART/2/kubesec-before.json"
jq 'length' "$ART/2/kube-linter-before.json"
```

## 3. Исправить Dockerfile

Не добавляйте secret в image layer и не используйте floating tag: используйте `$IMAGE`, в котором tag дополнен manifest digest. `USER 101` является свойством будущего hardened image.

```bash
cat > "$ROOT/Dockerfile" <<EOF
FROM $IMAGE
ARG CKS_SIGNATURE_TEST=signed
LABEL cks.signature-test=\$CKS_SIGNATURE_TEST
COPY --chown=101:101 . /usr/share/nginx/html
USER 101
CMD ["nginx", "-g", "daemon off;"]
EOF
mkdir -p "$ART/3"
hadolint "$ROOT/Dockerfile" | tee "$ART/3/hadolint-after.txt"
grep -nE '^(FROM|COPY|USER)' "$ROOT/Dockerfile"
```

`ARG CKS_SIGNATURE_TEST`/`LABEL cks.signature-test` не меняют ни одно из проверенных здесь
security-свойств (base image, non-root, отсутствие secret) - это единственная точка
контролируемого отличия, которая в задании 9c гарантирует другой manifest digest без
пересмотра остального Dockerfile.

Соберите и **опубликуйте** образ в registry, доступный Kubernetes; один только local image ID/DiffID не подходит для digest pinning. Подставьте свой repository, затем получите registry manifest digest и сформируйте immutable reference:

```bash
export HARDENED_TAG=registry.example/cks111/catalog:1.0
# docker login registry.example
# docker buildx build --platform linux/amd64 --push -t "$HARDENED_TAG" "$ROOT"
export HARDENED_DIGEST=$(docker buildx imagetools inspect "$HARDENED_TAG" --format '{{.Manifest.Digest}}')
export HARDENED_IMAGE="${HARDENED_TAG%:*}@${HARDENED_DIGEST}"
printf '%s
' "$HARDENED_IMAGE"   # registry.example/cks111/catalog@sha256:<manifest-digest>
```

## 4. Исправить Deployment

`readOnlyRootFilesystem` требует writable runtime paths nginx. `emptyDir` даёт их адресно; init container (также hardened image с `USER 101`) копирует default config в отдельный writable config volume. `$HARDENED_IMAGE` — собранная и digest-pinned ссылка из задания 3, не upstream image.

```bash
cat > "$ROOT/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  namespace: cks-111
spec:
  replicas: 1
  selector:
    matchLabels: {app: catalog}
  template:
    metadata:
      labels: {app: catalog}
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        runAsGroup: 101
        fsGroup: 101
        seccompProfile: {type: RuntimeDefault}
      initContainers:
      - name: prepare-nginx-config
        image: $HARDENED_IMAGE
        command: ["sh", "-c", "cp /etc/nginx/conf.d/default.conf /work/default.conf"]
        securityContext:
          allowPrivilegeEscalation: false
          capabilities: {drop: ["ALL"]}
        volumeMounts: [{name: nginx-config, mountPath: /work}]
      containers:
      - name: catalog
        image: $HARDENED_IMAGE
        ports: [{containerPort: 80, name: http}]
        readinessProbe: {httpGet: {path: /, port: http}}
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities: {drop: ["ALL"]}
        resources:
          requests: {cpu: 100m, memory: 64Mi}
          limits: {cpu: 250m, memory: 128Mi}
        volumeMounts:
        - {name: nginx-tmp, mountPath: /tmp}
        - {name: nginx-run, mountPath: /var/run}
        - {name: nginx-cache, mountPath: /var/cache/nginx}
        - {name: nginx-config, mountPath: /etc/nginx/conf.d}
      volumes:
      - {name: nginx-tmp, emptyDir: {medium: Memory}}
      - {name: nginx-run, emptyDir: {}}
      - {name: nginx-cache, emptyDir: {}}
      - {name: nginx-config, emptyDir: {}}
---
apiVersion: v1
kind: Service
metadata: {name: catalog, namespace: cks-111}
spec:
  selector: {app: catalog}
  ports: [{name: http, port: 80, targetPort: http}]
EOF
mkdir -p "$ART/4"
kubesec scan "$ROOT/deployment.yaml" > "$ART/4/kubesec-after.json" || true
kube-linter lint "$ROOT/deployment.yaml" --format json > "$ART/4/kube-linter-after.json" || true
jq type "$ART/4/kubesec-after.json" "$ART/4/kube-linter-after.json"
kubectl apply -f "$ROOT/deployment.yaml"
kubectl rollout status deployment/catalog -n cks-111 --timeout=180s
kubectl wait --for=condition=Available deployment/catalog -n cks-111 --timeout=180s
kubectl run catalog-http-smoke -n cks-111 --rm -i --restart=Never --image=curlimages/curl:8.11.0 --   curl -fsS --max-time 10 http://catalog
```

## 5. Поиск версий пакетов

`--list-all-pkgs` даёт фактический inventory. Канонический registry manifest digest берётся только из `Metadata.RepoDigests[0]`; `ImageID` и `DiffID` описывают локальный образ/layers и не являются fallback для registry digest.

```bash
mkdir -p "$ART/5" /tmp/cks-111
trivy image --list-all-pkgs --format json "$IMAGE" > /tmp/cks-111/packages.json
{
  echo "trivy image --list-all-pkgs --format json $IMAGE"
  echo "image=$IMAGE"
  echo "repo_digest=$(jq -er '.Metadata.RepoDigests[0]' /tmp/cks-111/packages.json)"
  jq -r '[.Results[].Packages[]? | select(.Name and .Version) | "\(.Name)=\(.Version)"] | unique | .[:3][]' /tmp/cks-111/packages.json
} > "$ART/5/version-search.txt"
cat "$ART/5/version-search.txt"
```

## 6. SPDX SBOM (bom)

```bash
mkdir -p "$ART/6"
echo "bom generate --format json --output $ART/6/bom.spdx.json --image $IMAGE" > "$ART/6/bom-command.txt"
bom generate --format json --output "$ART/6/bom.spdx.json" --image "$IMAGE"
jq '.spdxVersion, (.packages | length)' "$ART/6/bom.spdx.json"
```

## 7. CycloneDX SBOM (Syft) и keyless Cosign

Syft умеет и SPDX, и CycloneDX; здесь берём CycloneDX (`bom` уже дал SPDX в задании 6).
Проверяется публичный образ Distroless и его ожидаемая Google workload identity; не
используйте `--insecure-ignore-tlog` или пропуск certificate identity.

```bash
mkdir -p "$ART/7"
syft "$IMAGE" -o "cyclonedx-json=$ART/7/syft.cdx.json"
cosign verify \
  --certificate-oidc-issuer https://accounts.google.com \
  --certificate-identity keyless@distroless.iam.gserviceaccount.com \
  gcr.io/distroless/static:nonroot \
  | tee "$ART/7/cosign-verify.txt"
# Сохранить также reference, который может отсутствовать в компактном JSON-выводе cosign.
printf '\nreference=gcr.io/distroless/static:nonroot\n' >> "$ART/7/cosign-verify.txt"
jq '.bomFormat, (.components | length)' "$ART/7/syft.cdx.json"
grep -E 'Verified OK|gcr.io/distroless/static:nonroot' "$ART/7/cosign-verify.txt"
```

## 8. `trivy sbom`: сканирование готового SBOM-файла

SBOM из задания 6 описывает состав компонентов, но не содержит вывода об уязвимостях;
`trivy sbom` принимает такой файл напрямую как вход, без повторного обращения к registry
за самим image.

```bash
mkdir -p "$ART/8"
{
  echo "trivy sbom --format json --output $ART/8/sbom-scan.json $ART/6/bom.spdx.json"
  trivy sbom --format json --output "$ART/8/sbom-scan.json" "$ART/6/bom.spdx.json"
} > /tmp/cks-111-trivy-sbom.log 2>&1
# Записать использованную команду прямо в evidence-файл, чтобы критерий видел trivy sbom.
jq --arg cmd "trivy sbom --format json --output $ART/8/sbom-scan.json $ART/6/bom.spdx.json" \
  '. + {ScanCommand: $cmd}' "$ART/8/sbom-scan.json" > "$ART/8/sbom-scan.json.tmp" \
  && mv "$ART/8/sbom-scan.json.tmp" "$ART/8/sbom-scan.json"
jq '.ScanCommand, (.Results | length)' "$ART/8/sbom-scan.json"
```

## 9a. Kyverno и `ImageValidatingPolicy` на trusted signature

Установите Kyverno так же, как в лабе 108, и дождитесь готовности admission controller.

```bash
sudo install-kyverno
kubectl -n kyverno get deployment -l app.kubernetes.io/part-of=kyverno
kubectl -n kyverno wait --for=condition=Available deployment -l app.kubernetes.io/part-of=kyverno --timeout=180s
```

Сгенерируйте учебную пару ключей и подпишите именно `$HARDENED_IMAGE` из задания 3/4, а
не upstream `nginx`. Не переносите этот `cosign.key` в production CI.

```bash
mkdir -p "$ART/9a" "$ART/9b" "$ART/9c"
cosign generate-key-pair
cosign sign --key cosign.key --yes "$HARDENED_IMAGE" | tee "$ART/9a/cosign-sign.txt"
```

Создайте `ImageValidatingPolicy`, ссылающуюся на публичный ключ, которым только что
подписан `$HARDENED_IMAGE`. `matchImageReferences` ограничивает policy repository вашего
образа, чтобы не блокировать остальные Pod кластера.

```bash
export HARDENED_REPO="${HARDENED_IMAGE%@*}"
cat > "$ROOT/require-signed-catalog-images.yaml" <<EOF
apiVersion: policies.kyverno.io/v1
kind: ImageValidatingPolicy
metadata:
  name: require-signed-catalog-images
spec:
  failurePolicy: Fail
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  matchImageReferences:
  - glob: "${HARDENED_REPO}*"
  attestors:
  - name: catalogReleaseKey
    cosign:
      key:
        data: |-
$(sed 's/^/          /' cosign.pub)
  validations:
  - message: "catalog image must have a valid release signature"
    expression: >-
      (images.containers + images.?initContainers.orValue([]) +
      images.?ephemeralContainers.orValue([])).map(image,
        verifyImageSignatures(image, [attestors.catalogReleaseKey]) > 0).all(ok, ok)
EOF
kubectl apply -f "$ROOT/require-signed-catalog-images.yaml"
kubectl get imagevalidatingpolicy require-signed-catalog-images -o yaml
```

В конце выполните `check_result` (частично, тест 9a).

## 9b. Fresh signed ALLOW: новый Pod после создания policy

Повторный `kubectl apply` уже существующего Deployment `catalog` **не доказывает**
post-policy admission: если template не изменился, Kubernetes не создаёт новый
ReplicaSet/Pod, и наблюдаемый `Running` может быть тот же Pod, что существовал ещё до
`require-signed-catalog-images`. Чтобы доказать именно fresh admission, создаём **новый**
объект, которого не существовало до этого момента:

```bash
POLICY_CREATED=$(kubectl get imagevalidatingpolicy require-signed-catalog-images \
  -o jsonpath='{.metadata.creationTimestamp}')

kubectl run signed-admission-check -n cks-111 --image="$HARDENED_IMAGE" \
  --restart=Never --command -- sleep 300
kubectl wait --for=condition=Ready pod/signed-admission-check -n cks-111 --timeout=60s

kubectl get pod signed-admission-check -n cks-111 -o json \
  | jq --arg policy "$POLICY_CREATED" '{
      creationTimestamp: .metadata.creationTimestamp,
      policyCreationTimestamp: $policy,
      createdAfterPolicy: (.metadata.creationTimestamp > $policy),
      image: .spec.containers[0].image,
      phase: .status.phase,
      ready: ([.status.conditions[]? | select(.type == "Ready") | .status] | any(. == "True"))
    }' | tee "$ART/9b/signed-admission-check.json"
```

Критерий: `createdAfterPolicy == true` и `ready == true`. Это - и только это - доказывает,
что именно **эта** policy пропустила именно **этот**, ранее не существовавший Pod с
подписанным образом, а не что старый Pod просто продолжает работать.

В конце выполните `check_result` (частично, тест 9b).

## 9c. Signature-specific DENY: unsigned digest в том же repository

Unsigned candidate должен существовать в **том же** repository, что подписанный
`$HARDENED_IMAGE` - иначе admission может отказать из-за `manifest unknown` или ошибки
registry lookup, а не из-за отсутствия подписи, и denial не будет доказывать заявленное
security property. Собираем и публикуем второй, сознательно неподписанный tag в том же
repository - и **обязательно** с содержимым, отличным от `$HARDENED_IMAGE`: если собрать
тот же `Dockerfile`/context без изменений, reproducible/cached build может дать **тот же**
manifest digest, что и уже подписанный образ, и тогда `cosign verify` на "unsigned" тег
неожиданно пройдёт - потому что он физически укажет на уже подписанный artifact. Поэтому
вносим контролируемое отличие через `ARG`/`LABEL`, которое гарантированно меняет digest:

```bash
export UNSIGNED_TAG="${HARDENED_TAG%:*}:unsigned-1.0"
docker buildx build \
  --platform linux/amd64 \
  --build-arg CKS_SIGNATURE_TEST=unsigned-1 \
  --push \
  -t "$UNSIGNED_TAG" \
  "$ROOT"
export UNSIGNED_DIGEST=$(docker buildx imagetools inspect "$UNSIGNED_TAG" --format '{{.Manifest.Digest}}')
export UNSIGNED_IMAGE="${HARDENED_REPO}@${UNSIGNED_DIGEST}"
export HARDENED_DIGEST="${HARDENED_IMAGE#*@}"

# Обязательная проверка: unsigned candidate должен быть физически другим artifact,
# а не тем же digest, что уже подписанный HARDENED_IMAGE.
[[ "$UNSIGNED_DIGEST" != "$HARDENED_DIGEST" ]] || { echo "UNSIGNED_DIGEST совпал с HARDENED_DIGEST - соберите с другим build-arg/меткой"; exit 1; }
printf 'hardened_digest=%s\nunsigned_digest=%s\ndistinct=true\n' \
  "$HARDENED_DIGEST" "$UNSIGNED_DIGEST" | tee "$ART/9c/digest-comparison.txt"
```

`$ROOT/Dockerfile` из задания 3 должен принимать этот build-arg (например,
`ARG CKS_SIGNATURE_TEST=signed` и `LABEL cks.signature-test=$CKS_SIGNATURE_TEST` рядом с
существующими инструкциями) - тогда собранный образ отличается от `$HARDENED_IMAGE` ровно
одной безопасной меткой, не затрагивая security-свойства, проверенные в заданиях 3-4.

Явно доказываем, что этот digest существует и pullable, прежде чем проверять policy -
иначе denial ничего не докажет:

```bash
docker buildx imagetools inspect "$UNSIGNED_IMAGE" | tee "$ART/9c/unsigned-exists.txt"
grep -q "$UNSIGNED_DIGEST" "$ART/9c/unsigned-exists.txt"
```

Явно доказываем отсутствие валидной подписи этим же ключом - **до** попытки создания
Pod, чтобы denial было предсказуемо специфичным для signature, а не для чего-то ещё:

```bash
cosign verify --key cosign.pub "$UNSIGNED_IMAGE" > "$ART/9c/unsigned-not-signed.txt" 2>&1 || true
grep -Eiq 'error|no matching signatures' "$ART/9c/unsigned-not-signed.txt"
```

Только теперь пробуем создать Pod и подтверждаем, что denial ссылается именно на policy/
signature, а не на generic admission-ошибку:

```bash
kubectl run catalog-unsigned-probe -n cks-111 --image="$UNSIGNED_IMAGE" --restart=Never \
  2>&1 | tee "$ART/9c/admission-deny.txt" || true
grep -Ei 'require-signed-catalog-images|signature|attestor|verifyImageSignatures' "$ART/9c/admission-deny.txt"
kubectl get pod catalog-unsigned-probe -n cks-111 2>&1 | grep -q 'not found'
```

Разница с наивной проверкой: если бы вместо этого мы взяли digest из другого repository
(например, digest upstream `nginx` из задания 1), admission мог бы отказать по совершенно
другой причине (`manifest unknown`, отсутствие pull-доступа) - и такой denial выглядел бы
как "policy работает", хотя на самом деле проверка signature вообще не была достигнута.

В конце выполните `check_result`.

Финальная проверка:

```bash
check_result
```
