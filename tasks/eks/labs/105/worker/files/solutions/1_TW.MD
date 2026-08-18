[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 105 - 參考解答(密鑰:KMS envelope encryption、External Secrets)

所有命令都在 worker 機器上透過 SSH 執行。kubectl 已經設定好指向叢集,而 terraform 已經
建立了 Secrets Manager 的密鑰以及 ESO controller 用的 IRSA role - 它們的名稱與 ARN 都在
提示檔案 `/home/ubuntu/lab105_hints.txt` 中。

```bash
cat ~/lab105_hints.txt
```

以下命令會用到提示檔案中的變數:

```bash
export SECRET_NAME=$(grep '^secret_name' ~/lab105_hints.txt | awk '{print $3}')
export ROLE_ARN=$(grep '^role_arn' ~/lab105_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab105_hints.txt | awk '{print $3}')
```

## 任務 1. Namespace `eks-105`

```bash
kubectl create namespace eks-105
```

## 任務 2. 第一層:檢查 KMS envelope encryption

從 Kubernetes 1.28 開始,EKS 預設會用 AWS 的金鑰加密所有 API 物件(包括 `Secret`),
不需要你做任何事。我們檢查叢集的加密設定:

```bash
mkdir -p /var/work/tests/artifacts/2
aws eks describe-cluster --name "${CLUSTER_NAME}" --query 'cluster.encryptionConfig' \
  > /var/work/tests/artifacts/2/encryption_config.txt
cat /var/work/tests/artifacts/2/encryption_config.txt
```

輸出中,清單項目包含 `"resources": ["secrets"]` - 這確認了第一層(etcd 中密鑰的
envelope encryption)已啟用。如果需要自己的 customer managed key(CMK)而不是 AWS
owned key,這要透過另一個獨立命令 `aws eks associate-encryption-config` 完成 - 可以啟用
自己的 CMK,但無法關閉加密(這是不可逆的操作),所以這裡我們保留 AWS 的預設金鑰。

## 任務 3. 透過 Helm 安裝 External Secrets Operator

role `role_arn` 已經由 terraform 建立好,其 trust policy 精確地信任 `external-secrets`
namespace 中的 SA `external-secrets`(第 16 章,IRSA)。我們透過 Helm 安裝 ESO,並馬上用
ServiceAccount 上的註解把 role 綁上去:

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets --create-namespace \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${ROLE_ARN}"

kubectl rollout status deployment/external-secrets -n external-secrets
kubectl get pods -n external-secrets
```

我們確認註解已經套用到 controller 的 SA 上:

```bash
kubectl get sa external-secrets -n external-secrets -o yaml | grep -A1 annotations
```

## 任務 4. SecretStore 與 ExternalSecret

我們建立一個 `SecretStore`(namespace-scoped - 依團隊隔離,第 18.5 章),然後建立一個
引用 terraform 建立的示範密鑰的 `ExternalSecret`:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-sm
  namespace: eks-105
spec:
  provider:
    aws:
      service: SecretsManager
      region: eu-central-1
EOF

cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: eks-105
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: aws-sm
    kind: SecretStore
  target:
    name: db-credentials
  data:
    - secretKey: password
      remoteRef:
        key: ${SECRET_NAME}
        property: password
EOF
```

我們等待同步,並檢查原生 `Secret`:

```bash
kubectl wait --for=jsonpath='{.status.conditions[0].reason}'=SecretSynced \
  externalsecret/db-credentials -n eks-105 --timeout=120s

kubectl get externalsecret db-credentials -n eks-105
kubectl get secret db-credentials -n eks-105 -o jsonpath='{.data.password}' | base64 -d
echo
```

這個值應該與 terraform 放進 Secrets Manager 的密碼一致(`S3cr3tPass123`)。
`refreshInterval: 1m` 是故意設得小一點的 - 在任務 6 中,我們需要在 AWS 上手動修改密鑰後,
很快看到重新同步的效果。

## 任務 5. 帶 volume 的 Pod:有韌性的同步路徑

我們把 `Secret` 掛載為 volume(volumeMount),而不是透過 env - 這正是第 18.5 章對於
需要在不重建 pod 的情況下更新的值所建議的做法(當 `Secret` 改變時,kubelet 會自動更新
volume 中的檔案):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: vol-reader
  namespace: eks-105
spec:
  containers:
  - name: app
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
    volumeMounts:
    - name: db-creds
      mountPath: /etc/db-creds
      readOnly: true
  volumes:
  - name: db-creds
    secret:
      secretName: db-credentials
EOF

kubectl wait --for=condition=Ready pod/vol-reader -n eks-105 --timeout=120s
```

我們從 volume 中的檔案讀取值:

```bash
mkdir -p /var/work/tests/artifacts/5
kubectl exec vol-reader -n eks-105 -- cat /etc/db-creds/password \
  > /var/work/tests/artifacts/5/volume_password.txt
echo >> /var/work/tests/artifacts/5/volume_password.txt
cat /var/work/tests/artifacts/5/volume_password.txt
```

## 任務 6. 帶 env 的 Pod:舊值症狀

我們建立第二個 pod,讀取同一個 `Secret`,但透過環境變數:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: env-reader
  namespace: eks-105
spec:
  containers:
  - name: app
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
EOF

kubectl wait --for=condition=Ready pod/env-reader -n eks-105 --timeout=120s
kubectl exec env-reader -n eks-105 -- printenv DB_PASSWORD
```

我們直接在 Secrets Manager 中修改密鑰的值(不透過 Kubernetes):

```bash
aws secretsmanager put-secret-value --secret-id "${SECRET_NAME}" \
  --secret-string '{"username":"appuser","password":"RotatedPass456"}'
```

我們等待 `refreshInterval`(任務 4 中設為 `1m`)加上一些餘量,並確認 ESO 已重新同步了
原生 `Secret`:

```bash
sleep 90
kubectl get secret db-credentials -n eks-105 -o jsonpath='{.data.password}' | base64 -d
echo
```

`Secret` 中的值已經是新的了(`RotatedPass456`)- ESO 完成了它的工作。現在我們看看在
輪換之前建立的那個帶 env 的 pod:

```bash
kubectl exec env-reader -n eks-105 -- printenv DB_PASSWORD
```

這個 pod 仍然顯示舊值(`S3cr3tPass123`)。原因是:容器的環境變數在程序啟動時就固定了,
所以 etcd 中 `Secret` 的更新不會影響它們 - 必須重建 pod(對 Deployment 用 `kubectl
rollout restart`,對單獨的 Pod 就手動刪除再建立),才能透過 env 拿到新值。這不是 ESO 的
bug,而是 Kubernetes 中 env 本身的特性 - 與之不同的是 volume,kubelet 會在不重建 pod
的情況下更新它(任務 5)。

我們把觀察結果記錄成一個產物:

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/rotation.txt <<'EOF'
在 Secrets Manager 中執行 put-secret-value 並經過 ExternalSecret 的重新同步後,etcd 中
原生的 Secret db-credentials 已更新為新的密碼值 - ESO 正常運作。

Pod env-reader 透過 env(secretKeyRef)讀取密碼,而容器的環境變數只在程序啟動時固定
一次。env 的值在 Secret 改變後,如果不重建 pod 就不會更新 - 這不是 ESO 的故障,而是
Kubernetes 中 env 的特性。Pod vol-reader(任務 5)透過 volumeMount 讀取同一個
Secret - 這種 volume 會由 kubelet 自動在磁碟上更新,不需要重建 pod。
EOF
cat /var/work/tests/artifacts/7/rotation.txt
```

## 快速檢查

```bash
check_result
```
