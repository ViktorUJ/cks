[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 111 - solución de referencia

Todos los comandos se ejecutan en el worker. Son comandos normales de las herramientas (trivy, kubesec,
kube-linter, hadolint, podman, syft, bom, cosign) que hay en el examen; no hay scripts; cuando
hace falta comparar varios resultados, se hace a simple vista por la salida. Primero define las
variables comunes:

```bash
export ROOT=/home/ubuntu/cks-111 ART=/var/work/tests/artifacts BASE_TAG=nginx:1.27.3-alpine
cd $ROOT
# El tag es mutable: averiguamos una vez el manifest digest con Trivy y en adelante usamos tag@digest.
trivy image --format json $BASE_TAG > /tmp/cks-111-base.json
export IMAGE=$BASE_TAG@$(jq -r '.Metadata.RepoDigests[0]' /tmp/cks-111-base.json | cut -d@ -f2)
echo $IMAGE
```

## 0. Preparación: podman y registry

Para construir y publicar imágenes se usa `podman` (está en la lista de herramientas del examen;
rootless, se ejecuta como `ubuntu`). El registry ya lo levantó el bootstrap: es `registry:2` en el control-plane
(`<IP del nodo>:5000`, HTTP plano dentro de la VPC, datos en un PV local del nodo). Podman en el worker está configurado
para él como insecure registry (`/etc/containers/registries.conf.d/cks111.conf`), containerd en el
nodo también, por lo que el flag `--tls-verify=false` no hace falta. Las imágenes del laboratorio están descargadas de antemano en una caché
local que usan Trivy y Syft, por lo que los escaneos repetidos no chocan con el límite de Docker Hub.

Dirección del registry:

```bash
export REGISTRY="$(cat /etc/cks111/registry)"     # <IP control-plane>:5000
curl -fsS "http://$REGISTRY/v2/" && echo " registry ok: $REGISTRY"
podman --version
```

Dejamos la contraseña de la clave de cosign vacía, para que los comandos no esperen una entrada:

```bash
export COSIGN_PASSWORD=""
```

El registry funciona por HTTP: el digest de la imagen publicada lo tomamos de `podman push --digestfile`, y la
existencia del manifest la comprobamos con una petición a `/v2/`. `cosign` usa por sí mismo HTTP para las direcciones de
redes privadas; para Kyverno en la policy se establece `credentials.allowInsecureRegistry: true`. `bom` lee
las imágenes solo desde el registry, por lo que sigue acudiendo a Docker Hub; si ves
`TOOMANYREQUESTS`, espera o ejecuta `podman login docker.io` con tu propia cuenta.

## 1. Informe de Trivy

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
source ~/cks-111/candidates.txt
trivy image --scanners vuln --format json --output /tmp/cand1.json $CANDIDATE_1
trivy image --scanners vuln --format json --output /tmp/cand2.json $CANDIDATE_2
trivy image --scanners vuln --format json --output /tmp/cand3.json $CANDIDATE_3
grep -l $TARGET_CVE /tmp/cand?.json        # qué informe contiene TARGET_CVE
```

Supongamos que es `/tmp/cand1.json` (sustituye por tu número):

```bash
mkdir -p $ART/1b
cp /tmp/cand1.json $ART/1b/target-scan.json
echo "OFFENDING_IMAGE=$CANDIDATE_1" > $ART/1b/answer.txt
cat $ART/1b/answer.txt
# OFFENDING_IMAGE=python:3.9-slim@sha256:...
```

## 1c. Análisis de las imágenes de workload por nivel CRITICAL

Las imágenes las tomamos de los Deployments LIVE y escaneamos cada una; el número de CRITICAL únicas se imprime junto al
nombre del Deployment:

```bash
mkdir -p $ART/1c
kubectl -n cks-111 get deployment -l cks.io/task=1c \
  -o jsonpath='{range .items[*]}{.metadata.name} {.spec.template.spec.containers[0].image}{"\n"}{end}' |
while read name ref; do
  trivy image --scanners vuln --severity CRITICAL --format json --output /tmp/$name.json $ref
  echo "$name $(jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | unique | length' /tmp/$name.json)"
done
```

Por la salida encuentra el Deployment con el mayor número (el más vulnerable) y los dos con el menor. Anota
los nombres en `ranking.txt` (en lugar de `dep-a`, `dep-b`, `dep-c`, tus nombres):

```bash
cat > $ART/1c/ranking.txt <<EOF
MOST_VULNERABLE=dep-a
LEAST_VULNERABLE_1=dep-b
LEAST_VULNERABLE_2=dep-c
EOF
# dep-d es el cuarto Deployment (el segundo por número de CRITICAL), en ranking.txt no se anota
```

CycloneDX SBOM del Deployment más vulnerable (la imagen de su Deployment) y scale de los demás:

```bash
kubectl -n cks-111 get deployment dep-a -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
trivy image --format cyclonedx --output $ART/1c/cyclonedx.json <imagen de la salida anterior>
kubectl -n cks-111 scale deployment dep-a --replicas=0      # el más vulnerable
kubectl -n cks-111 scale deployment dep-d --replicas=0      # el cuarto (no entra entre los dos menos vulnerables)
kubectl -n cks-111 get deployment -l cks.io/task=1c
```

## 2. Informes antes de la corrección

`hadolint`, `kubesec` y `kube-linter` devuelven un estado distinto de cero cuando hay findings; es el resultado
esperado, el informe se guarda tal cual.

```bash
mkdir -p $ART/2
hadolint $ROOT/Dockerfile > $ART/2/hadolint-before.txt
kubesec scan $ROOT/deployment.yaml > $ART/2/kubesec-before.json
kube-linter lint $ROOT/deployment.yaml --format json > $ART/2/kube-linter-before.json
jq '.[0].scoring' $ART/2/kubesec-before.json
jq '{summary: .Summary, findings: (.Reports | length)}' $ART/2/kube-linter-before.json
```

## 3. Corregir el Dockerfile

No añadas un secret a una image layer ni uses un floating tag: usa `$IMAGE`, en el que el tag se complementa con el manifest digest. `USER 101` es una propiedad de la futura hardened image.

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
hadolint "$ROOT/Dockerfile" > "$ART/3/hadolint-after.txt"
# Un Dockerfile limpio da una salida de hadolint VACÍA (código de retorno 0): un archivo vacío aquí es esperado y correcto.
grep -nE '^(FROM|COPY|USER)' "$ROOT/Dockerfile"
```

`ARG CKS_SIGNATURE_TEST`/`LABEL cks.signature-test` no cambian ninguna de las propiedades de
seguridad comprobadas aquí (base image, non-root, ausencia de secret): es el único punto de
diferencia controlada que en la tarea 9c garantiza otro manifest digest sin
revisar el resto del Dockerfile.

Construye y **publica** la imagen en un registry accesible para Kubernetes; un local image ID/DiffID por sí solo no sirve para el digest pinning. Pon tu propio repository, luego obtén el registry manifest digest y forma la immutable reference:

```bash
export HARDENED_TAG="$REGISTRY/catalog:1.0"
podman build -t "$HARDENED_TAG" "$ROOT"
podman push --digestfile /tmp/cks-111-hardened.digest "$HARDENED_TAG"
export HARDENED_DIGEST=$(cat /tmp/cks-111-hardened.digest)
export HARDENED_IMAGE="${HARDENED_TAG%:*}@${HARDENED_DIGEST}"
printf '%s\n' "$HARDENED_IMAGE"   # <IP>:5000/catalog@sha256:<manifest-digest>
```

## 4. Corregir el Deployment

`readOnlyRootFilesystem` requiere writable runtime paths de nginx. `emptyDir` los proporciona de forma puntual, solo donde hace falta; el init container (también una hardened image con `USER 101`) copia la default config a un writable config volume aparte. `$HARDENED_IMAGE` es la referencia construida y fijada por digest de la tarea 3, y no la upstream image.

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

## 5. Búsqueda de versiones de paquetes

`--list-all-pkgs` da el inventory real. El registry manifest digest canónico se toma solo de `Metadata.RepoDigests[0]`; `ImageID` y `DiffID` describen la imagen/layers locales y no son un fallback para el registry digest.

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

## 5b. Encontrar la versión de un paquete en las imágenes de workload y eliminar los contenedores problemáticos

```bash
mkdir -p $ART/5b/bom
kubectl -n cks-111 get deployment pkg-audit-app \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name} {.image}{"\n"}{end}'
# c1 <imagen 1> / c2 <imagen 2> / c3 <imagen 3>
```

SBOM de cada imagen (sustituye las imágenes de la salida) y la lista `paquete=versión` de cada una:

```bash
bom generate --format json --output $ART/5b/bom/c1.spdx.json --image <imagen c1>
bom generate --format json --output $ART/5b/bom/c2.spdx.json --image <imagen c2>
bom generate --format json --output $ART/5b/bom/c3.spdx.json --image <imagen c3>
for c in c1 c2 c3; do
  jq -r '.packages[]? | select(.versionInfo) | "\(.name)=\(.versionInfo)"' $ART/5b/bom/$c.spdx.json | sort -u > /tmp/$c.pkgs
done
comm -12 /tmp/c1.pkgs /tmp/c2.pkgs | wc -l     # cuántos paquetes comunes tiene cada pareja de imágenes
comm -12 /tmp/c1.pkgs /tmp/c3.pkgs | wc -l
comm -12 /tmp/c2.pkgs /tmp/c3.pkgs | wc -l
```

Los contenedores de la pareja con paquetes comunes son los offending (digamos, `c1` y `c2`). Tienen
muchos paquetes comunes: sirve **cualquier** `name=version` que no esté en la tercera imagen:

```bash
comm -12 /tmp/c1.pkgs /tmp/c2.pkgs | grep -vxFf /tmp/c3.pkgs | head -3
```

Anota la pareja encontrada y elimina PRECISAMENTE esos dos contenedores (`kubectl edit`), dejando el "limpio":

```bash
printf 'TARGET_PACKAGE=%s\nTARGET_VERSION=%s\n' <name> <version> > $ART/5b/answer.txt     # por ejemplo apt y 3.0.3
cat $ART/5b/answer.txt
kubectl -n cks-111 edit deployment pkg-audit-app        # eliminar los dos contenedores offending
kubectl -n cks-111 rollout status deployment/pkg-audit-app --timeout=120s
```

## 6. SPDX SBOM (bom)

```bash
mkdir -p "$ART/6"
echo "bom generate --format json --output $ART/6/bom.spdx.json --image $IMAGE" > "$ART/6/bom-command.txt"
bom generate --format json --output "$ART/6/bom.spdx.json" --image "$IMAGE"
jq '.spdxVersion, (.packages | length)' "$ART/6/bom.spdx.json"
```

## 7. CycloneDX SBOM (Syft) y Cosign keyless

Syft sabe generar tanto SPDX como CycloneDX; aquí tomamos CycloneDX (`bom` ya dio SPDX en la tarea 6).
Se comprueba la imagen pública de Distroless y su Google workload identity esperada; no
uses `--insecure-ignore-tlog` ni omitas la certificate identity.

```bash
mkdir -p "$ART/7"
# Para una referencia del tipo tag@digest, Syft escribe en metadata.component.version solo el tag; una referencia
# sin tag ("nginx@sha256:...") da version = manifest digest, que es lo que se comprueba.
syft "nginx@${IMAGE#*@}" -o "cyclonedx-json=$ART/7/syft.cdx.json"
```

Tras `syft` espera a que termine y pega los comandos siguientes por separado: `syft` (igual que `apt-get`)
vacía el búfer de entrada del terminal, y las líneas pegadas justo después se pierden.

```bash
jq -r '.metadata.component.version' "$ART/7/syft.cdx.json"   # sha256:<manifest-digest>
cosign verify \
  --certificate-oidc-issuer https://accounts.google.com \
  --certificate-identity keyless@distroless.iam.gserviceaccount.com \
  gcr.io/distroless/static-debian13:nonroot > $ART/7/cosign-verify.txt 2>&1
echo "exit code: $?"      # 0 = firma verificada

# gcr.io/distroless/static:nonroot (sin el sufijo -debian13) se considera deprecated y ya no
# se actualiza según el README oficial de Distroless; usamos el tag vigente
# soportado gcr.io/distroless/static-debian13:nonroot. El éxito de cosign verify
# se determina por el exit code, y no por la cadena literal "Verified OK": esa cadena no está en la
# salida real de cosign (la salida exitosa empieza por la línea "Verification for <image> --"
# y la lista de comprobaciones realizadas). cosign escribe el progreso en stderr, por eso 2>&1
# es obligatorio; de lo contrario el artefacto quedará vacío.
printf '\nreference=gcr.io/distroless/static-debian13:nonroot\n' >> $ART/7/cosign-verify.txt
jq '.bomFormat, (.components | length)' $ART/7/syft.cdx.json
```

## 8. `trivy sbom`: escaneo de un archivo SBOM ya hecho

El CycloneDX SBOM de la tarea 7 describe la composición de componentes y el SO de la imagen, pero no contiene conclusiones sobre
vulnerabilidades; `trivy sbom` acepta ese archivo directamente como entrada, sin volver a acudir al
registry por la propia image.

```bash
mkdir -p $ART/8
echo "trivy sbom --format json --output $ART/8/sbom-scan.json $ART/7/syft.cdx.json" > $ART/8/sbom-scan-command.txt
trivy sbom --format json --output $ART/8/sbom-scan.json $ART/7/syft.cdx.json
jq '{artifact: .ArtifactType, os: .Metadata.OS.Family, results: (.Results | length)}' $ART/8/sbom-scan.json
```

Trivy determina el SO por el componente `operating-system` del CycloneDX (`alpine 3.20.5`) y
contrasta los paquetes con la base de vulnerabilidades: `Results` no vacío. Para comparar: el SPDX de la tarea 6
(`bom`) para una imagen multi-arch no contiene el SO (`Detected OS family="none"`), y `trivy sbom` sobre él
no encuentra nada (`Results` vacío); por eso para esta tarea se toma el CycloneDX.

## 9a. Kyverno e `ImageValidatingPolicy` de trusted signature

Instala Kyverno igual que en el laboratorio 108 y espera a que el admission controller esté listo.

```bash
sudo install-kyverno
```

Pega los siguientes comandos después de terminar la instalación (el instalador vacía el búfer de entrada):

```bash
kubectl -n kyverno get deployment kyverno-admission-controller
kubectl -n kyverno wait --for=condition=Available deployment/kyverno-admission-controller --timeout=180s
```

Genera el par de claves didáctico FUERA de `$ROOT`: este directorio se reutiliza como
Docker build context en la tarea 9c (`COPY . /usr/share/nginx/html` en el Dockerfile copia
TODO el contenido del build context), por lo que un `cosign.key` dejado dentro de `$ROOT` acabará
dentro del image filesystem publicado como una fuga de la private signing key al registry. Firma
precisamente `$HARDENED_IMAGE` de la tarea 3/4, y no el `nginx` upstream. No traslades este
`cosign.key` a un CI de producción.

```bash
export KEYDIR=/home/ubuntu/.cks111-cosign
mkdir -p $KEYDIR $ART/9a $ART/9b $ART/9c
cd $KEYDIR && cosign generate-key-pair && cd $ROOT

# cosign sign escribe el progreso en stderr, por eso 2>&1 es obligatorio; de lo contrario el artefacto quedará vacío.
cosign sign --key $KEYDIR/cosign.key --yes $HARDENED_IMAGE > $ART/9a/cosign-sign.txt 2>&1
cosign verify --key $KEYDIR/cosign.pub $HARDENED_IMAGE > $ART/9a/cosign-verify.txt 2>&1
cat $ART/9a/cosign-verify.txt | head -3
```

Crea la `ImageValidatingPolicy` que se refiere a la clave pública del par cuya clave privada se acaba de usar para
firmar `$HARDENED_IMAGE`. `matchImageReferences` limita la policy exactamente al repository
de tu imagen: para las OCI references hacen falta separadores aparte `:` (tag) y `@` (digest),
de lo contrario el prefijo `${HARDENED_REPO}*` capturaría, por ejemplo, otro repository con el mismo inicio
de nombre. Esto evita que la policy bloquee el resto de los Pod del clúster.

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
    allowInsecureRegistry: true   # el registry del laboratorio funciona por HTTP
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods", "pods/ephemeralcontainers"]
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

Al final ejecuta `check_result` (parcialmente, el test 9a).

## 9b. Fresh signed ALLOW: un Pod nuevo tras crear la policy

Un nuevo `kubectl apply` del Deployment ya existente `catalog` **no demuestra**
el post-policy admission: si el template no cambió, Kubernetes no crea un nuevo
ReplicaSet/Pod, y el `Running` observado puede ser el mismo Pod que existía ya antes de
`require-signed-catalog-images`. Para demostrar precisamente un fresh admission, creamos un objeto **nuevo**
que no existía hasta ese momento:

```bash
POLICY_CREATED=$(kubectl get imagevalidatingpolicy require-signed-catalog-images \
  -o jsonpath='{.metadata.creationTimestamp}')

# Justo después de crear la policy, la primera llamada al webhook de Kyverno (comprobación de la firma en el registry) puede
# toparse con un timeout de 10 s (`failed calling webhook ... context deadline exceeded`): con
# failurePolicy=Fail el Pod entonces no se crea. Simplemente repite el comando al cabo de unos segundos.
kubectl run signed-admission-check -n cks-111 --image=$HARDENED_IMAGE --restart=Never --command -- sleep 3600
kubectl wait --for=condition=Ready pod/signed-admission-check -n cks-111 --timeout=60s

kubectl get pod signed-admission-check -n cks-111 -o json \
  | jq --arg policy "$POLICY_CREATED" '{
      creationTimestamp: .metadata.creationTimestamp,
      policyCreationTimestamp: $policy,
      createdAfterPolicy: (.metadata.creationTimestamp >= $policy),
      image: .spec.containers[0].image,
      phase: .status.phase,
      ready: ([.status.conditions[]? | select(.type == "Ready") | .status] | any(. == "True"))
    }' > "$ART/9b/signed-admission-check.json"
cat "$ART/9b/signed-admission-check.json"
```

Criterio (`creationTimestamp` tiene una precisión de 1 s, por lo que la comparación no es estricta): `createdAfterPolicy == true` y `ready == true`. Esto, y solo esto, demuestra
que precisamente **esta** policy dejó pasar precisamente **este** Pod, que no existía antes, con
una imagen firmada, y no que un Pod antiguo simplemente siga funcionando.

Al final ejecuta `check_result` (parcialmente, el test 9b).

## 9c. Signature-specific DENY: un digest unsigned en el mismo repository

El unsigned candidate debe existir en **el mismo** repository que el `$HARDENED_IMAGE`
firmado; de lo contrario el admission puede rechazar por `manifest unknown` o por un error de
registry lookup, y no por la ausencia de firma, y el denial no demostrará la
security property declarada. Construimos y publicamos un segundo tag, deliberadamente sin firmar, en el mismo
repository, y **obligatoriamente** con un contenido distinto de `$HARDENED_IMAGE`: si se construye
el mismo `Dockerfile`/context sin cambios, un reproducible/cached build puede dar **el mismo**
manifest digest que la imagen ya firmada, y entonces `cosign verify` sobre el tag "unsigned"
pasará inesperadamente, porque físicamente apuntará a un artifact ya firmado. Por eso
introducimos una diferencia controlada mediante `ARG`/`LABEL`, que garantiza que el digest cambie:

```bash
export UNSIGNED_TAG="${HARDENED_TAG%:*}:unsigned-1"
podman build --build-arg CKS_SIGNATURE_TEST=unsigned-1 -t "$UNSIGNED_TAG" "$ROOT"
podman push --digestfile /tmp/cks-111-unsigned.digest "$UNSIGNED_TAG"
export UNSIGNED_DIGEST=$(cat /tmp/cks-111-unsigned.digest)
export UNSIGNED_IMAGE="${HARDENED_REPO}@${UNSIGNED_DIGEST}"
export HARDENED_DIGEST="${HARDENED_IMAGE#*@}"

# Comprobación obligatoria: el unsigned candidate debe ser un artifact físicamente distinto,
# y no el mismo digest que el HARDENED_IMAGE ya firmado.
[ "$UNSIGNED_DIGEST" != "$HARDENED_DIGEST" ] && echo "digests differ: OK"
printf 'hardened_digest=%s\nunsigned_digest=%s\nunsigned_image=%s\ndistinct=true\n' \
  "$HARDENED_DIGEST" "$UNSIGNED_DIGEST" "$UNSIGNED_IMAGE" > "$ART/9c/digest-comparison.txt"
cat "$ART/9c/digest-comparison.txt"
```

El `$ROOT/Dockerfile` de la tarea 3 debe aceptar este build-arg (por ejemplo,
`ARG CKS_SIGNATURE_TEST=signed` y `LABEL cks.signature-test=$CKS_SIGNATURE_TEST` junto a
las instrucciones existentes); entonces la imagen construida difiere de `$HARDENED_IMAGE` exactamente en
un `LABEL` inocuo, sin afectar a las propiedades de seguridad comprobadas en las tareas 3-4.

Demostramos explícitamente que este digest existe y es pullable antes de comprobar la policy;
de lo contrario el denial no demostrará nada. Es una self-check evidence para ti: el checker de la tarea 9c
no se fía de los archivos de texto como única prueba; él mismo resuelve
`unsigned_image` de `digest-comparison.txt`, comprueba por sí mismo la ausencia de firma y
crea por sí mismo un nuevo Pod con esta imagen, por lo que escribir estos archivos a mano sin un admission control
real en funcionamiento no basta para PASS.

```bash
curl -fsSI -H 'Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.v2+json' \
  "http://$REGISTRY/v2/catalog/manifests/$UNSIGNED_DIGEST" > "$ART/9c/unsigned-exists.txt"
cat "$ART/9c/unsigned-exists.txt"        # HTTP/1.1 200 OK y docker-content-digest: $UNSIGNED_DIGEST
```

Demostramos explícitamente la ausencia de una firma válida con esta misma clave, **antes** de intentar crear el
Pod, para que el denial sea previsiblemente específico de la signature, y no de otra cosa:

```bash
cosign verify --key "$KEYDIR/cosign.pub" "$UNSIGNED_IMAGE" > "$ART/9c/unsigned-not-signed.txt" 2>&1
cat "$ART/9c/unsigned-not-signed.txt"     # error: no matching signatures
```

Solo ahora intentamos crear el Pod y confirmamos que el denial se refiere precisamente a la policy/
signature, y no a un error genérico de admission:

```bash
kubectl run catalog-unsigned-probe -n cks-111 --image="$UNSIGNED_IMAGE" --restart=Never > "$ART/9c/admission-deny.txt" 2>&1
cat "$ART/9c/admission-deny.txt"        # ... catalog image must have a valid release signature
kubectl get pod catalog-unsigned-probe -n cks-111       # NotFound: el Pod no se ha creado
```

La diferencia con una comprobación ingenua: si en su lugar hubiéramos tomado un digest de otro repository
(por ejemplo, el digest del `nginx` upstream de la tarea 1), el admission podría haber rechazado por una razón
completamente distinta (`manifest unknown`, ausencia de acceso de pull), y ese denial parecería
"la policy funciona", aunque en realidad la comprobación de signature ni siquiera se alcanzó.

Al final ejecuta `check_result`.

Comprobación final:

```bash
check_result
```
