[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 111 - solution de référence

Toutes les commandes s'exécutent sur le worker. Ce sont des commandes ordinaires des outils (trivy, kubesec,
kube-linter, hadolint, podman, syft, bom, cosign) présents à l'examen ; il n'y a pas de scripts ; là où
il faut comparer plusieurs résultats, cela se fait à l'œil sur la sortie. Définissez d'abord les
variables communes :

```bash
export ROOT=/home/ubuntu/cks-111 ART=/var/work/tests/artifacts BASE_TAG=nginx:1.27.3-alpine
cd $ROOT
# Le tag est mutable : on récupère une seule fois le manifest digest via Trivy, puis on utilise tag@digest.
trivy image --format json $BASE_TAG > /tmp/cks-111-base.json
export IMAGE=$BASE_TAG@$(jq -r '.Metadata.RepoDigests[0]' /tmp/cks-111-base.json | cut -d@ -f2)
echo $IMAGE
```

## 0. Préparation : podman et registry

Pour construire et publier des images, on utilise `podman` (il figure dans la liste des outils de l'examen ;
rootless, s'exécute sous l'utilisateur `ubuntu`). Le registry a déjà été déployé par le bootstrap : c'est `registry:2` sur le control-plane
(`<IP du nœud>:5000`, HTTP simple dans le VPC, données sur un PV local du nœud). Podman sur le worker est configuré
pour l'utiliser comme insecure registry (`/etc/containers/registries.conf.d/cks111.conf`), containerd sur le
nœud aussi, c'est pourquoi le flag `--tls-verify=false` n'est pas nécessaire. Les images du lab sont téléchargées à l'avance dans un cache
local utilisé par Trivy et Syft, de sorte que les scans répétés ne se heurtent pas à la limite de Docker Hub.

Adresse du registry :

```bash
export REGISTRY="$(cat /etc/cks111/registry)"     # <IP control-plane>:5000
curl -fsS "http://$REGISTRY/v2/" && echo " registry ok: $REGISTRY"
podman --version
```

Nous laissons le mot de passe de la clé cosign vide, afin que les commandes n'attendent pas de saisie :

```bash
export COSIGN_PASSWORD=""
```

Le registry fonctionne en HTTP : le digest de l'image publiée, nous l'obtenons à partir de `podman push --digestfile`, et
existence du manifest, nous la vérifions par une requête à `/v2/`. `cosign` utilise lui-même HTTP pour les adresses de
réseaux privés ; pour Kyverno, dans la policy on définit `credentials.allowInsecureRegistry: true`. `bom` lit
les images uniquement depuis le registry, il s'adresse donc toujours à Docker Hub ; si vous voyez
`TOOMANYREQUESTS`, patientez ou exécutez `podman login docker.io` avec votre propre compte.

## 1. Rapport Trivy

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
grep -l $TARGET_CVE /tmp/cand?.json        # quel rapport contient TARGET_CVE
```

Supposons que ce soit `/tmp/cand1.json` (remplacez par votre numéro) :

```bash
mkdir -p $ART/1b
cp /tmp/cand1.json $ART/1b/target-scan.json
echo "OFFENDING_IMAGE=$CANDIDATE_1" > $ART/1b/answer.txt
cat $ART/1b/answer.txt
# OFFENDING_IMAGE=python:3.9-slim@sha256:...
```

## 1c. Analyse des images de workload par niveau CRITICAL

Nous prenons les images des Deployments LIVE et scannons chacune ; le nombre de CRITICAL uniques est affiché à côté du
nom du Deployment :

```bash
mkdir -p $ART/1c
kubectl -n cks-111 get deployment -l cks.io/task=1c \
  -o jsonpath='{range .items[*]}{.metadata.name} {.spec.template.spec.containers[0].image}{"\n"}{end}' |
while read name ref; do
  trivy image --scanners vuln --severity CRITICAL --format json --output /tmp/$name.json $ref
  echo "$name $(jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | unique | length' /tmp/$name.json)"
done
```

D'après la sortie, trouvez le Deployment avec le plus grand nombre (le plus vulnérable) et les deux avec le plus petit. Notez
les noms dans `ranking.txt` (à la place de `dep-a`, `dep-b`, `dep-c` - vos noms) :

```bash
cat > $ART/1c/ranking.txt <<EOF
MOST_VULNERABLE=dep-a
LEAST_VULNERABLE_1=dep-b
LEAST_VULNERABLE_2=dep-c
EOF
# dep-d est le quatrième Deployment (le deuxième par nombre de CRITICAL), il n'est pas noté dans ranking.txt
```

CycloneDX SBOM du Deployment le plus vulnérable (l'image de son Deployment) et scale des autres :

```bash
kubectl -n cks-111 get deployment dep-a -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
trivy image --format cyclonedx --output $ART/1c/cyclonedx.json <image de la sortie ci-dessus>
kubectl -n cks-111 scale deployment dep-a --replicas=0      # le plus vulnérable
kubectl -n cks-111 scale deployment dep-d --replicas=0      # le quatrième (n'entre pas dans les deux moins vulnérables)
kubectl -n cks-111 get deployment -l cks.io/task=1c
```

## 2. Rapports avant la correction

`hadolint`, `kubesec` et `kube-linter` renvoient un statut non nul en cas de findings ; c'est le résultat
attendu, le rapport est enregistré tel quel.

```bash
mkdir -p $ART/2
hadolint $ROOT/Dockerfile > $ART/2/hadolint-before.txt
kubesec scan $ROOT/deployment.yaml > $ART/2/kubesec-before.json
kube-linter lint $ROOT/deployment.yaml --format json > $ART/2/kube-linter-before.json
jq '.[0].scoring' $ART/2/kubesec-before.json
jq '{summary: .Summary, findings: (.Reports | length)}' $ART/2/kube-linter-before.json
```

## 3. Corriger le Dockerfile

N'ajoutez pas de secret à un image layer et n'utilisez pas de floating tag : utilisez `$IMAGE`, dans lequel le tag est complété par le manifest digest. `USER 101` est une propriété de la future hardened image.

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
# Un Dockerfile propre donne une sortie de hadolint VIDE (code de retour 0) : un fichier vide ici est attendu et correct.
grep -nE '^(FROM|COPY|USER)' "$ROOT/Dockerfile"
```

`ARG CKS_SIGNATURE_TEST`/`LABEL cks.signature-test` ne changent aucune des propriétés de
sécurité vérifiées ici (base image, non-root, absence de secret) - c'est l'unique point de
différence contrôlée qui, dans la tâche 9c, garantit un autre manifest digest sans
revoir le reste du Dockerfile.

Construisez et **publiez** l'image dans un registry accessible à Kubernetes ; un local image ID/DiffID à lui seul ne convient pas pour le digest pinning. Remplacez par votre repository, puis obtenez le registry manifest digest et constituez l'immutable reference :

```bash
export HARDENED_TAG="$REGISTRY/catalog:1.0"
podman build -t "$HARDENED_TAG" "$ROOT"
podman push --digestfile /tmp/cks-111-hardened.digest "$HARDENED_TAG"
export HARDENED_DIGEST=$(cat /tmp/cks-111-hardened.digest)
export HARDENED_IMAGE="${HARDENED_TAG%:*}@${HARDENED_DIGEST}"
printf '%s\n' "$HARDENED_IMAGE"   # <IP>:5000/catalog@sha256:<manifest-digest>
```

## 4. Corriger le Deployment

`readOnlyRootFilesystem` nécessite des writable runtime paths de nginx. `emptyDir` les fournit de façon ciblée ; l'init container (aussi une hardened image avec `USER 101`) copie la default config dans un writable config volume distinct. `$HARDENED_IMAGE` est la référence construite et épinglée par digest de la tâche 3, et non l'upstream image.

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

## 5. Recherche de versions de paquets

`--list-all-pkgs` donne l'inventory réel. Le registry manifest digest canonique est obtenu uniquement à partir de `Metadata.RepoDigests[0]` ; `ImageID` et `DiffID` décrivent l'image/layers locaux et ne sont pas un fallback pour le registry digest.

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

## 5b. Trouver la version d'un paquet dans les images de workload et supprimer les conteneurs problématiques

```bash
mkdir -p $ART/5b/bom
kubectl -n cks-111 get deployment pkg-audit-app \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name} {.image}{"\n"}{end}'
# c1 <image 1> / c2 <image 2> / c3 <image 3>
```

SBOM de chaque image (insérez les images issues de la sortie) et la liste `paquet=version` de chacune :

```bash
bom generate --format json --output $ART/5b/bom/c1.spdx.json --image <image c1>
bom generate --format json --output $ART/5b/bom/c2.spdx.json --image <image c2>
bom generate --format json --output $ART/5b/bom/c3.spdx.json --image <image c3>
for c in c1 c2 c3; do
  jq -r '.packages[]? | select(.versionInfo) | "\(.name)=\(.versionInfo)"' $ART/5b/bom/$c.spdx.json | sort -u > /tmp/$c.pkgs
done
comm -12 /tmp/c1.pkgs /tmp/c2.pkgs | wc -l     # combien de paquets communs a chaque paire d'images
comm -12 /tmp/c1.pkgs /tmp/c3.pkgs | wc -l
comm -12 /tmp/c2.pkgs /tmp/c3.pkgs | wc -l
```

La paire avec des paquets communs est celle des conteneurs offending (disons, `c1` et `c2`). Ils ont
beaucoup de paquets communs : **n'importe quel** `name=version` qui n'est pas dans la troisième image convient :

```bash
comm -12 /tmp/c1.pkgs /tmp/c2.pkgs | grep -vxFf /tmp/c3.pkgs | head -3
```

Notez la paire trouvée et supprimez PRÉCISÉMENT ces deux conteneurs (`kubectl edit`), en laissant le « propre » :

```bash
printf 'TARGET_PACKAGE=%s\nTARGET_VERSION=%s\n' <name> <version> > $ART/5b/answer.txt     # par exemple apt et 3.0.3
cat $ART/5b/answer.txt
kubectl -n cks-111 edit deployment pkg-audit-app        # supprimer les deux conteneurs offending
kubectl -n cks-111 rollout status deployment/pkg-audit-app --timeout=120s
```

## 6. SPDX SBOM (bom)

```bash
mkdir -p "$ART/6"
echo "bom generate --format json --output $ART/6/bom.spdx.json --image $IMAGE" > "$ART/6/bom-command.txt"
bom generate --format json --output "$ART/6/bom.spdx.json" --image "$IMAGE"
jq '.spdxVersion, (.packages | length)' "$ART/6/bom.spdx.json"
```

## 7. CycloneDX SBOM (Syft) et Cosign keyless

Syft sait faire à la fois SPDX et CycloneDX ; ici nous prenons CycloneDX (`bom` a déjà donné du SPDX dans la tâche 6).
On vérifie l'image publique de Distroless et sa Google workload identity attendue ; n'utilisez
pas `--insecure-ignore-tlog` et n'omettez pas la certificate identity.

```bash
mkdir -p "$ART/7"
# Pour une référence de la forme tag@digest, Syft écrit dans metadata.component.version uniquement le tag ; une référence
# sans tag ("nginx@sha256:...") donne version = manifest digest, ce qui est précisément vérifié.
syft "nginx@${IMAGE#*@}" -o "cyclonedx-json=$ART/7/syft.cdx.json"
```

Après `syft`, attendez la fin et collez les commandes suivantes séparément : `syft` (comme `apt-get`)
vide le tampon d'entrée du terminal, et les lignes collées juste après sont perdues.

```bash
jq -r '.metadata.component.version' "$ART/7/syft.cdx.json"   # sha256:<manifest-digest>
cosign verify \
  --certificate-oidc-issuer https://accounts.google.com \
  --certificate-identity keyless@distroless.iam.gserviceaccount.com \
  gcr.io/distroless/static-debian13:nonroot > $ART/7/cosign-verify.txt 2>&1
echo "exit code: $?"      # 0 = signature vérifiée

# gcr.io/distroless/static:nonroot (sans le suffixe -debian13) est considéré comme deprecated et n'est plus
# mis à jour d'après le README officiel de Distroless - nous utilisons le tag actuel
# pris en charge gcr.io/distroless/static-debian13:nonroot. Le succès de cosign verify
# se détermine par l'exit code, et non par la chaîne littérale "Verified OK" - cette chaîne n'existe pas dans la
# sortie réelle de cosign (la sortie réussie commence par la ligne "Verification for <image> --"
# et la liste des vérifications effectuées). cosign écrit le déroulement dans stderr, c'est pourquoi 2>&1
# est obligatoire - sinon l'artefact restera vide.
printf '\nreference=gcr.io/distroless/static-debian13:nonroot\n' >> $ART/7/cosign-verify.txt
jq '.bomFormat, (.components | length)' $ART/7/syft.cdx.json
```

## 8. `trivy sbom` : scan d'un fichier SBOM déjà prêt

Le CycloneDX SBOM de la tâche 7 décrit la composition des composants et l'OS de l'image, mais ne contient pas de conclusions sur
les vulnérabilités ; `trivy sbom` accepte un tel fichier directement en entrée, sans s'adresser de nouveau au
registry pour l'image elle-même.

```bash
mkdir -p $ART/8
echo "trivy sbom --format json --output $ART/8/sbom-scan.json $ART/7/syft.cdx.json" > $ART/8/sbom-scan-command.txt
trivy sbom --format json --output $ART/8/sbom-scan.json $ART/7/syft.cdx.json
jq '{artifact: .ArtifactType, os: .Metadata.OS.Family, results: (.Results | length)}' $ART/8/sbom-scan.json
```

Trivy détermine l'OS d'après le composant `operating-system` du CycloneDX (`alpine 3.20.5`) et
met en correspondance les paquets avec la base de vulnérabilités - `Results` non vide. Pour comparaison : le SPDX de la tâche 6
(`bom`) pour une image multi-arch ne contient pas l'OS (`Detected OS family="none"`), et `trivy sbom` sur lui
ne trouve rien (`Results` vide) - c'est pourquoi, pour cette tâche, on prend le CycloneDX.

## 9a. Kyverno et `ImageValidatingPolicy` de trusted signature

Installez Kyverno comme dans le lab 108 et attendez que l'admission controller soit prêt.

```bash
sudo install-kyverno
```

Collez les commandes suivantes après la fin de l'installation (l'installateur vide le tampon d'entrée) :

```bash
kubectl -n kyverno get deployment kyverno-admission-controller
kubectl -n kyverno wait --for=condition=Available deployment/kyverno-admission-controller --timeout=180s
```

Générez la paire de clés pédagogique EN DEHORS de `$ROOT` - ce répertoire est réutilisé comme
Docker build context dans la tâche 9c (`COPY . /usr/share/nginx/html` dans le Dockerfile copie
TOUT le contenu du build context), c'est pourquoi un `cosign.key` laissé dans `$ROOT` se retrouvera
à l'intérieur de l'image filesystem publié comme une fuite de la private signing key dans le registry. Signez
précisément `$HARDENED_IMAGE` de la tâche 3/4, et non l'`nginx` upstream. Ne transférez pas ce
`cosign.key` dans un CI de production.

```bash
export KEYDIR=/home/ubuntu/.cks111-cosign
mkdir -p $KEYDIR $ART/9a $ART/9b $ART/9c
cd $KEYDIR && cosign generate-key-pair && cd $ROOT

# cosign sign écrit le déroulement dans stderr, c'est pourquoi 2>&1 est obligatoire - sinon l'artefact restera vide.
cosign sign --key $KEYDIR/cosign.key --yes $HARDENED_IMAGE > $ART/9a/cosign-sign.txt 2>&1
cosign verify --key $KEYDIR/cosign.pub $HARDENED_IMAGE > $ART/9a/cosign-verify.txt 2>&1
cat $ART/9a/cosign-verify.txt | head -3
```

Créez l'`ImageValidatingPolicy` qui se réfère à la clé publique de la paire dont la clé privée vient de servir à signer
`$HARDENED_IMAGE`. `matchImageReferences` limite la policy exactement au repository
de votre image : pour les OCI references, il faut des séparateurs distincts `:` (tag) et `@` (digest),
sinon le préfixe `${HARDENED_REPO}*` capturerait, par exemple, un autre repository avec le même début
de nom. Cela empêche la policy de bloquer les autres Pod du cluster.

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
    allowInsecureRegistry: true   # le registry du lab fonctionne en HTTP
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

À la fin, exécutez `check_result` (partiellement, le test 9a).

## 9b. Fresh signed ALLOW : un Pod nouveau après la création de la policy

Un nouveau `kubectl apply` du Deployment déjà existant `catalog` **ne démontre pas**
le post-policy admission : si le template n'a pas changé, Kubernetes ne crée pas de nouveau
ReplicaSet/Pod, et le `Running` observé peut être le même Pod qui existait déjà avant
`require-signed-catalog-images`. Pour démontrer précisément un fresh admission, nous créons un **nouvel** objet
qui n'existait pas jusqu'à ce moment :

```bash
POLICY_CREATED=$(kubectl get imagevalidatingpolicy require-signed-catalog-images \
  -o jsonpath='{.metadata.creationTimestamp}')

# Juste après la création de la policy, le premier appel au webhook de Kyverno (vérification de la signature dans le registry) peut
# se heurter à un timeout de 10 s (`failed calling webhook ... context deadline exceeded`) : avec
# failurePolicy=Fail, le Pod n'est alors pas créé. Répétez simplement la commande au bout de quelques secondes.
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

Critère (`creationTimestamp` a une précision de 1 s, la comparaison est donc non stricte) : `createdAfterPolicy == true` et `ready == true`. Cela, et seulement cela, démontre
que c'est précisément **cette** policy qui a laissé passer précisément **ce** Pod, qui n'existait pas auparavant, avec
une image signée, et non qu'un ancien Pod continue simplement de fonctionner.

À la fin, exécutez `check_result` (partiellement, le test 9b).

## 9c. Signature-specific DENY : un digest unsigned dans le même repository

L'unsigned candidate doit exister dans **le même** repository que le `$HARDENED_IMAGE`
signé - sinon l'admission peut refuser à cause de `manifest unknown` ou d'une erreur de
registry lookup, et non à cause de l'absence de signature, et le denial ne démontrera pas la
security property déclarée. Nous construisons et publions un second tag, délibérément non signé, dans le même
repository - et **obligatoirement** avec un contenu différent de `$HARDENED_IMAGE` : si l'on construit
le même `Dockerfile`/context sans changement, un reproducible/cached build peut donner **le même**
manifest digest que l'image déjà signée, et alors `cosign verify` sur le tag « unsigned »
passera de façon inattendue - parce qu'il pointera physiquement vers un artifact déjà signé. C'est pourquoi
nous introduisons une différence contrôlée via `ARG`/`LABEL`, qui change à coup sûr le digest :

```bash
export UNSIGNED_TAG="${HARDENED_TAG%:*}:unsigned-1"
podman build --build-arg CKS_SIGNATURE_TEST=unsigned-1 -t "$UNSIGNED_TAG" "$ROOT"
podman push --digestfile /tmp/cks-111-unsigned.digest "$UNSIGNED_TAG"
export UNSIGNED_DIGEST=$(cat /tmp/cks-111-unsigned.digest)
export UNSIGNED_IMAGE="${HARDENED_REPO}@${UNSIGNED_DIGEST}"
export HARDENED_DIGEST="${HARDENED_IMAGE#*@}"

# Vérification obligatoire : l'unsigned candidate doit être un artifact physiquement différent,
# et non le même digest que le HARDENED_IMAGE déjà signé.
[ "$UNSIGNED_DIGEST" != "$HARDENED_DIGEST" ] && echo "digests differ: OK"
printf 'hardened_digest=%s\nunsigned_digest=%s\nunsigned_image=%s\ndistinct=true\n' \
  "$HARDENED_DIGEST" "$UNSIGNED_DIGEST" "$UNSIGNED_IMAGE" > "$ART/9c/digest-comparison.txt"
cat "$ART/9c/digest-comparison.txt"
```

Le `$ROOT/Dockerfile` de la tâche 3 doit accepter ce build-arg (par exemple,
`ARG CKS_SIGNATURE_TEST=signed` et `LABEL cks.signature-test=$CKS_SIGNATURE_TEST` à côté des
instructions existantes) - alors l'image construite diffère de `$HARDENED_IMAGE` exactement par
un label sûr, sans affecter les propriétés de sécurité vérifiées dans les tâches 3-4.

Nous démontrons explicitement que ce digest existe et est pullable avant de vérifier la policy -
sinon le denial ne démontrera rien. C'est un self-check evidence pour vous : le checker de la tâche 9c
ne fait pas confiance aux fichiers texte comme preuve unique - il résout lui-même
`unsigned_image` de `digest-comparison.txt`, vérifie lui-même l'absence de signature et
crée lui-même un nouveau Pod avec cette image, c'est pourquoi écrire ces fichiers à la main sans un admission control
réel en fonctionnement ne suffit pas pour PASS.

```bash
curl -fsSI -H 'Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.v2+json' \
  "http://$REGISTRY/v2/catalog/manifests/$UNSIGNED_DIGEST" > "$ART/9c/unsigned-exists.txt"
cat "$ART/9c/unsigned-exists.txt"        # HTTP/1.1 200 OK et docker-content-digest: $UNSIGNED_DIGEST
```

Nous démontrons explicitement l'absence de signature valide avec cette même clé - **avant** la tentative de création du
Pod, afin que le denial soit de façon prévisible spécifique à la signature, et non à autre chose :

```bash
cosign verify --key "$KEYDIR/cosign.pub" "$UNSIGNED_IMAGE" > "$ART/9c/unsigned-not-signed.txt" 2>&1
cat "$ART/9c/unsigned-not-signed.txt"     # error: no matching signatures
```

Ce n'est que maintenant que nous essayons de créer le Pod et confirmons que le denial se réfère précisément à la policy/
signature, et non à une erreur générique d'admission :

```bash
kubectl run catalog-unsigned-probe -n cks-111 --image="$UNSIGNED_IMAGE" --restart=Never > "$ART/9c/admission-deny.txt" 2>&1
cat "$ART/9c/admission-deny.txt"        # ... catalog image must have a valid release signature
kubectl get pod catalog-unsigned-probe -n cks-111       # NotFound : le Pod n'est pas créé
```

La différence avec une vérification naïve : si à la place nous avions pris un digest d'un autre repository
(par exemple, le digest de l'`nginx` upstream de la tâche 1), l'admission aurait pu refuser pour une raison
tout autre (`manifest unknown`, absence d'accès de pull), et un tel denial aurait donné l'impression que « la policy fonctionne », alors qu'en réalité la vérification de signature n'a même pas été atteinte.

À la fin, exécutez `check_result`.

Vérification finale :

```bash
check_result
```
