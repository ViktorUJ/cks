[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 130 - 參考解答(ECR 與 supply chain)

所有指令都在工作機(worker)上透過 SSH 執行。AWS CLI 已經透過執行個體的 role
設定好對應的帳戶(不需要額外的 `aws configure`),kubectl 也已指向這個實驗的
叢集。我們用 `podman` 取代 `docker`(worker 上已經安裝好了)。

先一次性定義好 account id 與私有登錄檔的位址:

```bash
export AWS_REGION=eu-central-1
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_HOST="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo "$ECR_HOST"
```

## 任務 1. 帶有 IMMUTABLE 標籤與 scanOnPush 的儲存庫

```bash
aws ecr create-repository \
  --repository-name eks-lab130/app \
  --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true \
  --region "$AWS_REGION"

aws ecr describe-repositories --repository-names eks-lab130/app --region "$AWS_REGION"
```

確認輸出中 `imageTagMutability: IMMUTABLE` 以及
`imageScanningConfiguration.scanOnPush: true`。

## 任務 2. Push 帶有 v1 標籤的映像

用一個 12 小時的 token 登入登錄檔,並重新標記公開映像:

```bash
aws ecr get-login-password --region "$AWS_REGION" \
  | podman login --username AWS --password-stdin "$ECR_HOST"

podman pull docker.io/library/alpine:3.19
podman tag docker.io/library/alpine:3.19 "$ECR_HOST/eks-lab130/app:v1"
podman push "$ECR_HOST/eks-lab130/app:v1"

aws ecr describe-images --repository-name eks-lab130/app --region "$AWS_REGION"
```

`describe-images` 的輸出中應該有一個標籤為 `v1` 的映像。

有兩個實際要注意的點。第一:這裡選 `alpine` 不是因為「比較輕」,而是因為 ECR
的基礎掃描能解析它的套件資料庫 - 任務 4 會得到真正的 findings(在測試環境上
驗證過:`alpine:3.19` 上是 HIGH 1、MEDIUM 1、LOW 2)。第二:請把任務 2-6 保持
在同一個 SSH session 中。`podman login` 會把 token 寫到
`$XDG_RUNTIME_DIR/containers/auth.json`,而這個目錄會隨著使用者 session 一起
被刪除,因此重新連線後,即使 ECR 12 小時的 token 還活著,push 也會回應
`unauthorized: authentication required`。

## 任務 3. 症狀:重複 push 標籤 v1 被拒絕

取另一個映像,用相同的 `v1` 標記,並嘗試覆寫:

```bash
podman pull docker.io/library/busybox:1.36
podman tag docker.io/library/busybox:1.36 "$ECR_HOST/eks-lab130/app:v1"

mkdir -p /var/work/tests/artifacts/3
podman push "$ECR_HOST/eks-lab130/app:v1" 2>&1 \
  | tee /var/work/tests/artifacts/3/denied.txt
```

Push 以登錄檔的拒絕告終(在測試環境上驗證過):

```
tag invalid: The image tag 'v1' already exists in the 'eks-lab130/app' repository
and cannot be overwritten because the tag is immutable.
```

這正是 IMMUTABLE 的運作方式:標籤 `v1` 已經被第一個映像佔用,無法被覆寫。輸出
會很長 - `podman` 會依序嘗試多種 manifest 格式(OCI、docker v2、docker
v1),每一種都得到同樣的拒絕;在產物 `denied.txt` 中,需要的那一行會出現在
每一次嘗試裡。請注意,這時層(layer)其實已經上傳完成了:IMMUTABLE 保護的是
「標籤的綁定」,而不是 blob 儲存本身。

## 任務 4. 掃描的 findings(scan on push)

掃描在 push 時(任務 2)會自動開始。我們透過 retry 迴圈等待完成(這個版本的
CLI 已經有現成的等待指令):

```bash
aws ecr wait image-scan-complete \
  --repository-name eks-lab130/app --image-id imageTag=v1 --region "$AWS_REGION"

mkdir -p /var/work/tests/artifacts/4
aws ecr describe-image-scan-findings \
  --repository-name eks-lab130/app --image-id imageTag=v1 --region "$AWS_REGION" \
  --query '{status: imageScanStatus.status, bySeverity: imageScanFindings.findingSeverityCounts}' \
  > /var/work/tests/artifacts/4/scan-summary.txt

cat /var/work/tests/artifacts/4/scan-summary.txt
```

如果你的 CLI 版本沒有 `aws ecr wait image-scan-complete`,可以用手動的 retry
迴圈代替:

```bash
for i in $(seq 1 30); do
  status=$(aws ecr describe-image-scan-findings \
    --repository-name eks-lab130/app --image-id imageTag=v1 --region "$AWS_REGION" \
    --query 'imageScanStatus.status' --output text 2>/dev/null)
  [[ "$status" == "COMPLETE" ]] && break
  sleep 5
done
```

`findingSeverityCounts` 會顯示按 severity 分類的 findings 數量 - 在
`alpine:3.19` 上這是 `{"HIGH": 1, "MEDIUM": 1, "LOW": 2}`(在測試環境上驗證
過,具體數字取決於掃描日期與漏洞資料庫)。

有一個值得自己驗證的重要適用範圍界線。ECR 的基礎掃描讀取的是已知發行版的套件
資料庫,因此以 `FROM scratch` 建置的映像(例如靜態編譯的 Go 二進位檔)或
distroless 映像,它是「無法」掃描的:

```bash
aws ecr describe-image-scan-findings --repository-name eks-lab130/app \
  --image-id imageTag=<scratch 映像的標籤> --region "$AWS_REGION" \
  --query 'imageScanStatus' --output json
# {
#   "status": "FAILED",
#   "description": "UnsupportedImageError: The operating system and/or package manager
#                   are not supported."
# }
```

由此可以得出一個實際的結論:「掃描器沒發現漏洞」與「掃描器沒辦法看」是兩件
不同的事,而在匯總報告中它們很容易被混在一起,變成「沒有問題」。如果 gate
政策要求乾淨的掃描結果,應該檢查的是狀態本身,而不只是 findings 的數量。

## 任務 5. 依 digest 部署

映像 `v1` 的 digest 可以從 ECR 取得(比 `podman inspect` 更可靠,因為這正是
登錄檔裡那份 manifest 的 digest):

```bash
DIGEST=$(aws ecr describe-images --repository-name eks-lab130/app --image-ids imageTag=v1 \
  --region "$AWS_REGION" --query 'imageDetails[0].imageDigest' --output text)
echo "$DIGEST"

kubectl create namespace eks-130 --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: digest-app
  namespace: eks-130
  labels:
    app: digest-app
spec:
  nodeSelector:
    kubernetes.io/arch: amd64
  containers:
  - name: app
    image: ${ECR_HOST}/eks-lab130/app@${DIGEST}
    command: ["sh", "-c", "sleep 86400"]
EOF

kubectl wait --for=condition=Ready pod/digest-app -n eks-130 --timeout=600s
kubectl get po -n eks-130 digest-app -o wide
```

這裡的 `nodeSelector` 是必須的,而且是一個很容易踩到的陷阱。工作機是
x86_64,所以 `podman push` 送到 ECR 的是單一架構的 manifest(只有
`amd64`),而這個實驗的 NodePool 同時允許 `arm64`。在測試環境上驗證過:沒有
選擇器的話,Karpenter 會啟動一台 `t4g.small`,映像順利下載下來,但容器以
`exitCode 255` 死掉,而且日誌是空的 - `CrashLoopBackOff`,卻找不到明確的
原因。同一類問題在實驗 124 中也出現過(映像 `polinux/stress` 只有
`amd64`)。對生產環境的啟示是:要麼建置多架構的 manifest,要麼明確把工作負
載綁定到特定架構。

Karpenter 節點的 role 已經帶有 managed policy
`AmazonEC2ContainerRegistryReadOnly`(在 `eks_v2_karpenter` 模組中設定
好),因此 pod 能順利拉取映像並進入 `Running` 狀態,不需要
`imagePullSecrets`。透過 `@sha256:` 的參照,精確固定了你在任務 2-4 中掃描並
檢查過的那組位元組 - 標籤可能會被改指向別處,digest 不會。

## 任務 6. registry.k8s.io 的 pull through cache

不需要驗證的規則 - 上游是公開的:

```bash
aws ecr create-pull-through-cache-rule \
  --ecr-repository-prefix k8s-cache \
  --upstream-registry-url registry.k8s.io \
  --region "$AWS_REGION"
```

建立帳戶中「第一個」規則時,ECR 會建立 service-linked role
`AWSServiceRoleForECRPullThroughCache`,因此呼叫者需要
`iam:CreateServiceLinkedRole` 權限(工作機的政策裡有這個權限,附帶條件
`iam:AWSServiceName = pullthroughcache.ecr.amazonaws.com`)。沒有這個權限
時,ECR 回應的不是直接針對使用者 IAM 的訊息,而是一層包裝,很容易被誤認成
參數錯誤:`ValidationException ... The Amazon ECR action failed due to an
IAM exception: ... is not authorized to perform:
iam:CreateServiceLinkedRole`(在測試環境上重現過)。

第一次透過快取 pull,會在你的 ECR 中建立儲存庫 `k8s-cache/pause` 並快取這個
映像:

```bash
podman pull "${ECR_HOST}/k8s-cache/pause:3.9"

aws ecr describe-repositories --region "$AWS_REGION" \
  --query "repositories[?starts_with(repositoryName,'k8s-cache/pause')].repositoryName"
```

## 任務 7. 帶密鑰的 Docker Hub pull through cache(不需要真正 pull)

這個實驗的主題就是要求密鑰,所以我們真的把它建起來,但用佔位符取代真正的
Docker Hub token:用這種憑證做真正的 pull 不會成功,但這不會影響設定本身
(密鑰加上 cache rule)的正確性,而且能完整地被檢查。

```bash
aws secretsmanager create-secret \
  --name ecr-pullthroughcache/dockerhub-creds \
  --description "Docker Hub creds for ECR pull through cache (lab placeholder)" \
  --secret-string '{"username":"lab-placeholder-user","accessToken":"lab-placeholder-token"}' \
  --region "$AWS_REGION"

SECRET_ARN=$(aws secretsmanager describe-secret \
  --secret-id ecr-pullthroughcache/dockerhub-creds --region "$AWS_REGION" \
  --query 'ARN' --output text)
echo "$SECRET_ARN"

aws ecr create-pull-through-cache-rule \
  --ecr-repository-prefix docker-hub \
  --upstream-registry-url registry-1.docker.io \
  --credential-arn "$SECRET_ARN" \
  --region "$AWS_REGION"

aws ecr describe-pull-through-cache-rules --region "$AWS_REGION"
```

密鑰一定要帶有前綴 `ecr-pullthroughcache/` - 否則 ECR 不會接受它作為
cache rule 的憑證。用這個佔位符透過 `docker-hub/...` 做真正的
`podman pull` 預期會失敗(憑證不是真的) - 任務檢查的是設定(密鑰與規則
存在),不是 pull 成功的事實。要確認透過快取成功 pull 的事實,由任務 6
(registry.k8s.io,不需要驗證)負責。

重要提示:這裡不要用真正的 Docker Hub 憑證。這個密鑰只是為了檢查這個實驗本身
的設定。

## 任務 8. Lifecycle policy

規則:最多保留 5 個帶標籤 `v.*` 的映像,其餘依標籤的存在時間刪除:

```bash
cat <<'EOF' > /tmp/lifecycle.json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "keep last 5 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 5
      },
      "action": { "type": "expire" }
    }
  ]
}
EOF

aws ecr put-lifecycle-policy \
  --repository-name eks-lab130/app \
  --lifecycle-policy-text file:///tmp/lifecycle.json \
  --region "$AWS_REGION"

aws ecr get-lifecycle-policy --repository-name eks-lab130/app --region "$AWS_REGION"
aws ecr start-lifecycle-policy-preview \
  --repository-name eks-lab130/app --region "$AWS_REGION" >/dev/null
sleep 5
aws ecr get-lifecycle-policy-preview \
  --repository-name eks-lab130/app --region "$AWS_REGION"
```

`get-lifecycle-policy-preview` 可能不會馬上回傳結果(預覽是非同步計算的) -
如果狀態還是 `IN_PROGRESS`,請幾秒後再重試一次。

## 快速檢查

```bash
check_result
```
