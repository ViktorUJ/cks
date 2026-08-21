[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 108 - ეტალონური გადაწყვეტა (AWS Load Balancer Controller: NLB Service-ისთვის)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე SSH-ით. kubectl უკვე კონფიგურირებულია
კლასტერზე. Terraform-მა უკვე შექმნა IAM-როლი კონტროლერისთვის (კომპონენტი
`eks_lbc_irsa`, მოდული `eks_v2_lbc_irsa`) - რჩება მისი ARN-ის აღება და კონტროლერის
ინსტალაცია.

## დავალება 1. Namespace `eks-108`

```bash
kubectl create namespace eks-108
```

## დავალება 2. ServiceAccount და AWS Load Balancer Controller-ის ინსტალაცია

ვპოულობთ ROLE-ს ARN-ს, რომელიც terraform-მა შექმნა (როლის სახელი
`<cluster-name>-lbc-irsa`):

```bash
ROLE_ARN=$(aws iam list-roles \
  --query "Roles[?contains(RoleName,'lbc-irsa')].Arn" --output text)
echo "$ROLE_ARN"
```

ვქმნით ServiceAccount-ს `kube-system`-ში ანოტაციით ამ როლზე. LBC ისეთდება Helm-ით
`serviceAccount.create=false`-ით, ამიტომ ServiceAccount საჭირო წინასწარ:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${ROLE_ARN}
EOF
```

ვაყენებთ თავად კონტროლერს ოფიციალური chart-იდან:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' | sed 's/.*\///')
VPC_ID=$(aws eks describe-cluster --name "${CLUSTER_NAME}" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)
echo "$VPC_ID"

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=eu-central-1 \
  --set vpcId="${VPC_ID}"

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
```

კონტროლერი მუშაობს Fargate-ზე (namespace `kube-system` Fargate-პროფილის ქვეშ), ხოლო
Fargate-ზე ფიზიკურად არ არსებობს EC2 instance metadata service (IMDS) - ცალსახა
`vpcId`/`region`-ის გარეშე კონტროლერი ცდილობს VPC ID-ის მიღებას IMDS-ით და ვარდება
`CrashLoopBackOff`-ში შეცდომით `failed to fetch VPC ID from instance metadata: ...
context deadline exceeded`. მართულ EC2-ნოუდებზე ეს ფლაგები საჭირო არაა (IMDS იქ
ხელმისაწვდომია), მაგრამ Fargate-ზე ისინი ყოველთვის ცალსახად უნდა გადავცეთ.

ვამოწმებთ, რომ კონტროლერი აღდგა და ხედავს როლს:

```bash
kubectl get deploy aws-load-balancer-controller -n kube-system
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml | grep role-arn
```

## დავალება 3. Deployment `web` (viktoruj/ping_pong, 2 რეპლიკა)

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=2 -n eks-108
kubectl rollout status deployment/web -n eks-108
```

## დავალება 4. Service `web` ტიპით LoadBalancer: NLB CLB-ის ნაცვლად

ნაგულისხმევად in-tree cloud provider ქმნის მოძველებულ Classic Load Balancer-ს
LoadBalancer ტიპის Service-ისთვის. ანოტაცია `aws-load-balancer-type: external`
გადასცემს რეკონსილაციას AWS Load Balancer Controller-ს, რომელიც ქმნის თანამედროვე
Network Load Balancer-ს:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: eks-108
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 8080
EOF
```

ველოდებით გარეთა მისამართს:

```bash
kubectl get svc web -n eks-108 -w
```

AWS CLI-ით ვადასტურებთ, რომ შექმნილია ზუსტად NLB (ტიპი `network`), არა CLB, და რომ
scheme-ია `internet-facing`:

```bash
HOSTNAME=$(kubectl get svc web -n eks-108 \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
LB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='${HOSTNAME}'].LoadBalancerArn" --output text)

mkdir -p /var/work/tests/artifacts/4
aws elbv2 describe-load-balancers --load-balancer-arns "$LB_ARN" \
  > /var/work/tests/artifacts/4/nlb.txt
cat /var/work/tests/artifacts/4/nlb.txt
```

output-ში `Type` უნდა იყოს `network` (NLB), ხოლო `Scheme` - `internet-facing`. თუ
ანოტაცია `aws-load-balancer-type` არ იქნებოდა, in-tree provider შექმნიდა
`Type: classic` - ეს ზუსტად არის სიმპტომი «ვითხოვე LoadBalancer, მივიღე CLB» თავი
26-დან.

## დავალება 5. Target-ების შემოწმება: პოდების IP, არა ნოუდების instance ID

`target-type: ip` target group-ში რეგისტრირებს VPC CNI-ის მიერ გამოცემულ პოდების
მისამართებს, არა ნოუდებს `InstanceId`-ით. ვამოწმებთ ამას `describe-target-groups`-ითა
და `describe-target-health`-ით:

```bash
TG_ARN=$(aws elbv2 describe-target-groups --load-balancer-arn "$LB_ARN" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

mkdir -p /var/work/tests/artifacts/5
{
  aws elbv2 describe-target-groups --target-group-arns "$TG_ARN"
  aws elbv2 describe-target-health --target-group-arn "$TG_ARN"
} > /var/work/tests/artifacts/5/targets.txt

cat /var/work/tests/artifacts/5/targets.txt
```

ფაილში `TargetType` უნდა იყოს `ip`, ხოლო თითოეული target-ის `Target.Id` - მისამართი
`10.10.0.0/16`-დან (ამ ლაბის VPC-ის ქვექსელი), არა `i-...` (instance ID). ზუსტად ასე
გამოიყურება NLB-ის target group `target-type: ip`-ით: კონტროლერი პოდის IP-ს პირდაპირ
რეგისტრირებს, NodePort-ის გავლის გარეშე, რაც აშორებს ზედმეტ hop-ს kube-proxy-ის
გავლით.

## დავალება 6. დიაგნოსტიკა: წარმატებული რეკონსილაცია AccessDenied-ის წინააღმდეგ

ვხედავთ კონტროლერის ლოგში, როგორ გამოიყურება ნორმალური Service-ის რეკონსილაცია - მასში
უნდა შეგვხვდეს შექმნილი load balancer-ის ARN:

```bash
kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=200 \
  | grep -i 'successfully reconciled\|loadBalancerARN\|arn:aws:elasticloadbalancing' \
  | tail -n 10
```

თუ ServiceAccount-ს არ ჰქონდა მიმაგრებული როლი (ან როლს არ ჰქონდა საჭირო
უფლებები), კონტროლერი ვერ შეძლებდა ELBv2 API-ს გამოძახებას და ლოგში გამოჩნდებოდა
შეტყობინება მსგავსი `AccessDenied: User: ... is not authorized to perform:
elasticloadbalancing:CreateLoadBalancer`-ის, ხოლო Service დარჩებოდა `<pending>`-ში
გარეთა მისამართის გარეშე - რადგან რეკონსილაცია ჩავარდება პირველივე API-გამოძახებაზე,
NLB-ის შექმნამდე.

ვინახავთ ორივე დაკვირვებას ერთ არტეფაქტში:

```bash
mkdir -p /var/work/tests/artifacts/6
{
  echo "=== წარმატებული რეკონსილაცია (რეალური კონტროლერის ლოგი) ==="
  kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=200 \
    | grep -i 'successfully reconciled\|arn:aws:elasticloadbalancing'
  echo
  echo "=== მოსალოდნელი სიმპტომი IAM-უფლებების გარეშე (არ არის რეპროდუცირებული აქტიურ როლზე) ==="
  echo "AccessDenied: User: arn:aws:sts::<account>:assumed-role/<cluster>-lbc-irsa/... " \
       "is not authorized to perform: elasticloadbalancing:CreateLoadBalancer " \
       "on resource: arn:aws:elasticloadbalancing:<region>:<account>:loadbalancer/*"
  echo "ამ შეცდომით web Service რჩება <pending>-ში: EXTERNAL-IP არასდროს ჩნდება," \
       "რადგან კონტროლერს არ შეეძლო NLB-ის შექმნა ELBv2 API-ის მეშვეობით."
} > /var/work/tests/artifacts/6/reconcile.txt

cat /var/work/tests/artifacts/6/reconcile.txt
```

## სწრაფი შემოწმება

```bash
check_result
```
