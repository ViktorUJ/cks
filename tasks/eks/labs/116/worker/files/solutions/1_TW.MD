[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 116 - 參考解答 (IMDSv2 hop limit、Pod Security Admission、私有 endpoint)

所有指令都在 worker 機器上透過 SSH 執行。kubectl 已經配置好指向該 cluster (kubeconfig
是機器啟動時透過 `aws eks update-kubeconfig` 產生的)。

## 任務 1. Namespace `eks-116`

```bash
kubectl create namespace eks-116
```

## 任務 2. 症狀:從 pod 無法存取 IMDS

NodePool `hardened` (這個 lab 裡唯一的一個) 透過 EC2NodeClass 的 `metadataOptions` 在其
所有 node 上設定了 `httpPutResponseHopLimit=1`。host 上程序發出的封包只需一個 hop 就能
到達 IMDS,而 pod 發出的封包會多一個 hop (容器的 network namespace) - 因此超出限制。
我們建立一個帶有休眠容器的 Deployment,方便用 exec 進去:

```bash
kubectl create deployment probe --image=curlimages/curl:latest -n eks-116 \
  -- sleep 3600
kubectl rollout status deployment/probe -n eks-116
```

從 pod 發出 IMDSv2 請求 (先拿 token,再取資料),並設定時間限制:

```bash
POD=$(kubectl get po -n eks-116 -l app=probe -o jsonpath='{.items[0].metadata.name}')
mkdir -p /var/work/tests/artifacts/2

kubectl exec -n eks-116 "$POD" -- sh -c '
  echo "=== PUT token ===";
  TOKEN=$(curl -sX PUT --max-time 5 "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600");
  if [ -z "$TOKEN" ]; then
    echo "no token received: request timed out (hop limit blocked the pod)";
  else
    echo "=== GET with token ===";
    curl -s --max-time 5 -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/iam/security-credentials/ \
      || echo "GET timed out (hop limit blocked the pod)";
  fi
' 2>&1 | tee /var/work/tests/artifacts/2/imds.txt

cat /var/work/tests/artifacts/2/imds.txt
```

在 hop limit 為 `1` 的情況下,`curl` 在給定的 `5` 秒內收不到回應,檔案裡會留下一行關於
timeout 的訊息 (`curl` 在 `-v` 模式下會印出 `curl: (28) ... timeout`,若沒拿到 token,
腳本本身會補上 `timed out` 的說明)。

## 任務 3. 透過 AWS API 驗證:node 上的 hop limit 和 IMDSv2

先找出 `probe` 跑在哪個 node 上,取得其 `providerID`,再取出 instance id:

```bash
NODE=$(kubectl get po -n eks-116 -l app=probe -o jsonpath='{.items[0].spec.nodeName}')
PROVIDER_ID=$(kubectl get node "$NODE" -o jsonpath='{.spec.providerID}')
# providerID 格式為 aws:///eu-central-1a/i-0abc123def456789
INSTANCE_ID=$(echo "$PROVIDER_ID" | awk -F'/' '{print $NF}')
echo "node=$NODE instance=$INSTANCE_ID"

mkdir -p /var/work/tests/artifacts/3
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[].Instances[].MetadataOptions' --output json \
  | tee /var/work/tests/artifacts/3/metadata_options.txt
```

輸出裡應該看到 `"HttpTokens": "required"` 和 `"HttpPutResponseHopLimit": 1` - 這正是
`eks_karpenter_hardened_vng/terragrunt.hcl` 裡 `vng.metadataOptions` 設定的值,也是
EC2NodeClass 傳給該 node 的 launch template 的值。

## 任務 4. Pod Security Admission:拒絕 privileged pod

透過標籤在 namespace 上啟用 restricted (PSA 內建於 EKS,但預設情況下沒有標籤的
namespace 行為等同於 `privileged` - 不會限制任何東西):

```bash
kubectl label namespace eks-116 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest
```

嘗試建立一個 privileged pod - admission 應該拒絕建立:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl run priv-test -n eks-116 --image=busybox --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"priv-test","image":"busybox","securityContext":{"privileged":true}}]}}' \
  2>&1 | tee /var/work/tests/artifacts/4/psa_reject.txt

kubectl get pod priv-test -n eks-116 2>&1 | tee -a /var/work/tests/artifacts/4/psa_reject.txt
cat /var/work/tests/artifacts/4/psa_reject.txt
```

預期輸出類似:

```
Error from server (Forbidden): pods "priv-test" is forbidden: violates PodSecurity "restricted:latest": privileged (container "priv-test" must not set securityContext.privileged=true)
```

pod 不會被建立出來 (`kubectl get pod priv-test` 會回傳 `NotFound`),訊息裡包含
`privileged` 和 `restricted`/`violates` 這些字 - 這正是驗收標準所要求的。

## 任務 5. 被允許的路徑:符合 restricted 的 pod

我們建立一個具備 `restricted` profile 要求的所有欄位的 pod。`runAsNonRoot: true` 只是
禁止以 root 身份執行 - `busybox:latest` 這個 image 預設沒有宣告 non-root 使用者,所以
如果沒有明確設定 `runAsUser` (任何非零的 UID),kubelet 會在 admission 已經放行該 pod
之後,再用另一個錯誤 `container has runAsNonRoot and image will run as root` 阻止容器
啟動:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: safe-pod
  namespace: eks-116
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:latest
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
EOF

kubectl get pod safe-pod -n eks-116 -o wide
```

這個 pod 通過 admission 並進入 `Running` 狀態 - 同一個 namespace、同一個 `restricted`
profile,但需求已完全滿足:`runAsNonRoot` 搭配明確的 `runAsUser`、
`allowPrivilegeEscalation: false`、`capabilities.drop: ["ALL"]`、`seccompProfile`
`RuntimeDefault`。

## 任務 6. control plane 的私有存取和 VPC endpoints

檢查 cluster 的 `resourcesVpcConfig` - `eks_v2_control_plane` 模組已經啟用了這兩個旗標
(`endpoint_public_access = true`、`endpoint_private_access = true`):

```bash
CLUSTER=$(kubectl config current-context | sed 's|.*/||')
mkdir -p /var/work/tests/artifacts/6

aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig' --output json \
  | tee /var/work/tests/artifacts/6/private_endpoint.txt
```

輸出裡有 `"endpointPrivateAccess": true`。在檔案裡補上說明:

```bash
cat >> /var/work/tests/artifacts/6/private_endpoint.txt <<'EOF'

要打造完全私有的 cluster (node 沒有連往網際網路的出口),需要以下 VPC endpoints:
ecr.api 和 ecr.dkr (用來拉取容器 images)、s3 gateway endpoint (ECR image 的 layer
實際上存放在 S3 裡,所以即使有 ecr.api 和 ecr.dkr,少了它 image 還是下載不下來)、
sts (把 IRSA token 換成暫時憑證)、ec2 (node 註冊和 DNS 名稱)、logs (把日誌送到
CloudWatch) 以及 eks (從 VPC 存取 EKS API)。control plane 的私有存取 (這個 cluster
已經啟用) 是獨立於 endpoint 清單之外的必要條件 - 少了它,node 就無法從私有子網路
向 API server 完成註冊。
EOF

cat /var/work/tests/artifacts/6/private_endpoint.txt
```

## 快速驗證

```bash
check_result
```
