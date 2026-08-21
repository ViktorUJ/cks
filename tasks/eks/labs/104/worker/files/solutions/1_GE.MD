[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 104 - ეტალონური გადაწყვეტა (workload identity: IRSA და Pod Identity)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე (worker) SSH-ის მეშვეობით. kubectl უკვე
კონფიგურირებულია კლასტერზე, ხოლო terraform-მა უკვე შექმნა S3 bucket, Secrets Manager-ის
secret და ორივე IAM-როლი - მათი სახელები და ARN-ები დევს მინიშნების ფაილში
`/home/ubuntu/lab104_hints.txt`.

```bash
cat ~/lab104_hints.txt
```

შემდეგ მაგალითებში გამოყენებულია ცვლადები ამ ფაილიდან - ჩასვათ საკუთარი მნიშვნელობები ან
ექსპორტი გააკეთეთ სესიის დასაწყისში:

```bash
export BUCKET_NAME=$(grep '^bucket_name' ~/lab104_hints.txt | awk '{print $3}')
export SECRET_NAME=$(grep '^secret_name' ~/lab104_hints.txt | awk '{print $3}')
export IRSA_ROLE_ARN=$(grep '^irsa_role_arn' ~/lab104_hints.txt | awk '{print $3}')
export POD_IDENTITY_ROLE_ARN=$(grep '^pod_identity_role_arn' ~/lab104_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab104_hints.txt | awk '{print $3}')
```

## დავალება 1. Namespace `eks-104`

```bash
kubectl create namespace eks-104
```

## დავალება 2. ServiceAccount IRSA-ანოტაციით

როლი `irsa_role_arn` უკვე შექმნილია terraform-ის მიერ trust policy-ით, რომელიც ზუსტად ამ
`ServiceAccount`-ს ენდობა (`system:serviceaccount:eks-104:s3-reader-irsa` - თავი 16).
ვქმნით SA ანოტაციით:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-reader-irsa
  namespace: eks-104
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

kubectl get sa s3-reader-irsa -n eks-104 -o yaml
```

## დავალება 3. Pod IRSA-ით: იდენტურობის შემოწმება

ვქმნით პოდს, რომელიც იყენებს ამ SA-ს. Pod Identity Webhook პოდის სტარტისას შეუტანს
ცვლადებს `AWS_ROLE_ARN` და `AWS_WEB_IDENTITY_TOKEN_FILE` (თავი 16):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: irsa-app
  namespace: eks-104
spec:
  serviceAccountName: s3-reader-irsa
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/irsa-app -n eks-104 --timeout=120s
```

ვამოწმებთ, რომ SDK-მ პოდის შინაგანად კრედენშალები web identity-ის მეშვეობით მიიღო, არა
ნოუდის როლის მეშვეობით:

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl exec irsa-app -n eks-104 -- aws sts get-caller-identity \
  > /var/work/tests/artifacts/3/irsa_identity.txt
cat /var/work/tests/artifacts/3/irsa_identity.txt
```

output-ში `Arn` უნდა იყოს სახის `arn:aws:sts::<account>:assumed-role/<prefix>-irsa-role/...`
- ეს ადასტურებს, რომ პოდი დადის IRSA-როლის ქვეშ, არა ნოუდის როლის ქვეშ.

## დავალება 4. ობიექტის წაკითხვა S3-დან IRSA-ს მეშვეობით

როლი `irsa` ატარებს მხოლოდ `s3:ListBucket`-სა და `s3:GetObject`-ს ამ კონკრეტულ bucket-ზე
(თავი 16, least privilege). ვკითხავთ ობიექტს, რომელიც terraform-მა bucket-ში დადო:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec irsa-app -n eks-104 -- aws s3 cp "s3://${BUCKET_NAME}/hello.txt" - \
  > /var/work/tests/artifacts/4/s3_read.txt
cat /var/work/tests/artifacts/4/s3_read.txt
```

ფაილში უნდა იყოს სტრიქონი `hello from s3` - ობიექტის შინაარსი, რომელიც მოდულმა
`eks_v2_workload_identity_demo` დადო.

## დავალება 5. Pod Identity-ის ასოციაცია

IRSA-ს განსხვავებით, Pod Identity-სთვის ანოტაცია SA-ზე არ სჭირდება - კავშირი
`namespace + SA -> როლი` ცხოვრობს EKS API-ში, არა Kubernetes-ში (თავი 17). ვქმნით SA-სა
და ასოციაციას:

```bash
kubectl create serviceaccount secret-reader-podid -n eks-104

aws eks create-pod-identity-association \
  --cluster-name "${CLUSTER_NAME}" \
  --namespace eks-104 \
  --service-account secret-reader-podid \
  --role-arn "${POD_IDENTITY_ROLE_ARN}"

mkdir -p /var/work/tests/artifacts/5
aws eks list-pod-identity-associations --cluster-name "${CLUSTER_NAME}" --namespace eks-104 \
  > /var/work/tests/artifacts/5/association.txt
cat /var/work/tests/artifacts/5/association.txt
```

## დავალება 6. Pod Pod Identity-ით: secret ნოუდის როლის ნაცვლად

ვქმნით პოდს SA `secret-reader-podid`-ით. აგენტი `eks-pod-identity-agent` (ამ ლაბაში უკვე
დაყენებული როგორც managed addon) მას მიაწოდებს როლის `pod_identity_role_arn`
კრედენშალებს ლოკალური endpoint `169.254.170.23`-ის მეშვეობით (თავი 17):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: podid-app
  namespace: eks-104
spec:
  serviceAccountName: secret-reader-podid
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/podid-app -n eks-104 --timeout=120s
```

ვკითხავთ secret-ს და ერთი ბრძანებით ვამოწმებთ იდენტურობას:

```bash
mkdir -p /var/work/tests/artifacts/6
{
  echo "--- caller identity ---"
  kubectl exec podid-app -n eks-104 -- aws sts get-caller-identity
  echo "--- secret value ---"
  kubectl exec podid-app -n eks-104 -- aws secretsmanager get-secret-value \
    --secret-id "${SECRET_NAME}" --query SecretString --output text
} > /var/work/tests/artifacts/6/secret_read.txt
cat /var/work/tests/artifacts/6/secret_read.txt
```

`get-caller-identity`-დან `Arn` აჩვენებს `assumed-role/<prefix>-pod-identity-role/...`,
ხოლო secret-ის მნიშვნელობა - JSON ველებით `username`/`password` (`demo`/`demo123`),
რომლებიც terraform-მა Secrets Manager-ში დადო.

## დავალება 7. სიმპტომი: ნოუდის როლს არ აქვს წვდომა bucket-ზე

ვქმნით პოდს IRSA-სთან ან Pod Identity-სთან კავშირის **გარეშე** - ის მემკვიდრედ მიიღებს
მხოლოდ ნოუდის როლის უფლებებს (თავი 16, ნაწილი 16.1: «ნოუდს როლი მისცემა - და უფლებები
ყველა პოდზე გაჟონა» მუშაობს საპირისპირო მიმართულებითაც, ნოუდის როლი პრიკლადულ უფლებებს
სულ არ ატარებს):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: plain-app
  namespace: eks-104
spec:
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/plain-app -n eks-104 --timeout=120s
```

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl exec plain-app -n eks-104 -- aws s3 ls "s3://${BUCKET_NAME}/" \
  > /var/work/tests/artifacts/7/node_role_denied.txt 2>&1
cat /var/work/tests/artifacts/7/node_role_denied.txt
```

ბრძანება უნდა დამთავრდეს შეცდომით `AccessDenied` (ან `is not authorized to perform`) -
ნოუდის როლი ამ bucket-ზე `s3:*`-ს არ ატარებს, მას გააქვს მხოლოდ სისტემური კომპონენტების
უფლებები (pull ECR-იდან, CNI-ის მუშაობა). ეს ნათლად აჩვენებს განსხვავებას: IRSA-სა ან Pod
Identity-ს გარეშე პოდი იღებს მხოლოდ იმას, რაც ნოუდის როლს აქვს, არა «ყველაფერს, რაც
სადმე ანგარიშში კონფიგურირებულია».

## სწრაფი გადამოწმება

```bash
check_result
```
