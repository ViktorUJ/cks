[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 117 - ეტალონური გადაწყვეტა (NAT თითო AZ-ზე ერთი NAT-ის წინააღმდეგ, VPC endpoints, cross-AZ)

ყველა ბრძანება სრულდება worker მანქანაზე SSH-ით. kubectl უკვე კონფიგურირებულია
კლასტერზე (kubeconfig შედგენილია `aws eks update-kubeconfig`-ით მანქანის ჩატვირთვისას).

```bash
export CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
export VPC=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)
kubectl create namespace eks-117
```

## დავალება 1. რამდენი NAT Gateway და რომელ ზონებში

ლაბის ქსელი აწყობილია ისე, რომ NAT Gateway არსებობს მხოლოდ სამი პრივატული AZ-იდან
ორში. ვიპოვოთ ამ VPC-ის ყველა NAT Gateway:

```bash
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" \
  --query 'NatGateways[].[NatGatewayId,SubnetId,State]' --output table
```

თითოეული NAT-ისთვის დავადგინოთ მისი subnet-ის AZ:

```bash
NAT1=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" \
  --query 'NatGateways[0].NatGatewayId' --output text)
NAT1_SUBNET=$(aws ec2 describe-nat-gateways --nat-gateway-ids "$NAT1" \
  --query 'NatGateways[0].SubnetId' --output text)
NAT1_AZ=$(aws ec2 describe-subnets --subnet-ids "$NAT1_SUBNET" \
  --query 'Subnets[0].AvailabilityZone' --output text)

NAT2=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" \
  --query 'NatGateways[1].NatGatewayId' --output text)
NAT2_SUBNET=$(aws ec2 describe-nat-gateways --nat-gateway-ids "$NAT2" \
  --query 'NatGateways[0].SubnetId' --output text)
NAT2_AZ=$(aws ec2 describe-subnets --subnet-ids "$NAT2_SUBNET" \
  --query 'Subnets[0].AvailabilityZone' --output text)

echo "nat1=$NAT1 az=$NAT1_AZ / nat2=$NAT2 az=$NAT2_AZ"
```

ორივე AZ, სადაც NAT არსებობს, არის `eu-central-1a` და `eu-central-1b`. პრივატული
subnet `eu-central-1c`-ში არსებობს (ატარებს ტეგს `karpenter.sh/discovery`, ამიტომ
Karpenter-ს შეუძლია მასში node-ების დაყენება), მაგრამ იმ ზონაში NAT Gateway არ არის:

```bash
mkdir -p /var/work/tests/artifacts/1
cat > /var/work/tests/artifacts/1/natdiscovery.txt <<EOF
nat_count=2
nat_1_id=$NAT1
nat_1_az=$NAT1_AZ
nat_2_id=$NAT2
nat_2_az=$NAT2_AZ
no_nat_az=eu-central-1c
EOF
cat /var/work/tests/artifacts/1/natdiscovery.txt
```

## დავალება 2. cross-AZ ხაფანგის გამეორება

ვიპოვოთ subnet `private-subnet-3`-ის route table (ის არის `eu-central-1c`-ში,
NAT-ის გარეშე):

```bash
RTB_C=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=private-subnet-3" \
  --query 'RouteTables[0].RouteTableId' --output text)
echo "route table AZ 1c = $RTB_C"
```

ვმიმართოთ ამ route table-ის `0.0.0.0/0` route ერთ-ერთი მეზობელი AZ-ის NAT Gateway-ზე -
ვირჩევთ `NAT1`-ს (`eu-central-1a`-ში), და ეს ზუსტად ის ნაბიჯია, რომელიც ქმნის
cross-AZ გზას:

```bash
aws ec2 create-route --route-table-id "$RTB_C" \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT1"

aws ec2 describe-route-tables --route-table-ids "$RTB_C" \
  --query 'RouteTables[0].Routes'
```

შევქმნათ დატვირთვა, რომელიც პირდაპირ ითხოვს ზონას `eu-central-1c`, რომ Karpenter-მა
იქ ააგოს node. Image არის `curlimages/curl:latest` დაძინებული `command`-ით: ამ
pod-იდან მოგვიანებით შევამოწმებთ egress-ს `kubectl exec`-ით, ამიტომ კონტეინერს
სჭირდება shell და `curl`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crossaz
  namespace: eks-117
spec:
  replicas: 1
  selector:
    matchLabels:
      app: crossaz
  template:
    metadata:
      labels:
        app: crossaz
    spec:
      nodeSelector:
        topology.kubernetes.io/zone: eu-central-1c
      containers:
      - name: app
        image: curlimages/curl:latest
        command: ["sleep", "3600"]
EOF

kubectl rollout status deployment/crossaz -n eks-117
```

შევამოწმოთ node და მისი ზონა, შემდეგ egress pod-ის შიგნიდან:

```bash
POD=$(kubectl get po -n eks-117 -l app=crossaz -o jsonpath='{.items[0].metadata.name}')
NODE=$(kubectl get po -n eks-117 -l app=crossaz -o jsonpath='{.items[0].spec.nodeName}')
NODE_ZONE=$(kubectl get node "$NODE" \
  -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
echo "node=$NODE zone=$NODE_ZONE"

HTTP_CODE=$(kubectl exec -n eks-117 "$POD" -- \
  curl -s -o /dev/null -w '%{http_code}' https://checkip.amazonaws.com)
echo "egress_http_code=$HTTP_CODE"
```

Egress მუშაობს (`200`), მაგრამ ეს ზუსტად თავი 31-ის ხაფანგია: pod ცხოვრობს
`eu-central-1c`-ში, ხოლო მისი პაკეტები თავიდან გადალახავენ AZ-ის საზღვარს NAT-ისკენ
`eu-central-1a`-ში, და მხოლოდ შემდეგ გადიან გარეთ. ეს გადასვლა ცალკე ტარიფირდება
როგორც cross-AZ ტრაფიკი, NAT-ის თავადვე დამუშავების საფასურის გარდა - ეს ნიშნავს,
რომ ერთი და იმავე ბაიტისთვის ორმაგად იხდით. სწორი პატერნია NAT Gateway ყველა AZ-ში,
სადაც node-ები არსებობს (როგორც ამ ლაბაში `eu-central-1a`-სთვის და
`eu-central-1b`-სთვის უკვე გაკეთებულია), რომ node-ის ტრაფიკი საკუთარ ზონას არასდროს
დაუტოვოს NAT-ს მიღწევამდე.

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/crossaz.txt <<EOF
subnet_c_route_table_id=$RTB_C
nat_gateway_id_used=$NAT1
nat_gateway_az_used=$NAT1_AZ
pod_node=$NODE
pod_node_zone=$NODE_ZONE
egress_http_code=$HTTP_CODE

eu-central-1c subnet-ის 0.0.0.0/0 route მიმართავს NAT Gateway-ს სხვა ზონაში
($NAT1_AZ), ამიტომ eu-central-1c-ში node-იდან ყველა გამავალი ტრაფიკი cross-AZ
გზას გადის: თავიდან AZ-შორისი გადასვლა NAT-ისკენ, შემდეგ დამუშავება თავად
NAT-ზე. ეს ორმაგად ტარიფირდება - ერთხელ AZ-შორისი (cross-AZ) ტრაფიკისთვის და
ერთხელ NAT-ის მიერ დამუშავებული გიგაბაიტებისთვის. სწორი პატერნია NAT Gateway
ყველა AZ-ში, სადაც node-ები არსებობს, რომ ტრაფიკმა ზონის საზღვარი საერთოდ არ
გადაკვეთოს.
EOF
cat /var/work/tests/artifacts/2/crossaz.txt
```

## დავალება 3. Gateway VPC endpoint S3-სთვის - უფასო route

ვიპოვოთ სამივე პრივატული subnet-ის route tables:

```bash
RTB_A=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=private-subnet-1" \
  --query 'RouteTables[0].RouteTableId' --output text)
RTB_B=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=private-subnet-2" \
  --query 'RouteTables[0].RouteTableId' --output text)
echo "rtb_a=$RTB_A rtb_b=$RTB_B rtb_c=$RTB_C"
```

შევქმნათ gateway endpoint S3-სთვის და პირდაპირ მივაბათ ის სამივე route table-ს:

```bash
S3_EP=$(aws ec2 create-vpc-endpoint --vpc-id "$VPC" \
  --vpc-endpoint-type Gateway --service-name com.amazonaws.eu-central-1.s3 \
  --route-table-ids "$RTB_A" "$RTB_B" "$RTB_C" \
  --query 'VpcEndpoint.VpcEndpointId' --output text)

until aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$S3_EP" \
    --query 'VpcEndpoints[0].State' --output text | grep -q available; do
  echo "waiting for the S3 endpoint to become available..."
  sleep 5
done

aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$S3_EP" \
  --query 'VpcEndpoints[0].{State:State,RouteTableIds:RouteTableIds}'
```

S3-ის gateway endpoint არ ქმნის ENI-ს და არ ტარიფირდება არც საათობრივად, არც
დამუშავებული გიგაბაიტებისთვის - ეს არის უბრალოდ ჩანაწერი route table-ში, რაც მას
ხდის ოპტიმიზაციის პირველ და ყველაზე ეფექტურ ნაბიჯად:

```bash
mkdir -p /var/work/tests/artifacts/3
cat > /var/work/tests/artifacts/3/s3endpoint.txt <<EOF
vpc_endpoint_id=$S3_EP
state=available
route_tables=$RTB_A,$RTB_B,$RTB_C

S3-ის gateway endpoint არის მხოლოდ ჩანაწერი route table-ში და ის უფასოა (free of charge):
არ არსებობს არც საათობრივი გადასახადი, არც გადასახადი დამუშავებული მონაცემისთვის,
interface endpoint-ისგან განსხვავებით.
EOF
cat /var/work/tests/artifacts/3/s3endpoint.txt
```

## დავალება 4. Interface VPC endpoint მაღალტრაფიკიანი სერვისისთვის

ვირჩევთ `sts`-ს - ყოველი pod, რომელიც იყენებს IRSA-ს ან EKS Pod Identity-ს, ცვლის
თავის token-ს დროებით credentials-ზე STS-ის მეშვეობით ყოველ სტარტზე და ყოველ
credentials refresh-ზე, და endpoint-ის გარეშე ეს გაცვლა NAT-ის მეშვეობით მიდის
ყოველ ასეთ მოთხოვნაზე. (ალტერნატივა არის `ecr.api`: image registry-ის ავტორიზაცია
ყოველ pull-ზე; ორივეს არჩევანი მიღებულია ტესტის მიერ.)

ავიღოთ default security group და პირდაპირ დავუშვათ მასში შემავალი HTTPS VPC-ის
CIDR-იდან. ამ წესის გარეშე endpoint შექმნილი იქნებოდა, მაგრამ მიუწვდომელი: default
security group-ის შემავალი წესი უშვებს ტრაფიკს მხოლოდ იმავე group-ის წევრებისგან,
ხოლო Karpenter-ის node-ები და pod-ები სხვა group-ებში ცხოვრობენ.

```bash
SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC" \
  "Name=group-name,Values=default" --query 'SecurityGroups[0].GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id "$SG" \
  --protocol tcp --port 443 --cidr 10.10.0.0/16

STS_EP=$(aws ec2 create-vpc-endpoint --vpc-id "$VPC" \
  --vpc-endpoint-type Interface --service-name com.amazonaws.eu-central-1.sts \
  --subnet-ids "$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=private-subnet-1" \
    --query 'Subnets[0].SubnetId' --output text)" \
    "$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=private-subnet-2" \
    --query 'Subnets[0].SubnetId' --output text)" \
  --security-group-ids "$SG" --private-dns-enabled \
  --query 'VpcEndpoint.VpcEndpointId' --output text)

until aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$STS_EP" \
    --query 'VpcEndpoints[0].State' --output text | grep -q available; do
  echo "waiting for the sts endpoint to become available..."
  sleep 5
done

aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$STS_EP" \
  --query 'VpcEndpoints[0].{State:State,PrivateDnsEnabled:PrivateDnsEnabled}'
```

შევამოწმოთ, რომ endpoint ფაქტობრივად პასუხობს კლასტერის შიგნიდან -
`private_dns_enabled=true` ნიშნავს, რომ სახელი `sts.eu-central-1.amazonaws.com`
ახლა რეზოლვირდება endpoint-ის ENI-ის პრივატულ მისამართებზე მთელ VPC-ში, და თუ
`443` წესი არ დამატებულიყო, STS ერთდროულად ყველა pod-ისთვის შეწყვეტდა მუშაობას:

```bash
kubectl exec -n eks-117 "$POD" -- nslookup sts.eu-central-1.amazonaws.com
kubectl exec -n eks-117 "$POD" -- \
  curl -s -o /dev/null -w '%{http_code}\n' --connect-timeout 8 \
  https://sts.eu-central-1.amazonaws.com
```

სახელი რეზოლვირდება `10.10.15.0/24`-ისა და `10.10.16.0/24`-ის მისამართებზე (ეს
არის endpoint-ის ENI-ები), და `curl` აბრუნებს კოდს `302` - PrivateLink-ის
მეშვეობით ნამდვილ STS-ის პასუხს. კოდი `000` და timeout ნაშუშავებდა, რომ
endpoint-ის security group არ უშვებდა ტრაფიკს pod-ებიდან.

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/interfaceendpoint.txt <<EOF
service_chosen=sts
vpc_endpoint_id=$STS_EP
state=available
private_dns_enabled=true

ავირჩიეთ sts: IRSA და EKS Pod Identity ცვლიან token-ს დროებით key-ებზე STS-ის
მეშვეობით ყოველ pod-ის სტარტზე და ყოველ credentials refresh-ზე, ეს ხშირი
მოთხოვნაა, და endpoint-ის გარეშე ის NAT-ის მეშვეობით მიდის. Interface endpoint
ხსნის ამ ტრაფიკს NAT-იდან, საათობრივი გადასახადის ფასად თითო ENI-ზე თითო AZ-ში
პლუს გადასახადი დამუშავებული გიგაბაიტებისთვის.
EOF
cat /var/work/tests/artifacts/4/interfaceendpoint.txt
```

## დავალება 5. NAT-ის მეტრიკები: რამდენი ბაიტი გავიდა თითო gateway-ზე

ავიღოთ `BytesOutToDestination`-ის ჯამი ბოლო რამდენიმე საათისთვის თითოეული NAT-ისთვის
(namespace `AWS/NATGateway`):

```bash
START=$(date -u -d '3 hours ago' +%Y-%m-%dT%H:%M:%S)
END=$(date -u +%Y-%m-%dT%H:%M:%S)

NAT_A_SUM=$(aws cloudwatch get-metric-statistics --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination --statistics Sum --period 3600 \
  --dimensions Name=NatGatewayId,Value="$NAT1" \
  --start-time "$START" --end-time "$END" \
  --query 'sum(Datapoints[].Sum)' --output text)
[[ "$NAT_A_SUM" == "None" ]] && NAT_A_SUM=0

NAT_B_SUM=$(aws cloudwatch get-metric-statistics --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination --statistics Sum --period 3600 \
  --dimensions Name=NatGatewayId,Value="$NAT2" \
  --start-time "$START" --end-time "$END" \
  --query 'sum(Datapoints[].Sum)' --output text)
[[ "$NAT_B_SUM" == "None" ]] && NAT_B_SUM=0

TOTAL=$(python3 -c "print(int(${NAT_A_SUM%.*}) + int(${NAT_B_SUM%.*}))")
echo "nat_a=$NAT1 sum=$NAT_A_SUM / nat_b=$NAT2 sum=$NAT_B_SUM / total=$TOTAL"
```

`NAT1` არის ის ზუსტად ის NAT Gateway, რომელზეც დავალება 2-მა მიმართა
`eu-central-1c` subnet-ის route. მან აიტანა როგორც საკუთარი ზონის
`eu-central-1a` ჩვეულებრივი ტრაფიკი, ისევე `crossaz` node-ის cross-AZ ტრაფიკი,
ამიტომ მოსალოდნელია, რომ იმავე პერიოდში `BytesOutToDestination`-ის მოცულობა
მასზე უფრო დიდი იყოს, ვიდრე `NAT2`-ზე, რომელიც მხოლოდ საკუთარ AZ-ს ემსახურება:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/natmetrics.txt <<EOF
nat_a_id=$NAT1
nat_a_bytes_out_sum=${NAT_A_SUM%.*}
nat_b_id=$NAT2
nat_b_bytes_out_sum=${NAT_B_SUM%.*}
total_bytes_out_sum=$TOTAL

მეტრიკა: AWS/NATGateway BytesOutToDestination, data points-ის ჯამი პერიოდში.
NAT $NAT1-მა აიტანა cross-AZ ტრაფიკი crossaz node-იდან eu-central-1c-ში
(დავალება 2), საკუთარი ზონის ჩვეულებრივი ტრაფიკის დამატებით, ამიტომ
მოსალოდნელია, რომ მას ჰქონდეს უფრო დიდი BytesOutToDestination მოცულობა, ვიდრე
$NAT2-ს, რომელიც მხოლოდ საკუთარ AZ-ს ემსახურება.
EOF
cat /var/work/tests/artifacts/5/natmetrics.txt
```

თუ ტესტის დატვირთვამ მოახერხა შესამჩნევი ტრაფიკის გენერირება (მაგალითად,
გამეორებული `curl` მოთხოვნები `crossaz` pod-იდან), ჯამების სხვაობა უკვე ჩანს
პირველ მეტრიკის ფანჯარაში; თუ დატვირთვა ერთჯერადი იყო, სხვაობა შესაძლოა მცირე
იყოს - მთავარია ფაქტი, რომ NAT, რომელმაც აიტანა cross-AZ node, აჩვენებს
მოცულობას, არანაკლებ მეორესთან შედარებით.

## სწრაფი შემოწმება

```bash
check_result
```
