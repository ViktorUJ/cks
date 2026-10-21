[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 111 - 參考解答

所有指令都在 worker 上執行。這些是考試中會有的一般工具指令(trivy、kubesec、
kube-linter、hadolint、podman、syft、bom、cosign);沒有腳本,在需要
比較多個結果的地方,是用眼睛看輸出來比較。首先設定共用的
變數:

```bash
export ROOT=/home/ubuntu/cks-111 ART=/var/work/tests/artifacts BASE_TAG=nginx:1.27.3-alpine
cd $ROOT
# Tag 是可變的:從 Trivy 取得一次 manifest digest,之後使用 tag@digest。
trivy image --format json $BASE_TAG > /tmp/cks-111-base.json
export IMAGE=$BASE_TAG@$(jq -r '.Metadata.RepoDigests[0]' /tmp/cks-111-base.json | cut -d@ -f2)
echo $IMAGE
```

## 0. 準備:podman 與 registry

建置與發布映像使用 `podman`(它在考試的工具清單中;
rootless,以 `ubuntu` 身分運作)。Registry 已由 bootstrap 啟動:這是 control-plane 上的 `registry:2`
(`<節點的 IP>:5000`,VPC 內部的 plain HTTP,資料位於節點本機的 PV)。worker 上的 Podman 已經把它設定
為 insecure registry(`/etc/containers/registries.conf.d/cks111.conf`),節點上的 containerd
同樣如此,因此不需要旗標 `--tls-verify=false`。實驗的映像事先下載到本機
快取中,Trivy 與 Syft 使用它,因此重複掃描不會撞上 Docker Hub 的限制。

Registry 的位址:

```bash
export REGISTRY="$(cat /etc/cks111/registry)"     # <control-plane 的 IP>:5000
curl -fsS "http://$REGISTRY/v2/" && echo " registry ok: $REGISTRY"
podman --version
```

cosign 金鑰的密碼保持為空,讓指令不用等待輸入:

```bash
export COSIGN_PASSWORD=""
```

Registry 以 HTTP 運作:已發布映像的 digest 取自 `podman push --digestfile`,而
manifest 是否存在則用對 `/v2/` 的請求檢查。`cosign` 對私有網路的位址會自己使用 HTTP;對 Kyverno,在 policy 中設定 `credentials.allowInsecureRegistry: true`。`bom` 只從 registry
讀取映像,因此仍然會存取 Docker Hub;如果看到
`TOOMANYREQUESTS`,請等待,或以你自己的帳號執行 `podman login docker.io`。

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
grep -l $TARGET_CVE /tmp/cand?.json        # 哪份報告包含 TARGET_CVE
```

假設是 `/tmp/cand1.json`(代入你自己的編號):

```bash
mkdir -p $ART/1b
cp /tmp/cand1.json $ART/1b/target-scan.json
echo "OFFENDING_IMAGE=$CANDIDATE_1" > $ART/1b/answer.txt
cat $ART/1b/answer.txt
# OFFENDING_IMAGE=python:3.9-slim@sha256:...
```

## 1c. 依 CRITICAL severity 做 workload image triage

映像取自 LIVE Deployments 並逐一掃描;唯一的 CRITICAL 數量會與
Deployment 的名稱一起輸出:

```bash
mkdir -p $ART/1c
kubectl -n cks-111 get deployment -l cks.io/task=1c \
  -o jsonpath='{range .items[*]}{.metadata.name} {.spec.template.spec.containers[0].image}{"\n"}{end}' |
while read name ref; do
  trivy image --scanners vuln --severity CRITICAL --format json --output /tmp/$name.json $ref
  echo "$name $(jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | unique | length' /tmp/$name.json)"
done
```

從輸出中找出數量最多的 Deployment(最有弱點的)以及數量最少的兩個。把
名稱寫入 `ranking.txt`(用你自己的名稱取代 `dep-a`、`dep-b`、`dep-c`):

```bash
cat > $ART/1c/ranking.txt <<EOF
MOST_VULNERABLE=dep-a
LEAST_VULNERABLE_1=dep-b
LEAST_VULNERABLE_2=dep-c
EOF
# dep-d - 第四個 Deployment(CRITICAL 數量第二多),它不會寫入 ranking.txt
```

最有弱點的 Deployment 的 CycloneDX SBOM(取自它的 Deployment 的映像),以及縮減其餘的 scale:

```bash
kubectl -n cks-111 get deployment dep-a -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
trivy image --format cyclonedx --output $ART/1c/cyclonedx.json <上面輸出中的映像>
kubectl -n cks-111 scale deployment dep-a --replicas=0      # 最有弱點的
kubectl -n cks-111 scale deployment dep-d --replicas=0      # 第四個(不屬於兩個最不脆弱的)
kubectl -n cks-111 get deployment -l cks.io/task=1c
```

## 2. 修正之前的報告

`hadolint`、`kubesec` 與 `kube-linter` 在有 findings 時會回傳非零狀態;這是預期的
結果,報告保持原樣儲存。

```bash
mkdir -p $ART/2
hadolint $ROOT/Dockerfile > $ART/2/hadolint-before.txt
kubesec scan $ROOT/deployment.yaml > $ART/2/kubesec-before.json
kube-linter lint $ROOT/deployment.yaml --format json > $ART/2/kube-linter-before.json
jq '.[0].scoring' $ART/2/kubesec-before.json
jq '{summary: .Summary, findings: (.Reports | length)}' $ART/2/kube-linter-before.json
```

## 3. 修正 Dockerfile

不要把 secret 加入 image layer,也不要使用 floating tag:請使用 `$IMAGE`,其中 tag 補上了 manifest digest。`USER 101` 是未來 hardened image 的屬性。

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
# 乾淨的 Dockerfile 會讓 hadolint 輸出為空(回傳碼為 0)- 這裡空檔案是預期且正確的。
grep -nE '^(FROM|COPY|USER)' "$ROOT/Dockerfile"
```

`ARG CKS_SIGNATURE_TEST`/`LABEL cks.signature-test` 不會改變這裡檢查的任何
security 特性(base image、non-root、沒有 secret)- 這是唯一的
受控差異點,在任務 9c 中,它能在不重新審視 Dockerfile 其餘部分的情況下,保證得到不同的 manifest digest。

建置並**發布**映像到 Kubernetes 可存取的 registry;只有本機的 image ID/DiffID 不適用於 digest pinning。代入你自己的 repository,然後取得 registry manifest digest 並組成 immutable reference:

```bash
export HARDENED_TAG="$REGISTRY/catalog:1.0"
podman build -t "$HARDENED_TAG" "$ROOT"
podman push --digestfile /tmp/cks-111-hardened.digest "$HARDENED_TAG"
export HARDENED_DIGEST=$(cat /tmp/cks-111-hardened.digest)
export HARDENED_IMAGE="${HARDENED_TAG%:*}@${HARDENED_DIGEST}"
printf '%s\n' "$HARDENED_IMAGE"   # <IP>:5000/catalog@sha256:<manifest-digest>
```

## 4. 修正 Deployment

`readOnlyRootFilesystem` 需要 nginx 的可寫 runtime 路徑。`emptyDir` 針對性地提供它們;init container(同樣是帶有 `USER 101` 的 hardened image)把預設 config 複製到單獨的可寫 config volume 中。`$HARDENED_IMAGE` 是任務 3 中建置的、以 digest 固定的引用,而不是上游的 image。

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

## 5. 搜尋套件版本

`--list-all-pkgs` 給出實際的 inventory。標準的 registry manifest digest 只取自 `Metadata.RepoDigests[0]`;`ImageID` 與 `DiffID` 描述的是本機的映像/layers,不是 registry digest 的 fallback。

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

## 5b. 在 workload 映像中找出套件版本並移除有問題的 containers

```bash
mkdir -p $ART/5b/bom
kubectl -n cks-111 get deployment pkg-audit-app \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name} {.image}{"\n"}{end}'
# c1 <映像 1> / c2 <映像 2> / c3 <映像 3>
```

每個映像的 SBOM(代入輸出中的映像),以及每個映像的 `套件=版本` 清單:

```bash
bom generate --format json --output $ART/5b/bom/c1.spdx.json --image <c1 的映像>
bom generate --format json --output $ART/5b/bom/c2.spdx.json --image <c2 的映像>
bom generate --format json --output $ART/5b/bom/c3.spdx.json --image <c3 的映像>
for c in c1 c2 c3; do
  jq -r '.packages[]? | select(.versionInfo) | "\(.name)=\(.versionInfo)"' $ART/5b/bom/$c.spdx.json | sort -u > /tmp/$c.pkgs
done
comm -12 /tmp/c1.pkgs /tmp/c2.pkgs | wc -l     # 每一對映像有多少共同的套件
comm -12 /tmp/c1.pkgs /tmp/c3.pkgs | wc -l
comm -12 /tmp/c2.pkgs /tmp/c3.pkgs | wc -l
```

有共同套件的那一對,就是有問題的 containers(假設是 `c1` 與 `c2`)。它們有很多共同的套件:**任何**不在第三個映像中的 `name=version` 都可以:

```bash
comm -12 /tmp/c1.pkgs /tmp/c2.pkgs | grep -vxFf /tmp/c3.pkgs | head -3
```

寫下找到的組合,並刪除正是這兩個 containers(`kubectl edit`),留下「乾淨的」:

```bash
printf 'TARGET_PACKAGE=%s\nTARGET_VERSION=%s\n' <name> <version> > $ART/5b/answer.txt     # 例如 apt 與 3.0.3
cat $ART/5b/answer.txt
kubectl -n cks-111 edit deployment pkg-audit-app        # 刪除兩個有問題的 containers
kubectl -n cks-111 rollout status deployment/pkg-audit-app --timeout=120s
```

## 6. SPDX SBOM(bom)

```bash
mkdir -p "$ART/6"
echo "bom generate --format json --output $ART/6/bom.spdx.json --image $IMAGE" > "$ART/6/bom-command.txt"
bom generate --format json --output "$ART/6/bom.spdx.json" --image "$IMAGE"
jq '.spdxVersion, (.packages | length)' "$ART/6/bom.spdx.json"
```

## 7. CycloneDX SBOM(Syft)與 keyless Cosign

Syft 同時支援 SPDX 與 CycloneDX;這裡使用 CycloneDX(`bom` 已經在任務 6 中給出了 SPDX)。
檢查的是公開的 Distroless 映像及其預期的 Google workload identity;不要
使用 `--insecure-ignore-tlog`,也不要略過 certificate identity。

```bash
mkdir -p "$ART/7"
# 對於形如 tag@digest 的引用,Syft 在 metadata.component.version 中只會寫入 tag;沒有
# tag 的引用("nginx@sha256:...")則會給出 version = manifest digest,而被檢查的正是它。
syft "nginx@${IMAGE#*@}" -o "cyclonedx-json=$ART/7/syft.cdx.json"
```

在 `syft` 之後,請等它結束,並把後續指令分開貼上:`syft`(和 `apt-get` 一樣)
會清空終端機的輸入緩衝區,緊接在它之後貼上的幾行會遺失。

```bash
jq -r '.metadata.component.version' "$ART/7/syft.cdx.json"   # sha256:<manifest-digest>
cosign verify \
  --certificate-oidc-issuer https://accounts.google.com \
  --certificate-identity keyless@distroless.iam.gserviceaccount.com \
  gcr.io/distroless/static-debian13:nonroot > $ART/7/cosign-verify.txt 2>&1
echo "exit code: $?"      # 0 = 簽章已驗證

# gcr.io/distroless/static:nonroot(不帶後綴 -debian13)被視為 deprecated,依據
# Distroless 官方 README 不再更新 - 我們使用目前
# 受支援的標籤 gcr.io/distroless/static-debian13:nonroot。cosign verify 是否成功,
# 取決於 exit code,而不是字面字串 "Verified OK" - 在
# cosign 真實的輸出中沒有這樣的字串(成功的輸出以 "Verification for <image> --" 這一行開頭,
# 後面接著已執行的檢查清單)。cosign 把執行過程寫到 stderr,因此 2>&1
# 是必須的 - 否則 artifact 會是空的。
printf '\nreference=gcr.io/distroless/static-debian13:nonroot\n' >> $ART/7/cosign-verify.txt
jq '.bomFormat, (.components | length)' $ART/7/syft.cdx.json
```

## 8. `trivy sbom`:掃描現成的 SBOM 檔案

任務 7 的 CycloneDX SBOM 描述了映像的組件與 OS 的組成,但不包含關於
弱點的結論;`trivy sbom` 直接接受這樣的檔案作為輸入,不需要再次向
registry 取得 image 本身。

```bash
mkdir -p $ART/8
echo "trivy sbom --format json --output $ART/8/sbom-scan.json $ART/7/syft.cdx.json" > $ART/8/sbom-scan-command.txt
trivy sbom --format json --output $ART/8/sbom-scan.json $ART/7/syft.cdx.json
jq '{artifact: .ArtifactType, os: .Metadata.OS.Family, results: (.Results | length)}' $ART/8/sbom-scan.json
```

Trivy 依據 CycloneDX 中的組件 `operating-system`(`alpine 3.20.5`)判斷 OS,並
把套件與弱點資料庫對照 - `Results` 非空。作為比較:任務 6 的 SPDX
(`bom`)對 multi-arch 映像不包含 OS(`Detected OS family="none"`),而 `trivy sbom` 對它
什麼也找不到(`Results` 為空)- 因此這個任務使用 CycloneDX。

## 9a. Kyverno 與針對 trusted signature 的 `ImageValidatingPolicy`

像實驗 108 中一樣安裝 Kyverno,並等待 admission controller 就緒。

```bash
sudo install-kyverno
```

請在安裝結束之後再貼上以下指令(安裝程式會清空輸入緩衝區):

```bash
kubectl -n kyverno get deployment kyverno-admission-controller
kubectl -n kyverno wait --for=condition=Available deployment/kyverno-admission-controller --timeout=180s
```

在 `$ROOT` 「之外」產生學習用的金鑰對 - 這個目錄在任務 9c 中會被重複用作
Docker build context(Dockerfile 中的 `COPY . /usr/share/nginx/html` 會複製
build context 的「全部」內容),因此留在 `$ROOT` 內的 `cosign.key`,會進入
所發布 image 的檔案系統,造成 private signing key 洩漏到 registry。請簽署
任務 3/4 的 `$HARDENED_IMAGE`,而不是上游的 `nginx`。不要把這個
`cosign.key` 搬到 production CI。

```bash
export KEYDIR=/home/ubuntu/.cks111-cosign
mkdir -p $KEYDIR $ART/9a $ART/9b $ART/9c
cd $KEYDIR && cosign generate-key-pair && cd $ROOT

# cosign sign 把執行過程寫到 stderr,因此 2>&1 是必須的 - 否則 artifact 會是空的。
cosign sign --key $KEYDIR/cosign.key --yes $HARDENED_IMAGE > $ART/9a/cosign-sign.txt 2>&1
cosign verify --key $KEYDIR/cosign.pub $HARDENED_IMAGE > $ART/9a/cosign-verify.txt 2>&1
cat $ART/9a/cosign-verify.txt | head -3
```

建立 `ImageValidatingPolicy`,引用剛剛用來簽署 `$HARDENED_IMAGE` 的
公開金鑰。`matchImageReferences` 把 policy 恰好限制在你的映像的 repository:
對於 OCI references,需要分別的分隔符號 `:`(tag)與 `@`(digest),
否則前綴 `${HARDENED_REPO}*` 會涵蓋例如名稱開頭相同的
另一個 repository。這樣可以避免 policy 阻擋叢集中的其他 Pod。

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
    allowInsecureRegistry: true   # 實驗的 registry 以 HTTP 運作
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

最後執行 `check_result`(部分,測試 9a)。

## 9b. Fresh signed ALLOW:policy 建立之後的新 Pod

對已經存在的 Deployment `catalog` 再次 `kubectl apply`,**並不能證明**
post-policy admission:如果 template 沒有改變,Kubernetes 不會建立新的
ReplicaSet/Pod,而觀察到的 `Running` 可能就是在
`require-signed-catalog-images` 之前就已存在的同一個 Pod。要證明 fresh admission,我們建立**新的**
物件,它在這一刻之前並不存在:

```bash
POLICY_CREATED=$(kubectl get imagevalidatingpolicy require-signed-catalog-images \
  -o jsonpath='{.metadata.creationTimestamp}')

# 剛建立 policy 之後,Kyverno webhook 的第一次呼叫(在 registry 中檢查簽章)可能
# 撞上 10 秒的逾時(`failed calling webhook ... context deadline exceeded`):在
# failurePolicy=Fail 下 Pod 就不會被建立。請幾秒鐘後重複執行指令即可。
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

準則(`creationTimestamp` 的精度為 1 秒,因此比較是非嚴格的):`createdAfterPolicy == true` 且 `ready == true`。這個 - 而且只有這個 - 證明
**這個** policy 放行了**這個**先前不存在的、帶有
已簽署映像的 Pod,而不是舊的 Pod 只是繼續運作。

最後執行 `check_result`(部分,測試 9b)。

## 9c. Signature-specific DENY:同一個 repository 中的 unsigned digest

Unsigned candidate 必須存在於與已簽署的 `$HARDENED_IMAGE`「相同的」repository 中 - 否則 admission 可能因為 `manifest unknown` 或
registry lookup 錯誤而拒絕,而不是因為缺少簽章,denial 也就無法證明所宣稱的
security property。我們在同一個 repository 中建置並發布第二個、刻意不簽署的 tag - 而且**務必**使用
與 `$HARDENED_IMAGE` 不同的內容:如果不加更改地建置
同一個 `Dockerfile`/context,reproducible/cached build 可能產生與已簽署映像**相同的**
manifest digest,那麼對「unsigned」tag 執行 `cosign verify` 會
出乎意料地通過 - 因為它在物理上會指向已經簽署的 artifact。因此
我們透過 `ARG`/`LABEL` 引入受控的差異,保證它會改變 digest:

```bash
export UNSIGNED_TAG="${HARDENED_TAG%:*}:unsigned-1"
podman build --build-arg CKS_SIGNATURE_TEST=unsigned-1 -t "$UNSIGNED_TAG" "$ROOT"
podman push --digestfile /tmp/cks-111-unsigned.digest "$UNSIGNED_TAG"
export UNSIGNED_DIGEST=$(cat /tmp/cks-111-unsigned.digest)
export UNSIGNED_IMAGE="${HARDENED_REPO}@${UNSIGNED_DIGEST}"
export HARDENED_DIGEST="${HARDENED_IMAGE#*@}"

# 必要的檢查:unsigned candidate 必須是物理上不同的 artifact,
# 而不是與已簽署的 HARDENED_IMAGE 相同的 digest。
[ "$UNSIGNED_DIGEST" != "$HARDENED_DIGEST" ] && echo "digests differ: OK"
printf 'hardened_digest=%s\nunsigned_digest=%s\nunsigned_image=%s\ndistinct=true\n' \
  "$HARDENED_DIGEST" "$UNSIGNED_DIGEST" "$UNSIGNED_IMAGE" > "$ART/9c/digest-comparison.txt"
cat "$ART/9c/digest-comparison.txt"
```

任務 3 的 `$ROOT/Dockerfile` 必須接受這個 build-arg(例如,
在既有指令旁邊有 `ARG CKS_SIGNATURE_TEST=signed` 與 `LABEL cks.signature-test=$CKS_SIGNATURE_TEST`)- 這樣建置出的映像與 `$HARDENED_IMAGE` 恰好
只差一個安全的 label,不會影響任務 3-4 中檢查的 security 特性。

在檢查 policy 之前,先明確證明這個 digest 存在且 pullable -
否則 denial 什麼也證明不了。這是給你自己的 self-check evidence:任務 9c 的 checker
並不信任文字檔作為唯一的證明 - 它會自己解析
`digest-comparison.txt` 中的 `unsigned_image`,自己檢查沒有簽章,並自己
以這個映像建立新的 Pod,因此在沒有真正運作的
admission control 的情況下,手動寫這些檔案不足以得到 PASS。

```bash
curl -fsSI -H 'Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.v2+json' \
  "http://$REGISTRY/v2/catalog/manifests/$UNSIGNED_DIGEST" > "$ART/9c/unsigned-exists.txt"
cat "$ART/9c/unsigned-exists.txt"        # HTTP/1.1 200 OK 以及 docker-content-digest: $UNSIGNED_DIGEST
```

明確證明沒有以同一個金鑰簽出的有效簽章 - 在嘗試建立
Pod「之前」,讓 denial 可預期地專屬於 signature,而不是其他東西:

```bash
cosign verify --key "$KEYDIR/cosign.pub" "$UNSIGNED_IMAGE" > "$ART/9c/unsigned-not-signed.txt" 2>&1
cat "$ART/9c/unsigned-not-signed.txt"     # error: no matching signatures
```

現在才嘗試建立 Pod,並確認 denial 指向的正是 policy/
signature,而不是一般的 admission 錯誤:

```bash
kubectl run catalog-unsigned-probe -n cks-111 --image="$UNSIGNED_IMAGE" --restart=Never > "$ART/9c/admission-deny.txt" 2>&1
cat "$ART/9c/admission-deny.txt"        # ... catalog image must have a valid release signature
kubectl get pod catalog-unsigned-probe -n cks-111       # NotFound:Pod 沒有建立
```

與天真的檢查的差別:如果我們改用另一個 repository 的 digest
(例如任務 1 的上游 `nginx` 的 digest),admission 可能因為完全不同的
原因而拒絕(`manifest unknown`、沒有 pull 權限)- 這樣的 denial 看起來
像是「policy 在運作」,而實際上根本沒有走到 signature 檢查。

最後執行 `check_result`。

最終檢查:

```bash
check_result
```
