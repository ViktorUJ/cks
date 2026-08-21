[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 128 - ეტალონური გადაწყვეტა (Gateway API AWS-ში: ALB Gateway API და VPC Lattice)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე (worker) SSH-ის მეშვეობით. kubectl უკვე
კონფიგურირებულია კლასტერზე. Terraform-მა უკვე შექმნა IAM-როლები ორივე კონტროლერისთვის
(კომპონენტები `eks_lbc_irsa`, `eks_vpclattice_irsa`) - მათი ARN დევს
`~/lab128_hints.txt`-ში.

```bash
cat ~/lab128_hints.txt
export CLUSTER=$(kubectl config current-context | sed 's|.*/||')
export LBC_ROLE_ARN=$(grep '^lbc_role_arn' ~/lab128_hints.txt | awk '{print $3}')
export LATTICE_ROLE_ARN=$(grep '^vpclattice_role_arn' ~/lab128_hints.txt | awk '{print $3}')
export NODE_SG=$(grep '^node_sg_id' ~/lab128_hints.txt | awk '{print $3}')
export VPC_ID=$(grep '^vpc_id' ~/lab128_hints.txt | awk '{print $3}')
export ACCOUNT_ID=$(grep '^account_id' ~/lab128_hints.txt | awk '{print $3}')
export REGION=eu-central-1
```

## დავალება 1. Gateway API CRD და ლაბის namespace

```bash
kubectl apply --server-side=true \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

kubectl create namespace eks-128
kubectl create namespace eks-128-backend
```

## დავალება 2. AWS Load Balancer Controller და Gateway კლასის ALB (L7)

```bash
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

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${REGION}" \
  --set vpcId="${VPC_ID}"

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
```

`region` და `vpcId` აქ სავალდებულოა, და ეს არ არის კოსმეტიკა. კონტროლერის პოდი
ხვდება `kube-system`-ში, ხოლო ეს namespace დაფარულია Fargate-პროფილით, სადაც IMDS
ზოგადად არ არსებობს. ფლაგების გარეშე კონტროლერი ვარდება `CrashLoopBackOff`-ში
`failed to get VPC ID ... ec2imds: GetMetadata ... context deadline exceeded`-ით
(გადამოწმებულია სტენდზე). ის ივე ხაფანგი ელოდება ყოველ კონტროლერს, რომელსაც
დააყენებთ `kube-system`-ში Fargate-ზე (თავები 15 და 26).

ვქმნით `GatewayClass`-ს ALB-სთვის და თავად `Gateway`-ს:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: aws-alb
spec:
  controllerName: gateway.k8s.aws/alb
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web
  namespace: eks-128
spec:
  gatewayClassName: aws-alb
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

kubectl get gateway web -n eks-128 -o wide
```

`gateway.k8s.aws/alb` - ეს არის ის ივე AWS Load Balancer Controller, რაც ლაბებში
108/109, უბრალოდ შესასვლელი აღწერილია Gateway API-ის რესურსებით Ingress-ის ნაცვლად:
L7-მარშრუტები `HTTPRoute` და `GRPCRoute` გარდაიქმნება ALB-ის listener-ებად და
წესებად (თავი 28, პარაგრაფი 28.4).

## დავალება 3. HTTPRoute ALB-ზე: აპლიკაციური მარშრუტიზაცია

```bash
kubectl create deployment frontend --image=viktoruj/ping_pong:latest \
  --replicas=2 -n eks-128
kubectl rollout status deployment/frontend -n eks-128
kubectl expose deployment frontend -n eks-128 --port=80 --target-port=8080

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app
  namespace: eks-128
spec:
  parentRefs:
    - kind: Gateway
      name: web
      sectionName: http
  rules:
    - backendRefs:
        - name: frontend
          port: 80
EOF
```

ერთი მარშრუტი ცოტაა: კონტროლერს უნდა ვუთხრათ, რა ტიპის სამიზნეები დაარეგისტრიროს.
ტიპი ნაგულისხმევად გამოიყვანება როგორც `instance`, ხოლო `instance`-ს სჭირდება
Service ტიპის `NodePort` ან `LoadBalancer`. `ClusterIP`-ით ბალანსერი დარჩება
დაუპროგრამირებელი: `Gateway` გადადის `Accepted: False`-ში `reason: Invalid`-ით, ხოლო
კონტროლერის ლოგში მეორდება `TargetGroup port is empty. When using Instance targets,
your service must be of type 'NodePort' or 'LoadBalancer'` (რეპროდუცირებულია
სტენდზე). Ingress-ის სამყაროში ამას მკურნალობდა ანოტაცია
`alb.ingress.kubernetes.io/target-type: ip`, Gateway API-ში ანოტაციის ნაცვლად
ცალკე ტიპიზებული ობიექტია, და ის ვალდებულია იდოს საკუთარი Service-ის namespace-ში:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.k8s.aws/v1
kind: TargetGroupConfiguration
metadata:
  name: frontend
  namespace: eks-128
spec:
  targetReference:
    name: frontend
  defaultConfiguration:
    targetType: ip
EOF
```

ვუელოდებით მისამართს და AWS CLI-ის მეშვეობით ვადასტურებთ, რომ ეს ზუსტად ALB არის:

```bash
for i in $(seq 1 30); do
  ADDR=$(kubectl get gateway web -n eks-128 -o jsonpath='{.status.addresses[0].value}')
  [[ -n "$ADDR" ]] && break
  sleep 10
done
echo "gateway address: $ADDR"

LB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='${ADDR}'].LoadBalancerArn" --output text)

mkdir -p /var/work/tests/artifacts/3
aws elbv2 describe-load-balancers --load-balancer-arns "$LB_ARN" \
  > /var/work/tests/artifacts/3/alb.txt
cat /var/work/tests/artifacts/3/alb.txt
```

output-ში `Type` უნდა იყოს `application` - `Gateway` კლასის `aws-alb` ქმნის ALB-ს
ის ივე გზით, როგორც `Ingress` `ingressClassName: alb`-ით ლაბაში 109, უბრალოდ
ტიპიზებული რესურსის მეშვეობით ანოტაციების ნაცვლად.

დარჩა დაველოდოთ `Programmed: True` და დავრწმუნდეთ, რომ ტრაფიკი ნამდვილად მიდის.
ბალანსერი შინაგანია (`internal-...`), ამიტომ მოთხოვნას ვაკეთებთ worker-იდან - ის ის ივე
VPC-შია:

```bash
for i in $(seq 1 30); do
  p=$(kubectl get gateway web -n eks-128 \
    -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}')
  [[ "$p" == "True" ]] && break
  sleep 10
done
kubectl get gateway web -n eks-128 -o wide

curl -s -o /dev/null -w "http=%{http_code}\n" "http://${ADDR}/"
```

პასუხი `http=200` მოვა წუთ-ორ წუთში `Programmed: True`-ის შემდეგ: თავდაპირველად ALB
ხდება აქტიური, შემდეგ სამიზნეები გადიან health check-ს (სამიზნეების მდგომარეობა
ჩანს `aws elbv2 describe-target-health`-ში).

## დავალება 4. AWS Gateway API Controller და Gateway კლასის VPC Lattice

თავდაპირველად ვხსნით ნოუდების SG-ს VPC Lattice-ის ტრაფიკისთვის - ამ წესის გარეშე
პოდები ტრაფიკს Service Network-იდან არ მიიღებენ (თავი 28, პარაგრაფი 28.4 კონტროლერის
დეპლოის დოკუმენტაციისა):

```bash
PREFIX_LIST_ID=$(aws ec2 describe-managed-prefix-lists \
  --query "PrefixLists[?PrefixListName=='com.amazonaws.eu-central-1.vpc-lattice'].PrefixListId" \
  --output text)

aws ec2 authorize-security-group-ingress --group-id "$NODE_SG" \
  --ip-permissions "PrefixListIds=[{PrefixListId=${PREFIX_LIST_ID}}],IpProtocol=-1"
```

ვაყენებთ კონტროლერს: namespace, ServiceAccount როლით, Helm-chart პარამეტრით
`defaultServiceNetwork` - კონტროლერი თავად შექმნის Service Network
`eks-task128-mesh`-ს და ასოცირებს მას კლასტერის VPC-სთან. Chart და image დევს
საჯარო ECR-ში და იზგება ანონიმურად, `helm registry login` არ სჭირდება (worker-ის
როლს არ აქვს `ecr-public:GetAuthorizationToken`, და ეს სწორია - საჯარო რეესტრი
იკითხება ტოკენის გარეშე):

```bash
kubectl create namespace aws-application-networking-system

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gateway-api-controller
  namespace: aws-application-networking-system
  annotations:
    eks.amazonaws.com/role-arn: ${LATTICE_ROLE_ARN}
EOF

helm install gateway-api-controller \
  oci://public.ecr.aws/aws-application-networking-k8s/aws-gateway-controller-chart \
  --version=v1.1.0 \
  --namespace aws-application-networking-system \
  --set=serviceAccount.create=false \
  --set=defaultServiceNetwork=eks-task128-mesh \
  --set=awsRegion="${REGION}" \
  --set=awsAccountId="${ACCOUNT_ID}" \
  --set=clusterVpcId="${VPC_ID}" \
  --set=clusterName="${CLUSTER}"

kubectl rollout status deployment -n aws-application-networking-system --timeout=180s
```

ბოლო ოთხი ფლაგი სავალდებულოა ის ივე მიზეზით, რაც `region` და `vpcId` LBC-ისთვის,
მაგრამ სიმპტომი სხვაა და ღირს დამახსოვრება. ამ კონტროლერის პოდი დგება ჩვეულებრივ
EC2-ნოუდზე, ესე იგი IMDS პრინციპში არსებობს, თუმცა IMDSv2 მიდის hop limit 1-ით და
მოთხოვნა პოდის ქსელური namespace-იდან ცხადდება. ფლაგების გარეშე კონტროლერი
ვარდება მყისვე
`init config failed: vpcId is not specified: EC2MetadataError ... status code: 401`-ით
(გადამოწმებულია სტენდზე). ზუსტად ეს hop limit განხილულია თავებში 10 და 19: ის
იცავს ნოუდის როლის კრედენციალებს პოდებისგან, და ამავე დროს ანგრევს ყოველ
კონტროლერს, რომელიც მეტადეიტას ეყრდნობა.

ვქმნით `GatewayClass`-ს VPC Lattice-სთვის და თავად `Gateway`-ს:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1beta1
kind: GatewayClass
metadata:
  name: amazon-vpc-lattice
spec:
  controllerName: application-networking.k8s.aws/gateway-api-controller
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: eks-task128-mesh
  namespace: eks-128
spec:
  gatewayClassName: amazon-vpc-lattice
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

kubectl get gateway eks-task128-mesh -n eks-128 -o wide
```

`Gateway`-ის სახელი აქ არ არის შემთხვევითი, და ეს არის დავალების მთავარი ხაფანგი.
VPC Lattice-ის კონტროლერი ეძებს Service Network-ს `Gateway`-ის ობიექტის სახელით,
არა `defaultServiceNetwork`-ის მნიშვნელობით. დაარქვით `Gateway`-ს სახელი `mesh` - და
ის მუდამ დარჩება `Programmed: False`-ში შეტყობინებით `VPC Lattice Service Network
not found`, რადგან ქსელს ანგარიშში ერქმევა `eks-task128-mesh` (გადამოწმებულია
სტენდზე: ორი `Gateway` გვერდიგვერდ, ემთხვევა სახელი - `Programmed: True` და ქსელის
ARN შეტყობინებაში, არ ემთხვევა - `not found`). აქედან წესი: `Gateway`-ის სახელი =
Service Network-ის სახელი.

`Gateway` კლასის `amazon-vpc-lattice` ჩაირისხება VPC Lattice-ის Service
Network-ში: ეს არის east-west კავშირი კლასტერის სერვისებს შორის, არა გარედან
შესასვლელი, როგორც `aws-alb`-ს (თავი 28, პარაგრაფი 28.5).

## დავალება 5. სიმპტომი: HTTPRoute ReferenceGrant-ის გარეშე

ვამართავთ backend-ს მეზობელ namespace-ში:

```bash
kubectl create deployment backend --image=viktoruj/ping_pong:latest \
  --replicas=1 -n eks-128-backend
kubectl rollout status deployment/backend -n eks-128-backend
kubectl expose deployment backend -n eks-128-backend --port=80 --target-port=8080

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.k8s.aws/v1
kind: TargetGroupConfiguration
metadata:
  name: backend
  namespace: eks-128-backend
spec:
  targetReference:
    name: backend
  defaultConfiguration:
    targetType: ip
EOF
```

`TargetGroupConfiguration` საჭიროა ის ივე მიზეზით, რაც დავალება 3-ში, და ერთდროულად
აჩვენებს მფლობელობის განაწილებას: ობიექტი დებულია საკუთარი Service-ის მფლობელის
namespace-ში, არა მარშრუტის გვერდით.

მარშრუტი `rates` ცხოვრობს `eks-128`-ში, ხოლო ბმულს ისვამს Service-ზე
`eks-128-backend`-ში. მშობელი - `Gateway` `web` კლასის `aws-alb`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: rates
  namespace: eks-128
spec:
  parentRefs:
    - kind: Gateway
      name: web
      sectionName: http
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /rates
      backendRefs:
        - name: backend
          namespace: eks-128-backend
          port: 80
EOF
```

ის ივე მარშრუტი, მაგრამ `Gateway` კლასის `amazon-vpc-lattice`-ზე - ეს არის საკონტროლო
ცდა, ის საჭიროა დავალების დასკვნისთვის:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: rates-lattice
  namespace: eks-128
spec:
  parentRefs:
    - kind: Gateway
      name: eks-task128-mesh
      sectionName: http
  rules:
    - backendRefs:
        - name: backend
          namespace: eks-128-backend
          port: 80
EOF

sleep 25
mkdir -p /var/work/tests/artifacts/5
{
  echo "rates status=$(kubectl get httproute rates -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')"
  echo "rates reason=$(kubectl get httproute rates -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].reason}')"
  echo "rates message=$(kubectl get httproute rates -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].message}')"
  echo "rates-lattice status=$(kubectl get httproute rates-lattice -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')"
  echo "rates-lattice reason=$(kubectl get httproute rates-lattice -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].reason}')"
} > /var/work/tests/artifacts/5/refnotpermitted.txt
cat /var/work/tests/artifacts/5/refnotpermitted.txt
```

არ ვიყენებთ `kubectl -o yaml | grep -A...`-ს: CRD-ობიექტებში (unstructured)
condition-ის ველები სერიალიზდება ალფაბეტური თანმიმდევრობით (`reason`, `status`
მოდის `type`-ზე ადრე), ამიტომ საიმედოა საჭირო condition-ის პირდაპირ გამოღება
`jsonpath`-ის მეშვეობით.

`backendRefs` ველით `namespace` ისვამს ბმულს Service-ზე სხვის namespace-ში - ეს
ბმული ნაგულისხმევად აკრძალულია, რომ `eks-128`-ის დეველოპერს არ შესძლოს ტრაფიკის
მიმართვა სხვის სერვისზე მისი მფლობელის ნებართვის გარეშე (თავი 28, პარაგრაფი 28.2).
მარშრუტ `rates`-ს condition `ResolvedRefs` ექნება `status: "False"`,
`reason: RefNotPermitted`, შეტყობინება
`No explicit ReferenceGrant exists to allow the reference.`

ხოლო აი output, რისთვისაც არსებობს საკონტროლო ცდა: `rates-lattice`-ს condition
დაუყოვნებლივ `ResolvedRefs: True` არსებობს, მიუხედავად იმისა, რომ არავითარი
`ReferenceGrant` `eks-128-backend`-ში ჯერ არ არსებობს (გადამოწმებულია სტენდზე).
წესი `ReferenceGrant` არის Gateway API-ის სპეციფიკაციის ნაწილი, მაგრამ მას იცავს
რეალიზაცია, არა API-სერვერი: AWS Load Balancer Controller ამოწმებს მას, VPC
Lattice-ის კონტროლერი ვერსია v1.1.0 - არა. აქედან პრაქტიკული დასკვნა: ერთი და ივე
YAML ორ რეალიზაციაში Gateway API-ისა იძლევა სხვადასხვა ნდობის საზღვარს გუნდებს
შორის, და `ReferenceGrant`-ს დაცვად ველოდოთ შესაძლებელია მხოლოდ იმ ადგილას, სადაც
თქვენ გადამოწმეთ კონტროლერის ქცევა.

## დავალება 6. Fix: ReferenceGrant უშვებს კროს-namespace ბმულს

`ReferenceGrant`-ს ქმნის **სამიზნე** backend-ის მფლობელი - namespace
`eks-128-backend`, არა ის, ვინც ბმულს ისვამს:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-from-eks-128
  namespace: eks-128-backend
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: eks-128
  to:
    - group: ""
      kind: Service
EOF

sleep 15
mkdir -p /var/work/tests/artifacts/6
{
  echo "ResolvedRefs status=$(kubectl get httproute rates -n eks-128 \
    -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')"
  echo "curl /rates http=$(curl -s -o /dev/null -w '%{http_code}' -m 10 "http://${ADDR}/rates")"
} > /var/work/tests/artifacts/6/resolved.txt
cat /var/work/tests/artifacts/6/resolved.txt
```

არტეფაქტის მეორე ხაზით ვამოწმებთ არა სტატუსს, არამედ თავად ტრაფიკს: `http=200`
პოდიდან `backend` ნიშნავს, რომ ჯაჭვი მთლიანად შედგა - მარშრუტს გრანტი აძლევს
ნებართვას, target group ტიპის `ip` შექმნილია, სამიზნეები გავიდნენ health check-ს.
თუ `ResolvedRefs` უკვე `True`-ია, ხოლო `curl` აბრუნებს `503`-ს, დაელოდეთ წუთს:
სამიზნეების რეგისტრაცია მიდის target group-ის გაჩენის შემდეგ.

`ReferenceGrant`-ის გამოჩენის შემდეგ condition `ResolvedRefs`-ს `rates`-ისთვის
იცვლება `True`-ზე წამებში - კონტროლერი ხელახლა აფასებს დაშვებულ ბმულებს მომდევნო
რეკონსილაციაზე, და მარშრუტი იწყებს `backend`-ის რეზოლუციას მეზობელ namespace-ში.
გაითვალისწინეთ, რომ ნებართვას გასცემს namespace-მფლობელი სამიზნისა: წაშალეთ
`ReferenceGrant`, და მარშრუტი დაბრუნდება `RefNotPermitted`-ში, თუმცა თავად
მარშრუტს არავინ შეცვლია.

## სწრაფი შემოწმება

```bash
check_result
```
