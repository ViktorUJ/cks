[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 129 - 參考解決方案(Mountpoint for S3:文件語義與備份)

所有命令都透過 SSH 在工作機上執行。kubectl 已經配置好對應的集群。驅動程式
`aws-mountpoint-s3-csi-driver`(provisioner `s3.csi.aws.com`)已經作為 managed
addon 安裝,並透過 IRSA 賦予了角色(組件 `eks_addon_s3_csi_irsa`),啟用了 versioning
的 bucket 和測試物件 `readme.txt` 也已經由 terraform 創建好了。

## 任務 1. Namespace `eks-129`

```bash
kubectl create namespace eks-129
```

## 任務 2. 指向真實 bucket 的靜態 PV/PVC

找到真實 bucket 的名稱:

```bash
BUCKET=$(aws s3api list-buckets \
  --query "Buckets[?contains(Name,'mountpoint-demo')].Name" --output text)
echo "$BUCKET"
```

Mountpoint 只支援靜態配置:PV 是手動寫入的,指向一個已經存在的 bucket。

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: s3-pv
spec:
  capacity:
    storage: 1200Gi
  accessModes: ["ReadWriteMany"]
  storageClassName: ""
  claimRef:
    namespace: eks-129
    name: s3-pvc
  mountOptions:
    - region eu-central-1
  csi:
    driver: s3.csi.aws.com
    volumeHandle: s3-csi-demo-volume
    volumeAttributes:
      bucketName: $BUCKET
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: s3-pvc
  namespace: eks-129
spec:
  accessModes: ["ReadWriteMany"]
  storageClassName: ""
  resources:
    requests:
      storage: 1200Gi
  volumeName: s3-pv
EOF

kubectl get pv s3-pv
kubectl get pvc s3-pvc -n eks-129
```

`capacity`/`requests.storage` - 這是佔位值,schema 要求填寫它們,但 Mountpoint 會忽
略它們:真實的大小由 bucket 的內容決定。

## 任務 3. 成功的操作:新建文件與讀取

啟動一個帶有這個 PVC 的 pod:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mountpoint-app
  namespace: eks-129
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mountpoint-app
  template:
    metadata:
      labels:
        app: mountpoint-app
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "sleep 86400"]
        volumeMounts:
        - name: s3
          mountPath: /data
      volumes:
      - name: s3
        persistentVolumeClaim:
          claimName: s3-pvc
EOF

kubectl rollout status deployment/mountpoint-app -n eks-129
POD=$(kubectl get po -n eks-129 -l app=mountpoint-app -o jsonpath='{.items[0].metadata.name}')
```

這裡的映像特意選用 `busybox`,而不是課程其他實驗裡的應用程式:`viktoruj/ping_pong`
裡既沒有 `sh`,也沒有 `cat`,`kubectl exec` 進去會回應
`exec: "sh": executable file not found in $PATH`(已驗證過)。整個實驗都是關於 pod 內
部的文件系統操作,所以需要一個帶有 shell、`mv` 和 `dd` 的映像。pod 只需要保持存活即
可,所以 `command` 用了 `sleep`。

創建新文件 - 這是從頭開始的順序寫入,符合對整個物件執行 `PutObject` 的模型,所以能
成功:

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl exec "$POD" -n eks-129 -- sh -c 'echo test > /data/newfile.txt && cat /data/newfile.txt' \
  > /var/work/tests/artifacts/3/create.txt
cat /var/work/tests/artifacts/3/create.txt
```

讀取,包括讀取 bucket 中已存在的物件 `readme.txt`,同樣能正常工作 - 這是
`GetObject`:

```bash
kubectl exec "$POD" -n eks-129 -- cat /data/readme.txt \
  > /var/work/tests/artifacts/3/read.txt
cat /var/work/tests/artifacts/3/read.txt
```

## 任務 4. 症狀:`rename` 會失敗

重命名在物件儲存上不是一個廉價的操作,Mountpoint 在普通 bucket 上會明確地拒絕它:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec "$POD" -n eks-129 -- \
  mv /data/newfile.txt /data/renamed.txt \
  > /var/work/tests/artifacts/4/rename.txt 2>&1
cat /var/work/tests/artifacts/4/rename.txt
```

輸出中會出現 `mv: can't rename '/data/newfile.txt': Function not implemented`(已在
測試環境驗證,驅動版本 v1.15.0-eksbuild.1,busybox 1.36)。請注意這裡的 errno:這是
`ENOSYS`,Mountpoint 根本沒有實作系統呼叫 `rename`。任務 5 中會出現另一種失敗 -
`EPERM`、`Operation not permitted`:那裡的操作是實作了的,但被掛載設定禁止。值班時區
分這兩者很有用:`ENOSYS` 意味著「驅動裡沒有這個功能,也不會有」,而 `EPERM` 意味著
「換一套掛載選項可能就能work」。

同時,文件 `newfile.txt` 仍然留在原地,而 `renamed.txt` 沒有出現:操作沒有開始,也沒
有讓 bucket 進入中間狀態。可以從 AWS 一側驗證這一點:

```bash
aws s3api list-objects-v2 --bucket "$BUCKET" --query 'Contents[].Key' --output text
```

## 任務 5. 症狀:append(追加寫入)和寫入文件中間會失敗

這兩種情況都是嘗試對一個已經存在的物件進行部分修改,而 S3 中的物件是不可變的,只能
透過一次新的 `PutObject` 整體更新:

```bash
mkdir -p /var/work/tests/artifacts/5

{
  echo "=== append(echo >>) ==="
  kubectl exec "$POD" -n eks-129 -- sh -c 'echo more >> /data/newfile.txt' 2>&1

  echo
  echo "=== 寫入文件中間(dd seek + conv=notrunc) ==="
  kubectl exec "$POD" -n eks-129 -- sh -c \
    'echo patched | dd of=/data/newfile.txt bs=1 seek=1 conv=notrunc' 2>&1

  echo
  echo "=== 覆寫現有文件(需要 allow-overwrite) ==="
  kubectl exec "$POD" -n eks-129 -- sh -c 'echo test2 > /data/newfile.txt' 2>&1

  echo
  echo "=== 刪除文件(需要 allow-delete) ==="
  kubectl exec "$POD" -n eks-129 -- rm /data/newfile.txt 2>&1

  echo
  echo "說明:S3 物件是不可變的。更新一個 key 是對整個物件執行新的 PutObject,"
  echo "所以 Mountpoint 無法在已上傳文件的末尾追加(append)或修改中間的位元組 -"
  echo "這兩種操作都會明確以 Operation not permitted 失敗,而不是悄悄地把數據"
  echo "弄壞。出於同樣的原因,默認情況下覆寫和刪除也是被禁止的:它們透過掛載選項"
  echo "allow-overwrite 和 allow-delete 啟用,啟用它們應該是一個經過深思的決定。"
} > /var/work/tests/artifacts/5/writesemantics.txt

cat /var/work/tests/artifacts/5/writesemantics.txt
```

上面的四種失敗都是同一個 `EPERM`,而且這四種都可以透過掛載設定啟用或禁止,這與任務
4 中的 `rename` 不同。一個有用的對比:`mkdir /data/sub` 會靜默通過,不會報錯,因為
S3 中的目錄是虛擬的 - 不會為它創建物件,`aws s3api list-objects-v2` 也不會顯示出新
的 key。但寫入一個不存在的嵌套前綴(`echo x > /data/sub2/nested.txt`)會以
`nonexistent directory` 失敗:必須先執行 `mkdir`。這正是第 25 章所警告的那種「幾乎是
文件系統」的東西。

## 任務 6. 為什麼沒有透過 AWS Backup 的備份,卻有 versioning

EKS 的 AWS Backup(第 41-42 章)透過 CSI 快照保護 EBS 卷的數據。Mountpoint 卷底層根
本沒有 EBS:`/data` 中的文件是 S3 bucket 中的物件,而不是磁碟上的區塊,所以 PVC
`s3-pvc` 沒有 `gp3` 卷那種意義上的快照(snapshot)(第 23 章)。這裡保護數據的是 S3
本身 - 首先是 bucket 的 versioning,terraform 已經提前啟用了它
(`aws_s3_bucket_versioning`):

```bash
mkdir -p /var/work/tests/artifacts/6

{
  echo "=== aws s3api get-bucket-versioning --bucket $BUCKET ==="
  aws s3api get-bucket-versioning --bucket "$BUCKET"

  echo
  echo "說明:PVC s3-pvc 是透過 Mountpoint S3 CSI 掛載的,而不是 EBS CSI。數據已經"
  echo "以物件形式存放在 S3 中,而不是在區塊裝置上,所以這個卷沒有透過 AWS Backup"
  echo "for EKS 的快照(那個機制是透過 EBS VolumeSnapshot 工作的,見第 41 章)。在"
  echo "這樣的 bucket 上防止意外覆寫或刪除物件的機制,是 versioning(terraform 已"
  echo "啟用)以及 S3 自身的 lifecycle 策略,而不是整個卷的備份。"
} > /var/work/tests/artifacts/6/backup.txt

cat /var/work/tests/artifacts/6/backup.txt
```

## 快速檢查

```bash
check_result
```
