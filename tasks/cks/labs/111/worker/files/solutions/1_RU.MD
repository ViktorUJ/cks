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
COPY --chown=101:101 . /usr/share/nginx/html
USER 101
CMD ["nginx", "-g", "daemon off;"]
EOF
mkdir -p "$ART/3"
hadolint "$ROOT/Dockerfile" | tee "$ART/3/hadolint-after.txt"
grep -nE '^(FROM|COPY|USER)' "$ROOT/Dockerfile"
```

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

Финальная проверка:

```bash
check_result
```
