[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 103 - ეტალონური გადაწყვეტა (მისამართების გეგმა: ENI, prefix delegation, secondary CIDR)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე (worker) SSH-ით. kubectl უკვე კონფიგურირებულია
კლასტერზე (kubeconfig აწყობილია `aws eks update-kubeconfig`-ით მანქანის ჩატვირთვისას).

```bash
export CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
kubectl create namespace eks-103
```

## დავალება 1. max-pods-ის გამოთვლა ფორმულით და ფაქტთან შედარება

ვქმნით საბაზისო დატვირთვას და ველოდებით, სანამ Karpenter მისთვის ასწევს EC2-ნოუდს
VPC CNI-ის ჩვეულ (მისამართობრივ) რეჟიმში - addon ჯერ არ არის გადართული prefix
delegation-ზე:

```bash
kubectl create deployment baseline --image=viktoruj/ping_pong:latest --replicas=2 -n eks-103
kubectl rollout status deployment/baseline -n eks-103

NODE=$(kubectl get po -n eks-103 -l app=baseline -o jsonpath='{.items[0].spec.nodeName}')
TYPE=$(kubectl get node "$NODE" \
  -o jsonpath='{.metadata.labels.node\.kubernetes\.io/instance-type}')
echo "node=$NODE type=$TYPE"
```

ვიღებთ ENI-ის რაოდენობას, IP ENI-ზე და vCPU-ს ამ instance-ის ტიპისთვის:

```bash
ENI=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].NetworkInfo.MaximumNetworkInterfaces' --output text)
IPS=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].NetworkInfo.Ipv4AddressesPerInterface' --output text)
VCPU=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].VCpuInfo.DefaultVCpus' --output text)
echo "eni=$ENI ips_per_eni=$IPS vcpu=$VCPU"
```

ვთვლით ფორმულით `max-pods = ENI * (IP ENI-ზე - 1) + 2` და ვიყენებთ managed node
group-ის cap-ს (`110`, თუ `vCPU < 30`, სხვაგვარად `250`):

```bash
FORMULA=$((ENI * (IPS - 1) + 2))
if [ "$VCPU" -lt 30 ]; then CAP=110; else CAP=250; fi
if [ "$FORMULA" -lt "$CAP" ]; then EXPECTED=$FORMULA; else EXPECTED=$CAP; fi
echo "formula=$FORMULA cap=$CAP expected_max_pods=$EXPECTED"

ACTUAL=$(kubectl get node "$NODE" -o jsonpath='{.status.allocatable.pods}')
echo "actual_allocatable_pods=$ACTUAL"
```

მაგალითი `m5.large`-სთვის: `ENI=3`, `IP ENI-ზე=10` იძლევა `formula = 3*(10-1)+2 = 29`,
cap `110` არ ახდენს გავლენას (`29 < 110`), ესე იგი `expected_max_pods = 29` - და ზუსტად
ეს უნდა აჩვენოს `kubectl get node`-მა.

ვინახავთ გამოთვლას და ფაქტს არტეფაქტში:

```bash
mkdir -p /var/work/tests/artifacts/1
cat > /var/work/tests/artifacts/1/maxpods.txt <<EOF
node=$NODE
instance_type=$TYPE
eni=$ENI
ips_per_eni=$IPS
vcpu=$VCPU
formula=$FORMULA
cap=$CAP
expected_max_pods=$EXPECTED
actual_allocatable_pods=$ACTUAL
EOF
cat /var/work/tests/artifacts/1/maxpods.txt
```

თუ `expected_max_pods` და `actual_allocatable_pods` არ ემთხვევა - kubelet-მა max-pods
გაიცნობს მხოლოდ ნოუდის სტარტისას, შედარება უნდა მოხდეს ნოუდზე, რომელიც უკვე
სრულად Ready-ია.

## დავალება 2. Prefix delegation: ახალი ნოუდი ძველის წინააღმდეგ

ვაფიქსირებთ ძველი ნოუდის მდგომარეობას (მისამართობრივი რეჟიმი) prefix delegation-ის
ჩართვამდე:

```bash
OLD_NODE="$NODE"
OLD_PODS=$(kubectl get node "$OLD_NODE" -o jsonpath='{.status.allocatable.pods}')
echo "old_node=$OLD_NODE old_node_allocatable_pods=$OLD_PODS"
```

ვრთავთ prefix delegation-ს managed addon `vpc-cni`-ზე (მუშაობს მხოლოდ Nitro-ზე
დაფუძნებულ instance-ებზე, ამიტომ მნიშვნელოვანია, რომ NodePool ამ ტიპებს იყენებდეს):

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
  --configuration-values '{"env":{"ENABLE_PREFIX_DELEGATION":"true","WARM_PREFIX_TARGET":"1"}}' \
  --resolve-conflicts PRESERVE

aws eks describe-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
  --query 'addon.configurationValues'
```

Prefix delegation ეხება მხოლოდ ახალ ნოუდებს: ძველ ნოუდ `baseline`-მ თავისი ლიმიტი
`allocatable.pods` უკვე მიიღო kubelet-ისგან სტარტისას და არ გადათვლის მას, სანამ არ
გადაიწერება. ვაპროვოცირებთ ახალი ნოუდის შექმნას დატვირთვით, რომელიც ძველზე არ ეხერხება:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scale
  namespace: eks-103
spec:
  replicas: 6
  selector:
    matchLabels:
      app: scale
  template:
    metadata:
      labels:
        app: scale
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "1"
            memory: "128Mi"
EOF

kubectl rollout status deployment/scale -n eks-103
```

ვადგენთ ახალ ნოუდს და ვადარებთ ლიმიტებს:

```bash
NEW_NODE=$(kubectl get po -n eks-103 -l app=scale -o jsonpath='{.items[*].spec.nodeName}' \
  | tr ' ' '\n' | grep -v "^${OLD_NODE}$" | head -n1)
NEW_TYPE=$(kubectl get node "$NEW_NODE" \
  -o jsonpath='{.metadata.labels.node\.kubernetes\.io/instance-type}')
NEW_PODS=$(kubectl get node "$NEW_NODE" -o jsonpath='{.status.allocatable.pods}')
echo "new_node=$NEW_NODE new_node_instance_type=$NEW_TYPE new_node_allocatable_pods=$NEW_PODS"
```

მაგალითი `m5.large`-სთვის პრეფიქსების რეჟიმში: ლიმიტი ხტება `29`-იდან `434`-მდე
(managed node group-ის cap `110`-ის ფარგლებში, ესე იგი ფაქტობრივი ჭერი `110`-ია,
მაგრამ ეს ისევ საგრძნობლად მეტია, ვიდრე მისამართობრივი რეჟიმის `29`).

ვინახავთ შედარებას და განმარტებას არტეფაქტში:

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/prefixdelegation.txt <<EOF
old_node=$OLD_NODE
old_node_allocatable_pods=$OLD_PODS
new_node=$NEW_NODE
new_node_instance_type=$NEW_TYPE
new_node_allocatable_pods=$NEW_PODS

old_node_allocatable_pods არ შეცვლილა, რადგან kubelet ითვლის max-pods-ს ერთხელ,
ნოუდის სტარტისას, და prefix delegation ეხება მხოლოდ ახალ ნოუდებს, არა უკვე
გაშვებულებს. new_node შექმნილია prefix delegation-ის ჩართვის შემდეგ, ამიტომ მისი ENI
იკავებს პრეფიქსებს /28 (თითო 16 მისამართით), ცალკეული IP-ების ნაცვლად, და პოდების
ლიმიტი საგრძნობლად მაღალია.
EOF
cat /var/work/tests/artifacts/2/prefixdelegation.txt
```

## დავალება 3. ქვექსელის ზომის დაგეგმვა ზრდისთვის

ვთვლით საბოლოო საჭიროებას: `850` პოდი, მარგინი `20%` warm pool-ისთვის, შემდეგ კიდევ
`15%` rolling update-ისთვის (მარგინები ერთმანეთზე მიმდევრობით მრავლდება):

```bash
python3 - <<'EOF'
base = 850
after_warm = base * 1.20
after_roll = after_warm * 1.15
print(f"base={base} after_warm_pool={after_warm:.0f} after_rolling_update={after_roll:.0f}")
EOF
```

შედეგი: `850 * 1.20 = 1020`, `1020 * 1.15 = 1173` - საბოლოო საჭიროება დაახლოებით
`1173` მისამართია. ვადარებთ ხელმისაწვდომი მისამართების ცხრილს ქვექსელის პრეფიქსის
მიხედვით (AWS რეზერვირებს `5` მისამართს ქვექსელზე):

- `/24` - სულ `256`, ხელმისაწვდომი `251` - ნაკლები `1173`-ზე, არ ეხერხება;
- `/22` - სულ `1024`, ხელმისაწვდომი `1019` - ასევე ნაკლები `1173`-ზე, არ ეხერხება;
- `/20` - სულ `4096`, ხელმისაწვდომი `4091` - საკმარისია დიდი მარგინით.

`4091 / 1173 ≈ 3.5` ჯერ მარგინი, რაც ფარავს მიმდინარე გამოთვლასაც და მომავალ ზრდასაც,
ამიტომ ვირჩევთ `/20`-ს.

```bash
mkdir -p /var/work/tests/artifacts/3
cat > /var/work/tests/artifacts/3/cidrplan.txt <<'EOF'
საჭიროება: 850 პოდი * 1.20 (მარგინი warm pool-ისთვის) * 1.15 (მარგინი rolling
update-ისთვის) = 1173 მისამართი (მისამართების საბოლოო საჭიროება).

/24 (სულ 256, ხელმისაწვდომი 251) - არ ეხერხება, ხელმისაწვდომი ნაკლებია საჭიროებაზე.
/22 (სულ 1024, ხელმისაწვდომი 1019) - არ ეხერხება, ხელმისაწვდომი ნაკლებია საჭიროებაზე (1173).
/20 (სულ 4096, ხელმისაწვდომი 4091) - ეხერხება: 4091 / 1173 ~= 3.5 ჯერ მარგინი.

არჩევანი: /20. Karpenter-ის warm pool და პარალელური rolling update ხანმოკლედ იკავებენ
დამატებით მისამართებს, ამიტომ ქვექსელი უნდა იყოს საგრძნობლად მეტი, ვიდრე წვეროვანი
პიკი, არა 1173 მისამართის ზღვარზე.
EOF
cat /var/work/tests/artifacts/3/cidrplan.txt
```

## დავალება 4. Secondary CIDR: ვაფართოებთ VPC-ის მისამართების გეგმას

ვგებულობთ კლასტერის `vpc-id`-ს და ვაერთებთ secondary CIDR-ს RFC 6598 shared address
space-იდან (`100.64.0.0/16` არ ეხმაურება ამ VPC-ის პირველად CIDR-ს `10.10.0.0/16`):

```bash
VPC=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)

aws ec2 associate-vpc-cidr-block --vpc-id "$VPC" --cidr-block 100.64.0.0/16
```

ველოდებით სტატუსს `associated` (გამოძახებისთანავე ბლოკი შესაძლოა იყოს `associating`):

```bash
until aws ec2 describe-vpcs --vpc-ids "$VPC" \
    --query "Vpcs[].CidrBlockAssociationSet[?CidrBlock=='100.64.0.0/16'].CidrBlockState.State" \
    --output text | grep -q associated; do
  echo "waiting for secondary CIDR to become associated..."
  sleep 5
done

aws ec2 describe-vpcs --vpc-ids "$VPC" \
  --query 'Vpcs[].CidrBlockAssociationSet[].{CIDR:CidrBlock,State:CidrBlockState.State}'
```

ვქმნით ქვექსელს ახალ ბლოკში:

```bash
SUBNET=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 100.64.1.0/24 \
  --availability-zone eu-central-1a --query 'Subnet.SubnetId' --output text)
echo "subnet=$SUBNET"
```

ვინახავთ შედეგს არტეფაქტში:

```bash
mkdir -p /var/work/tests/artifacts/4
{
  echo "secondary_cidr=100.64.0.0/16"
  aws ec2 describe-vpcs --vpc-ids "$VPC" \
    --query 'Vpcs[].CidrBlockAssociationSet[].{CIDR:CidrBlock,State:CidrBlockState.State}' \
    --output table
  echo "subnet_id=$SUBNET"
} > /var/work/tests/artifacts/4/secondary_cidr.txt
cat /var/work/tests/artifacts/4/secondary_cidr.txt
```

თუ `100.64.0.0/16`-ის ნაცვლად გვეცადა `172.16.0.0/12` ან `192.168.0.0/16` - AWS არ
დაგვირთავდა მათ დამატებას VPC-ზე, რომლის პირველადი CIDR უკვე დიაპაზონშია
`10.0.0.0/8` (RFC 1918 პრივატული დიაპაზონების გადაფარვა), ამიტომ ჩვეულებრივ იღებენ
ზუსტად RFC 6598-ს.

## დავალება 5. მისამართების უკმარისობის დიაგნოსტიკა (რეალური გაუმართაობის გარეშე)

ლაბის ინფრასტრუქტურას არ ვეხებით: ქვექსელებს არ ვამცირებთ და მისამართებს ხელოვნურად არ
ვამოწურავთ. ვხედავთ კლასტერის ქვექსელების მიმდინარე მდგომარეობას - ეს ზუსტად იმ
ბრძანებებია, რომლებითაც დიაგნოსტირდება მისამართების უკმარისობა ცოცხალ კლასტერზე:

```bash
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,AvailableIpAddressCount]' \
  --output table
```

ვინახავთ მისამართების უკმარისობის დიაგნოსტიკის განმარტებას არტეფაქტში:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/diagnostics.txt <<'EOF'
როგორ დაიდიაგნოსტიკება IP-მისამართების უკმარისობა ცოცხალ კლასტერზე:

1. სიმპტომი პოდზე: kubectl describe pod Events-ში აჩვენებს ივენთს
   FailedCreatePodSandBox aws-cni-დან - ეს არის პირველი სიგნალი იმისა, რომ VPC CNI-მ
   ვერ გამოყო მისამართი.

2. მისამართების ზოგადი უკმარისობა ქვექსელში: aws ec2 describe-subnets --query
   'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,AvailableIpAddressCount]' - თუ
   ამ AZ-ის AvailableIpAddressCount ტოლია 0-ის, ეს არის ამ ქვექსელსა და AZ-ში
   მისამართების ამოწურვის პირდაპირი დიაგნოზი.

3. ფრაგმენტაცია, ნამდვილი უკმარისობის ნაცვლად: თუ prefix delegation ჩართულია, მაგრამ
   ქვექსელში არ არსებობს უწყვეტი /28 ბლოკი (მისამართები დაქუცმაცებულია ცალკეული
   დაკავებული IP-ებით), ipamd/aws-node-ის ლოგებში იქნება შეცდომა
   InsufficientCidrBlocks, მაშინაც, როცა ქვექსელის AvailableIpAddressCount დიდი
   ჩანს. ეს ერთი და იმავე გარეგანი სიმპტომის (პოდი ვერ იღებს მისამართს) სხვადასხვა
   მიზეზია, და ისინი სხვადასხვანაირად იჭერება: მისამართების უკმარისობა CIDR-ის ან
   secondary CIDR-ის გაფართოებით (დავალება 4), ფრაგმენტაცია - ადგილის გათავისუფლებით
   უწყვეტი ბლოკისთვის ან ახალი ქვექსელით.
EOF
cat /var/work/tests/artifacts/5/diagnostics.txt
```

## სწრაფი შემოწმება

```bash
check_result
```
