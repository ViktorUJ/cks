[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 101 - ეტალონური გადაწყვეტა (კლასტერი როგორც კოდი: წვდომა, compute, ქსელი, AMI)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე (worker) SSH-ის მეშვეობით. kubectl უკვე
კონფიგურირებულია კლასტერზე (kubeconfig იწყობა `aws eks update-kubeconfig`-ით მანქანის
ჩატვირთვისას).

## დავალება 1. Namespace `eks-101`

```bash
kubectl create namespace eks-101
```

## დავალება 2. Deployment `web` (viktoruj/ping_pong, 3 რეპლიკა) EC2-ნოუდებზე

სისტემური პოდები (kube-system, karpenter) ხვდებიან Fargate-ზე, ხოლო ჩვეულებრივ
namespace-ში ნებისმიერი პოდი დაგეგმარდება EC2-ნოუდზე, რომელსაც ამართავს Karpenter. ამიტომ
Deployment `eks-101`-ში ავტომატურად ხვდება EC2-ზე:

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=3 -n eks-101
kubectl rollout status deployment/web -n eks-101
```

შემოწმება, რომ პოდები არ არიან Fargate-ზე (ნოუდის სახელი იწყება `ip-`-ით, არა
`fargate-`-ით):

```bash
kubectl get po -n eks-101 -l app=web -o wide
```

რატომ ასეა: Fargate პოდს გაშვებს მხოლოდ იმ შემთხვევაში, თუ პოდის namespace ხვდება
Fargate-profile-ის ქვეშ. ამ ლაბაში profile კონფიგურირებულია `kube-system`-ისთვის და
`karpenter`-ისთვის, ხოლო `eks-101`-ისთვის profile არ არსებობს, ამიტომ `eks-101`-ის
დატვირთვას იღებს Karpenter (EC2). ამ განმარტებას დააფიქსირებთ დავალება 7-ში.

## დავალება 3. არტეფაქტი: სისტემური და სამუშაო ნოუდების გამიჯვნა

ვინახავთ ნოუდების სიას იმის მითითებით, რომლები არიან Fargate და რომლები EC2:

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl get nodes -o wide > /var/work/tests/artifacts/3/nodes.txt
cat /var/work/tests/artifacts/3/nodes.txt
```

ფაილში უნდა იყოს ორივე: `fargate-...` ნოუდები (სისტემური პოდები) და `ip-...` ნოუდები
(Karpenter-ის სამუშაო ნოუდები). ეს არის ის compute-ის გამიჯვნა, რაზეც თავი 9 ლაპარაკობს.

## დავალება 4. არტეფაქტი: პოდის IP VPC-ის CIDR-იდან

VPC CNI პოდებს გამოუყოფს რაუტირებად მისამართებს ნოუდის ქვექსელიდან (`10.10.15.0/24` ან
`10.10.16.0/24`), ანუ VPC `10.10.0.0/16`-დან:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl get po -n eks-101 -l app=web -o jsonpath='{.items[0].status.podIP}' \
  > /var/work/tests/artifacts/4/podip.txt
echo >> /var/work/tests/artifacts/4/podip.txt
cat /var/work/tests/artifacts/4/podip.txt
```

VPC CNI-ის უკეთ გასაგებად, შეადარეთ პოდის მისამართი პრივატული ქვექსელების CIDR-ებს (პოდმა
IP მიიღო თავისივე ნოუდის ქვექსელიდან):

```bash
VPC=$(aws eks describe-cluster --name "$(kubectl config current-context | sed 's|.*/||')" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null)
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'Subnets[].[CidrBlock,AvailabilityZone]' --output table
```

## დავალება 5. არტეფაქტი: სამუშაო ნოუდის AMI (AL2023)

ვხედავთ ნებისმიერი სამუშაო (EC2) ნოუდის OS image-ს. ნაგულისხმევი NodePool აწყობილია
`al2023@latest`-ზე, ამიტომ ეს არის Amazon Linux 2023:

```bash
mkdir -p /var/work/tests/artifacts/5
NODE=$(kubectl get po -n eks-101 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
kubectl get node "$NODE" -o jsonpath='{.status.nodeInfo.osImage}' \
  > /var/work/tests/artifacts/5/ami.txt
echo >> /var/work/tests/artifacts/5/ami.txt
cat /var/work/tests/artifacts/5/ami.txt
```

## დავალება 6. Deployment `batch` (6 რეპლიკა CPU-request-ით) - მასშტაბირება Karpenter-ის მეშვეობით

დატვირთვა ცალსახა requests-ით აიძულებს Karpenter-ს დაამატოს compute-რესურსები. ვქმნით
deployment-ს CPU-request-ით და ველოდებით ყველა რეპლიკის მზაობას:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch
  namespace: eks-101
spec:
  replicas: 6
  selector:
    matchLabels:
      app: batch
  template:
    metadata:
      labels:
        app: batch
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "128Mi"
EOF

kubectl rollout status deployment/batch -n eks-101
```

ისე, რომ დავაკვირდეთ, როგორ ამართავს Karpenter ნოუდებს:

```bash
kubectl get nodeclaims.karpenter.sh
kubectl get nodes -l work_type=default -o wide
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | tail -n 20
```

## დავალება 7. პასუხისმგებლობის საზღვარი: სიმპტომი და განმარტება

განზრახ ვითხოვთ Fargate-ს იქ, სადაც ის არ არსებობს. პოდი უნდა ჩამორჩეს `Pending`-ში:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: fg-probe
  namespace: eks-101
spec:
  nodeSelector:
    eks.amazonaws.com/compute-type: fargate
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

kubectl get po fg-probe -n eks-101 -o wide
kubectl describe po fg-probe -n eks-101 | sed -n '/Events/,$p'
# მთელი namespace-ის events-ები დროის მიხედვით - SRE-დიაგნოსტიკის უნარი დაგეგმარების უკუთქმისთვის
kubectl get events -n eks-101 --sort-by='.metadata.creationTimestamp'
```

პოდი რჩება `Pending`-ში: `eks-101`-ისთვის Fargate-profile არ არსებობს, ამიტომ EKS არ
გეგმავს პოდს Fargate-ზე, ხოლო Karpenter არ ქმნის EC2-ნოუდს, რადგან მისი ნოუდები არ ატარებენ
label-ს `eks.amazonaws.com/compute-type: fargate`. ამ მოთხოვნას ვერავინ ასრულებს.

ვინახავთ განმარტებას არტეფაქტში:

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/whyfargate.txt <<'EOF'
web და batch პოდები მოხვდნენ Karpenter-ის EC2-ნოუდებზე და არა Fargate-ზე: Fargate პოდის
გაშვებას ახდენს მხოლოდ იმ შემთხვევაში, თუ პოდის namespace ხვდება Fargate profile-ის ქვეშ.
კლასტერში profile არსებობს kube-system-ისთვის და karpenter-ისთვის, მაგრამ eks-101-ისთვის
profile არ არსებობს.

fg-probe ჩარჩა Pending-ში, რადგან ის ცალსახად ითხოვს Fargate-ს (nodeSelector
eks.amazonaws.com/compute-type: fargate), მაგრამ profile eks-101-ისთვის არ არსებობს, ხოლო
Karpenter-ის EC2-ნოუდებს ეს label არ აქვს. ამ მოთხოვნას ვერავინ ასრულებს.
EOF
cat /var/work/tests/artifacts/7/whyfargate.txt
```

პასუხისმგებლობის საზღვარი კარგად ჩანს: რომელი namespace-ები ხვდებიან Fargate-ზე, ეს
თქვენზეა (Fargate-profile-ების მეშვეობით, თავი 9), არა EKS-ის "თავისთავად" გადაწყვეტილება.

## სწრაფი შემოწმება

```bash
check_result
```
