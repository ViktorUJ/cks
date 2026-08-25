[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 102 - 參考解答(集群存取:IAM、RBAC、access entries)

所有命令都在工作機(worker)上透過 SSH 執行。kubectl 已經配置好指向集群。worker 角色
擁有 `eks:*`(對所有 access entry/access policy 命令來說已經足夠)以及精確授權的
`iam:CreateRole/GetRole/DeleteRole/PutRolePolicy` 加上 `sts:AssumeRole`,並限定在名稱
形如 `*-test-*` 的角色上 - 這已經足夠用來創建測試角色並真正對它執行 assume-role,而不
會影響其他實驗的權限。

## 選擇第二個主體

集群已經由 `eks_v2_control_plane` 模組以 `authenticationMode = API` 模式創建完成
(v21 `terraform-aws-modules/eks/aws`,`enable_cluster_creator_admin_permissions = true`)。
worker 角色已經擁有自己的 access entry,帶有 `AmazonEKSClusterAdminPolicy`
(`terraform/modules/eks_v2_work_pc/iam.tf`) - 這證實了集群中的 API access entries 功能
已經啟用且正常運作。

這個實驗的任務需要一個**第二個** IAM 主體,它目前還沒有存取集群的權限。Karpenter 的
節點角色不適合用作這個主體:`terraform-aws-modules/eks/aws//modules/karpenter` submodule
會自動為它創建 `EC2_LINUX` 類型的 access entry(預設 `create_access_entry = true`),而
一個 IAM 主體不能同時存在於兩個 access entry 中。因此這個實驗直接在 worker 上透過
AWS CLI 創建一個獨立的測試角色,信任關係只授予 worker 角色本身(`sts:AssumeRole` 只允
許 worker 角色的 ARN,不允許任何其他人)。

## 任務 1。清單盤點:authenticationMode

```bash
mkdir -p /var/work/tests/artifacts/1
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.accessConfig' \
  > /var/work/tests/artifacts/1/accessconfig.json
cat /var/work/tests/artifacts/1/accessconfig.json
```

預期輸出類似:

```json
{
    "authenticationMode": "API",
    "bootstrapClusterCreatorAdminPermissions": true
}
```

`authenticationMode` 等於 `API` - 集群中沒有 `aws-auth` ConfigMap,所有主體的映射都透
過 access entries 進行。

## 任務 2。作為第二個主體的測試用 IAM 角色

先取得 worker 角色的 ARN 與帳戶 ID(我們要允許這個角色 assume 測試角色):

```bash
WORKER_ARN=$(aws sts get-caller-identity --query Arn --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "$WORKER_ARN"
```

對於使用 EC2 profile 的實例,`get-caller-identity` 顯示的是**會話**的 ARN
(`assumed-role/.../i-...`),而不是角色本身的 ARN。trust policy 和 access entry 需要
的是角色的 ARN,因此我們從會話中把它組裝出來:

```bash
ROLE_NAME=$(echo "$WORKER_ARN" | sed -E 's#.*assumed-role/([^/]+)/.*#\1#')
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "$ROLE_ARN"
```

創建測試角色。名稱必須包含 `-test-`,否則 worker 無法創建它,也無法 assume 它(它的
IAM 政策就是按這個子字串限定的):

```bash
TEST_ROLE_NAME="eks-task102-test-viewer"

cat > /tmp/trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": { "AWS": "${ROLE_ARN}" }
    }
  ]
}
EOF

aws iam create-role --role-name "$TEST_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust.json

TEST_ROLE_ARN=$(aws iam get-role --role-name "$TEST_ROLE_NAME" \
  --query 'Role.Arn' --output text)

mkdir -p /var/work/tests/artifacts/2
echo "$TEST_ROLE_ARN" > /var/work/tests/artifacts/2/test_role_arn.txt
cat /var/work/tests/artifacts/2/test_role_arn.txt
```

這個角色內部不需要任何 IAM 權限,除了 assume 之外 - 它的實際權限全部由集群透過
access entry 和 access policy/RBAC 賦予,而不是由 IAM 賦予。

## 任務 3。測試角色的 Access entry,群組 viewers

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)

aws eks create-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --kubernetes-groups viewers \
  --type STANDARD

aws eks describe-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN"
```

我們不設定 `username` - 讓 EKS 自動填入,這是文件推薦的做法。現在集群認識這個主體,
它屬於 Kubernetes 群組 `viewers`,但暫時還沒有任何權限:這條記錄本身不賦予權限,它只
是為 RBAC 提供了一個主體(subject)。

## 任務 4。針對群組 viewers 的 ClusterRole 與 ClusterRoleBinding

疊加在 access entry 之上的經典 RBAC,不涉及 access policy:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: viewers-pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: viewers-pod-reader
subjects:
- kind: Group
  name: viewers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: viewers-pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl get clusterrole viewers-pod-reader -o yaml
kubectl get clusterrolebinding viewers-pod-reader -o yaml
```

群組 `viewers` 現在可以在所有 namespace 中讀取 Pod,僅此而已。

## 任務 5。透過 assume-role 手動驗證權限

這是需要學員親手執行的步驟 - 自動測試只檢查帶有結果的產物,不檢查 assume-role 本身
(`tests.bats` 內部不需要臨時憑證)。

獲取測試角色的臨時憑證,以及一個帶有 alias 的獨立 kubeconfig:

```bash
CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name test-viewer-session)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

aws eks update-kubeconfig --name "$CLUSTER" --region eu-central-1 \
  --alias test-viewer --kubeconfig /tmp/test-viewer.kubeconfig

kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
kubectl --kubeconfig /tmp/test-viewer.kubeconfig create namespace test
```

預期結果:`get pods -A` 執行成功(RBAC 綁定到群組 `viewers` 只允許讀取),而
`create namespace test` 會以 `Forbidden` 失敗 - 群組 `viewers` 的 RBAC 不包含對
`namespaces` 的權限。返回 worker 的權限:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

將手動驗證的結果保存到產物:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/rbac_check.txt <<'EOF'
kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
  -> 執行成功:RBAC 綁定 viewers-pod-reader 賦予了對 pods 的 get/list 權限。

kubectl --kubeconfig /tmp/test-viewer.kubeconfig create namespace test
  -> Forbidden:群組 viewers 沒有創建 namespace 的權限,
     access entry 提供了主體,但 RBAC 沒有允許這個操作。
EOF
cat /var/work/tests/artifacts/5/rbac_check.txt
```

## 任務 6。疊加在 access entry 之上的 Access policy AmazonEKSViewPolicy

```bash
aws eks associate-access-policy --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster

aws eks list-associated-access-policies --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN"
```

現在測試角色有兩個獨立的權限來源:RBAC 群組 `viewers`(pod 的 get/list)以及 access
policy `AmazonEKSViewPolicy`(讀取集群中大多數資源,不包含 secrets)。請注意:
`kubectl --kubeconfig /tmp/test-viewer.kubeconfig auth can-i --list` 不會顯示來自
access policy 的權限 - 它不是以 RBAC 對象的形式表達的,唯一能看到它的方式是
`list-associated-access-policies`。

## 任務 7。診斷:Unauthorized 對比 Forbidden

用真實的命令展示這個差異。建立另一個**沒有** access entry 的角色 - 它對集群來說是
未知的:

```bash
NOBODY_ROLE_NAME="eks-task102-test-nobody"
aws iam create-role --role-name "$NOBODY_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust.json
NOBODY_ARN=$(aws iam get-role --role-name "$NOBODY_ROLE_NAME" --query 'Role.Arn' --output text)

CREDS2=$(aws sts assume-role --role-arn "$NOBODY_ARN" --role-session-name nobody-session)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS2" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS2" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS2" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

aws eks update-kubeconfig --name "$CLUSTER" --region eu-central-1 \
  --alias test-nobody --kubeconfig /tmp/test-nobody.kubeconfig

kubectl --kubeconfig /tmp/test-nobody.kubeconfig get pods -A
# error: You must be logged in to the server (Unauthorized)

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
aws iam delete-role --role-name "$NOBODY_ROLE_NAME"
```

拿它與任務 5 中用同一個測試角色(`test-viewer.kubeconfig`)嘗試創建 namespace 的結果
對比 - 那次集群認識這個主體,但 RBAC 不允許這個操作,也就是 `Forbidden`。差異就在於:
`Unauthorized` 意味著集群完全沒有找到這個 ARN 對應的 access entry
(`aws eks list-access-entries` 根本不會顯示這個 ARN),`Forbidden` 意味著 access
entry 存在,但 RBAC/access policy 不允許這個操作。

```bash
aws eks list-access-entries --cluster-name "$CLUSTER"
```

將解釋保存到產物:

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/unauthorized_vs_forbidden.txt <<'EOF'
Unauthorized (401):角色 eks-task102-test-nobody 在集群中沒有 access entry。
用它的 kubeconfig 執行 kubectl get pods -A 會回應 "You must be logged in to the server
(Unauthorized)" - 根本沒有進入 RBAC 這一步,身份驗證就沒有通過。驗證方式:
aws eks list-access-entries --cluster-name <cluster> 不包含它的 ARN。

Forbidden (403):角色 eks-task102-test-viewer 有 access entry(群組 viewers),
可以讀取 Pod,但用同一個角色執行 kubectl create namespace test 會回應 Forbidden -
集群認識這個主體,但群組 viewers 的 RBAC 不允許創建 namespace。
EOF
cat /var/work/tests/artifacts/7/unauthorized_vs_forbidden.txt
```

## 任務 8。刪除 access entry 並恢復

移除 access entry,確認存取權已經消失,然後再次創建這條記錄(讓集群保持在可供驗證的
可用狀態):

```bash
aws eks delete-access-entry --cluster-name "$CLUSTER" --principal-arn "$TEST_ROLE_ARN"

CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" --role-session-name test-viewer-2)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
# error: You must be logged in to the server (Unauthorized)

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

aws eks create-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --kubernetes-groups viewers --type STANDARD

aws eks describe-access-entry --cluster-name "$CLUSTER" --principal-arn "$TEST_ROLE_ARN"
```

`delete-access-entry` 會連同這條記錄的所有 access policy 關聯一起刪除 - 任務 6 中的
policy(`AmazonEKSViewPolicy`)在記錄被刪除後不會自動恢復。我們明確地把它加回來,讓
環境保持在任務 6 中驗證過的狀態:

```bash
aws eks associate-access-policy --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster

aws eks list-associated-access-policies --cluster-name "$CLUSTER" --principal-arn "$TEST_ROLE_ARN"
```

將刪除/恢復這個循環的結果保存到產物:

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/delete_recreate.txt <<'EOF'
aws eks delete-access-entry --cluster-name <cluster> --principal-arn <test_role_arn>
kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
  -> error: You must be logged in to the server (Unauthorized):被刪除的 access entry
     讓這個主體立刻對集群變得未知。

aws eks create-access-entry --cluster-name <cluster> --principal-arn <test_role_arn> \
  --kubernetes-groups viewers --type STANDARD
  -> 存取權已恢復,群組 viewers 的 RBAC 綁定沒有變動,重新開始正常工作。
EOF
cat /var/work/tests/artifacts/8/delete_recreate.txt
```

## 快速檢查

```bash
check_result
```
