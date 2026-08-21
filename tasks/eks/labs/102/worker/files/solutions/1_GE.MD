[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 102 - ეტალონური გადაწყვეტა (წვდომა კლასტერზე: IAM, RBAC, access entries)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე (worker) SSH-ის მეშვეობით. kubectl უკვე
კონფიგურირებულია კლასტერზე. Worker-ის როლს აქვს `eks:*` (საკმარისია ყველა access
entry/access policy ბრძანებისთვის) და წერტილოვანი უფლებები
`iam:CreateRole/GetRole/DeleteRole/PutRolePolicy` პლუს `sts:AssumeRole`, შეზღუდული
როლებზე სახელით `*-test-*` - ეს საკმარისია, რომ შექმნას ტესტური როლი და ნამდვილად
გააკეთოს მასზე assume-role, სხვა ლაბების უფლებების შეხების გარეშე.

## მეორე პრინციპალის შერჩევა

კლასტერი უკვე იქმნება მოდულით `eks_v2_control_plane` რეჯიმში `authenticationMode = API`
(v21 `terraform-aws-modules/eks/aws` `enable_cluster_creator_admin_permissions = true`-ით).
Worker-ის როლს უკვე აქვს საკუთარი access entry `AmazonEKSClusterAdminPolicy`-ით
(`terraform/modules/eks_v2_work_pc/iam.tf`) - ეს ადასტურებს, რომ API access entries
კლასტერში ჩართული და მუშაა.

ამ ლაბის დავალებებისთვის საჭირო არის **მეორე** IAM-პრინციპალი, რომელსაც ჯერ არ აქვს
წვდომა კლასტერზე. Karpenter-ის ნოუდის როლი ამისთვის არ ვარგა: submodule-ი
`terraform-aws-modules/eks/aws//modules/karpenter` მისთვის ავტომატურად ქმნის access
entry-ს ტიპით `EC2_LINUX` (`create_access_entry = true` ნაგულისხმევად), ხოლო ერთი
IAM-პრინციპალი ერთდროულად ორ access entry-ში ვერ ხვდება. ამიტომ ლაბა ქმნის ცალკე
ტესტურ როლს AWS CLI-ის მეშვეობით პირდაპირ worker-იდან, ნდობით მხოლოდ თავად worker-ის
როლზე (`sts:AssumeRole` დაშვებულია მხოლოდ worker-ის როლის ARN-ისთვის, არავის სხვას).

## დავალება 1. ინვენტარიზაცია: authenticationMode

```bash
mkdir -p /var/work/tests/artifacts/1
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.accessConfig' \
  > /var/work/tests/artifacts/1/accessconfig.json
cat /var/work/tests/artifacts/1/accessconfig.json
```

მოსალოდნელი გამოტანა მსგავსია:

```json
{
    "authenticationMode": "API",
    "bootstrapClusterCreatorAdminPermissions": true
}
```

`authenticationMode` უდრის `API`-ს - კლასტერში არ არსებობს `aws-auth` ConfigMap,
პრინციპალების ყველა ჩავენება მიდის access entries-ის მეშვეობით.

## დავალება 2. ტესტური IAM-როლი მეორე პრინციპალად

ვიგებთ worker-ის როლის ARN-ს და account id-ს (მას გავუშვებთ ტესტური როლის ასუმებას):

```bash
WORKER_ARN=$(aws sts get-caller-identity --query Arn --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "$WORKER_ARN"
```

`get-caller-identity` EC2-პროფილზე მდგარი ინსტანსისთვის აჩვენებს **სესიის** ARN-ს
(`assumed-role/.../i-...`), არა თავად როლის ARN-ს. Trust policy-სა და access
entry-სთვის საჭირო არის როლის ARN, ამიტომ ვაწყობთ მას სესიიდან:

```bash
ROLE_NAME=$(echo "$WORKER_ARN" | sed -E 's#.*assumed-role/([^/]+)/.*#\1#')
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "$ROLE_ARN"
```

ვქმნით ტესტურ როლს. სახელი უსათუოდ შეიცავს `-test-`-ს, სხვაგვარად worker ვერ შეძლებს
მის შექმნას, ვერც ასუმებას (მისი IAM-პოლიტიკა შეზღუდულია ამ ქვესტრიქონით):

```bash
TEST_ROLE_NAME="eks-task102-test-viewer"

cat > /tmp/trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": { "AWS": "${ROLE_ARN}" }
    }
  ]
}
EOF

aws iam create-role --role-name "$TEST_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust.json

TEST_ROLE_ARN=$(aws iam get-role --role-name "$TEST_ROLE_NAME" \
  --query 'Role.Arn' --output text)

mkdir -p /var/work/tests/artifacts/2
echo "$TEST_ROLE_ARN" > /var/work/tests/artifacts/2/test_role_arn.txt
cat /var/work/tests/artifacts/2/test_role_arn.txt
```

როლს შინაგანად არ სჭირდება ნებისმიერი IAM-უფლება, assume-ის გარდა - მისი ყველა
ნამდვილი უფლებამოსილება განისაზღვრება კლასტერით access entry-ისა და access
policy/RBAC-ის მეშვეობით, არა IAM-ით.

## დავალება 3. Access entry ტესტური როლისთვის, ჯგუფი viewers

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)

aws eks create-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --kubernetes-groups viewers \
  --type STANDARD

aws eks describe-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN"
```

`username`-ს არ ვასწორებთ - EKS თავად ჩაანაცხობს მას, როგორც დოკუმენტაცია
გვირჩევს. ახლა პრინციპალი ცნობილია კლასტერისთვის და ხვდება Kubernetes-ჯგუფში
`viewers`, მაგრამ ჯერ ერთი უფლების გარეშე: ჩანაწერი თავად უფლებებს არ აძლევს, ის
მხოლოდ სუბიექტს აძლევს RBAC-ისთვის.

## დავალება 4. ClusterRole და ClusterRoleBinding ჯგუფზე viewers

კლასიკური RBAC access entry-ის ზემოთ, access policy-ის გარეშე:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: viewers-pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: viewers-pod-reader
subjects:
- kind: Group
  name: viewers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: viewers-pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl get clusterrole viewers-pod-reader -o yaml
kubectl get clusterrolebinding viewers-pod-reader -o yaml
```

ჯგუფს `viewers` ახლა შეუძლია წაიკითხოს pods ყველა namespace-ში, და მეტი არაფერი.

## დავალება 5. უფლებების ხელით გადამოწმება assume-role-ის მეშვეობით

ეს არის ნაბიჯი, რომელსაც სტუდენტი ხელით ასრულებს - ავტოტესტი ამოწმებს მხოლოდ
შედეგის არტეფაქტს, არა თავად assume-role-ს (დროებითი კრედენშალები `tests.bats`-ის
შიგნით საჭირო არ არის).

ვიღებთ ტესტური როლის დროებით კრედენშალებს და ცალკე kubeconfig alias-ის ქვეშ:

```bash
CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name test-viewer-session)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

aws eks update-kubeconfig --name "$CLUSTER" --region eu-central-1 \
  --alias test-viewer --kubeconfig /tmp/test-viewer.kubeconfig

kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
kubectl --kubeconfig /tmp/test-viewer.kubeconfig create namespace test
```

მოსალოდნელი შედეგი: `get pods -A` მუშაობს (მხოლოდ წაკითხვა დაშვებულია
RBAC-ბაინდინგით ჯგუფზე `viewers`), ხოლო `create namespace test` ჩავარდება
`Forbidden`-ით - ჯგუფის `viewers` RBAC არ შეიცავს უფლებას `namespaces`-ზე.
ვბრუნდებით worker-ის უფლებებზე:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

ვინახავთ ხელით გადამოწმების შედეგს არტეფაქტში:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/rbac_check.txt <<'EOF'
kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
  -> გამოვა: RBAC-ბაინდინგი viewers-pod-reader აძლევს get/list-ს pods-ზე.

kubectl --kubeconfig /tmp/test-viewer.kubeconfig create namespace test
  -> Forbidden: ჯგუფს viewers არ აქვს namespace-ის შექმნის უფლება,
     access entry-მ სუბიექტი მისცა, მაგრამ RBAC-მა ეს მოქმედება არ დაუშვა.
EOF
cat /var/work/tests/artifacts/5/rbac_check.txt
```

## დავალება 6. Access policy AmazonEKSViewPolicy access entry-ის ზემოთ

```bash
aws eks associate-access-policy --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster

aws eks list-associated-access-policies --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN"
```

ახლა ტესტურ როლს აქვს ორი დამოუკიდებელი უფლებების წყარო: RBAC-ჯგუფი `viewers`
(get/list pods-ზე) და access policy `AmazonEKSViewPolicy` (კლასტერის უმეტესი
რესურსების წაკითხვა, secrets-ის გარეშე). გაითვალისწინეთ: `kubectl --kubeconfig
/tmp/test-viewer.kubeconfig auth can-i --list` არ დაგანახებთ access policy-დან
მომდინარე უფლებებს - ის არ არის გამოხატული RBAC-ობიექტებით, მისი დანახვის
ერთადერთი გზა - `list-associated-access-policies`.

## დავალება 7. დიაგნოსტიკა: Unauthorized წინააღმდეგ Forbidden-ის

ვაჩვენებთ განსხვავებას ნამდვილ ბრძანებებზე. ვქმნით კიდევ ერთ როლს access
entry-ის **გარეშე** - ის უცნობი იქნება კლასტერისთვის:

```bash
NOBODY_ROLE_NAME="eks-task102-test-nobody"
aws iam create-role --role-name "$NOBODY_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust.json
NOBODY_ARN=$(aws iam get-role --role-name "$NOBODY_ROLE_NAME" --query 'Role.Arn' --output text)

CREDS2=$(aws sts assume-role --role-arn "$NOBODY_ARN" --role-session-name nobody-session)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS2" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS2" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS2" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

aws eks update-kubeconfig --name "$CLUSTER" --region eu-central-1 \
  --alias test-nobody --kubeconfig /tmp/test-nobody.kubeconfig

kubectl --kubeconfig /tmp/test-nobody.kubeconfig get pods -A
# error: You must be logged in to the server (Unauthorized)

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
aws iam delete-role --role-name "$NOBODY_ROLE_NAME"
```

ვადარებთ namespace-ის შექმნის მცდელობას იმავე ტესტური როლით დავალება 5-იდან
(`test-viewer.kubeconfig`) - იქ კლასტერი პრინციპალს იცნობს, მაგრამ RBAC არ
უშვებს მოქმედებას, ანუ `Forbidden`. განსხვავება ერთშია: `Unauthorized` ნიშნავს,
რომ კლასტერს ვერ იპოვა access entry ამ ARN-ისთვის (`aws eks
list-access-entries` საერთოდ არ დაანახებდა ასეთ ARN-ს), `Forbidden` ნიშნავს,
რომ access entry არსებობს, მაგრამ RBAC/access policy ამ მოქმედებას არ
უშვებს.

```bash
aws eks list-access-entries --cluster-name "$CLUSTER"
```

ვინახავთ განსხვავების განმარტებას არტეფაქტში:

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/unauthorized_vs_forbidden.txt <<'EOF'
Unauthorized (401): როლს eks-task102-test-nobody არ აქვს access entry კლასტერში.
kubectl get pods -A მისი kubeconfig-ით პასუხობს "You must be logged in to the server
(Unauthorized)" - RBAC-მდე საკითხი არ მისულა, აუთენტიფიკაცია არ გავიდა. გადამოწმება:
aws eks list-access-entries --cluster-name <cluster> არ შეიცავს მის ARN-ს.

Forbidden (403): როლს eks-task102-test-viewer აქვს access entry (ჯგუფი viewers) და
შეუძლია პოდების წაკითხვა, მაგრამ kubectl create namespace test იმავე როლით პასუხობს
Forbidden-ით - კლასტერმა პრინციპალი იცნო, მაგრამ ჯგუფის viewers RBAC არ უშვებს
namespace-ის შექმნას.
EOF
cat /var/work/tests/artifacts/7/unauthorized_vs_forbidden.txt
```

## დავალება 8. Access entry-ის წაშლა და აღდგენა

ვხსნით access entry-ს და ვრწმუნდებით, რომ წვდომა გაქრა, შემდეგ ვქმნით ჩანაწერს
ხელახლა (კლასტერი რჩება სამუშაო მდგომარეობაში გადამოწმებისთვის):

```bash
aws eks delete-access-entry --cluster-name "$CLUSTER" --principal-arn "$TEST_ROLE_ARN"

CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" --role-session-name test-viewer-2)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
# error: You must be logged in to the server (Unauthorized)

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

aws eks create-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --kubernetes-groups viewers --type STANDARD

aws eks describe-access-entry --cluster-name "$CLUSTER" --principal-arn "$TEST_ROLE_ARN"
```

`delete-access-entry` ჩანაწერთან ერთად წაშლის ყველა მის access policy-ასოციაციასაც -
დავალება 6-ის policy (`AmazonEKSViewPolicy`) ჩანაწერის წაშლის შემდეგ თავისთვის არ
აღდგება. ვაბრუნებთ მას გამოხატულად, რომ სტენდი დარჩეს იმ მდგომარეობაში, რასაც
დავალება 6-ში მივაღწიეთ:

```bash
aws eks associate-access-policy --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster

aws eks list-associated-access-policies --cluster-name "$CLUSTER" --principal-arn "$TEST_ROLE_ARN"
```

ვინახავთ წაშლა/აღდგენის ციკლის შედეგს არტეფაქტში:

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/delete_recreate.txt <<'EOF'
aws eks delete-access-entry --cluster-name <cluster> --principal-arn <test_role_arn>
kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
  -> error: You must be logged in to the server (Unauthorized): წაშლილმა access entry-მ
     პრინციპალი კლასტერისთვის დაუყოვნებლივ უცნობი გახადა.

aws eks create-access-entry --cluster-name <cluster> --principal-arn <test_role_arn> \
  --kubernetes-groups viewers --type STANDARD
  -> წვდომა აღდგა, RBAC-ბაინდინგი ჯგუფზე viewers არ შეცვლილა და ისევ მუშაობს.
EOF
cat /var/work/tests/artifacts/8/delete_recreate.txt
```

## სწრაფი გადამოწმება

```bash
check_result
```
