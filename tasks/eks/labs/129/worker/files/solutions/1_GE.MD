[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 129 - ეტალონური გადაწყვეტა (Mountpoint for S3: ფაილების სემანტიკა და ბექაპი)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე (worker) SSH-ის მეშვეობით. kubectl უკვე
კონფიგურირებულია კლასტერზე. დრაივერი `aws-mountpoint-s3-csi-driver` (პროვიზიონერი
`s3.csi.aws.com`) უკვე დაყენებულია როგორც managed addon როლით IRSA-ს მეშვეობით
(კომპონენტი `eks_addon_s3_csi_irsa`), bucket ჩართული versioning-ითა და ტესტური
ობიექტით `readme.txt` უკვე შექმნილია terraform-ის მიერ.

## დავალება 1. Namespace `eks-129`

```bash
kubectl create namespace eks-129
```

## დავალება 2. სტატიკური PV/PVC რეალურ bucket-ზე

ვპოულობთ რეალური bucket-ის სახელს:

```bash
BUCKET=$(aws s3api list-buckets \
  --query "Buckets[?contains(Name,'mountpoint-demo')].Name" --output text)
echo "$BUCKET"
```

Mountpoint-ს აქვს მხოლოდ სტატიკური პროვიჟინინგი: PV იწერება ხელით, მიუთითებს
უკვე არსებულ bucket-ზე.

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

`capacity`/`requests.storage` - ეს არის placeholder-მნიშვნელობები, სქემა
მოითხოვს მათ, მაგრამ Mountpoint მათ იგნორირებს: რეალურ ზომას განსაზღვრავს
bucket-ის შინაარსი.

## დავალება 3. წარმატებული ოპერაციები: ახალი ფაილი და წაკითხვა

ვამაღლებთ პოდს ამ PVC-ით:

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

image აქ ზუსტად `busybox`-ია, არა კურსის სხვა ლაბების აპლიკაცია: `viktoruj/ping_pong`-ში
არ არსებობს არც `sh`, არც `cat`, და `kubectl exec` მასში პასუხობს
`exec: "sh": executable file not found in $PATH` (გადამოწმებულია). მთელი ლაბა
ეხება ფაილური სისტემის ოპერაციებს პოდის შიგნით, ამიტომ საჭიროა image shell-ით,
`mv`-ითა და `dd`-ით. პოდი უბრალოდ უნდა ცოცხლობდეს, აქედან `command` `sleep`-ით.

ახალი ფაილის შექმნა - ეს თანმიმდევრული ჩაწერაა თავიდან, ის ჯდება მთელი
ობიექტის `PutObject` მოდელში, ამიტომ მუშაობს:

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl exec "$POD" -n eks-129 -- sh -c 'echo test > /data/newfile.txt && cat /data/newfile.txt' \
  > /var/work/tests/artifacts/3/create.txt
cat /var/work/tests/artifacts/3/create.txt
```

წაკითხვა, bucket-ის არსებული ობიექტის `readme.txt`-ის ჩათვლით, ასევე მუშაობს -
ეს არის `GetObject`:

```bash
kubectl exec "$POD" -n eks-129 -- cat /data/readme.txt \
  > /var/work/tests/artifacts/3/read.txt
cat /var/work/tests/artifacts/3/read.txt
```

## დავალება 4. სიმპტომი: `rename` ვერდომდება

გადარქმევა არ არის ჩალი ოპერაცია ობიექტების საცავზე, Mountpoint ღიად
უკუაგდებს მას ჩვეულ bucket-ებზე:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec "$POD" -n eks-129 -- \
  mv /data/newfile.txt /data/renamed.txt \
  > /var/work/tests/artifacts/4/rename.txt 2>&1
cat /var/work/tests/artifacts/4/rename.txt
```

გამომავალში - `mv: can't rename '/data/newfile.txt': Function not implemented`
(გადამოწმებულია სტენდზე, დრაივერის ვერსია v1.15.0-eksbuild.1, busybox 1.36).
მიაქციეთ ყურადღება errno-ს: ეს არის `ENOSYS`, Mountpoint სისტემურ გამოძახებას
`rename` საერთოდ არ იმპლემენტირებს. დავალება 5-ში იქნება სხვა ვერდომდომა -
`EPERM`, `Operation not permitted`: იქ ოპერაცია იმპლემენტირებულია, მაგრამ
დაკრძალული მონტირების პარამეტრებით. სასარგებლოა განასხვავო მორბენდზე: `ENOSYS`
ნიშნავს "ეს დრაივერში არ არსებობს და არ იქნება", ხოლო `EPERM` - "შესაძლოა
გამოვიდეს სხვა mount options-ით".

ფაილი `newfile.txt` ამასთანავე რჩება ადგილზე, ხოლო `renamed.txt` არ ჩნდება:
ოპერაცია არ დაწყებულა და bucket არ გადავიდა შუალედურ მდგომარეობაში. შემოწმება
შესაძლებელია AWS-ის მხრიდან:

```bash
aws s3api list-objects-v2 --bucket "$BUCKET" --query 'Contents[].Key' --output text
```

## დავალება 5. სიმპტომი: დოზაწერა (append) და ფაილის შუაში ჩაწერა ვერდომდება

ორივე შემთხვევა არსებული ობიექტის ნაწილობრივი შეცვლის ცდაა, ხოლო ობიექტი
S3-ში უცვლელია და განახლდება მხოლოდ მთლიანად ახალი `PutObject`-ის მეშვეობით:

```bash
mkdir -p /var/work/tests/artifacts/5

{
  echo "=== append (echo >>) ==="
  kubectl exec "$POD" -n eks-129 -- sh -c 'echo more >> /data/newfile.txt' 2>&1

  echo
  echo "=== ფაილის შუაში ჩაწერა (dd seek + conv=notrunc) ==="
  kubectl exec "$POD" -n eks-129 -- sh -c \
    'echo patched | dd of=/data/newfile.txt bs=1 seek=1 conv=notrunc' 2>&1

  echo
  echo "=== არსებული ფაილის გადაწერა (საჭიროა allow-overwrite) ==="
  kubectl exec "$POD" -n eks-129 -- sh -c 'echo test2 > /data/newfile.txt' 2>&1

  echo
  echo "=== ფაილის წაშლა (საჭიროა allow-delete) ==="
  kubectl exec "$POD" -n eks-129 -- rm /data/newfile.txt 2>&1

  echo
  echo "განმარტება: S3 ობიექტი უცვლელია. გასაღების განახლება - ეს არის მთელი"
  echo "ობიექტის ახალი PutObject, ამიტომ Mountpoint-ს არ შეუძლია ბოლოში დამატება"
  echo "(append) ან უკვე ჩატანილი ფაილის შუაში ბაიტების შეცვლა - ორივე ოპერაცია"
  echo "ღიად ვერდომდება Operation not permitted-ით, ხოლო არა მდუმარედ აფუჭებს"
  echo "მონაცემებს. ამავე მიზეზით ნაგულისხმევად დაკრძალულია გადაწერა და წაშლა:"
  echo "ისინი ირთვება mount options allow-overwrite-ითა და allow-delete-ით, და"
  echo "მათი ჩართვა ღირს გააზრებულად."
} > /var/work/tests/artifacts/5/writesemantics.txt

cat /var/work/tests/artifacts/5/writesemantics.txt
```

ოთხი ვერდომდომა ზემოთ - ერთი და იგივე `EPERM`, და ყველა ოთხი ეხსნება ან არ
ეხსნება მონტირების პარამეტრებით, განსხვავებით `rename`-ისგან დავალება 4-იდან.
სასარგებლო კონტრასტი: `mkdir /data/sub` გადის მდუმარედ და გარეშე შეცდომის,
რადგან საქაღალდე S3-ში ვირტუალურია - ობიექტი მისთვის არ იქმნება, და
`aws s3api list-objects-v2` ახალ გასაღებს არ დაანახებს. მაგრამ ჩაწერა
არარსებულ ჩადგმულ პრეფიქსში (`echo x > /data/sub2/nested.txt`) ვერდომდება
`nonexistent directory`-ით: ჯერ საჭიროა `mkdir`. ეს ზუსტად ის "თითქმის
ფაილური სისტემა", რომელზეც გვაფრთხილებს თავი 25.

## დავალება 6. რატომ არ არსებობს ბექაპი AWS Backup-ის მეშვეობით, არსებობს versioning

AWS Backup EKS-სთვის (თავები 41-42) იცავს მონაცემებს EBS-ტომების CSI-სნეპშოტების
მეშვეობით. Mountpoint-ტომს არ აქვს EBS ქუდქვეშ საერთოდ: ფაილები `/data`-ში
არის bucket-ის S3-ობიექტები, არა ბლოკები დისკზე, ამიტომ PVC `s3-pvc`-ს არ აქვს
სნეპშოტი (snapshot) იმ გაგებით, რომელშიც ის აქვს `gp3`-ტომს (თავი 23). აქ
მონაცემებს იცავს თავად S3 - პირველ რიგში bucket-ის versioning, რომელიც
terraform-მა ჩართო წინასწარ (`aws_s3_bucket_versioning`):

```bash
mkdir -p /var/work/tests/artifacts/6

{
  echo "=== aws s3api get-bucket-versioning --bucket $BUCKET ==="
  aws s3api get-bucket-versioning --bucket "$BUCKET"

  echo
  echo "განმარტება: PVC s3-pvc მონტირებულია Mountpoint S3 CSI-ის მეშვეობით, არა"
  echo "EBS CSI-ის. მონაცემები უკვე ინახება S3-ში როგორც ობიექტები, არა ბლოკურ"
  echo "მოწყობილობაზე, ამიტომ ამ ტომს არ აქვს სნეპშოტი AWS Backup for EKS-ის"
  echo "მეშვეობით (ის მექანიზმი მუშაობს EBS VolumeSnapshot-ის მეშვეობით, თავი 41)."
  echo "დაცვა შემთხვევითი გადაწერისგან ან ობიექტების წაშლისგან ასეთ bucket-ზე -"
  echo "ეს არის versioning (ჩართული terraform-ის მიერ) და თავად S3-ის"
  echo "lifecycle-პოლიტიკები, არა ტომის მთლიანი ბექაპი."
} > /var/work/tests/artifacts/6/backup.txt

cat /var/work/tests/artifacts/6/backup.txt
```

## სწრაფი შემოწმება

```bash
check_result
```
