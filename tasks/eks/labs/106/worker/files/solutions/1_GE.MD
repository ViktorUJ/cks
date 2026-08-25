[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 106 - ეტალონური გადაწყვეტა (EBS CSI: gp3, AZ-ზე მიბმა, გაფართოება, სნეპშოტი)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე (worker) SSH-ის მეშვეობით. kubectl უკვე
კონფიგურირებულია კლასტერზე. დრაივერი `aws-ebs-csi-driver` (provisioner `ebs.csi.aws.com`)
უკვე დაყენებულია როგორც managed addon როლით IRSA-ის მეშვეობით (კომპონენტი
`eks_addon_ebs_irsa`) - როლის ხელახლა შექმნა საჭირო არ არის.

## დავალება 1. Namespace `eks-106`

```bash
kubectl create namespace eks-106
```

## დავალება 2. StorageClass `gp3-immediate` (გატეხილი კონფიგურაცია)

განზრახ ვიღებთ `volumeBindingMode: Immediate`-ს - ზუსტად ის იჭერს ტომს შემთხვევით
ზონაში:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-immediate
provisioner: ebs.csi.aws.com
volumeBindingMode: Immediate
allowVolumeExpansion: true
parameters:
  type: gp3
  encrypted: "true"
EOF
```

## დავალება 3. StatefulSet `db` `gp3-immediate`-ზე

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
  namespace: eks-106
spec:
  serviceName: db
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      storageClassName: gp3-immediate
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
EOF

kubectl get pvc -n eks-106
kubectl get po db-0 -n eks-106 -o wide
```

ლაბის კლასტერი ამართულია ორ AZ-ში (`eu-central-1a` და `eu-central-1b`). `Immediate`-ით
დრაივერი ქმნის ტომს PVC-ის გამოჩენისთანავე, არ ელოდება, სად დააყენებს scheduler-ი
პოდს, ამიტომ ტომის ზონა ირჩევა დამოუკიდებლად იმისგან, სად Karpenter ნამდვილად
ამართავს ნოუდს. ორ AZ-ში კონფლიქტი `volume node affinity conflict` ნამდვილად ჩნდება,
მაგრამ არა გარანტირებულად ყოველ გაშვებაზე: ტომს შემთხვევით შეუძლია მოხვდეს იმავე
ზონაში, სადაც უკვე არსებობს შესატყვისი ნოუდი. ზუსტად ამიტომ დავალება 4-ში
დიაგნოსტიკა სავალდებულოა შედეგისგან დამოუკიდებლად.

## დავალება 4. დიაგნოსტიკა: Immediate-ის სიმპტომი ზონაზე მიბმის წინააღმდეგ

```bash
mkdir -p /var/work/tests/artifacts/4

kubectl describe pod db-0 -n eks-106 | sed -n '/Events/,$p' \
  > /var/work/tests/artifacts/4/describe.txt

PV=$(kubectl get pvc data-db-0 -n eks-106 -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PV" -o yaml > /var/work/tests/artifacts/4/pv.yaml
grep -A6 nodeAffinity /var/work/tests/artifacts/4/pv.yaml
```

ვამოწმებთ, სად ნამდვილად მოხვდა პოდი და ემთხვევა თუ არა ტომის ზონა ნოუდის ზონას:

```bash
PHASE=$(kubectl get po db-0 -n eks-106 -o jsonpath='{.status.phase}')
NODE=$(kubectl get po db-0 -n eks-106 -o jsonpath='{.spec.nodeName}')
PV_ZONE=$(kubectl get pv "$PV" \
  -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}')
echo "phase=$PHASE node=$NODE pv_zone=$PV_ZONE"
```

ვინახავთ განმარტებას არტეფაქტში. ფორმულირება უნდა მუშაობდეს ორივე შემთხვევაში - იმისას,
როცა პოდი გაჭედილია `Pending`-ში, და იმისას, როცა მას შემთხვევით გაუმართლა:

```bash
cat > /var/work/tests/artifacts/4/diagnosis.txt <<'EOF'
StorageClass gp3-immediate იყენებს volumeBindingMode: Immediate-ს. ეს ნიშნავს, რომ
CSI-დრაივერი ebs.csi.aws.com ქმნის EBS-ტომს PVC-ის გამოჩენისთანავე, სანამ scheduler-მა
შეარჩია ნოუდი პოდისთვის. ტომის ზონა ფიქსირდება PV-ში spec.nodeAffinity.required.
nodeSelectorTerms[].matchExpressions[].key-ის მეშვეობით: topology.ebs.csi.aws.com/zone,
და scheduler ვალდებულია ეს მიბმა დააფასოს.

თუ პოდი db-0 არის Pending-ში, kubectl describe pod აჩვენებს events-ს
"0/N nodes are available: N node(s) had volume node affinity conflict" - ტომი შექმნილია
იმ ზონაში, სადაც შესატყვისი ნოუდი არ არსებობს.

თუ პოდი db-0 არის Running-ში, ეს არ ნიშნავს, რომ კონფიგურაცია სწორია: კლასტერში
სულ ორი AZ-ია (eu-central-1a, eu-central-1b), და Immediate-ით ტომი მოხვდა ზონაში,
სადაც ნოუდი უკვე იყო, უბრალოდ შემთხვევით. სხვა გაშვებისას, Karpenter-ის
consolidation-ის დროს ან AZ-ების უფრო დიდ რაოდენობაზე გადასვლისას იგივე StorageClass
ისევ მოგვცემს volume node affinity conflict-ს. გარანტირებულად სწორად მუშაობს მხოლოდ
WaitForFirstConsumer, სადაც ტომის ზონა ყოველთვის ტოლია უკვე შერჩეული ნოუდის ზონისა -
ეს დავალება 5-ია.
EOF
cat /var/work/tests/artifacts/4/diagnosis.txt
```

## დავალება 5. გამოსწორება: StorageClass `gp3` `WaitForFirstConsumer`-ით

PVC ერთხელ ერთვება საკუთარ StorageClass-ს, არსებულ PVC-ზე კლასის შეცვლა შეუძლებელია,
ამიტომ გამოსწორება ხდება არა `gp3-immediate`-ის პატჩით, არამედ ახალი კლასითა და
ახალი StatefulSet-ით:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  type: gp3
  encrypted: "true"
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db-fixed
  namespace: eks-106
spec:
  serviceName: db-fixed
  replicas: 1
  selector:
    matchLabels:
      app: db-fixed
  template:
    metadata:
      labels:
        app: db-fixed
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      storageClassName: gp3
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
EOF

kubectl rollout status statefulset/db-fixed -n eks-106
```

`WaitForFirstConsumer`-ით ტომის provisioning იგვიანდება მანამ, სანამ scheduler არ
შეარჩევს ნოუდს `db-fixed-0`-სთვის. მხოლოდ ამის შემდეგ დრაივერი ქმნის ტომს ამ ნოუდის
ზონაში, და `nodeAffinity`-ის კონფლიქტი შეუძლებელი ხდება თავად კონსტრუქციით.
ვამოწმებთ, რომ ტომის ზონა ემთხვევა ნოუდის ზონას:

```bash
NODE=$(kubectl get po db-fixed-0 -n eks-106 -o jsonpath='{.spec.nodeName}')
NODE_ZONE=$(kubectl get node "$NODE" \
  -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
PV=$(kubectl get pvc data-db-fixed-0 -n eks-106 -o jsonpath='{.spec.volumeName}')
PV_ZONE=$(kubectl get pv "$PV" \
  -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}')
echo "node_zone=$NODE_ZONE pv_zone=$PV_ZONE"
```

მნიშვნელობები `node_zone` და `pv_zone` უნდა ემთხვეოდეს - ეს არის სწორი, და არა
შემთხვევითი, მუშაობის ნიშანი. დამატებით შესაძლებელია ზონების ნაკრების ცალსახად
შეზღუდვა `allowedTopologies`-ის მეშვეობით StorageClass-ში (გასაღები
`topology.ebs.csi.aws.com/zone`), თუ საჭიროა კონკრეტული AZ-ის გამორიცხვა ტომების
provisioning-იდან.

## დავალება 6. ტომ `data-db-fixed-0`-ის გაფართოება 5Gi-დან 10Gi-მდე

`allowVolumeExpansion: true` `gp3`-ში ანებდობს გაფართოებას ონლაინ, პოდის ხელახლა
შექმნის გარეშე:

```bash
kubectl patch pvc data-db-fixed-0 -n eks-106 \
  -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'

# ველოდებით, სანამ CSI-დრაივერი დაასრულებს ტომისა და ფაილური სისტემის მოდიფიკაციას
until [[ "$(kubectl get pvc data-db-fixed-0 -n eks-106 \
  -o jsonpath='{.status.capacity.storage}')" == "10Gi" ]]; do
  sleep 5
done

kubectl get pvc data-db-fixed-0 -n eks-106 \
  -o jsonpath='{.status.capacity.storage}'
echo
```

ტომის შემცირება შეუძლებელია - მხოლოდ გაზრდა, და არა უფრო ხშირად, ვიდრე EBS-ის
მოდიფიკაციების ლიმიტი ანებდობს.

## დავალება 7. ტომის სნეპშოტი და აღდგენა (best effort)

სნეპშოტი მუშაობს სამი ობიექტის მეშვეობით: `VolumeSnapshotClass`, `VolumeSnapshot` და
ავტომატურად შექმნილი `VolumeSnapshotContent`. Snapshot-controller და CRD კლასტერში
უკვე დაყენებულია managed addon `snapshot-controller`-ით (კომპონენტი `eks_addons`):

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: ebs-snapclass
driver: ebs.csi.aws.com
deletionPolicy: Delete
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: db-snap
  namespace: eks-106
spec:
  volumeSnapshotClassName: ebs-snapclass
  source:
    persistentVolumeClaimName: data-db-fixed-0
EOF

kubectl get volumesnapshot db-snap -n eks-106
```

ველოდებით, სანამ სნეპშოტი გახდება მზა (`readyToUse: true`), და აღვადგენთ მას ახალ
PVC-ში. EBS-სნეპშოტი რეგიონალური ობიექტია, მაგრამ მისგან აღდგენილი ტომი ისევ
ზონალურია, ამიტომ კლასი `WaitForFirstConsumer`-ით საჭიროა აქაც:

```bash
kubectl wait --for=jsonpath='{.status.readyToUse}'=true \
  volumesnapshot/db-snap -n eks-106 --timeout=180s

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-restored
  namespace: eks-106
spec:
  storageClassName: gp3
  accessModes: ["ReadWriteOnce"]
  dataSource:
    kind: VolumeSnapshot
    name: db-snap
    apiGroup: snapshot.storage.k8s.io
  resources:
    requests:
      storage: 10Gi
EOF

kubectl get pvc data-restored -n eks-106
```

`data-restored` დარჩება `Pending`-ში, სანამ მას პოდი არ მიემართება (კლასი `gp3` -
`WaitForFirstConsumer`), ეს მოსალოდნელია: აღდგენილი ტომის provisioning-იც
იგვიანდება დაგეგმვამდე. თუ კლასტერში რაიმე მიზეზით არ არსებობს snapshot-controller
ან CRD, თავად დავალება არ ბლოკავს ლაბის დანარჩენ ნაწილს - ეს ცალკე არასავალდებულო
ეტაპია გადამოწმებისთვის.

## სწრაფი გადამოწმება

```bash
check_result
```
