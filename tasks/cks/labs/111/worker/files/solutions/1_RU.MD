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

## 0. Подготовка: podman и registry

Для сборки и публикации образов используется `podman` (он есть в списке инструментов экзамена;
rootless, работает от `ubuntu`). Registry уже поднят bootstrap'ом: это `registry:2` на control-plane
(`<IP узла>:5000`, plain HTTP внутри VPC, данные на локальном PV узла). Podman на worker настроен
на него как на insecure registry (`/etc/containers/registries.conf.d/cks111.conf`), containerd на
узле - тоже, поэтому флаг `--tls-verify=false` не нужен. Образы лабы заранее скачаны в локальный
кеш, которым пользуются Trivy и Syft, поэтому повторные сканы не упираются в лимит Docker Hub.

Адрес registry:

```bash
export REGISTRY="$(cat /etc/cks111/registry)"     # <IP control-plane>:5000
curl -fsS "http://$REGISTRY/v2/" && echo " registry ok: $REGISTRY"
podman --version
```

Пароль ключа cosign оставляем пустым, чтобы команды не ждали ввода:

```bash
export COSIGN_PASSWORD=""
```

Registry работает по HTTP: digest опубликованного образа берём из `podman push --digestfile`, а
существование манифеста проверяем запросом к `/v2/`. `cosign` сам использует HTTP для адресов
частных сетей; для Kyverno в policy задаётся `credentials.allowInsecureRegistry: true`. `bom` читает
образы только из registry, поэтому по-прежнему обращается к Docker Hub; если увидите
`TOOMANYREQUESTS`, подождите или выполните `podman login docker.io` под своей учётной записью.

## 1. Trivy report

```bash
mkdir -p "$ART/1"
trivy image --scanners vuln --vuln-type os,library --format json --output "$ART/1/trivy-report.json" "$IMAGE"
jq '.ArtifactName, (.Results | length)' "$ART/1/trivy-report.json"
```

## 1b. Multi-image CVE triage

```bash
cat ~/cks-111/candidates.txt
```

```
CANDIDATE_1=python:3.9-slim@sha256:...
CANDIDATE_2=python:3.11-slim@sha256:...
CANDIDATE_3=python:3.13-slim@sha256:...
TARGET_CVE=CVE-XXXX-XXXXX
```

```bash
source <(grep -v '^#' ~/cks-111/candidates.txt)
mkdir -p "$ART/1b"
for ref in "$CANDIDATE_1" "$CANDIDATE_2" "$CANDIDATE_3"; do
  out=$(mktemp)
  trivy image --scanners vuln --format json --output "$out" "$ref"
  if jq -e --arg cve "$TARGET_CVE" '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | index($cve) != null' "$out" >/dev/null; then
    echo "FOUND $TARGET_CVE in $ref"
    cp "$out" "$ART/1b/target-scan.json"
    echo "OFFENDING_IMAGE=$ref" > "$ART/1b/answer.txt"
  fi
  rm -f "$out"
done
cat "$ART/1b/answer.txt"
```

```
FOUND CVE-XXXX-XXXXX in python:3.9-slim@sha256:...
OFFENDING_IMAGE=python:3.9-slim@sha256:...
```

## 1c. Workload image triage by CRITICAL severity

```bash
mkdir -p "$ART/1c" "$ART/1c/bom" 2>/dev/null; true
mapfile -t triage < <(kubectl -n cks-111 get deployment -l cks.io/task=1c \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.template.spec.containers[0].image}{"\n"}{end}')

declare -A crit_count
for line in "${triage[@]}"; do
  name=$(awk '{print $1}' <<<"$line"); ref=$(awk '{print $2}' <<<"$line")
  out=$(mktemp)
  trivy image --scanners vuln --severity CRITICAL --format json --output "$out" "$ref"
  crit_count["$name"]=$(jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | unique | length' "$out")
  rm -f "$out"
  echo "$name $ref ${crit_count[$name]}"
done

mapfile -t ranked < <(for n in "${!crit_count[@]}"; do printf '%s %s\n' "${crit_count[$n]}" "$n"; done | sort -rn -k1,1 | awk '{print $2}')
most="${ranked[0]}"; least1="${ranked[-1]}"; least2="${ranked[-2]}"
printf 'MOST_VULNERABLE=%s\nLEAST_VULNERABLE_1=%s\nLEAST_VULNERABLE_2=%s\n' "$most" "$least1" "$least2" \
  | tee "$ART/1c/ranking.txt"

most_ref=$(kubectl -n cks-111 get deployment "$most" -o jsonpath='{.spec.template.spec.containers[0].image}')
trivy image --format cyclonedx --output "$ART/1c/cyclonedx.json" "$most_ref"

for n in "${ranked[@]}"; do
  if [[ "$n" == "$least1" || "$n" == "$least2" ]]; then
    kubectl -n cks-111 scale deployment/"$n" --replicas=1
  else
    kubectl -n cks-111 scale deployment/"$n" --replicas=0
  fi
done
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
jq '{summary: .Summary, findings: (.Reports | length)}' "$ART/2/kube-linter-before.json"
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
# Чистый Dockerfile даёт ПУСТОЙ вывод hadolint (код возврата 0) - пустой файл здесь ожидаем и корректен.
grep -nE '^(FROM|COPY|USER)' "$ROOT/Dockerfile"
```

`ARG CKS_SIGNATURE_TEST`/`LABEL cks.signature-test` не меняют ни одно из проверенных здесь
security-свойств (base image, non-root, отсутствие secret) - это единственная точка
контролируемого отличия, которая в задании 9c гарантирует другой manifest digest без
пересмотра остального Dockerfile.

Соберите и **опубликуйте** образ в registry, доступный Kubernetes; один только local image ID/DiffID не подходит для digest pinning. Подставьте свой repository, затем получите registry manifest digest и сформируйте immutable reference:

```bash
export HARDENED_TAG="$REGISTRY/catalog:1.0"
podman build -t "$HARDENED_TAG" "$ROOT"
podman push --digestfile /tmp/cks-111-hardened.digest "$HARDENED_TAG"
export HARDENED_DIGEST=$(cat /tmp/cks-111-hardened.digest)
export HARDENED_IMAGE="${HARDENED_TAG%:*}@${HARDENED_DIGEST}"
printf '%s\n' "$HARDENED_IMAGE"   # <IP>:5000/catalog@sha256:<manifest-digest>
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

## 5b. Find a package version in workload images and remove offending containers

```bash
mkdir -p "$ART/5b/bom"
mapfile -t containers < <(kubectl -n cks-111 get deployment pkg-audit-app \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{" "}{.image}{"\n"}{end}')

declare -A pkgset
for line in "${containers[@]}"; do
  cname=$(awk '{print $1}' <<<"$line"); ref=$(awk '{print $2}' <<<"$line")
  bom generate --format json --output "$ART/5b/bom/$cname.spdx.json" --image "$ref"
  pkgset["$cname"]=$(jq -r '.packages[]? | select((.name // "") != "" and (.versionInfo // "") != "") | "\(.name)=\(.versionInfo)"' "$ART/5b/bom/$cname.spdx.json" | sort -u)
done

names=("${!pkgset[@]}")
found=""
for ((i=0; i<${#names[@]}; i++)); do
  for ((j=i+1; j<${#names[@]}; j++)); do
    shared=$(comm -12 <(printf '%s\n' "${pkgset[${names[$i]}]}") <(printf '%s\n' "${pkgset[${names[$j]}]}"))
    [[ -n "$shared" ]] && { found="$shared"; a="${names[$i]}"; b="${names[$j]}"; break 2; }
  done
done
pkg=$(head -1 <<<"$found" | cut -d= -f1); ver=$(head -1 <<<"$found" | cut -d= -f2)
printf 'TARGET_PACKAGE=%s\nTARGET_VERSION=%s\n' "$pkg" "$ver" | tee "$ART/5b/answer.txt"
echo "offending containers: $a $b"

# Remove exactly the offending containers, keep the clean one, re-apply.
kubectl -n cks-111 get deployment pkg-audit-app -o json \
  | jq --arg a "$a" --arg b "$b" '.spec.template.spec.containers |= map(select(.name != $a and .name != $b))' \
  | kubectl apply -f -
kubectl -n cks-111 rollout status deployment/pkg-audit-app --timeout=120s
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
# Для ссылки вида tag@digest Syft записывает в metadata.component.version только tag; ссылка
# без tag ("nginx@sha256:...") даёт version = manifest digest, который и проверяется.
syft "nginx@${IMAGE#*@}" -o "cyclonedx-json=$ART/7/syft.cdx.json"
jq -r '.metadata.component.version' "$ART/7/syft.cdx.json"   # sha256:<manifest-digest>
set -o pipefail
cosign verify \
  --certificate-oidc-issuer https://accounts.google.com \
  --certificate-identity keyless@distroless.iam.gserviceaccount.com \
  gcr.io/distroless/static-debian13:nonroot \
  2>&1 | tee "$ART/7/cosign-verify.txt"
cosign_rc=${PIPESTATUS[0]}
set +o pipefail
[[ "$cosign_rc" -eq 0 ]]

# gcr.io/distroless/static:nonroot (без суффикса -debian13) считается deprecated и больше
# не обновляется согласно официальному README Distroless - используем текущий
# поддерживаемый тег gcr.io/distroless/static-debian13:nonroot. Успех cosign verify
# определяется exit code, а не литеральной строкой "Verified OK" - такой строки нет в
# реальном выводе cosign (успешный вывод начинается строкой "Verification for <image> --"
# и списком выполненных проверок). Сохраняем reference отдельно для evidence, не для
# pass/fail проверки.
printf '\nreference=gcr.io/distroless/static-debian13:nonroot\n' >> "$ART/7/cosign-verify.txt"
jq '.bomFormat, (.components | length)' "$ART/7/syft.cdx.json"
test -s "$ART/7/cosign-verify.txt"
```

## 8. `trivy sbom`: сканирование готового SBOM-файла

CycloneDX SBOM из задания 7 описывает состав компонентов и ОС образа, но не содержит вывода об
уязвимостях; `trivy sbom` принимает такой файл напрямую как вход, без повторного обращения к
registry за самим image.

```bash
mkdir -p "$ART/8"
printf '%s\n' \
  "trivy sbom --format json --output $ART/8/sbom-scan.json $ART/7/syft.cdx.json" \
  > "$ART/8/sbom-scan-command.txt"

trivy sbom \
  --format json \
  --output "$ART/8/sbom-scan.json" \
  "$ART/7/syft.cdx.json"

jq '{artifact: .ArtifactType, os: .Metadata.OS.Family, results: (.Results | length), vulns: ([.Results[]?.Vulnerabilities[]?] | length)}' "$ART/8/sbom-scan.json"
```

Trivy определяет ОС по компоненту `operating-system` из CycloneDX (`alpine 3.20.5`) и
сопоставляет пакеты с базой уязвимостей - `Results` непустой. Для сравнения: SPDX из задания 6
(`bom`) для multi-arch образа не содержит ОС (`Detected OS family="none"`), и `trivy sbom` по нему
не находит ничего (`Results` пуст) - поэтому для этого задания берётся CycloneDX.

## 9a. Kyverno и `ImageValidatingPolicy` на trusted signature

Установите Kyverno так же, как в лабе 108, и дождитесь готовности admission controller.

```bash
sudo install-kyverno
kubectl -n kyverno get deployment kyverno-admission-controller
kubectl -n kyverno wait --for=condition=Available deployment/kyverno-admission-controller --timeout=180s
```

Сгенерируйте учебную пару ключей ВНЕ `$ROOT` - этот каталог повторно используется как
Docker build context в задании 9c (`COPY . /usr/share/nginx/html` в Dockerfile копирует
ВСЁ содержимое build context), поэтому `cosign.key`, оставленный внутри `$ROOT`, попадёт
внутрь публикуемого image filesystem как утечка private signing key в registry. Подпишите
именно `$HARDENED_IMAGE` из задания 3/4, а не upstream `nginx`. Не переносите этот
`cosign.key` в production CI.

```bash
export KEYDIR=/home/ubuntu/.cks111-cosign
install -d -m 0700 "$KEYDIR"
mkdir -p "$ART/9a" "$ART/9b" "$ART/9c"

(
  cd "$KEYDIR"
  cosign generate-key-pair
)
chmod 0600 "$KEYDIR/cosign.key"
chmod 0644 "$KEYDIR/cosign.pub"

# cosign sign пишет ход работы в stderr, поэтому 2>&1 обязателен - иначе артефакт останется пустым.
cosign sign --key "$KEYDIR/cosign.key" --yes "$HARDENED_IMAGE" 2>&1 | tee "$ART/9a/cosign-sign.txt"
# Реально проверяем подпись тем же public key, а не только наличие текста sign-команды.
cosign verify --key "$KEYDIR/cosign.pub" "$HARDENED_IMAGE" | tee "$ART/9a/cosign-verify.txt"
```

Создайте `ImageValidatingPolicy`, ссылающуюся на публичный ключ, которым только что
подписан `$HARDENED_IMAGE`. `matchImageReferences` ограничивает policy ровно repository
вашего образа: для OCI references нужны отдельные разделители `:` (tag) и `@` (digest),
иначе префикс `${HARDENED_REPO}*` захватит, например, другой repository с тем же началом
имени. Это не даёт policy блокировать остальные Pod кластера.

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
  credentials:
    allowInsecureRegistry: true   # registry лабы работает по HTTP
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  matchImageReferences:
  - glob: "${HARDENED_REPO}:*"
  - glob: "${HARDENED_REPO}@*"
  attestors:
  - name: catalogReleaseKey
    cosign:
      key:
        data: |-
$(sed 's/^/          /' "$KEYDIR/cosign.pub")
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

# Сразу после создания policy первый вызов webhook Kyverno (проверка подписи в registry)
# может упереться в таймаут 10 с (`failed calling webhook ... context deadline exceeded`);
# при failurePolicy=Fail Pod тогда не создаётся. Повторите создание, пока webhook не прогреется.
for attempt in $(seq 1 10); do
  kubectl run signed-admission-check -n cks-111 --image="$HARDENED_IMAGE" \
    --restart=Never --command -- sleep 3600 && break
  sleep 10
done
kubectl wait --for=condition=Ready pod/signed-admission-check -n cks-111 --timeout=60s

kubectl get pod signed-admission-check -n cks-111 -o json \
  | jq --arg policy "$POLICY_CREATED" '{
      creationTimestamp: .metadata.creationTimestamp,
      policyCreationTimestamp: $policy,
      createdAfterPolicy: (.metadata.creationTimestamp >= $policy),
      image: .spec.containers[0].image,
      phase: .status.phase,
      ready: ([.status.conditions[]? | select(.type == "Ready") | .status] | any(. == "True"))
    }' | tee "$ART/9b/signed-admission-check.json"
```

Критерий (`creationTimestamp` имеет точность 1 с, поэтому сравнение нестрогое): `createdAfterPolicy == true` и `ready == true`. Это - и только это - доказывает,
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
export UNSIGNED_TAG="${HARDENED_TAG%:*}:unsigned-1"
podman build --build-arg CKS_SIGNATURE_TEST=unsigned-1 -t "$UNSIGNED_TAG" "$ROOT"
podman push --digestfile /tmp/cks-111-unsigned.digest "$UNSIGNED_TAG"
export UNSIGNED_DIGEST=$(cat /tmp/cks-111-unsigned.digest)
export UNSIGNED_IMAGE="${HARDENED_REPO}@${UNSIGNED_DIGEST}"
export HARDENED_DIGEST="${HARDENED_IMAGE#*@}"

# Обязательная проверка: unsigned candidate должен быть физически другим artifact,
# а не тем же digest, что уже подписанный HARDENED_IMAGE.
[[ "$UNSIGNED_DIGEST" != "$HARDENED_DIGEST" ]] || { echo "UNSIGNED_DIGEST совпал с HARDENED_DIGEST - соберите с другим build-arg/меткой"; exit 1; }
printf 'hardened_digest=%s\nunsigned_digest=%s\nunsigned_image=%s\ndistinct=true\n' \
  "$HARDENED_DIGEST" "$UNSIGNED_DIGEST" "$UNSIGNED_IMAGE" \
  | tee "$ART/9c/digest-comparison.txt"
```

`$ROOT/Dockerfile` из задания 3 должен принимать этот build-arg (например,
`ARG CKS_SIGNATURE_TEST=signed` и `LABEL cks.signature-test=$CKS_SIGNATURE_TEST` рядом с
существующими инструкциями) - тогда собранный образ отличается от `$HARDENED_IMAGE` ровно
одной безопасной меткой, не затрагивая security-свойства, проверенные в заданиях 3-4.

Явно доказываем, что этот digest существует и pullable, прежде чем проверять policy -
иначе denial ничего не докажет. Это self-check evidence для вас: checker для задания 9c
не доверяет текстовым файлам как единственному доказательству - он сам резолвит
`unsigned_image` из `digest-comparison.txt`, сам проверяет отсутствие подписи и сам
создаёт новый Pod с этим образом, поэтому написать эти файлы вручную без реального
работающего admission control недостаточно для PASS.

```bash
curl -fsSI -H 'Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.v2+json' \
  "http://$REGISTRY/v2/catalog/manifests/$UNSIGNED_DIGEST" | tee "$ART/9c/unsigned-exists.txt"
grep -qi "docker-content-digest: $UNSIGNED_DIGEST" "$ART/9c/unsigned-exists.txt"
```

Явно доказываем отсутствие валидной подписи этим же ключом - **до** попытки создания
Pod, чтобы denial было предсказуемо специфичным для signature, а не для чего-то ещё:

```bash
cosign verify --key "$KEYDIR/cosign.pub" "$UNSIGNED_IMAGE" > "$ART/9c/unsigned-not-signed.txt" 2>&1 || true
grep -Eiq 'error|no matching signatures' "$ART/9c/unsigned-not-signed.txt"
```

Только теперь пробуем создать Pod и подтверждаем, что denial ссылается именно на policy/
signature, а не на generic admission-ошибку:

```bash
kubectl run catalog-unsigned-probe -n cks-111 --image="$UNSIGNED_IMAGE" --restart=Never \
  2>&1 | tee "$ART/9c/admission-deny.txt" || true
grep -F 'catalog image must have a valid release signature' "$ART/9c/admission-deny.txt"
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
