[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 126 - ეტალონური გამოსავალი (security groups for pods)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე SSH-ის მეშვეობით, როგორც კურსის დანარჩენ
ლაბებში: worker-ის როლმა მიღო უფლებები security group-ის შესაქმნელად, მასზე წესების
დასამატებლად და პოლიტიკის `AmazonEKSVPCResourceController` კლასტერის როლზე
მისამაგრებლად (იხილეთ README-ის „ინფრასტრუქტურის" განყოფილება).

გამოსავალში საერთო ცვლადები:

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
CLUSTER=$(kubectl config current-context | awk -F/ '{print $NF}')
REGION=eu-central-1
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.resourcesVpcConfig.vpcId' --output text)
echo "cluster=$CLUSTER vpc=$VPC_ID"
```

## დავალება 1. Namespace `eks-126`

```bash
kubectl create namespace eks-126
```

## დავალება 2. წინაპირობების შემოწმება

მოძებნეთ control plane-ის როლის სახელი და შეამოწმეთ მიმაგრებული პოლიტიკები (worker-ზე):

```bash
ROLE_ARN=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.roleArn' --output text)
ROLE_NAME=$(echo "$ROLE_ARN" | sed 's|.*/||')
echo "cluster role: $ROLE_NAME"
aws iam list-attached-role-policies --role-name "$ROLE_NAME"
```

ნაგულისხმევად ის იქ არ არის (როლს აქვს მხოლოდ `AmazonEKSClusterPolicy` და
დაშიფვრის პოლიტიკა), ამიტომ ვამაგრებთ მას:

```bash
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSVPCResourceController
```

პოლიტიკა მიემაგრება **control plane**-ის (კლასტერის) როლზე, არა Karpenter-ის
ნოუდის როლზე - ეს ის როლია, რომელიც EKS-ს აძლევს უფლებას შექმნას/წაშალოს branch
ENI-ები და მართოს მათი IP-ები.

ვამოწმებთ VPC CNI-ის სამ ცვლადს - ყველა უკვე დაყენებულია terraform-ის მიერ addon
`vpc-cni`-ის `configuration`-ის მეშვეობით:

```bash
kubectl describe daemonset aws-node -n kube-system \
  | grep -E 'ENABLE_POD_ENI|POD_SECURITY_GROUP_ENFORCING_MODE|DISABLE_TCP_EARLY_DEMUX'
```

მოსალოდნელი გამოტანილი: `ENABLE_POD_ENI: true`, `POD_SECURITY_GROUP_ENFORCING_MODE: strict`,
`DISABLE_TCP_EARLY_DEMUX: true`. პირველი ჩართავს trunk interface-ს, მეორე აქტიურად
ინახავს პოდის SG-ის წესის შემოწმებას ნოუდიდან მომავალი ტრაფიკისთვის (`standard`
რეჟიმში ეს ასე არ არის, და დავალება 4-ის სიმპტომი არ გამოჩნდებოდა), მესამე ანებებს
`kubelet`-ს TCP-კავშირის გახსნას branch ENI-ზე მდებარე პოდთან.

შეინახეთ ორივე დამადასტურებელი ჩანაწერი:

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "cluster role: $ROLE_NAME"
  aws iam list-attached-role-policies --role-name "$ROLE_NAME"
  echo "---"
  kubectl describe daemonset aws-node -n kube-system | grep ENABLE_POD_ENI
} > /var/work/tests/artifacts/2/prereqs.txt
cat /var/work/tests/artifacts/2/prereqs.txt
```

## დავალება 3. არასრული security group და SecurityGroupPolicy

შექმენით SG ლაბის VPC-ში. მნიშვნელოვანია: ტეგი `karpenter.sh/discovery` არ
დააყენოთ, სხვაგვარად EC2NodeClass მას ნოუდის SG-დ ჩათვლის:

```bash
SG_ID=$(aws ec2 create-security-group \
  --group-name eks-task126-secured-pod-sg \
  --description "security group for secured-app pods (lab 126, intentionally incomplete)" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' --output text)
echo "$SG_ID"
```

ჯერ არ ვამატებთ არავითარ `authorize-security-group-ingress`-ს ან `egress`-ს: ახალ
SG-ს აქვს მხოლოდ AWS-ის ნაგულისხმევი allow-all egress და ნული inbound-წესი - ეს
ზუსტად ის მდგომარეობაა, რომელიც სიმპტომს გამოიწვევს.

შექმენით `SecurityGroupPolicy`:

```bash
mkdir -p /var/work/tests/artifacts/3
echo -n "$SG_ID" > /var/work/tests/artifacts/3/sg_id.txt

cat <<EOF | kubectl apply -f -
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: secured-sgp
  namespace: eks-126
spec:
  podSelector:
    matchLabels:
      app: secured
  securityGroups:
    groupIds:
      - ${SG_ID}
EOF

kubectl get securitygrouppolicy secured-sgp -n eks-126 -o yaml
```

## დავალება 4. სიმპტომი: Running, მაგრამ არასდროს Ready

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secured-app
  namespace: eks-126
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secured
  template:
    metadata:
      labels:
        app: secured
    spec:
      nodeSelector:
        work_type: nitro
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          periodSeconds: 5
          failureThreshold: 3
EOF

kubectl rollout status deployment/secured-app -n eks-126 --timeout=180s || true
kubectl get pod -n eks-126 -l app=secured
```

პოდი ჩერდება `0/1 Ready`-ზე, მიუხედავად იმისა, რომ ფაზა `Running`-ია - branch ENI
შეიქმნა, მაგრამ პოდის SG არ ატარებს kubelet-ის probe-ს. შეინახეთ დიაგნოსტიკა:

```bash
mkdir -p /var/work/tests/artifacts/4
POD=$(kubectl get pod -n eks-126 -l app=secured -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod "$POD" -n eks-126 > /var/work/tests/artifacts/4/pod_not_ready.txt
grep -i 'readiness probe failed\|unhealthy' /var/work/tests/artifacts/4/pod_not_ready.txt
```

Event ასეთი სახის არის (გადამოწმებული სტენდზე):

```
Warning  Unhealthy  49s (x33 over 5m44s)  kubelet  Readiness probe failed:
Get "http://10.10.16.177:8080/": context deadline exceeded
```

ვადასტურებთ, რომ პოდი ნამდვილად branch ENI-ზეა, არა ნოუდის ENI-ზე:

```bash
kubectl get pod "$POD" -n eks-126 \
  -o jsonpath='{.metadata.annotations.vpc\.amazonaws\.com/pod-eni}{"\n"}'
kubectl get pod "$POD" -n eks-126 -o jsonpath='{.spec.containers[0].resources.limits}{"\n"}'
aws ec2 describe-network-interfaces --filters "Name=group-id,Values=$SG_ID" \
  --query 'NetworkInterfaces[].[NetworkInterfaceId,InterfaceType,Status,PrivateIpAddress]' \
  --output text
```

ანოტაცია შეიცავს `eniId`-ს, `vlanId`-ს და `associationID`-ს, ისეთს, როგორიც არის
`trunk-assoc-...`, ლიმიტები აჩვენებს `vpc.amazonaws.com/pod-eni: 1`-ს, ხოლო
ინტერფეისის ტიპი იქნება `branch`, პოდის იმავე IP-ით.

## დავალება 5. Probe-ების გამოსწორება: inbound წესი ნოუდის SG-დან

მოძებნეთ Karpenter-ის ნოუდის SG იმ ნოუდის მეშვეობით, რომელზეც `secured-app`
მუშაობს (worker-ზე):

```bash
NODE=$(kubectl get pod "$POD" -n eks-126 -o jsonpath='{.spec.nodeName}')
INSTANCE_ID=$(kubectl get node "$NODE" -o jsonpath='{.spec.providerID}' | sed 's|.*/||')
NODE_SG=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)
echo "node=$NODE instance=$INSTANCE_ID node_sg=$NODE_SG"
```

დაამატეთ inbound-წესი პოდის SG-ში:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 8080 \
  --source-group "$NODE_SG"
```

დაიცადეთ, სანამ probe გაივლის, და შეინახეთ შედეგი:

```bash
sleep 15
kubectl get pod -n eks-126 -l app=secured
mkdir -p /var/work/tests/artifacts/5
kubectl get pod "$POD" -n eks-126 > /var/work/tests/artifacts/5/pod_ready.txt
cat /var/work/tests/artifacts/5/pod_ready.txt
```

`READY` ახლა უნდა აჩვენებდეს `1/1`-ს - kubelet-ს ახლა შეუძლია პოდის branch ENI-ს
მიწვდომა probe-ის პორტზე.

## დავალება 6. DNS-ის დიაგნოსტიკა და გამოსწორება

შეამოწმეთ რეზოლვინგი `secured-app`-ის შიგნიდან. image `viktoruj/ping_pong:latest`-ს
DNS-ისთვის შელის ხელსაწყოები არ აქვს (აწყობილია `scratch`-იდან), ამიტომ ვიყენებთ
ცალკე დიაგნოსტიკურ პოდს იმავე ლეიბლით `app: secured`, რომ `secured-sgp` მასზეც
გავრცელდეს:

```bash
kubectl run dns-probe -n eks-126 --image=busybox --restart=Never \
  --labels='app=secured' \
  --overrides='{"spec":{"nodeSelector":{"work_type":"nitro"}}}' \
  -- sleep 3600
kubectl wait --for=condition=Ready pod/dns-probe -n eks-126 --timeout=120s || true

mkdir -p /var/work/tests/artifacts/6
kubectl exec dns-probe -n eks-126 -- nslookup kubernetes.default.svc.cluster.local \
  > /var/work/tests/artifacts/6/dns_before.txt 2>&1 || true
cat /var/work/tests/artifacts/6/dns_before.txt
```

გამოტანილი არის `;; connection timed out; no servers could be reached`. მნიშვნელოვანია
მიზეზი სწორად დავარქმევთ: egress აქ საკითხი არ არის, ახალ SG-ს აქვს ნაგულისხმევი
allow-all egress წესი, და მოთხოვნა თავისუფლად გადის. პაკეტი ეკარგება მიმღები მხარის
inbound-ზე, რომელსაც ჩვენი SG-სთვის წესი არ აქვს. CoreDNS ამ ლაბში Fargate-ზეა და
ცხოვრობს cluster primary security group-ის მიღმა:

```bash
CLUSTER_PRIMARY_SG=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
echo "cluster primary sg (CoreDNS on Fargate): $CLUSTER_PRIMARY_SG"
```

ვამატებთ inbound `53` TCP და UDP cluster primary SG-ზე, წყაროდ ჩვენი პოდის SG
დაყენებით. ეს ერთი წესი კმარა, რადგან security group stateful-ია: პასუხი
დაშვებულ inbound-მოთხოვნაზე ცალკე წესის გარეშე ბრუნდება.

```bash
aws ec2 authorize-security-group-ingress --group-id "$CLUSTER_PRIMARY_SG" \
  --ip-permissions \
    "IpProtocol=tcp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$SG_ID}]" \
    "IpProtocol=udp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$SG_ID}]"
```

ხელახლა ვამოწმებთ რეზოლვინგს:

```bash
sleep 5
kubectl exec dns-probe -n eks-126 -- nslookup kubernetes.default.svc.cluster.local \
  > /var/work/tests/artifacts/6/dns_after.txt 2>&1
cat /var/work/tests/artifacts/6/dns_after.txt
```

ახლა მეორე ნაბიჯი, მინიმალური უფლებების პრინციპით. პოდის SG-ის ნაგულისხმევი
allow-all egress ნიშნავს „პოდს ყველაფრის გამოშვება ეშვება" - პოდისთვის საკუთარი
security group-ით ეს ზუსტად ის არის, რასაც ვცდილობდით, გვერდი ავევლო. ვავიწროებთ
egress-ს `53`-მდე და ვადასტურებთ, DNS მუშაობას რომ აგრძელებს:

```bash
aws ec2 revoke-security-group-egress --group-id "$SG_ID" \
  --protocol -1 --port all --cidr 0.0.0.0/0
aws ec2 authorize-security-group-egress --group-id "$SG_ID" \
  --ip-permissions \
    "IpProtocol=tcp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$CLUSTER_PRIMARY_SG}]" \
    "IpProtocol=udp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$CLUSTER_PRIMARY_SG}]"

kubectl delete pod dns-probe -n eks-126 --ignore-not-found
kubectl run dns-probe -n eks-126 --image=busybox --restart=Never --labels='app=secured' \
  --overrides='{"spec":{"nodeSelector":{"work_type":"nitro"}}}' \
  --command -- sh -c 'nslookup kubernetes.default.svc.cluster.local'
sleep 45
kubectl logs dns-probe -n eks-126 | tee -a /var/work/tests/artifacts/6/dns_after.txt
```

ვაგებთ არტეფაქტს:

```bash
cat > /var/work/tests/artifacts/6/dns_fix.txt <<EOF
გამოსწორებამდე (dns_before.txt): nslookup kubernetes.default-ისკენ ჩავარდა
";; connection timed out; no servers could be reached"-ით.

მიზეზი ეს არ არის egress: ახალ security group ${SG_ID}-ს აქვს ნაგულისხმევი allow-all
egress წესი, და პოდიდან წასული მოთხოვნა თავისუფლად გადის. პაკეტი ეკარგება მიმღები
მხარის INBOUND-ზე - cluster primary security group ${CLUSTER_PRIMARY_SG}, რომლის
მიღმაც მუშაობს CoreDNS Fargate-ზე, ჩვენი SG-სთვის inbound-წესი არ აქვს. წესი ზუსტად
იქ არის საჭირო, და ერთი კმარა: security group stateful-ია, პასუხი დაშვებულ
inbound-მოთხოვნაზე თავისთავად ბრუნდება.

გამოსწორება: inbound 53 TCP და UDP ${CLUSTER_PRIMARY_SG}-ზე, source-group ${SG_ID}-ით.
ამის შემდეგ nslookup რეზოლვს kubernetes.default.svc.cluster.local-ს (dns_after.txt).

მეორე ნაბიჯი: პოდის SG-დან მოცილებულია ნაგულისხმევი allow-all egress, შეცვლილია
ცხადი egress 53 TCP და UDP-ით ${CLUSTER_PRIMARY_SG}-ისკენ. DNS მუშაობას აგრძელებს -
ეს აჩვენებს, რომ egress წყაროს მხარეს და inbound მიმღების მხარეს ორი დამოუკიდებელი
წესია, და პოდისთვის მთლიანი გამავალი ტრაფიკის დაშვება DNS-ისთვის საჭირო არ არის.
EOF
cat /var/work/tests/artifacts/6/dns_fix.txt
```

## დავალება 7. ხაფანგი: ერთი ნოუდი, სხვადასხვა security group

გავუშვათ ექსპერიმენტი: ორი პოდი სხვადასხვა security group-ით ერთსა და იმავე
ნოუდზე. ვაწყობთ მეორე SG-ს და მეორე `SecurityGroupPolicy`-ს ლეიბლისთვის `app: other`:

```bash
mkdir -p /var/work/tests/artifacts/7
SG2=$(aws ec2 create-security-group \
  --group-name eks-task126-other-pod-sg \
  --description "second pod sg for the same-node experiment (lab 126)" \
  --vpc-id "$VPC_ID" --query 'GroupId' --output text)
echo "second pod sg: $SG2"

cat <<EOF | kubectl apply -f -
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: other-sgp
  namespace: eks-126
spec:
  podSelector:
    matchLabels:
      app: other
  securityGroups:
    groupIds:
      - ${SG2}
EOF
```

ვპოულობთ Deployment-ის პოდს (ზუსტად მას, არა დიაგნოსტიკურ პოდებს - მათაც აქვთ
ლეიბლი `app: secured`) და ვუშვებთ გვერდით პოდს სხვა SG-ით:

```bash
APP_POD=$(kubectl get pod -n eks-126 -l app=secured \
  -o jsonpath='{range .items[?(@.metadata.ownerReferences[0].kind=="ReplicaSet")]}{.metadata.name}{"\n"}{end}' \
  | head -1)
APP_IP=$(kubectl get pod "$APP_POD" -n eks-126 -o jsonpath='{.status.podIP}')
APP_NODE=$(kubectl get pod "$APP_POD" -n eks-126 -o jsonpath='{.spec.nodeName}')
echo "secured-app=$APP_POD ip=$APP_IP node=$APP_NODE"

kubectl delete pod othersg -n eks-126 --ignore-not-found --wait=true
kubectl run othersg -n eks-126 --image=busybox --restart=Never --labels='app=other' \
  --overrides="{\"spec\":{\"nodeName\":\"$APP_NODE\"}}" \
  --command -- sh -c "wget -T 10 -qO- http://$APP_IP:8080/ ; echo RC=\$?"
sleep 55
kubectl logs othersg -n eks-126 | tee /var/work/tests/artifacts/7/before.txt
```

შედეგი არის `wget: download timed out`: პოდს აქვს საკუთარი SG, მეზობელს - საკუთარი,
და მათ შორის ტრაფიკის დამშვები წესი არ არსებობს. ვამატებთ წესს და ვიმეორებთ:

```bash
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 8080 --source-group "$SG2"

kubectl delete pod othersg -n eks-126 --ignore-not-found --wait=true
kubectl run othersg -n eks-126 --image=busybox --restart=Never --labels='app=other' \
  --overrides="{\"spec\":{\"nodeName\":\"$APP_NODE\"}}" \
  --command -- sh -c "wget -T 10 -qO- http://$APP_IP:8080/ ; echo RC=\$?"
sleep 55
kubectl logs othersg -n eks-126 | tee /var/work/tests/artifacts/7/after.txt
```

ახლა მოთხოვნა გაივლის (`RC=0`). ეს ნიშნავს, რომ `strict` რეჟიმში პოდის SG-ის
წესები ერთი ნოუდის შიგნითაც გამოიყენება - ორივე პოდს საკუთარი branch ENI აქვს, და
გადამწყვეტი წესია. ვაგებთ არტეფაქტს:

```bash
{
  echo "=== Deployment-ის პოდი SecurityGroupPolicy secured-sgp-ით (branch ENI) ==="
  kubectl get pod "$APP_POD" -n eks-126 -o wide
  echo
  echo "=== პოდი განსხვავებული security group-ით (other-sgp), იმავე ნოუდზე ==="
  kubectl get pod othersg -n eks-126 -o wide
  echo
  echo "=== წესის დამატებამდე ==="
  cat /var/work/tests/artifacts/7/before.txt
  echo "=== inbound 8080 წესის დამატების შემდეგ მეორე SG-დან ==="
  cat /var/work/tests/artifacts/7/after.txt
  echo
  echo "=== სად არის CoreDNS ==="
  kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
  cat <<'TXT'

დასკვნა ექსპერიმენტიდან. ჩვენი POD_SECURITY_GROUP_ENFORCING_MODE არის strict, და
მასში პოდის security group-ის წესები გამოიყენება ერთი ნოუდის შიგნით ტრაფიკზეც: ორი
პოდი სხვადასხვა SG-ით ერთსა და იმავე ნოუდზე თავიდან არ ერთვებოდა (download timed
out), ხოლო inbound-წესის დამატების შემდეგ ერთვებოდა. ესე იგი აქ დიაგნოზი ჩვეულებრივია -
ვხედავთ წესებს, არა ტოპოლოგიას.

კონტრასტი, რომლის ცოდნაც ღირს (AWS-ის დოკუმენტაცია, standard რეჟიმი): standard
რეჟიმში პოდის SG-ის წესები არ გამოიყენება ერთ ნოუდზე მდებარე პოდებსა და
სერვისებს შორის ტრაფიკზე, kubelet-ისა და nodeLocalDNS-ის ჩათვლით, ხოლო
სხვადასხვა security group-ის მქონე პოდები ერთსა და იმავე ნოუდზე საერთოდ არ
ურთიერთობენ, რადგან ისინი სხვადასხვა ქვექსელში ცხოვრობენ, გამორთული routing-ით
მათ შორის. იქ ეს იგივე სიტუაცია წესით არ ლაგდება, მხოლოდ პოდების ნოუდებზე გადანაწილებით.
ეს ასევე ზუსტად იმის მიზეზია, რატომ standard არ იმეორებს დავალებების 4 და 5
სიმპტომს: kubelet-ის probe SG-ის წესებს ევლის, და readiness გაივლის security
group-ითაც, სადაც ერთი inbound-წესიც არ არსებობს.
TXT
} > /var/work/tests/artifacts/7/same_node_trap.txt
cat /var/work/tests/artifacts/7/same_node_trap.txt
```

## სწრაფი შემოწმება

```bash
check_result
```
