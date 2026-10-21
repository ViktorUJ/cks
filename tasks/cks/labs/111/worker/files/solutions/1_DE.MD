[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 111 - Referenzlösung

Alle Befehle werden auf dem worker ausgeführt. Das sind gewöhnliche Befehle der Werkzeuge (trivy, kubesec,
kube-linter, hadolint, podman, syft, bom, cosign), die es in der Prüfung gibt; es gibt keine Skripte, wo
mehrere Ergebnisse verglichen werden müssen, geschieht das mit eigenen Augen anhand der Ausgabe. Lege zuerst die gemeinsamen
Variablen fest:

```bash
export ROOT=/home/ubuntu/cks-111 ART=/var/work/tests/artifacts BASE_TAG=nginx:1.27.3-alpine
cd $ROOT
# Der Tag ist veränderlich: Wir erfahren einmal den manifest digest von Trivy und verwenden danach tag@digest.
trivy image --format json $BASE_TAG > /tmp/cks-111-base.json
export IMAGE=$BASE_TAG@$(jq -r '.Metadata.RepoDigests[0]' /tmp/cks-111-base.json | cut -d@ -f2)
echo $IMAGE
```

## 0. Vorbereitung: podman und registry

Zum Bauen und Veröffentlichen von Images wird `podman` verwendet (er steht in der Liste der Werkzeuge der Prüfung;
rootless, läuft als `ubuntu`). Die Registry wurde bereits vom bootstrap hochgefahren: Das ist `registry:2` auf der control-plane
(`<IP des Nodes>:5000`, plain HTTP innerhalb der VPC, Daten auf dem lokalen PV des Nodes). Podman auf dem worker ist
darauf als insecure registry eingestellt (`/etc/containers/registries.conf.d/cks111.conf`), containerd auf dem
Node - ebenfalls, daher wird das Flag `--tls-verify=false` nicht gebraucht. Die Images der Lab sind vorab in einen lokalen
Cache geladen, den Trivy und Syft verwenden, daher stoßen wiederholte Scans nicht an das Limit von Docker Hub.

Adresse der Registry:

```bash
export REGISTRY="$(cat /etc/cks111/registry)"     # <IP der control-plane>:5000
curl -fsS "http://$REGISTRY/v2/" && echo " registry ok: $REGISTRY"
podman --version
```

Das Passwort des cosign-Schlüssels lassen wir leer, damit die Befehle nicht auf Eingabe warten:

```bash
export COSIGN_PASSWORD=""
```

Die Registry arbeitet über HTTP: Den digest des veröffentlichten Images holen wir aus `podman push --digestfile`, und
die Existenz des Manifests prüfen wir mit einer Anfrage an `/v2/`. `cosign` verwendet für Adressen privater Netze selbst HTTP; für Kyverno wird in der policy `credentials.allowInsecureRegistry: true` gesetzt. `bom` liest
Images nur aus der Registry und wendet sich daher weiterhin an Docker Hub; wenn du
`TOOMANYREQUESTS` siehst, warte oder führe `podman login docker.io` mit deinem eigenen Konto aus.

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
source ~/cks-111/candidates.txt
trivy image --scanners vuln --format json --output /tmp/cand1.json $CANDIDATE_1
trivy image --scanners vuln --format json --output /tmp/cand2.json $CANDIDATE_2
trivy image --scanners vuln --format json --output /tmp/cand3.json $CANDIDATE_3
grep -l $TARGET_CVE /tmp/cand?.json        # welcher Bericht TARGET_CVE enthält
```

Nehmen wir an, es ist `/tmp/cand1.json` (setze deine Nummer ein):

```bash
mkdir -p $ART/1b
cp /tmp/cand1.json $ART/1b/target-scan.json
echo "OFFENDING_IMAGE=$CANDIDATE_1" > $ART/1b/answer.txt
cat $ART/1b/answer.txt
# OFFENDING_IMAGE=python:3.9-slim@sha256:...
```

## 1c. Workload image triage nach CRITICAL severity

Die Images nehmen wir aus LIVE Deployments und scannen jedes; die Anzahl der eindeutigen CRITICAL wird neben dem
Namen des Deployments ausgegeben:

```bash
mkdir -p $ART/1c
kubectl -n cks-111 get deployment -l cks.io/task=1c \
  -o jsonpath='{range .items[*]}{.metadata.name} {.spec.template.spec.containers[0].image}{"\n"}{end}' |
while read name ref; do
  trivy image --scanners vuln --severity CRITICAL --format json --output /tmp/$name.json $ref
  echo "$name $(jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | unique | length' /tmp/$name.json)"
done
```

Finde in der Ausgabe das Deployment mit der größten Anzahl (das verwundbarste) und die zwei mit der geringsten. Schreibe die
Namen in `ranking.txt` (statt `dep-a`, `dep-b`, `dep-c` - deine Namen):

```bash
cat > $ART/1c/ranking.txt <<EOF
MOST_VULNERABLE=dep-a
LEAST_VULNERABLE_1=dep-b
LEAST_VULNERABLE_2=dep-c
EOF
# dep-d - das vierte Deployment (das zweite nach der Anzahl CRITICAL), es wird nicht in ranking.txt geschrieben
```

CycloneDX SBOM des verwundbarsten Deployments (das Image aus seinem Deployment) und scale der übrigen:

```bash
kubectl -n cks-111 get deployment dep-a -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
trivy image --format cyclonedx --output $ART/1c/cyclonedx.json <Image aus der obigen Ausgabe>
kubectl -n cks-111 scale deployment dep-a --replicas=0      # das verwundbarste
kubectl -n cks-111 scale deployment dep-d --replicas=0      # das vierte (gehört nicht zu den zwei am wenigsten verwundbaren)
kubectl -n cks-111 get deployment -l cks.io/task=1c
```

## 2. Berichte vor der Korrektur

`hadolint`, `kubesec` und `kube-linter` geben bei findings einen Status ungleich null zurück; das ist das erwartete
Ergebnis, der Bericht wird so gespeichert, wie er ist.

```bash
mkdir -p $ART/2
hadolint $ROOT/Dockerfile > $ART/2/hadolint-before.txt
kubesec scan $ROOT/deployment.yaml > $ART/2/kubesec-before.json
kube-linter lint $ROOT/deployment.yaml --format json > $ART/2/kube-linter-before.json
jq '.[0].scoring' $ART/2/kubesec-before.json
jq '{summary: .Summary, findings: (.Reports | length)}' $ART/2/kube-linter-before.json
```

## 3. Dockerfile korrigieren

Füge kein Secret in den image layer ein und verwende keinen floating tag: Verwende `$IMAGE`, bei dem der tag um den manifest digest ergänzt ist. `USER 101` ist eine Eigenschaft des künftigen hardened image.

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
# Ein sauberes Dockerfile ergibt eine LEERE Ausgabe von hadolint (Rückgabecode 0) - eine leere Datei ist hier erwartet und korrekt.
grep -nE '^(FROM|COPY|USER)' "$ROOT/Dockerfile"
```

`ARG CKS_SIGNATURE_TEST`/`LABEL cks.signature-test` ändern keine der hier geprüften
security-Eigenschaften (base image, non-root, Fehlen von Secrets) - das ist der einzige Punkt eines
kontrollierten Unterschieds, der in Aufgabe 9c einen anderen manifest digest garantiert, ohne
den Rest des Dockerfile zu überarbeiten.

Baue das Image und **veröffentliche** es in einer für Kubernetes erreichbaren Registry; eine lokale image ID/DiffID allein passt nicht für digest pinning. Setze dein repository ein, hole dann den registry manifest digest und bilde die immutable reference:

```bash
export HARDENED_TAG="$REGISTRY/catalog:1.0"
podman build -t "$HARDENED_TAG" "$ROOT"
podman push --digestfile /tmp/cks-111-hardened.digest "$HARDENED_TAG"
export HARDENED_DIGEST=$(cat /tmp/cks-111-hardened.digest)
export HARDENED_IMAGE="${HARDENED_TAG%:*}@${HARDENED_DIGEST}"
printf '%s\n' "$HARDENED_IMAGE"   # <IP>:5000/catalog@sha256:<manifest-digest>
```

## 4. Deployment korrigieren

`readOnlyRootFilesystem` erfordert beschreibbare runtime-Pfade von nginx. `emptyDir` liefert sie gezielt; der init container (ebenfalls ein hardened image mit `USER 101`) kopiert die default config in ein separates beschreibbares config volume. `$HARDENED_IMAGE` ist die in Aufgabe 3 gebaute und digest-pinned Referenz, kein upstream image.

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

## 5. Suche nach Paketversionen

`--list-all-pkgs` liefert das tatsächliche Inventory. Der kanonische registry manifest digest wird nur aus `Metadata.RepoDigests[0]` genommen; `ImageID` und `DiffID` beschreiben das lokale Image/die layers und sind kein fallback für den registry digest.

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
mkdir -p $ART/5b/bom
kubectl -n cks-111 get deployment pkg-audit-app \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name} {.image}{"\n"}{end}'
# c1 <Image 1> / c2 <Image 2> / c3 <Image 3>
```

SBOM jedes Images (setze die Images aus der Ausgabe ein) und eine Liste `Paket=Version` für jedes:

```bash
bom generate --format json --output $ART/5b/bom/c1.spdx.json --image <Image von c1>
bom generate --format json --output $ART/5b/bom/c2.spdx.json --image <Image von c2>
bom generate --format json --output $ART/5b/bom/c3.spdx.json --image <Image von c3>
for c in c1 c2 c3; do
  jq -r '.packages[]? | select(.versionInfo) | "\(.name)=\(.versionInfo)"' $ART/5b/bom/$c.spdx.json | sort -u > /tmp/$c.pkgs
done
comm -12 /tmp/c1.pkgs /tmp/c2.pkgs | wc -l     # wie viele gemeinsame Pakete jedes Paar von Images hat
comm -12 /tmp/c1.pkgs /tmp/c3.pkgs | wc -l
comm -12 /tmp/c2.pkgs /tmp/c3.pkgs | wc -l
```

Das Paar mit den gemeinsamen Paketen sind die offending Container (nehmen wir an, `c1` und `c2`). Sie haben viele
gemeinsame Pakete: **Jedes** `name=version`, das im dritten Image fehlt, passt:

```bash
comm -12 /tmp/c1.pkgs /tmp/c2.pkgs | grep -vxFf /tmp/c3.pkgs | head -3
```

Schreibe das gefundene Paar auf und entferne GENAU diese zwei Container (`kubectl edit`), sodass der "saubere" übrig bleibt:

```bash
printf 'TARGET_PACKAGE=%s\nTARGET_VERSION=%s\n' <name> <version> > $ART/5b/answer.txt     # zum Beispiel apt und 3.0.3
cat $ART/5b/answer.txt
kubectl -n cks-111 edit deployment pkg-audit-app        # die zwei offending Container löschen
kubectl -n cks-111 rollout status deployment/pkg-audit-app --timeout=120s
```

## 6. SPDX SBOM (bom)

```bash
mkdir -p "$ART/6"
echo "bom generate --format json --output $ART/6/bom.spdx.json --image $IMAGE" > "$ART/6/bom-command.txt"
bom generate --format json --output "$ART/6/bom.spdx.json" --image "$IMAGE"
jq '.spdxVersion, (.packages | length)' "$ART/6/bom.spdx.json"
```

## 7. CycloneDX SBOM (Syft) und keyless Cosign

Syft beherrscht sowohl SPDX als auch CycloneDX; hier nehmen wir CycloneDX (`bom` hat bereits in Aufgabe 6 SPDX geliefert).
Geprüft werden das öffentliche Distroless-Image und seine erwartete Google workload identity; verwende
nicht `--insecure-ignore-tlog` und überspringe nicht die certificate identity.

```bash
mkdir -p "$ART/7"
# Bei einer Referenz der Form tag@digest schreibt Syft in metadata.component.version nur den tag; eine Referenz
# ohne tag ("nginx@sha256:...") ergibt version = manifest digest, und gerade er wird geprüft.
syft "nginx@${IMAGE#*@}" -o "cyclonedx-json=$ART/7/syft.cdx.json"
```

Warte nach `syft` auf das Ende und füge die weiteren Befehle separat ein: `syft` (wie auch `apt-get`)
leert den Eingabepuffer des Terminals, und unmittelbar danach eingefügte Zeilen gehen verloren.

```bash
jq -r '.metadata.component.version' "$ART/7/syft.cdx.json"   # sha256:<manifest-digest>
cosign verify \
  --certificate-oidc-issuer https://accounts.google.com \
  --certificate-identity keyless@distroless.iam.gserviceaccount.com \
  gcr.io/distroless/static-debian13:nonroot > $ART/7/cosign-verify.txt 2>&1
echo "exit code: $?"      # 0 = Signatur geprüft

# gcr.io/distroless/static:nonroot (ohne das Suffix -debian13) gilt als deprecated und wird laut
# dem offiziellen README von Distroless nicht mehr aktualisiert - wir verwenden den aktuell
# unterstützten Tag gcr.io/distroless/static-debian13:nonroot. Der Erfolg von cosign verify
# wird am exit code bestimmt und nicht an der literalen Zeile "Verified OK" - eine solche Zeile gibt es in der
# echten Ausgabe von cosign nicht (die erfolgreiche Ausgabe beginnt mit der Zeile "Verification for <image> --"
# und einer Liste der ausgeführten Prüfungen). cosign schreibt den Verlauf nach stderr, daher ist 2>&1
# Pflicht - sonst bleibt das artifact leer.
printf '\nreference=gcr.io/distroless/static-debian13:nonroot\n' >> $ART/7/cosign-verify.txt
jq '.bomFormat, (.components | length)' $ART/7/syft.cdx.json
```

## 8. `trivy sbom`: Scan einer fertigen SBOM-Datei

Das CycloneDX SBOM aus Aufgabe 7 beschreibt die Zusammensetzung der Komponenten und des OS des Images, enthält aber keine Aussage zu
Schwachstellen; `trivy sbom` nimmt eine solche Datei direkt als Eingabe, ohne sich erneut an die
Registry für das Image selbst zu wenden.

```bash
mkdir -p $ART/8
echo "trivy sbom --format json --output $ART/8/sbom-scan.json $ART/7/syft.cdx.json" > $ART/8/sbom-scan-command.txt
trivy sbom --format json --output $ART/8/sbom-scan.json $ART/7/syft.cdx.json
jq '{artifact: .ArtifactType, os: .Metadata.OS.Family, results: (.Results | length)}' $ART/8/sbom-scan.json
```

Trivy erkennt das OS anhand der Komponente `operating-system` aus CycloneDX (`alpine 3.20.5`) und
gleicht die Pakete mit der Schwachstellendatenbank ab - `Results` ist nicht leer. Zum Vergleich: Das SPDX aus Aufgabe 6
(`bom`) enthält für ein multi-arch Image kein OS (`Detected OS family="none"`), und `trivy sbom` findet damit
nichts (`Results` ist leer) - deshalb wird für diese Aufgabe CycloneDX genommen.

## 9a. Kyverno und `ImageValidatingPolicy` auf trusted signature

Installiere Kyverno genauso wie in Lab 108 und warte auf die Bereitschaft des admission controller.

```bash
sudo install-kyverno
```

Füge die folgenden Befehle nach Abschluss der Installation ein (der installer leert den Eingabepuffer):

```bash
kubectl -n kyverno get deployment kyverno-admission-controller
kubectl -n kyverno wait --for=condition=Available deployment/kyverno-admission-controller --timeout=180s
```

Erzeuge das Lern-Schlüsselpaar AUSSERHALB von `$ROOT` - dieses Verzeichnis wird in Aufgabe 9c erneut als
Docker build context verwendet (`COPY . /usr/share/nginx/html` im Dockerfile kopiert
ALLES aus dem build context), daher gelangt ein in `$ROOT` zurückgelassenes `cosign.key`
in das Dateisystem des veröffentlichten Images, als Leck des private signing key in die Registry. Signiere
gerade `$HARDENED_IMAGE` aus Aufgabe 3/4 und nicht das upstream `nginx`. Übertrage dieses
`cosign.key` nicht in eine production CI.

```bash
export KEYDIR=/home/ubuntu/.cks111-cosign
mkdir -p $KEYDIR $ART/9a $ART/9b $ART/9c
cd $KEYDIR && cosign generate-key-pair && cd $ROOT

# cosign sign schreibt den Verlauf nach stderr, daher ist 2>&1 Pflicht - sonst bleibt das artifact leer.
cosign sign --key $KEYDIR/cosign.key --yes $HARDENED_IMAGE > $ART/9a/cosign-sign.txt 2>&1
cosign verify --key $KEYDIR/cosign.pub $HARDENED_IMAGE > $ART/9a/cosign-verify.txt 2>&1
cat $ART/9a/cosign-verify.txt | head -3
```

Erstelle die `ImageValidatingPolicy`, die auf den öffentlichen Schlüssel verweist, mit dem gerade
`$HARDENED_IMAGE` signiert wurde. `matchImageReferences` begrenzt die policy genau auf das repository
deines Images: Für OCI references braucht man getrennte Trennzeichen `:` (tag) und `@` (digest),
sonst erfasst das Präfix `${HARDENED_REPO}*` zum Beispiel ein anderes repository mit demselben Anfang
des Namens. Das verhindert, dass die policy die übrigen Pods des Clusters blockiert.

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
    allowInsecureRegistry: true   # die Registry der Lab arbeitet über HTTP
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

Führe zum Schluss `check_result` aus (teilweise, Test 9a).

## 9b. Fresh signed ALLOW: neuer Pod nach dem Erstellen der policy

Ein erneutes `kubectl apply` des bereits vorhandenen Deployments `catalog` **beweist** die
post-policy admission **nicht**: Wenn sich das template nicht geändert hat, erstellt Kubernetes kein neues
ReplicaSet/Pod, und das beobachtete `Running` kann derselbe Pod sein, der schon vor
`require-signed-catalog-images` existierte. Um gerade die fresh admission zu belegen, erstellen wir ein **neues**
Objekt, das es bis zu diesem Moment nicht gab:

```bash
POLICY_CREATED=$(kubectl get imagevalidatingpolicy require-signed-catalog-images \
  -o jsonpath='{.metadata.creationTimestamp}')

# Unmittelbar nach dem Erstellen der policy kann der erste Aufruf des Kyverno-webhook (Prüfung der Signatur in der Registry)
# an das Timeout von 10 s stoßen (`failed calling webhook ... context deadline exceeded`): Bei
# failurePolicy=Fail wird der Pod dann nicht erstellt. Wiederhole den Befehl einfach nach ein paar Sekunden.
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

Kriterium (`creationTimestamp` hat eine Genauigkeit von 1 s, daher ist der Vergleich nicht strikt): `createdAfterPolicy == true` und `ready == true`. Das - und nur das - belegt,
dass gerade **diese** policy gerade **diesen** zuvor nicht existierenden Pod mit einem
signierten Image durchgelassen hat und nicht, dass ein alter Pod einfach weiterläuft.

Führe zum Schluss `check_result` aus (teilweise, Test 9b).

## 9c. Signature-specific DENY: unsigned digest im selben repository

Der unsigned candidate muss im **selben** repository existieren wie das signierte
`$HARDENED_IMAGE` - sonst kann admission wegen `manifest unknown` oder eines Fehlers beim
registry lookup ablehnen und nicht wegen des Fehlens einer Signatur, und das denial belegt die behauptete
security property nicht. Wir bauen und veröffentlichen einen zweiten, bewusst unsignierten tag im selben
repository - und **unbedingt** mit einem Inhalt, der sich von `$HARDENED_IMAGE` unterscheidet: Wenn man
dasselbe `Dockerfile`/denselben context ohne Änderungen baut, kann ein reproducible/cached build **denselben**
manifest digest ergeben wie das bereits signierte Image, und dann besteht `cosign verify` auf den "unsigned" Tag
unerwartet - weil er physisch auf ein bereits signiertes artifact zeigt. Daher
führen wir über `ARG`/`LABEL` einen kontrollierten Unterschied ein, der den digest garantiert ändert:

```bash
export UNSIGNED_TAG="${HARDENED_TAG%:*}:unsigned-1"
podman build --build-arg CKS_SIGNATURE_TEST=unsigned-1 -t "$UNSIGNED_TAG" "$ROOT"
podman push --digestfile /tmp/cks-111-unsigned.digest "$UNSIGNED_TAG"
export UNSIGNED_DIGEST=$(cat /tmp/cks-111-unsigned.digest)
export UNSIGNED_IMAGE="${HARDENED_REPO}@${UNSIGNED_DIGEST}"
export HARDENED_DIGEST="${HARDENED_IMAGE#*@}"

# Obligatorische Prüfung: Der unsigned candidate muss ein physisch anderes artifact sein
# und nicht derselbe digest wie das bereits signierte HARDENED_IMAGE.
[ "$UNSIGNED_DIGEST" != "$HARDENED_DIGEST" ] && echo "digests differ: OK"
printf 'hardened_digest=%s\nunsigned_digest=%s\nunsigned_image=%s\ndistinct=true\n' \
  "$HARDENED_DIGEST" "$UNSIGNED_DIGEST" "$UNSIGNED_IMAGE" > "$ART/9c/digest-comparison.txt"
cat "$ART/9c/digest-comparison.txt"
```

Das `$ROOT/Dockerfile` aus Aufgabe 3 muss dieses build-arg akzeptieren (zum Beispiel
`ARG CKS_SIGNATURE_TEST=signed` und `LABEL cks.signature-test=$CKS_SIGNATURE_TEST` neben den
vorhandenen Anweisungen) - dann unterscheidet sich das gebaute Image von `$HARDENED_IMAGE` genau
durch ein sicheres Label, ohne die in den Aufgaben 3-4 geprüften security-Eigenschaften zu berühren.

Wir belegen explizit, dass dieser digest existiert und pullable ist, bevor wir die policy prüfen -
sonst beweist das denial nichts. Das ist self-check evidence für dich: Der Checker für Aufgabe 9c
vertraut Textdateien nicht als einzigem Nachweis - er löst `unsigned_image` aus `digest-comparison.txt`
selbst auf, prüft selbst das Fehlen der Signatur und erstellt selbst einen neuen Pod mit diesem Image, daher reicht es
nicht für PASS, diese Dateien von Hand ohne eine echte
funktionierende admission control zu schreiben.

```bash
curl -fsSI -H 'Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.v2+json' \
  "http://$REGISTRY/v2/catalog/manifests/$UNSIGNED_DIGEST" > "$ART/9c/unsigned-exists.txt"
cat "$ART/9c/unsigned-exists.txt"        # HTTP/1.1 200 OK und docker-content-digest: $UNSIGNED_DIGEST
```

Wir belegen explizit das Fehlen einer gültigen Signatur mit demselben Schlüssel - **vor** dem Versuch, den
Pod zu erstellen, damit das denial vorhersehbar spezifisch für die signature ist und nicht für etwas anderes:

```bash
cosign verify --key "$KEYDIR/cosign.pub" "$UNSIGNED_IMAGE" > "$ART/9c/unsigned-not-signed.txt" 2>&1
cat "$ART/9c/unsigned-not-signed.txt"     # error: no matching signatures
```

Erst jetzt versuchen wir, den Pod zu erstellen, und bestätigen, dass das denial gerade auf die policy/
signature verweist und nicht auf einen generischen admission-Fehler:

```bash
kubectl run catalog-unsigned-probe -n cks-111 --image="$UNSIGNED_IMAGE" --restart=Never > "$ART/9c/admission-deny.txt" 2>&1
cat "$ART/9c/admission-deny.txt"        # ... catalog image must have a valid release signature
kubectl get pod catalog-unsigned-probe -n cks-111       # NotFound: Der Pod wurde nicht erstellt
```

Unterschied zur naiven Prüfung: Wenn wir stattdessen den digest aus einem anderen repository genommen hätten
(zum Beispiel den digest des upstream `nginx` aus Aufgabe 1), hätte admission aus einem völlig
anderen Grund ablehnen können (`manifest unknown`, fehlender pull-Zugriff) - und ein solches denial hätte
ausgesehen wie "die policy funktioniert", obwohl die Prüfung der signature in Wirklichkeit gar nicht erreicht wurde.

Führe zum Schluss `check_result` aus.

Abschließende Prüfung:

```bash
check_result
```
