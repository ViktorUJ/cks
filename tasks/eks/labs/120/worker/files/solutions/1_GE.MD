[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 120 - ეტალონური გადაწყვეტა (ქსელური სახსრები, unhealthy targets load balancer-ში)

ყველა ბრძანება მუშავდება worker მანქანაზე SSH-ით. kubectl უკვე კონფიგურირებულია
კლასტერზე. Terraform-მა უკვე შექმნა "დამტვრეული" security group (კომპონენტი
`eks_network_break_demo`) და IRSA role AWS Load Balancer Controller-ისთვის
(`eks_lbc_irsa`) - სახელები და id-ები ჩაწერილია `~/lab120_hints.txt`-ში.

```bash
cat ~/lab120_hints.txt
export SG_ID=$(grep '^broken_sg_id' ~/lab120_hints.txt | awk '{print $3}')
export NODE_SG=$(grep '^node_sg_id' ~/lab120_hints.txt | awk '{print $3}')
export CLUSTER=$(grep '^cluster_name' ~/lab120_hints.txt | awk '{print $3}')
```

## დავალება 1. Namespace და ლაბის დატვირთვა

```bash
kubectl create namespace eks-120

kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=2 -n eks-120
kubectl rollout status deployment/api -n eks-120

kubectl expose deployment api -n eks-120 --port=80 --target-port=8080 --name=api

kubectl create deployment client --image=busybox:1.36 -n eks-120 -- sleep 3600
kubectl rollout status deployment/client -n eks-120
```

## დავალება 2. ბაზისური connectivity და SG-ის დიაგნოსტიკა

```bash
CLIENT_POD=$(kubectl get pod -n eks-120 -l app=client -o jsonpath='{.items[0].metadata.name}')

mkdir -p /var/work/tests/artifacts/2
kubectl exec -n eks-120 "$CLIENT_POD" -- \
  wget -qO- --timeout=5 http://api.eks-120.svc.cluster.local \
  > /var/work/tests/artifacts/2/connectivity.txt
cat /var/work/tests/artifacts/2/connectivity.txt
```

Connectivity აქ ჩვეულებრივად მუშაობს: node SG უშვებს ტრაფიკს კლასტერის pod-ებს
შორის, ხოლო SG-ები stateful-ია, ამიტომ ამ მოთხოვნის პასუხი თავად გადის (თავი 46.3).
ვხედავთ, რომელი SG-ები რეალურად ჰკიდია `api` pod-ის ENI-ზე:

```bash
API_IP=$(kubectl get pod -n eks-120 -l app=api -o jsonpath='{.items[0].status.podIP}')

მნიშვნელოვანია, რა ფილტრით ვეძებოთ ENI. VPC CNI-ის შემთხვევაში pod-ის IP არის
**მეორადი** მისამართი node-ის ENI-ზე, ამიტომ ფილტრი `private-ip-address` (რომელიც
ინტერფეისის ძირად მისამართს ამოწმებს) დააბრუნებს `null`-ს. საჭიროა
`addresses.private-ip-address`, რომელიც ინტერფეისის ყველა მისამართზე ეძებს:

```bash
aws ec2 describe-network-interfaces \
  --filters "Name=addresses.private-ip-address,Values=${API_IP}" \
  --query 'NetworkInterfaces[0].Groups' \
  > /var/work/tests/artifacts/2/api_sg.txt
cat /var/work/tests/artifacts/2/api_sg.txt
```

## დავალება 3. AWS Load Balancer Controller-ის დაყენება

```bash
LBC_ROLE_ARN=$(aws iam get-role --role-name "${CLUSTER}-lbc-irsa" \
  --query 'Role.Arn' --output text)

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${LBC_ROLE_ARN}
EOF

helm repo add eks https://aws.github.io/eks-charts
helm repo update

ამ სტენდის მნიშვნელოვანი დეტალი: namespace `kube-system` მოხვდება Fargate profile-ის
ქვეშ, ამიტომ კონტროლერის pod-ები Fargate-ზე მუშაობს, ხოლო მას **არ აქვს IMDS**. IMDS-ის
გარეშე კონტროლერს არ შეუძლია თავად განსაზღვროს რეგიონი და VPC და ჩავარდება
`failed to get VPC ID: ... ec2imds ... context deadline exceeded`-ით. ამიტომ `region`
და `vpcId` მიეთითება ცალსახად:

```bash
REGION=eu-central-1
VPC_ID=$(aws eks describe-cluster --name "${CLUSTER}" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${REGION}" \
  --set vpcId="${VPC_ID}"

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
```

## დავალება 4. სიმპტომი: NLB unhealthy targets-ით

ვანიჭებთ "დამტვრეულ" SG-ს balancer-ის საკუთარ security group-ის როლს. როგორც კი SG
ცალსახად მითითებულია ანოტაციით, LBC წყვეტს დაგვამატოს node SG-ში ის ინბაუნდ წესი,
რომელიც არ ჰყოფნის - ეს ზუსტად ეს სახსარია (თავი 46.6):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: api-lb
  namespace: eks-120
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    service.beta.kubernetes.io/aws-load-balancer-security-groups: ${SG_ID}
spec:
  type: LoadBalancer
  selector:
    app: api
  ports:
    - port: 80
      targetPort: 8080
EOF

kubectl get svc api-lb -n eks-120 -w
```

ველოდებით გარეთა მისამართს, ვპოულობთ target group-ს და ვამოწმებთ targets-ების
ჯანმრთელობას:

```bash
HOSTNAME=$(kubectl get svc api-lb -n eks-120 \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
LB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='${HOSTNAME}'].LoadBalancerArn" --output text)
TG_ARN=$(aws elbv2 describe-target-groups --load-balancer-arn "$LB_ARN" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

mkdir -p /var/work/tests/artifacts/4
aws elbv2 describe-target-health --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table > /var/work/tests/artifacts/4/unhealthy.txt
cat /var/work/tests/artifacts/4/unhealthy.txt
```

ყველა target `unhealthy`-ია - balancer-ის SG არ უშვებს health check-ს node SG-ისკენ,
ამიტომ ის `api` pod-საც არასდროს მიაღწევს.

## დავალება 5. დიაგნოსტიკა: ვისი SG ბლოკავს health check-ს

```bash
aws ec2 describe-security-groups --group-ids "$SG_ID" \
  --query 'SecurityGroups[0].IpPermissions'
```

ცარიელი სია ადასტურებს: balancer-ის SG-ს არ აქვს ერთი ინბაუნდ წესიც.

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/diagnosis.txt <<EOF
Balancer-ის security group (${SG_ID}) მინიჭებულია api-lb-ზე ანოტაციით
aws-load-balancer-security-groups და არ შეიცავს ინბაუნდ წესებს. Health check
NLB-იდან მოდის, როგორც ახალი TCP-კავშირი balancer-ის security group-იდან node
security group-ისკენ (${NODE_SG}) აპლიკაციის პორტ 8080-ზე. Node security group
არ უშვებს ინბაუნდ ტრაფიკს balancer-ის security group-იდან ამ პორტზე, ამიტომ
health check არ გადის და targets რჩება unhealthy (თავი 46.6).
EOF
cat /var/work/tests/artifacts/5/diagnosis.txt
```

## დავალება 6. ჩასწორება: authorize-security-group-ingress, targets healthy

ორი წესი: ვხსნით health check-ს და აპლიკაციის ტრაფიკს balancer-ის SG-დან node
SG-ისკენ, და ვხსნით NLB-ის listener-ს კლიენტებისთვის პორტ 80-ზე:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id "$NODE_SG" \
  --protocol tcp --port 8080 \
  --source-group "$SG_ID"

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 80 \
  --cidr 0.0.0.0/0
```

ველოდებით, სანამ targets გახდება `healthy` (ჩვეულებრივ 1-2 წუთი), და ვამოწმებთ
curl-ით:

```bash
sleep 90

mkdir -p /var/work/tests/artifacts/6
{
  aws elbv2 describe-target-health --target-group-arn "$TG_ARN" \
    --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State]' --output table
  echo
  curl -s --max-time 5 "http://${HOSTNAME}"
} > /var/work/tests/artifacts/6/healthy.txt
cat /var/work/tests/artifacts/6/healthy.txt
```

## დავალება 7. DNS მუშაობს: საკონტრასტო შემოწმება

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl run dnstest --image=busybox:1.36 --rm -i --restart=Never -- \
  sh -c 'nslookup kubernetes.default.svc.cluster.local; nslookup example.com' \
  > /var/work/tests/artifacts/7/dns.txt
cat /var/work/tests/artifacts/7/dns.txt
```

შინაგან სახელს ვკითხულობთ მისი სრული FQDN-ით. მოკლე `kubernetes.default`
`nslookup`-ის მეშვეობით busybox-იდან აბრუნებს `NXDOMAIN`-ს: ეს resolver არ ამატებს
ძებნის დომენებს `/etc/resolv.conf`-იდან, ისე როგორც ჩვეულებრივი კლიენტი, და ამ
პასუხს ადვილად ავურევდით DNS-ის იმ სახსარში, რომელიც არ არსებობს.

ორივე სახელი ჩვეულებრივად რეზოლვდება (`kubernetes.default.svc.cluster.local`
`kubernetes` service-ის მისამართზე, `example.com` გარეთა მისამართებზე) - DNS ამ
ლაბაში სახსრის წყარო არ არის (თავები 46.5, 46.7), განსხვავებით security group-ისგან
დავალებებიდან 4-6.

## დავალება 8. საბოლოო ჩეკლისტი: სიმპტომი - სავარაუდო მიზეზი - რის შემოწმებაა საჭირო

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/summary.txt <<EOF
სიმპტომი: NLB target group-ის targets არის unhealthy, api-lb service აბრუნებს 503-ს.
სავარაუდო მიზეზი: balancer-ის security group არ უშვებს ინბაუნდ ტრაფიკს node SG-ისკენ
health check-ის პორტზე (თავი 46.6).
რის შემოწმებაა საჭირო: aws elbv2 describe-target-health --target-group-arn <arn> გვიჩვენებს
TargetHealth.Reason=Target.FailedHealthChecks-ს, ხოლო aws ec2
describe-security-groups დაადასტურებს, რომ balancer-ის SG-ს ინბაუნდ წესი არ აქვს.
EOF
cat /var/work/tests/artifacts/8/summary.txt
```

## სწრაფი შემოწმება

```bash
check_result
```
