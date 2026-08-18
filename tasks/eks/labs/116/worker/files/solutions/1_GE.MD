[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 116 - ეტალონური გადაწყვეტა (IMDSv2 hop limit, Pod Security Admission, პრივატული endpoint)

ყველა ბრძანება სრულდება worker მანქანაზე SSH-ით. kubectl უკვე კონფიგურირებულია
კლასტერზე (kubeconfig შედგენილია `aws eks update-kubeconfig`-ით მანქანის ჩატვირთვისას).

## დავალება 1. Namespace `eks-116`

```bash
kubectl create namespace eks-116
```

## დავალება 2. სიმპტომი: IMDS მიუწვდომელია pod-იდან

NodePool `hardened` (ერთადერთი ამ ლაბაში) თავის ყველა node-ზე აყენებს
`httpPutResponseHopLimit=1`-ს EC2NodeClass-ის `metadataOptions`-ის მეშვეობით. პაკეტი
host-ზე მომუშავე პროცესიდან IMDS-ს აღწევს ერთი hop-ით, ხოლო pod-იდან პაკეტი აკეთებს
დამატებით hop-ს (კონტეინერის ქსელური namespace) - და არ ჯდება ლიმიტში. ვქმნით
Deployment-ს დაძინებული კონტეინერით, რომ შევძლოთ შიგნით შესვლა exec-ით:

```bash
kubectl create deployment probe --image=curlimages/curl:latest -n eks-116 \
  -- sleep 3600
kubectl rollout status deployment/probe -n eks-116
```

IMDSv2 მოთხოვნა pod-იდან (თავიდან token, შემდეგ მონაცემები), დროის ლიმიტით:

```bash
POD=$(kubectl get po -n eks-116 -l app=probe -o jsonpath='{.items[0].metadata.name}')
mkdir -p /var/work/tests/artifacts/2

kubectl exec -n eks-116 "$POD" -- sh -c '
  echo "=== PUT token ===";
  TOKEN=$(curl -sX PUT --max-time 5 "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600");
  if [ -z "$TOKEN" ]; then
    echo "no token received: request timed out (hop limit blocked the pod)";
  else
    echo "=== GET with token ===";
    curl -s --max-time 5 -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/iam/security-credentials/ \
      || echo "GET timed out (hop limit blocked the pod)";
  fi
' 2>&1 | tee /var/work/tests/artifacts/2/imds.txt

cat /var/work/tests/artifacts/2/imds.txt
```

hop limit `1`-ის დროს `curl` არ იღებს პასუხს გამოყოფილ `5` წამში, და ფაილში ჩნდება
სტრიქონი timeout-ის შესახებ (`curl` აჩვენებს `curl: (28) ... timeout`-ს `-v`-ით, ხოლო
token-ის გარეშე სკრიპტი თავად ამატებს განმარტებას `timed out`).

## დავალება 3. შემოწმება AWS API-ის მეშვეობით: hop limit და IMDSv2 node-ზე

ვიგებთ, რომელ node-ზე მუშაობს `probe`, ვიღებთ მის `providerID`-ს და გამოვყოფთ instance-ის
id-ს:

```bash
NODE=$(kubectl get po -n eks-116 -l app=probe -o jsonpath='{.items[0].spec.nodeName}')
PROVIDER_ID=$(kubectl get node "$NODE" -o jsonpath='{.spec.providerID}')
# providerID სახით aws:///eu-central-1a/i-0abc123def456789
INSTANCE_ID=$(echo "$PROVIDER_ID" | awk -F'/' '{print $NF}')
echo "node=$NODE instance=$INSTANCE_ID"

mkdir -p /var/work/tests/artifacts/3
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[].Instances[].MetadataOptions' --output json \
  | tee /var/work/tests/artifacts/3/metadata_options.txt
```

გამონატანში უნდა იყოს `"HttpTokens": "required"` და `"HttpPutResponseHopLimit": 1` -
ზუსტად ის, რაც `vng.metadataOptions`-მა დააყენა
`eks_karpenter_hardened_vng/terragrunt.hcl`-ში და რაც EC2NodeClass-მა გადასცა node-ის
launch template-ს.

## დავალება 4. Pod Security Admission: პრივილეგირებული pod-ის უარყოფა

ვრთავთ restricted-ს namespace-ზე ლეიბლებით (PSA ჩაშენებულია EKS-ში, მაგრამ ლეიბლების
გარეშე namespace ნაგულისხმევად მუშაობს როგორც `privileged` - არაფერს არ ზღუდავს):

```bash
kubectl label namespace eks-116 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest
```

ვცდილობთ პრივილეგირებულ pod-ს - admission-მა უნდა უარყოს შექმნა:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl run priv-test -n eks-116 --image=busybox --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"priv-test","image":"busybox","securityContext":{"privileged":true}}]}}' \
  2>&1 | tee /var/work/tests/artifacts/4/psa_reject.txt

kubectl get pod priv-test -n eks-116 2>&1 | tee -a /var/work/tests/artifacts/4/psa_reject.txt
cat /var/work/tests/artifacts/4/psa_reject.txt
```

მოსალოდნელი გამონატანი, მსგავსი:

```
Error from server (Forbidden): pods "priv-test" is forbidden: violates PodSecurity "restricted:latest": privileged (container "priv-test" must not set securityContext.privileged=true)
```

pod არ იქმნება (`kubectl get pod priv-test` დააბრუნებს `NotFound`-ს), შეტყობინებაში
არის სიტყვები `privileged` და `restricted`/`violates` - ეს არის ის, რასაც მოითხოვს
მიღების კრიტერიუმები.

## დავალება 5. დაშვებული გზა: restricted-თან თანხვედრილი pod

ვაწყობთ pod-ს ყველა იმ ველით, რასაც მოითხოვს პროფილი `restricted`. `runAsNonRoot: true`
მხოლოდ root-ად გაშვებას კრძალავს - image `busybox:latest` ნაგულისხმევად არ აცხადებს
non-root მომხმარებელს, ამიტომ ცხადი `runAsUser`-ის გარეშე (ნებისმიერი ნულის გარეშე UID)
kubelet ბლოკავს კონტეინერის გაშვებას ცალკე შეცდომით, `container has runAsNonRoot and
image will run as root`, უკვე მას შემდეგ, რაც admission-მა pod-ს გაატარა:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: safe-pod
  namespace: eks-116
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:latest
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
EOF

kubectl get pod safe-pod -n eks-116 -o wide
```

pod გადალახავს admission-ს და გადადის `Running` მდგომარეობაში - იგივე namespace, იგივე
პროფილი `restricted`, მაგრამ მოთხოვნები სრულად შესრულებულია: `runAsNonRoot` ცხადი
`runAsUser`-ით, `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`,
`seccompProfile` `RuntimeDefault`.

## დავალება 6. control plane-ის პრივატული წვდომა და VPC endpoints

ვამოწმებთ კლასტერის `resourcesVpcConfig`-ს - მოდული `eks_v2_control_plane` უკვე რთავს
ორივე ფლაგს (`endpoint_public_access = true`, `endpoint_private_access = true`):

```bash
CLUSTER=$(kubectl config current-context | sed 's|.*/||')
mkdir -p /var/work/tests/artifacts/6

aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig' --output json \
  | tee /var/work/tests/artifacts/6/private_endpoint.txt
```

გამონატანში - `"endpointPrivateAccess": true`. ვამატებთ ფაილს განმარტებას:

```bash
cat >> /var/work/tests/artifacts/6/private_endpoint.txt <<'EOF'

სრულად პრივატული კლასტერისთვის (node-ები ინტერნეტზე გასვლის გარეშე) საჭიროა VPC
endpoints: ecr.api და ecr.dkr (კონტეინერის images-ის ჩამოსატანად), s3 gateway endpoint
(ECR image-ის ფენები ფიზიკურად ინახება S3-ში, ამიტომ მის გარეშე image არ ჩამოტვირთვა
მაშინაც, როცა ecr.api და ecr.dkr ადგილზეა), sts (IRSA token-ის დროებით credentials-ზე
გაცვლა), ec2 (node-ის რეგისტრაცია და DNS სახელი), logs (log-ების მიწოდება CloudWatch-ში)
და eks (EKS API-ზე წვდომა VPC-იდან). control plane-ის private access (ამ კლასტერზე
უკვე ჩართული) სავალდებულოა endpoints-ის სიისგან დამოუკიდებლად - მის გარეშე node-ები არ
შეძლებენ დარეგისტრირებას API-server-ზე პრივატული subnet-იდან.
EOF

cat /var/work/tests/artifacts/6/private_endpoint.txt
```

## სწრაფი შემოწმება

```bash
check_result
```
