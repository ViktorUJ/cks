[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 111 - ეტალონური ამოხსნა

ყველა ბრძანება სრულდება worker-ზე. ეს ინსტრუმენტების ჩვეულებრივი ბრძანებებია (trivy, kubesec,
kube-linter, hadolint, podman, syft, bom, cosign), რომლებიც გამოცდაზე არის; სკრიპტები არ არის, სადაც
რამდენიმე შედეგის შედარებაა საჭირო, ეს გამოტანის მიხედვით თვალით კეთდება. ჯერ დააყენეთ საერთო
ცვლადები:

```bash
export ROOT=/home/ubuntu/cks-111 ART=/var/work/tests/artifacts BASE_TAG=nginx:1.27.3-alpine
cd $ROOT
# Tag ცვალებადია: ერთხელ ვიგებთ manifest digest-ს Trivy-დან და შემდეგ ვიყენებთ tag@digest-ს.
trivy image --format json $BASE_TAG > /tmp/cks-111-base.json
export IMAGE=$BASE_TAG@$(jq -r '.Metadata.RepoDigests[0]' /tmp/cks-111-base.json | cut -d@ -f2)
echo $IMAGE
```

## 0. მომზადება: podman და registry

image-ების აწყობისა და გამოქვეყნებისთვის გამოიყენება `podman` (ის გამოცდის ინსტრუმენტების სიაშია;
rootless, მუშაობს `ubuntu`-დან). Registry უკვე აამაღლა bootstrap-მა: ეს `registry:2` control-plane-ზე
(`<node-ის IP>:5000`, plain HTTP VPC-ის შიგნით, მონაცემები node-ის ლოკალურ PV-ზე). Podman worker-ზე მასზე გამართულია
როგორც insecure registry-ზე (`/etc/containers/registries.conf.d/cks111.conf`), containerd
node-ზე - ასევე, ამიტომ ფლაგი `--tls-verify=false` საჭირო არ არის. ლაბის image-ები წინასწარ ჩამოტვირთულია ლოკალურ
ქეშში, რომელსაც Trivy და Syft იყენებენ, ამიტომ განმეორებითი სკანები Docker Hub-ის ლიმიტს არ ეჯახება.

registry-ის მისამართი:

```bash
export REGISTRY="$(cat /etc/cks111/registry)"     # <IP control-plane>:5000
curl -fsS "http://$REGISTRY/v2/" && echo " registry ok: $REGISTRY"
podman --version
```

cosign-ის გასაღების პაროლს ცარიელს ვტოვებთ, რომ ბრძანებები შეყვანას არ ელოდონ:

```bash
export COSIGN_PASSWORD=""
```

Registry მუშაობს HTTP-ით: გამოქვეყნებული image-ის digest-ს ვიღებთ `podman push --digestfile`-დან, ხოლო
manifest-ის არსებობას ვამოწმებთ მოთხოვნით `/v2/`-ზე. `cosign` თავად იყენებს HTTP-ს კერძო
ქსელების მისამართებისთვის; Kyverno-სთვის policy-ში ეთითება `credentials.allowInsecureRegistry: true`. `bom` კითხულობს
image-ებს მხოლოდ registry-იდან, ამიტომ ისევ მიმართავს Docker Hub-ს; თუ `TOOMANYREQUESTS`-ს დაინახავთ, დაელოდეთ ან შეასრულეთ `podman login docker.io` თქვენი ანგარიშით.

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
grep -l $TARGET_CVE /tmp/cand?.json        # რომელი ანგარიში შეიცავს TARGET_CVE-ს
```

დავუშვათ, ეს არის `/tmp/cand1.json` (ჩასვით თქვენი ნომერი):

```bash
mkdir -p $ART/1b
cp /tmp/cand1.json $ART/1b/target-scan.json
echo "OFFENDING_IMAGE=$CANDIDATE_1" > $ART/1b/answer.txt
cat $ART/1b/answer.txt
# OFFENDING_IMAGE=python:3.9-slim@sha256:...
```

## 1c. Workload image triage by CRITICAL severity

image-ებს ვიღებთ LIVE Deployments-იდან და თითოეულს ვასკანერებთ; უნიკალური CRITICAL-ების რაოდენობა გამოდის
Deployment-ის სახელის გვერდით:

```bash
mkdir -p $ART/1c
kubectl -n cks-111 get deployment -l cks.io/task=1c \
  -o jsonpath='{range .items[*]}{.metadata.name} {.spec.template.spec.containers[0].image}{"\n"}{end}' |
while read name ref; do
  trivy image --scanners vuln --severity CRITICAL --format json --output /tmp/$name.json $ref
  echo "$name $(jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | unique | length' /tmp/$name.json)"
done
```

გამოტანის მიხედვით იპოვეთ Deployment ყველაზე დიდი რაოდენობით (ყველაზე მოწყვლადი) და ორი ყველაზე მცირეთი. ჩაწერეთ
სახელები `ranking.txt`-ში (`dep-a`, `dep-b`, `dep-c`-ის ნაცვლად - თქვენი სახელები):

```bash
cat > $ART/1c/ranking.txt <<EOF
MOST_VULNERABLE=dep-a
LEAST_VULNERABLE_1=dep-b
LEAST_VULNERABLE_2=dep-c
EOF
# dep-d - მეოთხე Deployment-ია (CRITICAL-ების რაოდენობით მეორე), ranking.txt-ში ის არ იწერება
```

ყველაზე მოწყვლადი Deployment-ის CycloneDX SBOM (image მისი Deployment-იდან) და დანარჩენების scale:

```bash
kubectl -n cks-111 get deployment dep-a -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
trivy image --format cyclonedx --output $ART/1c/cyclonedx.json <ზემოთ-გამოტანილი-image>
kubectl -n cks-111 scale deployment dep-a --replicas=0      # ყველაზე მოწყვლადი
kubectl -n cks-111 scale deployment dep-d --replicas=0      # მეოთხე (ორ ყველაზე ნაკლებად მოწყვლადში არ შედის)
kubectl -n cks-111 get deployment -l cks.io/task=1c
```

## 2. ანგარიშები შესწორებამდე

`hadolint`, `kubesec` და `kube-linter` findings-ის დროს აბრუნებენ არანულოვან სტატუსს; ეს მოსალოდნელი
შედეგია, ანგარიში ინახება როგორც არის.

```bash
mkdir -p $ART/2
hadolint $ROOT/Dockerfile > $ART/2/hadolint-before.txt
kubesec scan $ROOT/deployment.yaml > $ART/2/kubesec-before.json
kube-linter lint $ROOT/deployment.yaml --format json > $ART/2/kube-linter-before.json
jq '.[0].scoring' $ART/2/kubesec-before.json
jq '{summary: .Summary, findings: (.Reports | length)}' $ART/2/kube-linter-before.json
```

## 3. Dockerfile-ის შესწორება

Secret-ს image layer-ში ნუ დაამატებთ და floating tag-ს ნუ გამოიყენებთ: გამოიყენეთ `$IMAGE`, რომელშიც tag შევსებულია manifest digest-ით. `USER 101` მომავალი hardened image-ის თვისებაა.

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
# სუფთა Dockerfile იძლევა hadolint-ის ცარიელ გამოტანას (დაბრუნების კოდი 0) - ცარიელი ფაილი აქ მოსალოდნელი და სწორია.
grep -nE '^(FROM|COPY|USER)' "$ROOT/Dockerfile"
```

`ARG CKS_SIGNATURE_TEST`/`LABEL cks.signature-test` არ ცვლის აქ შემოწმებული არც ერთ
security-თვისებას (base image, non-root, secret-ის არარსებობა) - ეს კონტროლირებადი
განსხვავების ერთადერთი წერტილია, რომელიც დავალება 9c-ში სხვა manifest digest-ს
გარანტირებულად იძლევა Dockerfile-ის დანარჩენის გადახედვის გარეშე.

ააგეთ და **გამოაქვეყნეთ** image Kubernetes-ისთვის ხელმისაწვდომ registry-ში; მხოლოდ local image ID/DiffID digest pinning-ისთვის არ გამოდგება. ჩასვით თქვენი repository, შემდეგ მიიღეთ registry manifest digest და ჩამოაყალიბეთ immutable reference:

```bash
export HARDENED_TAG="$REGISTRY/catalog:1.0"
podman build -t "$HARDENED_TAG" "$ROOT"
podman push --digestfile /tmp/cks-111-hardened.digest "$HARDENED_TAG"
export HARDENED_DIGEST=$(cat /tmp/cks-111-hardened.digest)
export HARDENED_IMAGE="${HARDENED_TAG%:*}@${HARDENED_DIGEST}"
printf '%s\n' "$HARDENED_IMAGE"   # <IP>:5000/catalog@sha256:<manifest-digest>
```

## 4. Deployment-ის შესწორება

`readOnlyRootFilesystem` მოითხოვს nginx-ის writable runtime paths-ს. `emptyDir` მათ მიზნობრივად იძლევა; init container (ასევე hardened image `USER 101`-ით) აკოპირებს default config-ს ცალკე writable config volume-ში. `$HARDENED_IMAGE` - აწყობილი და digest-pinned მითითებაა დავალება 3-იდან, და არა upstream image.

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

## 5. პაკეტების ვერსიების ძიება

`--list-all-pkgs` იძლევა ფაქტობრივ inventory-ს. registry manifest digest-ის კანონიკური მნიშვნელობა მიიღება მხოლოდ `Metadata.RepoDigests[0]`-დან; `ImageID` და `DiffID` აღწერს ლოკალურ image-ს/layers-ს და registry digest-ის fallback არ არის.

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

## 5b. პაკეტის ვერსიის პოვნა workload image-ებში და დამრღვევი კონტეინერების წაშლა

```bash
mkdir -p $ART/5b/bom
kubectl -n cks-111 get deployment pkg-audit-app \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name} {.image}{"\n"}{end}'
# c1 <image 1> / c2 <image 2> / c3 <image 3>
```

თითოეული image-ის SBOM (ჩასვით image-ები გამოტანიდან) და სია `პაკეტი=ვერსია` თითოეულისთვის:

```bash
bom generate --format json --output $ART/5b/bom/c1.spdx.json --image <c1-ის image>
bom generate --format json --output $ART/5b/bom/c2.spdx.json --image <c2-ის image>
bom generate --format json --output $ART/5b/bom/c3.spdx.json --image <c3-ის image>
for c in c1 c2 c3; do
  jq -r '.packages[]? | select(.versionInfo) | "\(.name)=\(.versionInfo)"' $ART/5b/bom/$c.spdx.json | sort -u > /tmp/$c.pkgs
done
comm -12 /tmp/c1.pkgs /tmp/c2.pkgs | wc -l     # რამდენი საერთო პაკეტი აქვს image-ების თითოეულ წყვილს
comm -12 /tmp/c1.pkgs /tmp/c3.pkgs | wc -l
comm -12 /tmp/c2.pkgs /tmp/c3.pkgs | wc -l
```

წყვილი საერთო პაკეტებით - ეს არის offending კონტეინერები (დავუშვათ, `c1` და `c2`). მათ ბევრი
საერთო პაკეტი აქვთ: გამოდგება **ნებისმიერი** `name=version`, რომელიც მესამე image-ში არ არის:

```bash
comm -12 /tmp/c1.pkgs /tmp/c2.pkgs | grep -vxFf /tmp/c3.pkgs | head -3
```

ჩაწერეთ ნაპოვნი წყვილი და წაშალეთ სწორედ ეს ორი კონტეინერი (`kubectl edit`), "სუფთას" დატოვებით:

```bash
printf 'TARGET_PACKAGE=%s\nTARGET_VERSION=%s\n' <name> <version> > $ART/5b/answer.txt     # მაგალითად apt და 3.0.3
cat $ART/5b/answer.txt
kubectl -n cks-111 edit deployment pkg-audit-app        # წაშალეთ ორი offending კონტეინერი
kubectl -n cks-111 rollout status deployment/pkg-audit-app --timeout=120s
```

## 6. SPDX SBOM (bom)

```bash
mkdir -p "$ART/6"
echo "bom generate --format json --output $ART/6/bom.spdx.json --image $IMAGE" > "$ART/6/bom-command.txt"
bom generate --format json --output "$ART/6/bom.spdx.json" --image "$IMAGE"
jq '.spdxVersion, (.packages | length)' "$ART/6/bom.spdx.json"
```

## 7. CycloneDX SBOM (Syft) და keyless Cosign

Syft ახერხებს როგორც SPDX-ს, ისე CycloneDX-ს; აქ ვიღებთ CycloneDX-ს (`bom`-მა SPDX უკვე მისცა დავალება 6-ში).
მოწმდება საჯარო Distroless image და მისი მოსალოდნელი Google workload identity; არ
გამოიყენოთ `--insecure-ignore-tlog` ან certificate identity-ის გამოტოვება.

```bash
mkdir -p "$ART/7"
# მითითებისთვის ფორმით tag@digest Syft metadata.component.version-ში წერს მხოლოდ tag-ს; მითითება
# tag-ის გარეშე ("nginx@sha256:...") იძლევა version = manifest digest-ს, რომელიც სწორედ მოწმდება.
syft "nginx@${IMAGE#*@}" -o "cyclonedx-json=$ART/7/syft.cdx.json"
```

`syft`-ის შემდეგ დაელოდეთ დასრულებას და შემდგომი ბრძანებები ცალკე ჩასვით: `syft` (`apt-get`-ის მსგავსად)
ასუფთავებს ტერმინალის შეყვანის ბუფერს, და მის უშუალოდ შემდეგ ჩასმული სტრიქონები იკარგება.

```bash
jq -r '.metadata.component.version' "$ART/7/syft.cdx.json"   # sha256:<manifest-digest>
cosign verify \
  --certificate-oidc-issuer https://accounts.google.com \
  --certificate-identity keyless@distroless.iam.gserviceaccount.com \
  gcr.io/distroless/static-debian13:nonroot > $ART/7/cosign-verify.txt 2>&1
echo "exit code: $?"      # 0 = ხელმოწერა შემოწმებულია

# gcr.io/distroless/static:nonroot (სუფიქსის -debian13 გარეშე) deprecated-ად ითვლება და აღარ
# განახლდება Distroless-ის ოფიციალური README-ის მიხედვით - ვიყენებთ მიმდინარე
# მხარდაჭერილ ტეგს gcr.io/distroless/static-debian13:nonroot. cosign verify-ის წარმატება
# განისაზღვრება exit code-ით, და არა ლიტერალური სტრიქონით "Verified OK" - ასეთი სტრიქონი
# cosign-ის რეალურ გამოტანაში არ არის (წარმატებული გამოტანა იწყება სტრიქონით "Verification for <image> --"
# და შესრულებული შემოწმებების სიით). cosign მუშაობის მსვლელობას წერს stderr-ში, ამიტომ 2>&1
# სავალდებულოა - წინააღმდეგ შემთხვევაში artifact ცარიელი დარჩება.
printf '\nreference=gcr.io/distroless/static-debian13:nonroot\n' >> $ART/7/cosign-verify.txt
jq '.bomFormat, (.components | length)' $ART/7/syft.cdx.json
```

## 8. `trivy sbom`: მზა SBOM-ფაილის სკანირება

CycloneDX SBOM დავალება 7-დან აღწერს კომპონენტებისა და image-ის OS-ის შემადგენლობას, მაგრამ მოწყვლადობების შესახებ
დასკვნას არ შეიცავს; `trivy sbom` ასეთ ფაილს პირდაპირ იღებს შესასვლელად, registry-ს თავად image-ისთვის
ხელახლა მიმართვის გარეშე.

```bash
mkdir -p $ART/8
echo "trivy sbom --format json --output $ART/8/sbom-scan.json $ART/7/syft.cdx.json" > $ART/8/sbom-scan-command.txt
trivy sbom --format json --output $ART/8/sbom-scan.json $ART/7/syft.cdx.json
jq '{artifact: .ArtifactType, os: .Metadata.OS.Family, results: (.Results | length)}' $ART/8/sbom-scan.json
```

Trivy განსაზღვრავს OS-ს CycloneDX-ის კომპონენტით `operating-system` (`alpine 3.20.5`) და
უთანადებს პაკეტებს მოწყვლადობების ბაზას - `Results` არაცარიელია. შედარებისთვის: SPDX დავალება 6-დან
(`bom`) multi-arch image-ისთვის OS-ს არ შეიცავს (`Detected OS family="none"`), და `trivy sbom` მასზე
არაფერს პოულობს (`Results` ცარიელია) - ამიტომ ამ დავალებისთვის CycloneDX-ს იღებენ.

## 9a. Kyverno და `ImageValidatingPolicy` trusted signature-ზე

დააყენეთ Kyverno ისევე, როგორც ლაბ 108-ში, და დაელოდეთ admission controller-ის მზადყოფნას.

```bash
sudo install-kyverno
```

ჩასვით შემდეგი ბრძანებები დაყენების დასრულების შემდეგ (installer ასუფთავებს შეყვანის ბუფერს):

```bash
kubectl -n kyverno get deployment kyverno-admission-controller
kubectl -n kyverno wait --for=condition=Available deployment/kyverno-admission-controller --timeout=180s
```

დააგენერირეთ გასაღებების სასწავლო წყვილი `$ROOT`-ის გარეთ - ეს დირექტორია ხელახლა გამოიყენება როგორც
Docker build context დავალება 9c-ში (Dockerfile-ში `COPY . /usr/share/nginx/html` აკოპირებს
build context-ის მთელ შიგთავსს), ამიტომ `cosign.key`, `$ROOT`-ის შიგნით დარჩენილი, მოხვდება
გამოქვეყნებული image-ის filesystem-ში private signing key-ის registry-ში გაჟონვის სახით. ხელი მოაწერეთ
სწორედ `$HARDENED_IMAGE`-ს დავალება 3/4-დან, და არა upstream `nginx`-ს. ეს
`cosign.key` production CI-ში ნუ გადაიტანთ.

```bash
export KEYDIR=/home/ubuntu/.cks111-cosign
mkdir -p $KEYDIR $ART/9a $ART/9b $ART/9c
cd $KEYDIR && cosign generate-key-pair && cd $ROOT

# cosign sign მუშაობის მსვლელობას წერს stderr-ში, ამიტომ 2>&1 სავალდებულოა - წინააღმდეგ შემთხვევაში artifact ცარიელი დარჩება.
cosign sign --key $KEYDIR/cosign.key --yes $HARDENED_IMAGE > $ART/9a/cosign-sign.txt 2>&1
cosign verify --key $KEYDIR/cosign.pub $HARDENED_IMAGE > $ART/9a/cosign-verify.txt 2>&1
cat $ART/9a/cosign-verify.txt | head -3
```

შექმენით `ImageValidatingPolicy`, რომელიც მიუთითებს public key-ზე, რომლითაც ახლახან
ხელმოწერილია `$HARDENED_IMAGE`. `matchImageReferences` ზღუდავს policy-ს ზუსტად თქვენი image-ის
repository-ით: OCI references-ისთვის საჭიროა ცალკე გამყოფები `:` (tag) და `@` (digest),
წინააღმდეგ შემთხვევაში პრეფიქსი `${HARDENED_REPO}*` დაიჭერს, მაგალითად, სხვა repository-ს იმავე
სახელის დასაწყისით. ეს policy-ს კლასტერის დანარჩენი Pod-ების დაბლოკვის საშუალებას არ აძლევს.

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
    allowInsecureRegistry: true   # ლაბის registry მუშაობს HTTP-ით
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

ბოლოს გაუშვით `check_result` (ნაწილობრივ, ტესტი 9a).

## 9b. Fresh signed ALLOW: ახალი Pod policy-ის შექმნის შემდეგ

უკვე არსებული Deployment `catalog`-ის განმეორებითი `kubectl apply` **არ ამტკიცებს**
post-policy admission-ს: თუ template არ შეცვლილა, Kubernetes ახალ
ReplicaSet/Pod-ს არ ქმნის, და დაკვირვებადი `Running` შეიძლება იყოს იგივე Pod, რომელიც `require-signed-catalog-images`-მდეც
არსებობდა. სწორედ fresh admission-ის დასამტკიცებლად ვქმნით **ახალ**
ობიექტს, რომელიც ამ მომენტამდე არ არსებობდა:

```bash
POLICY_CREATED=$(kubectl get imagevalidatingpolicy require-signed-catalog-images \
  -o jsonpath='{.metadata.creationTimestamp}')

# policy-ის შექმნისთანავე Kyverno webhook-ის პირველი გამოძახება (ხელმოწერის შემოწმება registry-ში) შეიძლება
# 10 წმ-იან timeout-ს მიადგეს (`failed calling webhook ... context deadline exceeded`):
# failurePolicy=Fail-ის დროს Pod მაშინ არ იქმნება. უბრალოდ გაიმეორეთ ბრძანება რამდენიმე წამში.
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

კრიტერიუმი (`creationTimestamp`-ს სიზუსტე 1 წმ აქვს, ამიტომ შედარება არამკაცრია): `createdAfterPolicy == true` და `ready == true`. ეს - და მხოლოდ ეს - ამტკიცებს,
რომ სწორედ **ამ** policy-მ გაატარა სწორედ **ეს**, ადრე არარსებული Pod
ხელმოწერილი image-ით, და არა ის, რომ ძველი Pod უბრალოდ აგრძელებს მუშაობას.

ბოლოს გაუშვით `check_result` (ნაწილობრივ, ტესტი 9b).

## 9c. Signature-specific DENY: unsigned digest იმავე repository-ში

Unsigned candidate უნდა არსებობდეს **იმავე** repository-ში, რაც ხელმოწერილი
`$HARDENED_IMAGE` - წინააღმდეგ შემთხვევაში admission შეიძლება უარს ამბობდეს `manifest unknown`-ის ან
registry lookup-ის შეცდომის გამო, და არა ხელმოწერის არარსებობის გამო, და denial დეკლარირებულ
security property-ს ვერ დაამტკიცებს. ვაგებთ და ვაქვეყნებთ მეორე, შეგნებულად ხელმოუწერელ tag-ს იმავე
repository-ში - და **აუცილებლად** `$HARDENED_IMAGE`-სგან განსხვავებული შიგთავსით: თუ
იმავე `Dockerfile`/context-ს ცვლილებების გარეშე ააგებთ, reproducible/cached build-მა შეიძლება **იგივე**
manifest digest მოგცეთ, რაც უკვე ხელმოწერილ image-ს აქვს, და მაშინ `cosign verify` "unsigned" tag-ზე
მოულოდნელად გაივლის - რადგან ის ფიზიკურად უკვე ხელმოწერილ artifact-ზე მიუთითებს. ამიტომ
კონტროლირებად განსხვავებას `ARG`/`LABEL`-ით შევიტანთ, რომელიც digest-ს გარანტირებულად ცვლის:

```bash
export UNSIGNED_TAG="${HARDENED_TAG%:*}:unsigned-1"
podman build --build-arg CKS_SIGNATURE_TEST=unsigned-1 -t "$UNSIGNED_TAG" "$ROOT"
podman push --digestfile /tmp/cks-111-unsigned.digest "$UNSIGNED_TAG"
export UNSIGNED_DIGEST=$(cat /tmp/cks-111-unsigned.digest)
export UNSIGNED_IMAGE="${HARDENED_REPO}@${UNSIGNED_DIGEST}"
export HARDENED_DIGEST="${HARDENED_IMAGE#*@}"

# სავალდებულო შემოწმება: unsigned candidate უნდა იყოს ფიზიკურად სხვა artifact,
# და არა იგივე digest, რაც უკვე ხელმოწერილ HARDENED_IMAGE-ს აქვს.
[ "$UNSIGNED_DIGEST" != "$HARDENED_DIGEST" ] && echo "digests differ: OK"
printf 'hardened_digest=%s\nunsigned_digest=%s\nunsigned_image=%s\ndistinct=true\n' \
  "$HARDENED_DIGEST" "$UNSIGNED_DIGEST" "$UNSIGNED_IMAGE" > "$ART/9c/digest-comparison.txt"
cat "$ART/9c/digest-comparison.txt"
```

`$ROOT/Dockerfile` დავალება 3-იდან უნდა იღებდეს ამ build-arg-ს (მაგალითად,
`ARG CKS_SIGNATURE_TEST=signed` და `LABEL cks.signature-test=$CKS_SIGNATURE_TEST` არსებული
ინსტრუქციების გვერდით) - მაშინ აწყობილი image `$HARDENED_IMAGE`-სგან ზუსტად
ერთი უსაფრთხო მარკით განსხვავდება, დავალებებში 3-4 შემოწმებულ security-თვისებებს ხელს არ ახლებს.

აშკარად ვამტკიცებთ, რომ ეს digest არსებობს და pullable-ია, policy-ის შემოწმებამდე -
წინააღმდეგ შემთხვევაში denial არაფერს დაამტკიცებს. ეს თქვენთვის self-check evidence-ია: checker დავალება 9c-სთვის
ტექსტურ ფაილებს ერთადერთ დადასტურებად არ ენდობა - ის თავად resolve-ს უკეთებს
`unsigned_image`-ს `digest-comparison.txt`-დან, თავად ამოწმებს ხელმოწერის არარსებობას და თავად
ქმნის ახალ Pod-ს ამ image-ით, ამიტომ ამ ფაილების ხელით დაწერა რეალურად
მომუშავე admission control-ის გარეშე PASS-ისთვის საკმარისი არ არის.

```bash
curl -fsSI -H 'Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.v2+json' \
  "http://$REGISTRY/v2/catalog/manifests/$UNSIGNED_DIGEST" > "$ART/9c/unsigned-exists.txt"
cat "$ART/9c/unsigned-exists.txt"        # HTTP/1.1 200 OK და docker-content-digest: $UNSIGNED_DIGEST
```

აშკარად ვამტკიცებთ ვალიდური ხელმოწერის არარსებობას ამავე გასაღებით - Pod-ის შექმნის ცდამდე,
რათა denial იყოს პროგნოზირებადად signature-ისთვის სპეციფიკური, და არა სხვა რამისთვის:

```bash
cosign verify --key "$KEYDIR/cosign.pub" "$UNSIGNED_IMAGE" > "$ART/9c/unsigned-not-signed.txt" 2>&1
cat "$ART/9c/unsigned-not-signed.txt"     # error: no matching signatures
```

მხოლოდ ახლა ვცდილობთ Pod-ის შექმნას და ვადასტურებთ, რომ denial მიუთითებს სწორედ policy-ზე/
signature-ზე, და არა generic admission-შეცდომაზე:

```bash
kubectl run catalog-unsigned-probe -n cks-111 --image="$UNSIGNED_IMAGE" --restart=Never > "$ART/9c/admission-deny.txt" 2>&1
cat "$ART/9c/admission-deny.txt"        # ... catalog image must have a valid release signature
kubectl get pod catalog-unsigned-probe -n cks-111       # NotFound: Pod არ არის შექმნილი
```

განსხვავება ნაივური შემოწმებისგან: თუ ამის ნაცვლად სხვა repository-იდან ავიღებდით digest-ს
(მაგალითად, upstream `nginx`-ის digest-ს დავალება 1-დან), admission შეიძლება სრულიად
სხვა მიზეზით უარს ამბობდეს (`manifest unknown`, pull-წვდომის არარსებობა) - და ასეთი denial
"policy მუშაობს"-ს დაემსგავსებოდა, თუმცა სინამდვილეში signature-ის შემოწმებამდე საქმე საერთოდ არ მისულა.

ბოლოს გაუშვით `check_result`.

საბოლოო შემოწმება:

```bash
check_result
```
