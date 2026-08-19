[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 121 - 參考解答(存取疑難排解:access entries、IRSA、kubeconfig)

所有命令都在工作機上透過 SSH 執行。kubectl 已經配置好指向集群,terraform 已經創建了
`eks_irsa_break_demo` 組件的 S3 bucket 和 IRSA 角色 - 它們的名稱和 ARN 都在提示檔案
`/home/ubuntu/lab121_hints.txt` 中。

```bash
cat ~/lab121_hints.txt
```

解答的其餘部分會使用這個檔案中的變數:

```bash
export BUCKET_NAME=$(grep '^bucket_name' ~/lab121_hints.txt | awk '{print $3}')
export IRSA_ROLE_ARN=$(grep '^irsa_role_arn' ~/lab121_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab121_hints.txt | awk '{print $3}')
```

這個實驗涵蓋了第 47 章中兩條彼此獨立的存取軸線:人類/CI 無法進入集群(任務 1-4),以
及 Pod 在呼叫 AWS 時得到 `AccessDenied`(任務 5-8)。

## 任務 1。Namespace `eks-121`

```bash
kubectl create namespace eks-121
```

## 任務 2。Unauthorized 症狀:一個沒有 access entry 的角色

我們創建一個完全沒有 access entry 的測試用 IAM 角色。worker 的角色只允許管理名稱中含
`-test-` 的角色(參見 `eks_v2_work_pc` 模組的 `iam.tf`),所以名稱中必須包含這個子字
串:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TEST_ROLE_NAME="eks-task121-test-noaccess"

cat > /tmp/trust-worker.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "AWS": "$(aws sts get-caller-identity --query Arn --output text)" },
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role --role-name "$TEST_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust-worker.json

export TEST_ROLE_ARN=$(aws iam get-role --role-name "$TEST_ROLE_NAME" \
  --query 'Role.Arn' --output text)
```

worker 的角色專門對名稱中含 `-test-` 的 ARN 帶有 `sts:AssumeRole` 權限,因此我們可以
直接 assume 這個角色:

這裡的順序很重要。我們**在** `assume-role` **之前**,用 worker 自己的憑證建立這個獨立
的 kubeconfig:`aws eks update-kubeconfig` 會呼叫 `eks:DescribeCluster`,而測試角色完全
沒有任何 IAM policy,因此在該角色下執行這個命令會以 `AccessDeniedException` 失敗,檔案
也不會被創建。順帶一提,這其實是這條鏈路中的第三種失敗類型:來自 IAM 的
`AccessDenied`(對 AWS API 沒有權限)與 `Unauthorized`(身份沒有映射進集群)以及
`Forbidden`(RBAC)都不相同。`kubectl` 本身之後會透過 `aws eks get-token` 取得 token,
而這個 token 會來自環境變數中當前存在的那個身份的憑證:

```bash
aws eks update-kubeconfig --name "$CLUSTER_NAME" --kubeconfig /tmp/kubeconfig-test

CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name lab121-noaccess --duration-seconds 900)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')
```

我們檢查這個身份對集群的存取權 - 因為沒有 access entry,它沒有被映射,所以我們預期會
得到 `Unauthorized`(第 47 章,47.3 節):

```bash
mkdir -p /var/work/tests/artifacts/2
kubectl --kubeconfig /tmp/kubeconfig-test get pods -A \
  > /var/work/tests/artifacts/2/unauthorized.txt 2>&1
cat /var/work/tests/artifacts/2/unauthorized.txt
```

檔案中應該有一行包含 `Unauthorized` 這個詞 - API server 無法將這個 IAM 身份對應到任何
access entry 或 aws-auth 記錄。

我們恢復 worker 自己的憑證(這個會話的環境變數已經不再需要):

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

## 任務 3。修復 Unauthorized:access entry + AmazonEKSViewPolicy

我們為測試角色創建一個 access entry,並在 cluster scope 上授予它 `AmazonEKSViewPolicy`
這個 access policy(第 47 章,47.4 節):

```bash
aws eks create-access-entry --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$TEST_ROLE_ARN" --type STANDARD

aws eks associate-access-policy --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster
```

我們重新執行 `assume-role`(第一個會話已經過期或結束),再用同一個臨時 kubeconfig 執
行同樣的請求 - 現在應該返回 Pod 清單,而不是 `Unauthorized`:

```bash
CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name lab121-access --duration-seconds 900)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')

mkdir -p /var/work/tests/artifacts/3
kubectl --kubeconfig /tmp/kubeconfig-test get pods -A \
  > /var/work/tests/artifacts/3/authorized.txt 2>&1
cat /var/work/tests/artifacts/3/authorized.txt
```

現在檔案中有 `NAMESPACE ... POD ...` 這樣的行 - access entry 已經清除了
`Unauthorized` 錯誤。

## 任務 4。Forbidden 症狀:View 權限不允許寫入

這個角色只有 `AmazonEKSViewPolicy`(讀取)。我們用同一個臨時 kubeconfig 嘗試創建一個
namespace - RBAC 應該會以 `Forbidden` 拒絕它(第 47 章,47.3 節):

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl --kubeconfig /tmp/kubeconfig-test create namespace test-forbidden \
  > /var/work/tests/artifacts/4/forbidden.txt 2>&1
cat /var/work/tests/artifacts/4/forbidden.txt
```

我們在同一個檔案後面附加一段說明,解釋任務 2(`Unauthorized`)與任務 4
(`Forbidden`)之間的差異:

```bash
cat >> /var/work/tests/artifacts/4/forbidden.txt <<'EOF'

差異:在任務 2 中,role 根本沒有被映射到叢集中 - API server 無法證明 identity,這就是
Unauthorized (認證失敗,authn 層)。在任務 4 中,identity 已經被證明並透過 access entry
完成映射,但 RBAC (AmazonEKSViewPolicy 只授予讀取) 不允許建立 namespace - 這就是 Forbidden
(授權失敗,authz 層)。修正方式不同:Unauthorized 是在映射 (access entry / aws-auth) 中修正,
Forbidden 是在 RBAC (Role、ClusterRole、policy binding) 中修正。
EOF
cat /var/work/tests/artifacts/4/forbidden.txt

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

## 任務 5。帶有正確 IRSA 註解的 ServiceAccount

`eks_irsa_break_demo` 角色已經由 terraform 創建完成,它的 trust policy 恰好信任
`system:serviceaccount:eks-121:demo-reader`(第 16 章、第 47 章 47.6 節):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-reader
  namespace: eks-121
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: irsa-app
  namespace: eks-121
spec:
  serviceAccountName: demo-reader
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/irsa-app -n eks-121 --timeout=120s
```

我們檢查身份,並從 S3 讀取這個物件:

```bash
mkdir -p /var/work/tests/artifacts/5
{
  echo "--- caller identity ---"
  kubectl exec irsa-app -n eks-121 -- aws sts get-caller-identity
  echo "--- s3 object ---"
  kubectl exec irsa-app -n eks-121 -- aws s3 cp "s3://${BUCKET_NAME}/hello.txt" -
} > /var/work/tests/artifacts/5/irsa_ok.txt
cat /var/work/tests/artifacts/5/irsa_ok.txt
```

輸出中的 `Arn` 應該看起來像 `assumed-role/<prefix>-irsa-role/...`,第二個區塊應該是
`hello from s3` 這一行(terraform 放進去的物件內容)。

## 任務 6。AccessDenied 症狀:另一個 namespace 中的錯誤註解

我們創建第二個 SA,帶有指向同一個角色的相同註解,但放在 `default` namespace 中。這個
角色的 trust policy 期望的是
`sub = system:serviceaccount:eks-121:demo-reader`,而這個 SA 的 `sub` 會是
`system:serviceaccount:default:demo-reader-broken` - 這個條件不會相符(第 47 章,47.6
節):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-reader-broken
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-app
  namespace: default
spec:
  serviceAccountName: demo-reader-broken
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/broken-app -n default --timeout=120s
```

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl exec broken-app -n default -- aws sts get-caller-identity \
  > /var/work/tests/artifacts/6/broken.txt 2>&1
cat /var/work/tests/artifacts/6/broken.txt
```

這個命令應該會以 token 交換錯誤失敗:`AccessDenied` 或 `WebIdentityErr`(具體訊息因
SDK/CLI 版本而不同,但原理是一樣的 - STS 拒絕了 `sts:AssumeRoleWithWebIdentity`,因為
token 中的 `sub` 與 trust policy 的條件不相符)。

## 任務 7。診斷:對比註解並找出 `sub` 的根本原因

我們對比兩個 namespace 中的 SA 註解,並解釋原因:

```bash
mkdir -p /var/work/tests/artifacts/7
{
  echo "--- eks-121/demo-reader ---"
  kubectl get sa demo-reader -n eks-121 \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
  echo
  echo "--- default/demo-reader-broken ---"
  kubectl get sa demo-reader-broken -n default \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
  echo
  echo
  cat <<'TXT'
兩個註解都指向同一個 IRSA role,但 role 的 trust policy 會檢查 STS token 上的 sub 條件:
system:serviceaccount:<namespace>:<serviceaccount>。對於 demo-reader 而言那是
system:serviceaccount:eks-121:demo-reader - 它與 role 的條件相符,因此交換被允許。對於
demo-reader-broken,token 帶有 sub=system:serviceaccount:default:demo-reader-broken - 這是
不同的 namespace 和不同的 SA 名稱,因此 StringEquals 條件不相符,而且無論註解中的 role ARN
是否相同,sts:AssumeRoleWithWebIdentity 都會被拒絕。
TXT
} > /var/work/tests/artifacts/7/diagnostics.txt
cat /var/work/tests/artifacts/7/diagnostics.txt
```

## 任務 8。總結:兩條存取軸線

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/summary.txt <<'EOF'
人的軸線 (任務 2-4) 存在於這條鏈中:kubectl - IAM - EKS authenticator - RBAC:Unauthorized
表示 IAM identity 根本無法被證明或映射到叢集中 (透過 access entry 或 aws-auth 修正),而
Forbidden 表示 identity 已經是已知的,但 RBAC 不允許那個特定動作 (透過 Role/ClusterRoleBinding
修正)。pod 的軸線 (任務 5-7) 存在於這條鏈中:pod - ServiceAccount - STS - IAM role:
AccessDenied 或 WebIdentityErr 表示 role 的 trust policy 與 ServiceAccount token 的 sub
不相符 (透過編輯 trust policy 或 SA 註解中的 sub 條件來修正)。關鍵差異:在第一條軸線上,修正的是
叢集內部的 RBAC,在第二條軸線上,修正的是 AWS 中 IAM role 的 trust policy,這兩者絕不可混淆。
EOF
cat /var/work/tests/artifacts/8/summary.txt
```

## 快速檢查

```bash
check_result
```
