[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 109 - 參考解答：Secret 的 encryption at rest

> 像考試中一樣工作：`kubectl` 指令在工作機上執行，而對
> 節點的操作(etcd、control-plane 的檔案與 manifest)- 在 control-plane 本身上執行：用
> `ssh control-plane` 登入它，執行指令，然後離開(`exit`)。這**只是學習用的單節點
> 叢集**；在 production 中不會讓使用者直接存取 etcd。

## 在文件中哪裡可以找到範例

下面所有指令都取自 Kubernetes 官方文件 - 在考試中需要在
同一處找到它們，而不是死記：

| 需要什麼 | 頁面與章節 |
| :--- | :--- |
| 讀取 etcd 的 raw 記錄並看到前綴 `k8s:enc:aescbc:v1:`(指令 `ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key get /registry/secrets/default/secret1 \| hexdump -C`) | [Encrypting Confidential Data at Rest - Verify that newly written data is encrypted](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#verifying-that-data-is-encrypted) |
| 帶有 `aescbc` 與 `identity` 的 `EncryptionConfiguration` 範例 | [Encrypting Confidential Data at Rest - Write an encryption configuration file](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#write-an-encryption-configuration-file) |
| 旗標 `--encryption-provider-config` 以及把檔案掛載到 kube-apiserver 的 static Pod | [Encrypting Confidential Data at Rest - Use the new encryption configuration file](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#use-the-new-encryption-configuration-file) |
| 重寫所有 Secret(`kubectl get secrets --all-namespaces -o json \| kubectl replace -f -`) | [Encrypting Confidential Data at Rest - Ensure all relevant data are encrypted](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#ensure-all-secrets-are-encrypted) |
| 金鑰輪替(步驟 1-7)與刪除舊金鑰 | [Encrypting Confidential Data at Rest - Rotate a decryption key](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#rotating-a-decryption-key) |
| 如果記不住 etcd 憑證的路徑，可以在哪裡取得：「`trusted-ca-file`、`cert-file` 與 `key-file` 可以從 etcd Pod 的描述中取得」(`kubectl -n kube-system describe pod etcd-<node>` 或 `/etc/kubernetes/manifests/etcd.yaml`) | [Operating etcd clusters for Kubernetes - Snapshot using etcdctl options](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/) |
| Role/RoleBinding 與 ServiceAccount(`automountServiceAccountToken`) | [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/), [Configure Service Accounts for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) |

kubeadm 叢集中的憑證路徑：`/etc/kubernetes/pki/etcd/ca.crt`、
`/etc/kubernetes/pki/etcd/server.crt`、`/etc/kubernetes/pki/etcd/server.key`；預設的 endpoint 是
`https://127.0.0.1:2379`，因此在 control-plane 上不需要旗標 `--endpoints`。

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
export NS=encryption-109
kubectl config use-context "$CTX"
```

## 1. 在啟用加密之前記錄 plaintext 的證明

API 中的 `Secret.data` 是以 base64 編碼的，而不是加密的。Bootstrap 在 EncryptionConfiguration 出現之前
建立了安全的 canary。首先用文件中的指令查看 etcd 的 raw 記錄，然後把字串形式的證明儲存到 control-plane 上的檔案
(`/tmp/plaintext-proof.txt`)，再把它複製到工作機的
`/var/work/109/plaintext-proof.txt`(目錄由 bootstrap 建立)：檢查讀取的是工作機上的檔案。

登入 control-plane 並在上面執行(這個指令中的一切都來自文件，除了 etcd 中的
key:`/registry/secrets/<namespace>/<name>`):

```bash
ssh control-plane
sudo -i
```

```bash
# 在 control-plane 上:etcd 的 raw 記錄,hexdump -C 的輸出會顯示 plaintext
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret | hexdump -C

# 儲存證明(只要值,透過 strings)- 同樣在 control-plane 上
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret --print-value-only \
  | strings > /tmp/plaintext-proof.txt
cat /tmp/plaintext-proof.txt
# cks-109-legacy-plaintext
exit   # 離開 root
exit   # 離開 control-plane
```

```bash
# 在工作機上:複製證明
scp control-plane:/tmp/plaintext-proof.txt /var/work/109/plaintext-proof.txt
cat /var/work/109/plaintext-proof.txt
```

在這個步驟中，檔案裡沒有 `k8s:enc:`。這是設定**之前**的狀態證明；
在 re-encryption 之後，再次輸出的必須是 ciphertext,marker 會消失。

## 2. 建立 EncryptionConfiguration

選擇 `aescbc` 只是為了 CKS 學習用的操作機制。Kubernetes 因為 padding-oracle 攻擊的風險而認為 AES-CBC 較弱，
並且不建議把它作為 production 的預設值。對於外部的 key
manager，請使用 KMS v2；本機 provider 只有在搭配最新的 threat model
與輪替程序時才選用。

產生 32-byte 的 AES-256 金鑰，以 base64 編碼，並在 control-plane 上建立設定。
`aescbc` 放在第一位：新的 Secret 會以它寫入。`identity` 放在最後，讓 API
server 只在遷移之前能夠讀取舊的 plaintext 記錄。檔案範例 - 在
文件頁面上(連結在解答開頭)。

```bash
ssh control-plane
sudo -i
```

```bash
# 在 control-plane 上(root)
mkdir -m 700 /etc/kubernetes/enc
key=$(head -c 32 /dev/urandom | base64)
cat > /etc/kubernetes/enc/encryption-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: cks-109-aescbc
        secret: ${key}
  - identity: {}
EOF
chmod 600 /etc/kubernetes/enc/encryption-config.yaml
ls -ld /etc/kubernetes/enc; ls -l /etc/kubernetes/enc
exit   # 離開 root
exit   # 離開 control-plane
```

真正的金鑰不能放進 Git、ticket、終端機 log 或 Terraform state。
金鑰遺失時，snapshot 中的 encrypted Secret 會變得無法讀取。

## 3. 把設定接到 static kube-apiserver

首先把 manifest 保存在 `/etc/kubernetes/manifests/` 目錄**之外**:kubelet 會把該目錄中每個非隱藏的檔案
都當作 static Pod 讀取，包括 `*.bak`。在目錄內放一份原始 manifest 的副本
就是第二個同名的 static Pod;kubelet 可能繼續啟動的正是它
(沒有 `--encryption-provider-config` 的舊設定)，而對主要檔案的修改會悄悄地
不生效，加密保持關閉，而 API server 表面上看起來健康。
在 control-plane 上，打開既有的 static-Pod
manifest，並把這些元素加到**既有的** `command`、`volumeMounts` 與 `volumes` 中；
不要用範本取代整個檔案。

```bash
ssh control-plane
sudo -i
```

```bash
# 在 control-plane 上(root)
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak-109
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
# container name: kube-apiserver
command:
- kube-apiserver
- --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml
volumeMounts:
- name: encryption-config
  mountPath: /etc/kubernetes/enc
  readOnly: true

# spec.volumes
volumes:
- name: encryption-config
  hostPath:
    path: /etc/kubernetes/enc
    type: Directory
```

Kubelet 會注意到變更並重新啟動 static Pod。繼續之前，請等待 API
server，否則 YAML/路徑的錯誤可能讓 control-plane 無法使用。

```bash
# 仍然在 control-plane 上:確認旗標進入了執行中的 manifest,然後離開
grep -n -- '--encryption-provider-config\|encryption-config' /etc/kubernetes/manifests/kube-apiserver.yaml
exit   # 離開 root
exit   # 離開 control-plane
```

```bash
# 在工作機上:API server 重新啟動大約需要一分鐘;請重複執行,直到指令
# 回傳 "readyz check passed"(在那之前會是 "connection refused")
kubectl get --raw='/readyz?verbose'
```

## 4. 重寫舊的 Secret 並檢查 ciphertext

設定不會改變已經儲存的記錄。首先在啟用 provider 之後建立 Secret,
然後透過 API 重寫所有既有的 Secret。在 production 中，在此之前
會先做受保護的 snapshot，並使用帶有 retry 的受控程序。

```bash
kubectl -n "$NS" create secret generic encrypted-secret \
  --from-literal=token='cks-109-fresh-ciphertext'
kubectl get secrets --all-namespaces -o json | kubectl replace -f -

kubectl -n "$NS" get secret legacy-secret -o jsonpath='{.data.token}' | base64 -d; echo
kubectl -n "$NS" get secret encrypted-secret -o jsonpath='{.data.token}' | base64 -d; echo
# cks-109-legacy-plaintext
# cks-109-fresh-ciphertext
```

在 control-plane 上讀取 raw 記錄，就像任務 1 那樣：

```bash
ssh control-plane
sudo -i
```

```bash
# 在 control-plane 上(root)
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret | hexdump -C
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/encrypted-secret | hexdump -C
# 兩筆記錄都以 k8s:enc:aescbc:v1:... 開頭
exit   # 離開 root
exit   # 離開 control-plane
```

API 會向已授權的用戶端回傳 plaintext - 這是正常的，並不能證明
at rest 的加密。這裡的證明是：raw etcd 對
舊的與新的記錄都包含 `k8s:enc:aescbc:v1:`，並且不再包含 legacy marker。

現在不再需要 migration fallback。我們刪除 `identity`，透過 CRI 強制重新啟動
static kube-apiserver，並再次檢查健康狀態與讀取。請只在
做過 snapshot 並確認所有受影響的資源類型的 ciphertext 之後才這樣做。

```bash
ssh control-plane
sudo -i
```

```bash
# 在 control-plane 上(root):移除 identity 並重新啟動 static kube-apiserver
vim /etc/kubernetes/enc/encryption-config.yaml   # 刪除 "- identity: {}" 這一行
crictl stop $(crictl ps --name kube-apiserver -q)
exit   # 離開 root
exit   # 離開 control-plane
```

```bash
# 在工作機上
until kubectl get --raw=/readyz 2>/dev/null | grep -qx ok; do sleep 2; done
kubectl -n "$NS" get secret legacy-secret encrypted-secret
```

本實驗的最終狀態：負責加密的 provider(`aescbc`)是第一個也是唯一的，`identity`
已被刪除。不可以把臨時的 fallback 留作永久的「保險」。

## 5. 限制 API 存取並停用 token automount

Encryption at rest 不能取代 RBAC：擁有 `get` Secret 權限的主體會透過 API 看到 plaintext。
我們建立一個只能存取恰好一個 Secret 的 ServiceAccount，以及一個沒有
掛載 service-account token 的診斷 Pod。

```yaml
# rbac-109.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secret-reader
  namespace: encryption-109
automountServiceAccountToken: false
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader-109
  namespace: encryption-109
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["encrypted-secret"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secret-reader-109
  namespace: encryption-109
subjects:
- kind: ServiceAccount
  name: secret-reader
  namespace: encryption-109
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: secret-reader-109
---
apiVersion: v1
kind: Pod
metadata:
  name: secret-reader-109
  namespace: encryption-109
spec:
  serviceAccountName: secret-reader
  automountServiceAccountToken: false
  containers:
  - name: pause
    image: registry.k8s.io/pause:3.10
```

```bash
kubectl apply -f rbac-109.yaml
kubectl wait -n "$NS" --for=condition=Ready pod/secret-reader-109 --timeout=120s
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader get secret/encrypted-secret -n "$NS"
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader list secrets -n "$NS"
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader get secret/legacy-secret -n "$NS"
# yes
# no
# no

check_result
```

`automountServiceAccountToken: false` 縮小了 Pod 可用的 credential surface，但不會
限制 ServiceAccount 本身的 RBAC，如果應用程式取得了其他 credentials 的話。

## 補充：KMS v2 的樣子與完整的金鑰輪替

### KMS v2：設定中沒有本機金鑰的 envelope encryption

上面的 `aescbc` 只是為了學習用的操作機制。在 production 中，KMS v2 透過 `EncryptionConfiguration` 中的
本機 Unix socket 接入受支援的 KMS-plugin。
對於 KMS v2,API server 在 API server 層級使用加密的 seed/DEK，並
推導出各筆記錄的加密金鑰。Plugin 透過外部 KEK 保護 seed;
這是 KMS v2 與 per-resource KMS v1 的差別。Etcd 儲存資源的 ciphertext 以及
解密所需的 metadata。KEK 留在外部的 KMS 中，而不是在 etcd 或 Git 中。設定
的 schema 取決於 Kubernetes 與 plugin 的版本，但原則上需要 provider `kms`、
穩定的 key 名稱以及 socket 的 endpoint。不要複製別的叢集的範例 endpoint:
請對照你所用 Kubernetes 版本的文件，核對 KMS v2 的格式與 health/ACL 要求。

### aescbc 金鑰輪替的完整 lifecycle

任務 4 中的 `identity -> aescbc` 轉換是 migration，而不是對已經
加密的資料所用金鑰進行輪替。輪替之前，請做加密的 etcd snapshot，並保存
舊金鑰以便 rollback。把新金鑰加在**最前面**，舊金鑰暫時留在
第二位：providers 依序讀取，而新記錄以第一個金鑰寫入。

```yaml
- aescbc:
    keys:
    - name: cks-109-aescbc-2026-rotation
      secret: <base64-32-byte-new-key>
    - name: cks-109-aescbc
      secret: <base64-32-byte-old-key>
```

API server 重新啟動之後，重寫資源，並檢查 raw
ciphertext 中新 key 的名稱，而不只是通用的 `k8s:enc` 前綴：

```bash
# 在工作機上
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
ssh control-plane
sudo -i
```

```bash
# 在 control-plane 上(root)
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret --print-value-only \
  | strings | grep -F 'k8s:enc:aescbc:v1:cks-109-aescbc-2026-rotation:'
exit   # 離開 root
exit   # 離開 control-plane
```

當所有 Secret 的 migration 都已確認、backup 已完成、API 能讀取資料，而且 `/readyz`
回傳 `ok` 之後，再從清單中刪除舊的 key，重新啟動 API server 並重複
檢查。不要更早刪除舊的 key：沒有被新 provider 重寫的記錄會變得
無法讀取。對於 KMS v2，順序相同：先是新的 primary KEK/plugin，然後
re-encryption、檢查，而只有在 migration 之後，才讓舊的 KEK 退出使用。
