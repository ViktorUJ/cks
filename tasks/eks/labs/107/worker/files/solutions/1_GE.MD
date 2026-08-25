[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 107 - ეტალონური გადაწყვეტა (EFS CSI: ReadWriteMany AZ-ებს შორის)

ყველა ბრძანება სრულდება worker მანქანაზე SSH-ის მეშვეობით. kubectl უკვე
კონფიგურირებულია კლასტერზე. დრაივერი `aws-efs-csi-driver` (provisioner
`efs.csi.aws.com`) უკვე დაინსტალირებულია, როგორც managed addon როლით IRSA-ის
მეშვეობით (კომპონენტი `eks_addon_efs_irsa`), EFS ფაილური სისტემა და mount target
ყველა AZ-ში უკვე შექმნილია terraform-ის მიერ - მათი ხელახლა შექმნა საჭირო არ არის.

## დავალება 1. Namespace `eks-107`

```bash
kubectl create namespace eks-107
```

## დავალება 2. StorageClass `efs-sc` ნამდვილ `fileSystemId`-ზე მიმართვით

ფაილური სისტემა წინასწარ შექმნილია terraform-ის მიერ, დრაივერი მხოლოდ მასზე ზემოთ
მუშაობს. მის ID-ს ვპოულობთ AWS CLI-ის მეშვეობით (თეგი `Name` აგებულია ლაბის
`prefix`-იდან):

```bash
FS_ID=$(aws efs describe-file-systems --region eu-central-1 \
  --query "FileSystems[?Tags[?Key=='Name' && Value=='eks-task107-efs']].FileSystemId" \
  --output text)
echo "$FS_ID"

cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: ${FS_ID}
  directoryPerms: "755"
  uid: "1000"
  gid: "1000"
  basePath: "/dynamic"
mountOptions: ["tls"]
EOF
```

`provisioningMode: efs-ap` ნიშნავს დინამიურ პროვიზირებას: თითოეული PVC-სთვის
დრაივერი ქმნის ცალკე access point-ს ამ ფაილური სისტემის შიგნით, მთელი ფაილური
სისტემის გადაცემის ნაცვლად.

## დავალება 3. PVC `shared-data` (`ReadWriteMany`, `5Gi`)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-data
  namespace: eks-107
spec:
  accessModes: ["ReadWriteMany"]
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi
EOF

kubectl get pvc shared-data -n eks-107
```

EFS არის რეგიონული სისტემა, ამიტომ PVC გადადის `Bound` სტატუსში იმისგან
დამოუკიდებლად, თუ რომელ ზონაში მოხდება pod-ების მოგვიანებით დათვლა: mount target
ხელმისაწვდომია ნებისმიერი AZ-დან, სადაც ის შექმნილია.

## დავალება 4. Deployment `writer` (3 რეპლიკა, სხვადასხვა AZ, გაზიარებული PVC)

`topologySpreadConstraints` გასაღებზე `topology.kubernetes.io/zone` აძლევს
სქედულერს დაავალო რეპლიკები სხვადასხვა ზონებში:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: writer
  namespace: eks-107
spec:
  replicas: 3
  selector:
    matchLabels:
      app: writer
  template:
    metadata:
      labels:
        app: writer
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: writer
      containers:
      - name: app
        image: viktoruj/ping_pong:alpine
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: shared-data
EOF

kubectl rollout status deployment/writer -n eks-107
kubectl get po -n eks-107 -l app=writer -o wide
```

ვამოწმებთ, რომ რეპლიკები მოხვდნენ სხვადასხვა AZ-ში:

```bash
kubectl get po -n eks-107 -l app=writer \
  -o custom-columns='POD:.metadata.name,NODE:.spec.nodeName' --no-headers | \
  while read -r pod node; do
    zone=$(kubectl get node "$node" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
    echo "$pod  node=$node  zone=$zone"
  done
```

ყველა 3 რეპლიკა ერთდროულად არის `Running` და მონტავს ერთსა და იმავე PVC
`shared-data`-ს, მიუხედავად იმისა, რომ ისინი სხვადასხვა AZ-ში არიან. EBS-ით ეს
შეუძლებელია (`ReadWriteOnce`, შეცდომა `Multi-Attach error`), რადგან EBS არის
ზონალური ბლოკური ტომი, ხოლო EFS არის რეგიონული NFS სისტემა mount target-ით
ყოველ ზონაში.

## დავალება 5. გაზიარებული წვდომა: ჩაწერა ერთი რეპლიკიდან, წაკითხვა მეორედან

```bash
PODS=($(kubectl get po -n eks-107 -l app=writer -o jsonpath='{.items[*].metadata.name}'))
WRITER_POD=${PODS[0]}
READER_POD=${PODS[1]}

kubectl exec -n eks-107 "$WRITER_POD" -- sh -c \
  'echo "efs-rwx-test from $(hostname)" >> /data/shared.txt'

mkdir -p /var/work/tests/artifacts/5
kubectl exec -n eks-107 "$READER_POD" -- cat /data/shared.txt \
  > /var/work/tests/artifacts/5/readback.txt
cat /var/work/tests/artifacts/5/readback.txt
```

ხაზი, რომელიც ჩაწერილია pod `$WRITER_POD`-ის მიერ ერთ AZ-ში, წაკითხულია pod
`$READER_POD`-ის მიერ სხვა AZ-ში - ეს ადასტურებს, რომ ეს ნამდვილად გაზიარებული
ქსელური ტომია NFS-ის მეშვეობით, არა ლოკალური კოპია ნოუდის დისკზე.

## დავალება 6. ზონალური `nodeAffinity`-ის არარსებობის შემოწმება

```bash
mkdir -p /var/work/tests/artifacts/6

PV=$(kubectl get pvc shared-data -n eks-107 -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PV" -o yaml > /var/work/tests/artifacts/6/pv.yaml
grep -A3 nodeAffinity /var/work/tests/artifacts/6/pv.yaml
echo "exit code: $?"

cat > /var/work/tests/artifacts/6/explanation.txt <<'EOF'
efs.csi.aws.com-ის მიერ შექმნილ PV-ს არ აქვს spec.nodeAffinity სექცია (EBS-ისგან
განსხვავებით, თავი 23, სადაც nodeAffinity მკაცრად მიაბამს კონკრეტულ AZ-ს გასაღების
topology.ebs.csi.aws.com/zone მეშვეობით). მიზეზი იმაში მდგომარეობს, რომ EFS არის
რეგიონული ფაილური სისტემა mount target-ით ყოველ AZ-ში, ამიტომ pod, რომელიც
იყენებს ამ ტომს, შეიძლება ხელახლა შეიქმნას კლასტერის ნებისმიერ სხვა ზონაში და
ისევ დაინახავს იმავე მონაცემებს თავისი ახალი ზონის mount target-ის მეშვეობით.
სქედულერს არ სჭირდება pod-ის მიბმა კონკრეტულ ნოუდზე ან ზონაზე ტომის გამო, როგორც
ეს ხდება EBS-ის შემთხვევაში.
EOF
cat /var/work/tests/artifacts/6/explanation.txt
```

ბრძანება `grep -A3 nodeAffinity` არაფერს პოულობს (ცარიელი გამოტანა, exit code
`1`) - ეს არის დადასტურება, რომ სექცია არ არსებობს. შეადარეთ ლაბა 106-ის
`pv.yaml`-ს (EBS), სადაც `spec.nodeAffinity.required.nodeSelectorTerms` მკაცრად
მიაბამს ტომის ზონას.

## დავალება 7. დიაგნოსტიკა: mount target-ის SG და პორტი 2049 (მხოლოდ წაკითხვა)

ნამდვილი ინფრასტრუქტურის დამტვრევა რისკიანია, ამიტომ ეს დავალება მხოლოდ
ადასტურებს მიმდინარე მდგომარეობას AWS CLI-ის მეშვეობით და განმარტავს წესის
არარსებობის შედეგებს.

```bash
mkdir -p /var/work/tests/artifacts/7

FS_ID=$(aws efs describe-file-systems --region eu-central-1 \
  --query "FileSystems[?Tags[?Key=='Name' && Value=='eks-task107-efs']].FileSystemId" \
  --output text)

MT_SG=$(aws efs describe-mount-targets --region eu-central-1 --file-system-id "$FS_ID" \
  --query 'MountTargets[0].MountTargetId' --output text | \
  xargs -I{} aws efs describe-mount-target-security-groups --region eu-central-1 \
  --mount-target-id {} --query 'SecurityGroups[0]' --output text)

aws ec2 describe-security-groups --region eu-central-1 --group-ids "$MT_SG" \
  --query 'SecurityGroups[0].IpPermissions[?ToPort==`2049`]' \
  > /var/work/tests/artifacts/7/sg-rule.txt
cat /var/work/tests/artifacts/7/sg-rule.txt
```

დარწმუნდით, რომ გამოტანაში არის წესი `FromPort/ToPort: 2049`, `IpProtocol: tcp`,
და რომ წყარო (`UserIdGroupPairs`) არის კლასტერის ნოუდის security group, არა
CIDR. შეინახეთ მიზეზ-შედეგობრივი დიაგნოზი:

```bash
cat > /var/work/tests/artifacts/7/diagnosis.txt <<'EOF'
Mount target-ის security group უშვებს inbound TCP 2049-ს (NFS) კლასტერის ნოუდის
security group-იდან - ეს დადასტურებულია aws ec2 describe-security-groups-ის
გამოტანით (sg-rule.txt). ეს წესი საჭიროა ყოველი mount target-ისთვის: მის გარეშე
efs.csi.aws.com დრაივერს კვლავ შეუძლია შექმნას mount point API დონეზე, მაგრამ
ნამდვილი მონტირების პროცესი ნოუდზე ვერ შეძლებს NFS-კავშირის დამყარებას mount
target-თან.

თუ ეს წესი მოშორდება, მონტირება არ ჩავარდება დაუყოვნებლივ ცხადად გამოხატული
შეცდომით: TCP პაკეტები პორტ 2049-ზე დაითქვას security group-ის მიერ, და ბირთვი
ნოუდზე დაელოდება NFS სერვერის პასუხს, სანამ timeout არ ამოიწურება. Pod დარჩება
Pending/ContainerCreating მდგომარეობაში, და kubectl describe pod გამოაჩენს
FailedMount event-ს ტექსტით, მსგავსი "Unable to mount... connection timed out" -
ვიზუალურად ეს მოგონებას ჰგავს ნელ ქსელს, ცხადად გამოხატულ წვდომის აკრძალვას
ნაცვლად, და security group-ის დიაგნოსტიკის გარეშე ადვილია მიზეზის აღრევა თავად
NFS სერვერის ან subnet-ის პრობლემასთან.
EOF
cat /var/work/tests/artifacts/7/diagnosis.txt
```

## სწრაფი გადამოწმება

```bash
check_result
```
