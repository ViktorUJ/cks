[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბი 122 - ეტალონური გადაწყვეტა (AWS Backup EKS-ისთვის: composite recovery point,
namespace-ის აღდგენა)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე SSH-ით. kubectl და aws CLI უკვე გამართულია
ლაბის კლასტერსა და რეგიონზე. Terraform-მა უკვე შექმნა IAM-როლი AWS Backup-ისთვის და
backup vault (კომპონენტი `eks_backup_iam`, მოდული `eks_v2_backup_iam`) - მათი ARN-ები და
სახელები მინიშნებების ფაილშია `~/lab122_hints.txt`.

```bash
cat ~/lab122_hints.txt
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab122_hints.txt | awk '{print $3}')
export CLUSTER_ARN=$(grep '^cluster_arn' ~/lab122_hints.txt | awk '{print $3}')
export ROLE_ARN=$(grep '^backup_role_arn' ~/lab122_hints.txt | awk '{print $3}')
export VAULT_NAME=$(grep '^vault_name' ~/lab122_hints.txt | awk '{print $3}')
```

## დავალება 1. Namespace `eks-122`, დატვირთვა EBS-ტომზე და მარკერი

Namespace, Deployment, PVC `gp3` კლასზე (addon `aws-ebs-csi-driver` უკვე დაყენებულია
კომპონენტ `eks_addon_ebs_irsa`-ს მიერ) და ConfigMap მარკერით, რომელიც მოგვიანებით
დაადასტურებს, რომ აღდგენილი ობიექტი მართლა backup-იდან მოვიდა:

```bash
kubectl create namespace eks-122

cat <<'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
  encrypted: "true"
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
  namespace: eks-122
spec:
  storageClassName: gp3
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 5Gi
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: eks-122
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: data
EOF

kubectl rollout status deployment/web -n eks-122

MARKER="MARKER_LAB122_$(tr -dc a-z0-9 </dev/urandom | head -c 8)"
kubectl create configmap marker -n eks-122 --from-literal=marker="$MARKER"

mkdir -p /var/work/tests/artifacts/1
echo -n "$MARKER" > /var/work/tests/artifacts/1/marker.txt
cat /var/work/tests/artifacts/1/marker.txt
```

`volumeBindingMode: WaitForFirstConsumer` აჭიანურებს ტომის შექმნას მანამ, სანამ pod არ
დაიგეგმება (თავი 23) - PVC `Bound` ხდება მხოლოდ მაშინ, როცა pod `web` რეალურად
დაიგეგმება. არტეფაქტში ჩაწერილი მარკერი მოგვიანებით დაამტკიცებს, რომ აღდგენილი ConfigMap
backup-იდან მოვიდა და არ არის ხელით ხელახლა შექმნილი.

## დავალება 2. Amazon EKS-ის opt-in AWS Backup-ში რეგიონისთვის

```bash
mkdir -p /var/work/tests/artifacts/2
BEFORE=$(aws backup describe-region-settings \
  --query "ResourceTypeOptInPreference.EKS" --output text)
echo "before=$BEFORE" > /var/work/tests/artifacts/2/optin.txt

if [[ "$BEFORE" != "True" ]]; then
  aws backup update-region-settings \
    --resource-type-opt-in-preference '{"EKS":true}'
fi

AFTER=$(aws backup describe-region-settings \
  --query "ResourceTypeOptInPreference.EKS" --output text)
echo "after=$AFTER" >> /var/work/tests/artifacts/2/optin.txt
cat /var/work/tests/artifacts/2/optin.txt
```

ამ opt-in-ის გარეშე AWS Backup ვერ ხედავს EKS-კლასტერს დაცვად რესურსად და კლასტერისთვის
`start-backup-job` ვარდება (თავი 41, სექცია 41.4).

## დავალება 3. კლასტერის on-demand backup

კლასტერი უკვე შეიქმნა ცხადი `authentication_mode = "API_AND_CONFIG_MAP"`-ით (მოდული
`eks_v2_control_plane`), ამიტომ AWS Backup-ის მოთხოვნა ავტორიზაციის რეჟიმზე უკვე
შესრულებულია - სერვისი პირველივე backup job-ზე თავად შექმნის access entry-ს.

```bash
BACKUP_JOB_ID=$(aws backup start-backup-job \
  --backup-vault-name "$VAULT_NAME" \
  --resource-arn "$CLUSTER_ARN" \
  --iam-role-arn "$ROLE_ARN" \
  --query 'BackupJobId' --output text)

echo "backup_job_id=$BACKUP_JOB_ID"

while true; do
  STATE=$(aws backup describe-backup-job --backup-job-id "$BACKUP_JOB_ID" \
    --query 'State' --output text)
  echo "backup job state: $STATE"
  case "$STATE" in
    COMPLETED|PARTIAL|FAILED|ABORTED|EXPIRED) break ;;
  esac
  sleep 15
done

RECOVERY_POINT_ARN=$(aws backup describe-backup-job --backup-job-id "$BACKUP_JOB_ID" \
  --query 'RecoveryPointArn' --output text)
```

ტომის `data` EBS-სნეპშოტის აწყობას შეიძლება მეტი დრო დასჭირდეს, ვიდრე კლასტერის
მდგომარეობას, ამიტომ ველოდებით ტერმინალურ სტატუსს და არა კონკრეტულად `COMPLETED`-ს:
`PARTIAL` (თავი 41, სექცია 41.4) ასევე ნიშნავს, რომ backup job დასრულდა და recovery point
შეიქმნა, უბრალოდ ჩადგმული წერტილებიდან ნაწილი შეიძლება ვერ აეწყო. შევინახოთ არტეფაქტი:

```bash
mkdir -p /var/work/tests/artifacts/3
{
  echo "backup_job_id=$BACKUP_JOB_ID"
  echo "status=$STATE"
  echo "recovery_point_arn=$RECOVERY_POINT_ARN"
} > /var/work/tests/artifacts/3/backup_status.txt
cat /var/work/tests/artifacts/3/backup_status.txt
```

## დავალება 4. composite recovery point-ის დიაგნოსტიკა

`RECOVERY_POINT_ARN` 3-ე დავალებიდან არის composite recovery point: მშობელი წერტილი ერთ
თანმიმდევრულ ერთეულად აჯგუფებს კლასტერის მდგომარეობის child recovery point-სა და ტომის
`data` child recovery point-ს (თავი 41, სექცია 41.4). ვნახოთ ის და ჩადგმული წერტილები:

```bash
aws backup list-recovery-points-by-backup-vault --backup-vault-name "$VAULT_NAME" \
  --query 'RecoveryPoints[].{Arn:RecoveryPointArn,Parent:ParentRecoveryPointArn,IsParent:IsParent,Status:Status}'

aws backup list-recovery-points-by-backup-vault --backup-vault-name "$VAULT_NAME" \
  --by-parent-recovery-point-arn "$RECOVERY_POINT_ARN"
```

შევინახოთ არტეფაქტში composite და child წერტილებს შორის განსხვავების განმარტება:

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/composite.txt <<'EOF'
composite recovery point არის EKS-კლასტერის შედგენილი აღდგენის წერტილი: ის თავის ქვეშ
ერთ თანმიმდევრულ ერთეულად აჯგუფებს რამდენიმე ჩადგმულ (nested/child) წერტილს. ამ ლაბისთვის
ეს ნიშნავს კლასტერის მდგომარეობის child recovery point-ს (namespace eks-122-ის Kubernetes
ობიექტების მანიფესტები) და ტომის data child recovery point-ს (PVC-ს უკან მდგარი
EBS-სნეპშოტი).

composite წერტილს არ აქვს საკუთარი ParentRecoveryPointArn - ის ზედა დონეა. ყოველ child
წერტილში ველი ParentRecoveryPointArn მიუთითებს composite წერტილის ARN-ზე, ხოლო
IsParent=true მონიშნულია სწორედ composite-ზე. კლასტერის მდგომარეობის child-ს მშობელთან
1:1 კავშირი აქვს: მისი კოპირება, წაშლა ან მოხსნა ცალკე შეუძლებელია. ტომის child წერტილი კი,
პირიქით, შეიძლება დაკოპირდეს, წაიშალოს და აღდგეს composite-ისგან დამოუკიდებლად.

სწორედ ამიტომ composite წერტილი ვერ წაიშლება, სანამ მის შიგნით ჩადგმული წერტილებია -
პირველად უნდა წაიშალოს ან მოიხსნას nested წერტილები და მხოლოდ შემდეგ თავად composite.
EOF
cat /var/work/tests/artifacts/4/composite.txt
```

## დავალება 5. Namespace restore (non-destructive)

ვიწყებთ composite recovery point-ის restore-ს namespace `eks-122`-ის მითითებით იმავე
(ცოცხალ) კლასტერში:

მხოლოდ `namespaceLevelRestore` აქ არ კმარა. composite წერტილში ასევე არის EBS-სნეპშოტი და
მისი აღდგენისთვის AWS Backup **აუცილებლად მოითხოვს Availability Zone-ს**, სადაც ტომი
შეიქმნება. თუ არ მიეთითება, ტომის child restore job ვარდება შეტყობინებით
`Restore Job failed as no restore metadata was provided`, ხოლო მშობელი -
`All PV restore jobs failed to restore`. ეს გადაეცემა პარამეტრით `nestedRestoreJobs`:
რუკა `ჩადგმული წერტილის ARN -> მისი მეტამონაცემები`. ზონა აიღება არსებული ნოუდიდან, თორემ
ტომი შეიქმნება იმ ადგილას, სადაც მისი მიმაუნთება ვერავინ შეძლებს.

გაითვალისწინეთ კოდირების ჩადგმულობა: `nestedRestoreJobs`-ის მნიშვნელობა არის JSON-სტრიქონი,
რომლის შიგნით არის რუკა, და რუკის ელემენტის მნიშვნელობაც თავის მხრივ JSON-სტრიქონია.
ბრჭყალების ზედმეტი დონე იძლევა შეცდომას `Invalid JSON format in NestedRestoreMetadata`,
ამიტომ მას `jq`-ით ვაწყობთ (შეამჩნიეთ `-r` პირველ გამოძახებაში - სწორედ ის ხსნის ზედმეტ
დონეს):

```bash
AZ=$(kubectl get nodes -l 'eks.amazonaws.com/compute-type notin (fargate)' \
  -o jsonpath='{.items[0].metadata.labels.topology\.kubernetes\.io/zone}')

SNAP_ARN=$(aws backup list-recovery-points-by-backup-vault --backup-vault-name "$VAULT_NAME" \
  --by-parent-recovery-point-arn "$RECOVERY_POINT_ARN" \
  --query 'RecoveryPoints[?ResourceType==`EBS`].RecoveryPointArn' --output text)

NESTED=$(jq -rn --arg s "$SNAP_ARN" --arg az "$AZ" \
  '{($s): ({AvailabilityZone: $az} | tostring)} | tostring')

METADATA=$(jq -cn --arg c "$CLUSTER_NAME" --arg n "$NESTED" \
  '{clusterName: $c, newCluster: "false", namespaceLevelRestore: "true",
    namespaces: "[\"eks-122\"]", nestedRestoreJobs: $n}')

RESTORE_JOB_ID=$(aws backup start-restore-job \
  --recovery-point-arn "$RECOVERY_POINT_ARN" \
  --iam-role-arn "$ROLE_ARN" \
  --resource-type EKS \
  --metadata "$METADATA" \
  --query 'RestoreJobId' --output text)

echo "restore_job_id=$RESTORE_JOB_ID"

while true; do
  STATUS=$(aws backup describe-restore-job --restore-job-id "$RESTORE_JOB_ID" \
    --query 'Status' --output text)
  echo "restore job status: $STATUS"
  case "$STATUS" in
    COMPLETED|FAILED|ABORTED) break ;;
  esac
  sleep 15
done
```

ვამოწმებთ, რომ Deployment `web` და ConfigMap `marker` არ დუბლირდა და მარკერი ემთხვევა
1-ელ დავალებაში შენახულს - ეს ადასტურებს restore-ის non-destructive ქცევას (თავი 42,
სექცია 42.2): ობიექტები, რომლებიც კლასტერში იმავე სახელით უკვე არსებობს, არ გადაიწერება,
მხოლოდ გამოტოვდება, ამიტომ restore ცოცხალ namespace-ზე მეორე ასლს არ ქმნის.

```bash
kubectl rollout status deployment/web -n eks-122
kubectl get cm marker -n eks-122 -o jsonpath='{.data.marker}'; echo
cat /var/work/tests/artifacts/1/marker.txt; echo
```

შევინახოთ არტეფაქტი განმარტებით:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/restore_status.txt <<EOF
restore_job_id=$RESTORE_JOB_ID
status=$STATUS
AWS Backup-ში restore ყოველთვის non-destructive არის: Kubernetes-ის ობიექტები, რომლებიც
სამიზნე namespace-ში უკვე არსებობს, არ გადაიწერება, მხოლოდ გამოტოვდება. Deployment web და
ConfigMap marker restore-ის მომენტში eks-122-ში იმავე შიგთავსით უკვე არსებობდა, ამიტომ
restore-მ მათი დუბლიკატები არ შექმნა და მარკერის მნიშვნელობა არ შეცვალა - ობიექტები
უბრალოდ დაემთხვა და გამოტოვდა.
EOF
cat /var/work/tests/artifacts/5/restore_status.txt
```

## დავალება 6. რატომ არ აბრუნებს კლასტერის ვერსიის rollback `kubectl delete namespace`-ს

41-ე თავის 41.1 სექციის მოტივირებადი მაგალითი: ინჟინერი შეცდომით უშვებს
`kubectl delete namespace prod`-ს არასწორ კლასტერზე და პირველი აზრი არის "მოდი დავაბრუნოთ
უკან". მაგრამ დასაბრუნებელი არაფერია.

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/whynonrollback.txt <<'EOF'
კლასტერის ვერსიის rollback (თავი 39) მუშაობს control plane-სა და მის Kubernetes ვერსიასთან -
ის არ ინახავს და არ აბრუნებს არც Kubernetes-ის ობიექტებს, არც ტომების შიგთავსს. ობიექტები,
რომლებიც kubectl delete namespace-მ წაშალა, ცხოვრობს etcd-ში, ხოლო EKS-ში etcd managed არის:
მასზე პირდაპირი წვდომა არ არსებობს და ვერ აიღებ etcd-ის dump-ს და ხელით ვერ აღადგენ, როგორც
ეს თვითმართვად კლასტერზე შეიძლებოდა. managed control plane-ისთვის ასევე არ არსებობს ბრძანება
"დააბრუნე ისე, როგორც გუშინ იყო".

სწორედ ამიტომ წაშლილი namespace-ის დაბრუნების ერთადერთი მომუშავე გზაა წინასწარ AWS Backup-ით
გაკეთებული კლასტერის მდგომარეობის backup (დავალებები 3-4) და შემდეგ restore (დავალება 5),
და არა control plane-ის ვერსიის rollback.
EOF
cat /var/work/tests/artifacts/6/whynonrollback.txt
```

## სწრაფი შემოწმება

```bash
check_result
```
