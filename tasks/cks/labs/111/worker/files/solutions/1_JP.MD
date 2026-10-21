[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 111 - 参考解答

すべてのコマンドは worker で実行します。これらは、試験にもあるツール (trivy、kubesec、
kube-linter、hadolint、podman、syft、bom、cosign) の通常のコマンドです；スクリプトはなく、複数の結果を
比較する必要がある場合は、出力を目で見て行います。まず共通の
変数を設定します：

```bash
export ROOT=/home/ubuntu/cks-111 ART=/var/work/tests/artifacts BASE_TAG=nginx:1.27.3-alpine
cd $ROOT
# Tag は可変です: Trivy から manifest digest を一度だけ取得し、以降は tag@digest を使用します。
trivy image --format json $BASE_TAG > /tmp/cks-111-base.json
export IMAGE=$BASE_TAG@$(jq -r '.Metadata.RepoDigests[0]' /tmp/cks-111-base.json | cut -d@ -f2)
echo $IMAGE
```

## 0. 準備：podman と registry

image のビルドと公開には `podman` を使用します (試験のツールのリストにあります；
rootless で、`ubuntu` として動作します)。Registry は bootstrap によってすでに立ち上げられています：control-plane 上の `registry:2`
(`<ノードの IP>:5000`、VPC 内の plain HTTP、データはノードのローカル PV) です。worker の Podman は
これを insecure registry として設定済み (`/etc/containers/registries.conf.d/cks111.conf`) で、ノードの containerd も
同様なので、フラグ `--tls-verify=false` は不要です。実習の image はローカルの
キャッシュにあらかじめダウンロードされており、Trivy と Syft がそれを使用するため、再スキャンが Docker Hub の制限に当たりません。

registry のアドレス：

```bash
export REGISTRY="$(cat /etc/cks111/registry)"     # <IP control-plane>:5000
curl -fsS "http://$REGISTRY/v2/" && echo " registry ok: $REGISTRY"
podman --version
```

cosign の鍵のパスワードは、コマンドが入力待ちにならないよう空のままにします：

```bash
export COSIGN_PASSWORD=""
```

Registry は HTTP で動作します：公開した image の digest は `podman push --digestfile` から取得し、
manifest の存在は `/v2/` へのリクエストで確認します。`cosign` はプライベートネットワークのアドレスには自動的に HTTP を使用します；
Kyverno では policy に `credentials.allowInsecureRegistry: true` を設定します。`bom` は
registry からしか image を読み取れないため、引き続き Docker Hub にアクセスします；`TOOMANYREQUESTS` が出たら、
待つか、自分のアカウントで `podman login docker.io` を実行してください。

## 1. Trivy のレポート

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
grep -l $TARGET_CVE /tmp/cand?.json        # どのレポートに TARGET_CVE が含まれるか
```

たとえばそれが `/tmp/cand1.json` だとします (自分の番号に置き換えてください)：

```bash
mkdir -p $ART/1b
cp /tmp/cand1.json $ART/1b/target-scan.json
echo "OFFENDING_IMAGE=$CANDIDATE_1" > $ART/1b/answer.txt
cat $ART/1b/answer.txt
# OFFENDING_IMAGE=python:3.9-slim@sha256:...
```

## 1c. CRITICAL severity による Workload image の triage

image は live な Deployments から取得してそれぞれをスキャンします；一意の CRITICAL の数は
Deployment の名前の隣に出力されます：

```bash
mkdir -p $ART/1c
kubectl -n cks-111 get deployment -l cks.io/task=1c \
  -o jsonpath='{range .items[*]}{.metadata.name} {.spec.template.spec.containers[0].image}{"\n"}{end}' |
while read name ref; do
  trivy image --scanners vuln --severity CRITICAL --format json --output /tmp/$name.json $ref
  echo "$name $(jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | unique | length' /tmp/$name.json)"
done
```

出力から、数が最も多い Deployment (最も脆弱) と、最も少ない 2 つを見つけます。名前を
`ranking.txt` に書きます (`dep-a`、`dep-b`、`dep-c` の代わりに自分の名前を使用します)：

```bash
cat > $ART/1c/ranking.txt <<EOF
MOST_VULNERABLE=dep-a
LEAST_VULNERABLE_1=dep-b
LEAST_VULNERABLE_2=dep-c
EOF
# dep-d は 4 つ目の Deployment (CRITICAL の数が 2 番目に多い) で、ranking.txt には書きません
```

最も脆弱な Deployment の CycloneDX SBOM (その Deployment の image から) と、残りのスケール：

```bash
kubectl -n cks-111 get deployment dep-a -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
trivy image --format cyclonedx --output $ART/1c/cyclonedx.json <上の出力の image>
kubectl -n cks-111 scale deployment dep-a --replicas=0      # 最も脆弱
kubectl -n cks-111 scale deployment dep-d --replicas=0      # 4 つ目 (最も脆弱でない 2 つには入らない)
kubectl -n cks-111 get deployment -l cks.io/task=1c
```

## 2. 修正前のレポート

`hadolint`、`kubesec`、`kube-linter` は、findings があるとゼロ以外のステータスを返します；これは想定される
結果であり、レポートはそのまま保存します。

```bash
mkdir -p $ART/2
hadolint $ROOT/Dockerfile > $ART/2/hadolint-before.txt
kubesec scan $ROOT/deployment.yaml > $ART/2/kubesec-before.json
kube-linter lint $ROOT/deployment.yaml --format json > $ART/2/kube-linter-before.json
jq '.[0].scoring' $ART/2/kubesec-before.json
jq '{summary: .Summary, findings: (.Reports | length)}' $ART/2/kube-linter-before.json
```

## 3. Dockerfile を修正する

secret を image layer に追加せず、floating tag を使用しないでください：tag に manifest digest を加えた `$IMAGE` を使用します。`USER 101` は将来の hardened image の性質です。

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
# きれいな Dockerfile では hadolint の出力が空になります (戻り値 0) - ここでは空のファイルが想定どおりで正しいです。
grep -nE '^(FROM|COPY|USER)' "$ROOT/Dockerfile"
```

`ARG CKS_SIGNATURE_TEST`/`LABEL cks.signature-test` は、ここで確認した
security の性質 (base image、non-root、secret がないこと) のいずれも変えません - これは、課題 9c で
Dockerfile の残りを見直すことなく、別の manifest digest を保証する、
制御された差異の唯一の箇所です。

Kubernetes からアクセスできる registry に image をビルドして**公開**してください；ローカルの image ID/DiffID だけでは digest pinning には使えません。自分の repository に置き換えてから、registry の manifest digest を取得し、immutable reference を組み立てます：

```bash
export HARDENED_TAG="$REGISTRY/catalog:1.0"
podman build -t "$HARDENED_TAG" "$ROOT"
podman push --digestfile /tmp/cks-111-hardened.digest "$HARDENED_TAG"
export HARDENED_DIGEST=$(cat /tmp/cks-111-hardened.digest)
export HARDENED_IMAGE="${HARDENED_TAG%:*}@${HARDENED_DIGEST}"
printf '%s\n' "$HARDENED_IMAGE"   # <IP>:5000/catalog@sha256:<manifest-digest>
```

## 4. Deployment を修正する

`readOnlyRootFilesystem` では、nginx の writable な runtime paths が必要です。`emptyDir` がそれらをピンポイントで提供します；init container (これも `USER 101` を持つ hardened image) は、default config を別の writable な config volume にコピーします。`$HARDENED_IMAGE` は、課題 3 でビルドされた digest 固定の参照であり、upstream の image ではありません。

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

## 5. パッケージのバージョンの検索

`--list-all-pkgs` は実際の inventory を与えます。正規の registry manifest digest は `Metadata.RepoDigests[0]` からのみ取得します；`ImageID` と `DiffID` はローカルの image/layers を表すものであり、registry の digest の fallback ではありません。

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

## 5b. workload の image でパッケージのバージョンを見つけ、問題のあるコンテナを削除する

```bash
mkdir -p $ART/5b/bom
kubectl -n cks-111 get deployment pkg-audit-app \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name} {.image}{"\n"}{end}'
# c1 <image 1> / c2 <image 2> / c3 <image 3>
```

各 image の SBOM (出力の image に置き換えてください) と、それぞれの `パッケージ=バージョン` のリスト：

```bash
bom generate --format json --output $ART/5b/bom/c1.spdx.json --image <c1 の image>
bom generate --format json --output $ART/5b/bom/c2.spdx.json --image <c2 の image>
bom generate --format json --output $ART/5b/bom/c3.spdx.json --image <c3 の image>
for c in c1 c2 c3; do
  jq -r '.packages[]? | select(.versionInfo) | "\(.name)=\(.versionInfo)"' $ART/5b/bom/$c.spdx.json | sort -u > /tmp/$c.pkgs
done
comm -12 /tmp/c1.pkgs /tmp/c2.pkgs | wc -l     # image の各ペアにいくつ共通のパッケージがあるか
comm -12 /tmp/c1.pkgs /tmp/c3.pkgs | wc -l
comm -12 /tmp/c2.pkgs /tmp/c3.pkgs | wc -l
```

共通のパッケージを持つペアが、問題のあるコンテナです (たとえば `c1` と `c2`)。それらには共通のパッケージが
多数あります：3 つ目の image にない**任意の** `name=version` で構いません：

```bash
comm -12 /tmp/c1.pkgs /tmp/c2.pkgs | grep -vxFf /tmp/c3.pkgs | head -3
```

見つけた組を書き込み、まさにこの 2 つのコンテナを削除して (`kubectl edit`)、「クリーンな」ものを残します：

```bash
printf 'TARGET_PACKAGE=%s\nTARGET_VERSION=%s\n' <name> <version> > $ART/5b/answer.txt     # たとえば apt と 3.0.3
cat $ART/5b/answer.txt
kubectl -n cks-111 edit deployment pkg-audit-app        # 問題のある 2 つのコンテナを削除する
kubectl -n cks-111 rollout status deployment/pkg-audit-app --timeout=120s
```

## 6. SPDX SBOM (bom)

```bash
mkdir -p "$ART/6"
echo "bom generate --format json --output $ART/6/bom.spdx.json --image $IMAGE" > "$ART/6/bom-command.txt"
bom generate --format json --output "$ART/6/bom.spdx.json" --image "$IMAGE"
jq '.spdxVersion, (.packages | length)' "$ART/6/bom.spdx.json"
```

## 7. CycloneDX SBOM (Syft) と keyless Cosign

Syft は SPDX と CycloneDX の両方に対応します；ここでは CycloneDX を使います (`bom` はすでに課題 6 で SPDX を生成しました)。
公開されている Distroless の image と、期待される Google の workload identity を確認します；
`--insecure-ignore-tlog` や certificate identity のスキップは使用しないでください。

```bash
mkdir -p "$ART/7"
# tag@digest 形式の参照では、Syft は metadata.component.version に tag のみを記録します。tag のない
# 参照 ("nginx@sha256:...") では version = manifest digest となり、それが確認されます。
syft "nginx@${IMAGE#*@}" -o "cyclonedx-json=$ART/7/syft.cdx.json"
```

`syft` の後は、完了するのを待ってから、以降のコマンドを別々に貼り付けてください：`syft` (`apt-get` と同様) は
ターミナルの入力バッファを破棄するため、その直後に貼り付けた行は失われます。

```bash
jq -r '.metadata.component.version' "$ART/7/syft.cdx.json"   # sha256:<manifest-digest>
cosign verify \
  --certificate-oidc-issuer https://accounts.google.com \
  --certificate-identity keyless@distroless.iam.gserviceaccount.com \
  gcr.io/distroless/static-debian13:nonroot > $ART/7/cosign-verify.txt 2>&1
echo "exit code: $?"      # 0 = 署名が検証された

# gcr.io/distroless/static:nonroot (サフィックス -debian13 なし) は deprecated とされ、Distroless の公式 README によれば
# もう更新されません - 現在サポートされているタグ gcr.io/distroless/static-debian13:nonroot を使用します。cosign verify の成功は
# exit code によって判断され、文字列 "Verified OK" ではありません - そのような文字列は
# 実際の cosign の出力にはありません (成功時の出力は行 "Verification for <image> --" で始まり、
# 実行された確認のリストが続きます)。cosign は進行状況を stderr に書くため、2>&1 は
# 必須です - そうでないと成果物が空のままになります。
printf '\nreference=gcr.io/distroless/static-debian13:nonroot\n' >> $ART/7/cosign-verify.txt
jq '.bomFormat, (.components | length)' $ART/7/syft.cdx.json
```

## 8. `trivy sbom`: 用意された SBOM ファイルのスキャン

課題 7 の CycloneDX SBOM は、image のコンポーネントと OS の構成を記述していますが、脆弱性についての結論は
含んでいません；`trivy sbom` はそのようなファイルを入力として直接受け取り、image 自体のために
registry に再度アクセスすることはありません。

```bash
mkdir -p $ART/8
echo "trivy sbom --format json --output $ART/8/sbom-scan.json $ART/7/syft.cdx.json" > $ART/8/sbom-scan-command.txt
trivy sbom --format json --output $ART/8/sbom-scan.json $ART/7/syft.cdx.json
jq '{artifact: .ArtifactType, os: .Metadata.OS.Family, results: (.Results | length)}' $ART/8/sbom-scan.json
```

Trivy は、CycloneDX の `operating-system` コンポーネント (`alpine 3.20.5`) から OS を判定し、
パッケージを脆弱性データベースと照合します - `Results` は空ではありません。比較のために：課題 6 の SPDX
(`bom`) は、multi-arch image について OS を含まず (`Detected OS family="none"`)、`trivy sbom` はそれから
何も見つけません (`Results` が空) - そのため、この課題では CycloneDX を使用します。

## 9a. Kyverno と trusted signature の `ImageValidatingPolicy`

実習 108 と同じように Kyverno をインストールし、admission controller の準備ができるまで待ちます。

```bash
sudo install-kyverno
```

次のコマンドは、インストールが終わってから貼り付けてください (インストーラーは入力バッファを破棄します)：

```bash
kubectl -n kyverno get deployment kyverno-admission-controller
kubectl -n kyverno wait --for=condition=Available deployment/kyverno-admission-controller --timeout=180s
```

学習用の鍵ペアを `$ROOT` の外で生成してください - このディレクトリは課題 9c で
Docker build context として再利用され (Dockerfile の `COPY . /usr/share/nginx/html` は
build context のすべての内容をコピーします)、`$ROOT` の中に残された `cosign.key` は、
公開される image の filesystem の中に入り、private signing key の registry への漏洩になります。署名するのは
upstream の `nginx` ではなく、課題 3/4 の `$HARDENED_IMAGE` そのものです。この
`cosign.key` を production の CI に持ち込まないでください。

```bash
export KEYDIR=/home/ubuntu/.cks111-cosign
mkdir -p $KEYDIR $ART/9a $ART/9b $ART/9c
cd $KEYDIR && cosign generate-key-pair && cd $ROOT

# cosign sign は進行状況を stderr に書くため、2>&1 は必須です - そうでないと成果物が空のままになります。
cosign sign --key $KEYDIR/cosign.key --yes $HARDENED_IMAGE > $ART/9a/cosign-sign.txt 2>&1
cosign verify --key $KEYDIR/cosign.pub $HARDENED_IMAGE > $ART/9a/cosign-verify.txt 2>&1
cat $ART/9a/cosign-verify.txt | head -3
```

`$HARDENED_IMAGE` の署名に使ったばかりの鍵ペアの公開鍵を参照する `ImageValidatingPolicy` を作成します。
`matchImageReferences` は、policy をあなたの image の repository だけに厳密に限定します：OCI references には、
別々の区切り文字 `:` (tag) と `@` (digest) が必要です。そうでなければ、プレフィックス `${HARDENED_REPO}*` が、
たとえば同じ名前の始まりを持つ別の repository まで捕捉してしまいます。
これにより、policy がクラスターの他の Pod をブロックすることがなくなります。

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
    allowInsecureRegistry: true   # 実習の registry は HTTP で動作します
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

最後に `check_result` を実行します (部分的に、テスト 9a)。

## 9b. Fresh signed ALLOW: policy の作成後の新しい Pod

すでに存在する Deployment `catalog` を再度 `kubectl apply` しても、post-policy の admission は
**証明されません**：template が変わっていなければ、Kubernetes は新しい
ReplicaSet/Pod を作成せず、観察される `Running` は、`require-signed-catalog-images` よりも前から存在していた同じ Pod かもしれません。
fresh な admission をまさに証明するため、この時点まで存在しなかった**新しい**
オブジェクトを作成します：

```bash
POLICY_CREATED=$(kubectl get imagevalidatingpolicy require-signed-catalog-images \
  -o jsonpath='{.metadata.creationTimestamp}')

# policy の作成直後は、Kyverno の webhook の最初の呼び出し (registry での署名の確認) が
# 10 秒のタイムアウトに当たることがあります (`failed calling webhook ... context deadline exceeded`):
# failurePolicy=Fail の場合、そのとき Pod は作成されません。数秒後に単にコマンドをやり直してください。
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

基準 (`creationTimestamp` の精度は 1 秒なので、比較は非厳密です)：`createdAfterPolicy == true` かつ `ready == true`。これが - そしてこれだけが - 証明するのは、
まさに**この** policy が、署名された image を持つ、以前には存在しなかったまさに**この** Pod を通したことであり、
古い Pod が単に動作し続けているのではないことです。

最後に `check_result` を実行します (部分的に、テスト 9b)。

## 9c. Signature-specific DENY: 同じ repository の署名されていない digest

署名されていない candidate は、署名された `$HARDENED_IMAGE` と**同じ** repository に存在する必要があります -
そうでないと、admission は署名がないからではなく、`manifest unknown` や
registry lookup のエラーで拒否する可能性があり、denial は主張される
security property を証明しません。同じ repository に、2 つ目の、意図的に署名しない tag をビルドして公開します -
そして**必ず** `$HARDENED_IMAGE` とは異なる内容にしてください：変更なしで
同じ `Dockerfile`/context をビルドすると、reproducible/cached なビルドが、すでに署名された image と**同じ**
manifest digest を生成することがあり、その場合、「署名されていない」tag に対する `cosign verify` が
予期せず通ってしまいます - それは物理的にすでに署名された artifact を指すからです。そのため、
digest を確実に変える `ARG`/`LABEL` によって、制御された差異を加えます：

```bash
export UNSIGNED_TAG="${HARDENED_TAG%:*}:unsigned-1"
podman build --build-arg CKS_SIGNATURE_TEST=unsigned-1 -t "$UNSIGNED_TAG" "$ROOT"
podman push --digestfile /tmp/cks-111-unsigned.digest "$UNSIGNED_TAG"
export UNSIGNED_DIGEST=$(cat /tmp/cks-111-unsigned.digest)
export UNSIGNED_IMAGE="${HARDENED_REPO}@${UNSIGNED_DIGEST}"
export HARDENED_DIGEST="${HARDENED_IMAGE#*@}"

# 必須の確認: 署名されていない candidate は、物理的に異なる artifact でなければならず、
# すでに署名された HARDENED_IMAGE と同じ digest であってはなりません。
[ "$UNSIGNED_DIGEST" != "$HARDENED_DIGEST" ] && echo "digests differ: OK"
printf 'hardened_digest=%s\nunsigned_digest=%s\nunsigned_image=%s\ndistinct=true\n' \
  "$HARDENED_DIGEST" "$UNSIGNED_DIGEST" "$UNSIGNED_IMAGE" > "$ART/9c/digest-comparison.txt"
cat "$ART/9c/digest-comparison.txt"
```

課題 3 の `$ROOT/Dockerfile` は、この build-arg を受け取れる必要があります (たとえば、
`ARG CKS_SIGNATURE_TEST=signed` と `LABEL cks.signature-test=$CKS_SIGNATURE_TEST` を、
既存の命令の隣に) - そうすれば、ビルドされた image は、課題 3-4 で確認した security の性質に触れることなく、
1 つの安全な label だけで `$HARDENED_IMAGE` と異なります。

policy を確認する前に、この digest が存在し pullable であることを明示的に実証します -
そうでないと denial は何も証明しません。これはあなた自身のための self-check の evidence です：課題 9c の checker は
テキストファイルを唯一の証明として信用しません - `digest-comparison.txt` の
`unsigned_image` を自分で解決し、署名がないことを自分で確認し、
この image を持つ新しい Pod を自分で作成するため、実際に動作する
admission control なしにこれらのファイルを手で書いても PASS には不十分です。

```bash
curl -fsSI -H 'Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.v2+json' \
  "http://$REGISTRY/v2/catalog/manifests/$UNSIGNED_DIGEST" > "$ART/9c/unsigned-exists.txt"
cat "$ART/9c/unsigned-exists.txt"        # HTTP/1.1 200 OK と docker-content-digest: $UNSIGNED_DIGEST
```

同じ鍵による有効な署名がないことを明示的に実証します - Pod を作成しようとする**前に**行い、
denial が他の何かではなく、signature に固有のものであると予測できるようにします：

```bash
cosign verify --key "$KEYDIR/cosign.pub" "$UNSIGNED_IMAGE" > "$ART/9c/unsigned-not-signed.txt" 2>&1
cat "$ART/9c/unsigned-not-signed.txt"     # error: no matching signatures
```

ここで初めて Pod の作成を試み、denial が一般的な admission エラーではなく、まさに policy/
signature を参照していることを確認します：

```bash
kubectl run catalog-unsigned-probe -n cks-111 --image="$UNSIGNED_IMAGE" --restart=Never > "$ART/9c/admission-deny.txt" 2>&1
cat "$ART/9c/admission-deny.txt"        # ... catalog image must have a valid release signature
kubectl get pod catalog-unsigned-probe -n cks-111       # NotFound: Pod は作成されていない
```

素朴な確認との違い：代わりに別の repository の digest (たとえば、課題 1 の upstream `nginx` の digest) を使っていたら、
admission はまったく別の理由 (`manifest unknown`、pull アクセスがない) で拒否した可能性があり - そのような denial は
「policy が動作している」ように見えたでしょうが、実際には signature の確認にまったく到達していなかったことになります。

最後に `check_result` を実行します。

最終確認：

```bash
check_result
```
