# Лаба 111 — эталонное решение

Все команды выполняются на worker. Сначала задайте общие переменные и убедитесь, что
используются установленные pinned binaries:

```bash
export ROOT=/home/ubuntu/cks-111
export ART=/var/work/tests/artifacts
export IMAGE=nginx:1.27.3-alpine
cd "$ROOT"
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

Не добавляйте secret в image layer и не используйте floating tag. `nginx` уже имеет
системного пользователя `nginx`; для демонстрации задаём явный непривилегированный UID.

```bash
cat > "$ROOT/Dockerfile" <<'EOF'
FROM nginx:1.27.3-alpine
COPY --chown=101:101 . /usr/share/nginx/html
USER 101
CMD ["nginx", "-g", "daemon off;"]
EOF
mkdir -p "$ART/3"
hadolint "$ROOT/Dockerfile" | tee "$ART/3/hadolint-after.txt"
grep -nE '^(FROM|COPY|USER)' "$ROOT/Dockerfile"
```

## 4. Исправить Deployment

`readOnlyRootFilesystem` требует, чтобы приложение не записывало в root filesystem. Для
этого минимального nginx-примера достаточно показать security context; при реальном
приложении следует подключить нужные writable `emptyDir` только к конкретным путям.

```bash
cat > "$ROOT/deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  namespace: cks-111
spec:
  replicas: 1
  selector:
    matchLabels:
      app: catalog
  template:
    metadata:
      labels:
        app: catalog
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: catalog
        image: nginx:1.27.3-alpine
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 250m
            memory: 128Mi
EOF
mkdir -p "$ART/4"
kubesec scan "$ROOT/deployment.yaml" > "$ART/4/kubesec-after.json" || true
kube-linter lint "$ROOT/deployment.yaml" --format json > "$ART/4/kube-linter-after.json" || true
jq type "$ART/4/kubesec-after.json" "$ART/4/kube-linter-after.json"
```

## 5. Поиск версий пакетов

`--list-all-pkgs` даёт фактический inventory. Digest берётся из JSON Trivy, а не
придумывается вручную. Названия metadata отличаются между registry, поэтому предусмотрен
fallback к `ImageID`/первому DiffID.

```bash
mkdir -p "$ART/5" /tmp/cks-111
trivy image --list-all-pkgs --format json "$IMAGE" > /tmp/cks-111/packages.json
{
  echo "trivy image --list-all-pkgs --format json $IMAGE"
  echo "image=$IMAGE"
  echo "digest=$(jq -r '.Metadata.ImageID // .Metadata.DiffIDs[0] // "sha256:unavailable"' /tmp/cks-111/packages.json)"
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
