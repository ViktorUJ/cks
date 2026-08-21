[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 104 - 參考解答(workload identity:IRSA 和 Pod Identity)

所有指令都在工作機(worker)上透過 SSH 執行。kubectl 已經設定好連接叢集,terraform 也已經
建立好 S3 bucket、Secrets Manager secret 以及兩個 IAM 角色 - 它們的名稱與 ARN 都在提示
檔案 `/home/ubuntu/lab104_hints.txt` 中。

```bash
cat ~/lab104_hints.txt
```

接下來的範例會使用這個檔案中的變數 - 請代入你自己的值,或在 session 開始時匯出它們:

```bash
export BUCKET_NAME=$(grep '^bucket_name' ~/lab104_hints.txt | awk '{print $3}')
export SECRET_NAME=$(grep '^secret_name' ~/lab104_hints.txt | awk '{print $3}')
export IRSA_ROLE_ARN=$(grep '^irsa_role_arn' ~/lab104_hints.txt | awk '{print $3}')
export POD_IDENTITY_ROLE_ARN=$(grep '^pod_identity_role_arn' ~/lab104_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab104_hints.txt | awk '{print $3}')
```

## 任務 1. Namespace `eks-104`

```bash
kubectl create namespace eks-104
```

## 任務 2. 帶有 IRSA 註解的 ServiceAccount

角色 `irsa_role_arn` 已經由 terraform 建立好,其 trust policy 剛好信任這個
`ServiceAccount`(`system:serviceaccount:eks-104:s3-reader-irsa` - 第 16 章)。建立帶有
註解的 SA:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-reader-irsa
  namespace: eks-104
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

kubectl get sa s3-reader-irsa -n eks-104 -o yaml
```

## 任務 3. 帶有 IRSA 的 Pod:驗證身分

建立一個使用這個 SA 的 pod。Pod Identity Webhook 會在 pod 啟動時注入 `AWS_ROLE_ARN` 和
`AWS_WEB_IDENTITY_TOKEN_FILE` 這兩個變數(第 16 章):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: irsa-app
  namespace: eks-104
spec:
  serviceAccountName: s3-reader-irsa
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/irsa-app -n eks-104 --timeout=120s
```

確認 pod 內的 SDK 是透過 web identity 取得憑證,而不是節點角色:

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl exec irsa-app -n eks-104 -- aws sts get-caller-identity \
  > /var/work/tests/artifacts/3/irsa_identity.txt
cat /var/work/tests/artifacts/3/irsa_identity.txt
```

輸出中的 `Arn` 應該類似
`arn:aws:sts::<account>:assumed-role/<prefix>-irsa-role/...` - 這證明 pod 是以 IRSA
角色在運行,而不是節點角色。

## 任務 4. 透過 IRSA 讀取 S3 中的物件

角色 `irsa` 只帶有針對這個特定 bucket 的 `s3:ListBucket` 和 `s3:GetObject`(第 16 章,
最小權限原則)。讀取 terraform 放進 bucket 中的物件:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec irsa-app -n eks-104 -- aws s3 cp "s3://${BUCKET_NAME}/hello.txt" - \
  > /var/work/tests/artifacts/4/s3_read.txt
cat /var/work/tests/artifacts/4/s3_read.txt
```

檔案中應該有一行 `hello from s3` - 這是模組 `eks_v2_workload_identity_demo` 放進去的
物件內容。

## 任務 5. Pod Identity 關聯

與 IRSA 不同,Pod Identity 不需要在 SA 上加註解 - `namespace + SA -> 角色` 的連結存在於
EKS API 中,而不是 Kubernetes 裡(第 17 章)。建立 SA 與關聯:

```bash
kubectl create serviceaccount secret-reader-podid -n eks-104

aws eks create-pod-identity-association \
  --cluster-name "${CLUSTER_NAME}" \
  --namespace eks-104 \
  --service-account secret-reader-podid \
  --role-arn "${POD_IDENTITY_ROLE_ARN}"

mkdir -p /var/work/tests/artifacts/5
aws eks list-pod-identity-associations --cluster-name "${CLUSTER_NAME}" --namespace eks-104 \
  > /var/work/tests/artifacts/5/association.txt
cat /var/work/tests/artifacts/5/association.txt
```

## 任務 6. 帶有 Pod Identity 的 Pod:secret 取代節點角色

建立一個使用 SA `secret-reader-podid` 的 pod。代理程式 `eks-pod-identity-agent`(這一課
中已經以 managed addon 的形式安裝好)會透過本機端點 `169.254.170.23` 把
`pod_identity_role_arn` 角色的憑證交給它(第 17 章):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: podid-app
  namespace: eks-104
spec:
  serviceAccountName: secret-reader-podid
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/podid-app -n eks-104 --timeout=120s
```

用一個指令讀取 secret 並驗證身分:

```bash
mkdir -p /var/work/tests/artifacts/6
{
  echo "--- caller identity ---"
  kubectl exec podid-app -n eks-104 -- aws sts get-caller-identity
  echo "--- secret value ---"
  kubectl exec podid-app -n eks-104 -- aws secretsmanager get-secret-value \
    --secret-id "${SECRET_NAME}" --query SecretString --output text
} > /var/work/tests/artifacts/6/secret_read.txt
cat /var/work/tests/artifacts/6/secret_read.txt
```

`get-caller-identity` 中的 `Arn` 會顯示 `assumed-role/<prefix>-pod-identity-role/...`,
secret 的值則是包含 `username`/`password` 欄位(`demo`/`demo123`)的 JSON,這是
terraform 放進 Secrets Manager 中的內容。

## 任務 7. 症狀:節點角色沒有存取 bucket 的權限

建立一個 **沒有** 連結 IRSA 或 Pod Identity 的 pod - 它只會繼承節點角色的權限(第 16
章 16.1 節:「把角色給了節點,權限就洩漏給了所有 pod」反過來也一樣成立,節點角色根本
不帶任何應用程式層級的權限):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: plain-app
  namespace: eks-104
spec:
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/plain-app -n eks-104 --timeout=120s
```

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl exec plain-app -n eks-104 -- aws s3 ls "s3://${BUCKET_NAME}/" \
  > /var/work/tests/artifacts/7/node_role_denied.txt 2>&1
cat /var/work/tests/artifacts/7/node_role_denied.txt
```

指令應該以 `AccessDenied`(或 `is not authorized to perform`)錯誤結束 - 節點角色對
這個 bucket 沒有 `s3:*` 權限,它只帶有系統元件的權限(從 ECR 拉取映像、執行 CNI)。這
清楚地展示了差異:沒有 IRSA 或 Pod Identity 時,pod 只能取得節點角色擁有的權限,而不是
「帳戶裡任何地方設定好的所有權限」。

## 快速檢查

```bash
check_result
```
