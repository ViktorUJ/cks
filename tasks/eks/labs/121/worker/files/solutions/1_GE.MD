[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 121 - საცნობარო ამოხსნა (access troubleshooting: access entries, IRSA, kubeconfig)

ყველა ბრძანება გაშვებულია worker-მანქანაზე SSH-ის საშუალებით. kubectl უკვე
კონფიგურირებულია კლასტერისთვის, ხოლო terraform-მა უკვე შექმნა S3 bucket და IRSA role
component `eks_irsa_break_demo`-სთვის - მათი სახელები და ARN-ები hint-ფაილშია
`/home/ubuntu/lab121_hints.txt`.

```bash
cat ~/lab121_hints.txt
```

ამოხსნის დარჩენილი ნაწილი იმ ფაილის ცვლადებს იყენებს:

```bash
export BUCKET_NAME=$(grep '^bucket_name' ~/lab121_hints.txt | awk '{print $3}')
export IRSA_ROLE_ARN=$(grep '^irsa_role_arn' ~/lab121_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab121_hints.txt | awk '{print $3}')
```

ლაბორატორია მოიცავს წვდომის ორ დამოუკიდებელ ღერძს 47-ე თავიდან: ადამიანი/CI ვერ ხერხდება
კლასტერში (დავალებები 1-4), და pod-ს AWS-ზე უჩენდება `AccessDenied` (დავალებები 5-8).

## დავალება 1. Namespace `eks-121`

```bash
kubectl create namespace eks-121
```

## დავალება 2. Unauthorized სიმპტომი: role access entry-ის გარეშე

ჩვენ ვქმნით ტესტურ IAM role-ს, რომელსაც access entry საერთოდ არა აქვს. worker-ის role-ს
საშუალება აქვს მართოს მხოლოდ ის role-ები, სახელში რომელთაცაა `-test-` (იხილეთ `iam.tf`
module `eks_v2_work_pc`-ის), ამიტომ სახელში ეს substring უნდა იყოს:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TEST_ROLE_NAME="eks-task121-test-noaccess"

cat > /tmp/trust-worker.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "AWS": "$(aws sts get-caller-identity --query Arn --output text)" },
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role --role-name "$TEST_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust-worker.json

export TEST_ROLE_ARN=$(aws iam get-role --role-name "$TEST_ROLE_NAME" \
  --query 'Role.Arn' --output text)
```

worker-ის role-ს `sts:AssumeRole` კონკრეტულად აქვს იმ ARN-ებისთვის, სახელში რომელთაცაა
`-test-`, ამიტომ ამ role-ს პირდაპირ შეგვიძლია assume-role გავუკეთოთ:

აქ თანმიმდევრობა მნიშვნელოვანია. ჩვენ ცალკე kubeconfig-ს ვაწყობთ **worker-ის
credentials-ით, სანამ** `assume-role`-ს გავაკეთებთ: `aws eks update-kubeconfig` იძახებს
`eks:DescribeCluster`-ს, ხოლო ტესტურ role-ს IAM policy საერთოდ არ აქვს, ამიტომ იმ role-ის
ქვეშ ბრძანება ჩავარდებოდა `AccessDeniedException`-ით და ფაილი არ შეიქმნებოდა. ეს, სხვათა
შორის, ამ ჯაჭვში მესამე ტიპის შეცდომაა: `AccessDenied` IAM-იდან (AWS API-ზე უფლების
არარსებობა) განსხვავდება ორივესგან - `Unauthorized`-გან (identity არ არის დამაპებული
კლასტერში) და `Forbidden`-გან (RBAC). `kubectl` თავადვე შემდეგ ტოკენს იღებს `aws eks
get-token`-ის საშუალებით, და ეს ტოკენი მოვა იმ identity-ის credentials-იდან, რომელიც
environment ცვლადებში იმ დროისთვისაა:

```bash
aws eks update-kubeconfig --name "$CLUSTER_NAME" --kubeconfig /tmp/kubeconfig-test

CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name lab121-noaccess --duration-seconds 900)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')
```

ვამოწმებთ ამ identity-ის წვდომას კლასტერზე - access entry-ის გარეშე ის დამაპებული არაა,
ამიტომ ველოდებით `Unauthorized`-ს (47-ე თავი, 47.3 პარაგრაფი):

```bash
mkdir -p /var/work/tests/artifacts/2
kubectl --kubeconfig /tmp/kubeconfig-test get pods -A \
  > /var/work/tests/artifacts/2/unauthorized.txt 2>&1
cat /var/work/tests/artifacts/2/unauthorized.txt
```

ფაილში უნდა იყოს ხაზი სიტყვით `Unauthorized` - API server-ს ამ IAM identity-ის
შესატყვისი ვერცერთი access entry ან aws-auth ჩანაწერი ვერ დაუდგინა.

worker-ის credentials-ს აღვადგენთ (session ცვლადები უკვე არ გვინდა):

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

## დავალება 3. Unauthorized-ის გამოსწორება: access entry + AmazonEKSViewPolicy

ვქმნით access entry-ს ტესტური role-ისთვის და ვანიჭებთ მას `AmazonEKSViewPolicy`
access policy-ს კლასტერის scope-ზე (47-ე თავი, 47.4 პარაგრაფი):

```bash
aws eks create-access-entry --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$TEST_ROLE_ARN" --type STANDARD

aws eks associate-access-policy --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster
```

`assume-role`-ს ვიმეორებთ (პირველი session-ი უკვე ამოწურულია ან დასრულებულია) და იმავე
დროებით kubeconfig-ით იმავე request-ს ვაკეთებთ - ახლა უკვე pod-ების სია უნდა დაბრუნდეს,
`Unauthorized`-ის ნაცვლად:

```bash
CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name lab121-access --duration-seconds 900)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')

mkdir -p /var/work/tests/artifacts/3
kubectl --kubeconfig /tmp/kubeconfig-test get pods -A \
  > /var/work/tests/artifacts/3/authorized.txt 2>&1
cat /var/work/tests/artifacts/3/authorized.txt
```

ფაილში ახლა ხაზები აქვს ტიპის `NAMESPACE ... POD ...` - access entry-მა `Unauthorized`
შეცდომა მოაცილა.

## დავალება 4. Forbidden სიმპტომი: View წვდომა ჩაწერას არ იძლევა

Role-ს მხოლოდ `AmazonEKSViewPolicy` (წაკითხვა) აქვს. იმავე დროებითი kubeconfig-ით namespace-ის
შექმნას ვცდილობთ - RBAC-ი ამას `Forbidden`-ით უნდა უკრძალავდეს (47-ე თავი, 47.3
პარაგრაფი):

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl --kubeconfig /tmp/kubeconfig-test create namespace test-forbidden \
  > /var/work/tests/artifacts/4/forbidden.txt 2>&1
cat /var/work/tests/artifacts/4/forbidden.txt
```

იმავე ფაილს ვამატებთ განმარტებას სხვაობაზე დავალება 2-ს (`Unauthorized`) და დავალება
4-ს (`Forbidden`) შორის:

```bash
cat >> /var/work/tests/artifacts/4/forbidden.txt <<'EOF'

Difference: in task 2 the role wasn't mapped into the cluster at all - the API server
couldn't prove the identity, that's Unauthorized (an authentication failure, the authn
layer). In task 4 the identity is already proven and mapped via an access entry, but RBAC
(AmazonEKSViewPolicy only grants read) doesn't allow create namespace - that's Forbidden
(an authorization failure, the authz layer). The fixes differ: Unauthorized is fixed in the
mapping (access entry / aws-auth), Forbidden is fixed in RBAC (Role, ClusterRole, policy
binding).
EOF
cat /var/work/tests/artifacts/4/forbidden.txt

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

## დავალება 5. ServiceAccount სწორი IRSA ანოტაციით

`eks_irsa_break_demo` role უკვე შექმნილია terraform-ის მიერ, trust policy-ით, რომელიც
ზუსტად ენდობა `system:serviceaccount:eks-121:demo-reader`-ს (16-ე თავი, 47-ე თავის 47.6
პარაგრაფი):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-reader
  namespace: eks-121
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: irsa-app
  namespace: eks-121
spec:
  serviceAccountName: demo-reader
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/irsa-app -n eks-121 --timeout=120s
```

ვამოწმებთ identity-ს და S3-იდან ვკითხულობთ ობიექტს:

```bash
mkdir -p /var/work/tests/artifacts/5
{
  echo "--- caller identity ---"
  kubectl exec irsa-app -n eks-121 -- aws sts get-caller-identity
  echo "--- s3 object ---"
  kubectl exec irsa-app -n eks-121 -- aws s3 cp "s3://${BUCKET_NAME}/hello.txt" -
} > /var/work/tests/artifacts/5/irsa_ok.txt
cat /var/work/tests/artifacts/5/irsa_ok.txt
```

`Arn` output-ში ისე უნდა გამოიყურებოდეს, როგორც `assumed-role/<prefix>-irsa-role/...`, ხოლო
მეორე ბლოკი უნდა იყოს ხაზი `hello from s3` (ობიექტი, terraform-მა რაც იქ დადო).

## დავალება 6. AccessDenied სიმპტომი: გატეხილი ანოტაცია სხვა namespace-ში

ვქმნით მეორე SA-ს, ზუსტად იმავე ანოტაციით იმავე role-ზე, მაგრამ namespace `default`-ში.
Role-ის trust policy ელოდება `sub = system:serviceaccount:eks-121:demo-reader`-ს, ხოლო
ამ SA-ის `sub` იქნება `system:serviceaccount:default:demo-reader-broken` - პირობა არ
ემთხვევა (47-ე თავი, 47.6 პარაგრაფი):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-reader-broken
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-app
  namespace: default
spec:
  serviceAccountName: demo-reader-broken
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/broken-app -n default --timeout=120s
```

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl exec broken-app -n default -- aws sts get-caller-identity \
  > /var/work/tests/artifacts/6/broken.txt 2>&1
cat /var/work/tests/artifacts/6/broken.txt
```

ბრძანება ტოკენის გაცვლის შეცდომით ჩავარდნილი უნდა იყოს: `AccessDenied` ან
`WebIdentityErr` (ზუსტი შეტყობინება SDK/CLI ვერსიის მიხედვით სხვადასხვაა, მაგრამ არსი
იგივეა - STS-მა `sts:AssumeRoleWithWebIdentity` ჩააგდო, რადგან ტოკენში `sub` არ ემთხვეოდა
trust policy-ის პირობას).

## დავალება 7. დიაგნოსტიკა: ანოტაციების შედარება და `sub`-ის ძირეული მიზეზი

ვადარებთ SA-ის ანოტაციას ორივე namespace-ში და ვხსნით მიზეზს:

```bash
mkdir -p /var/work/tests/artifacts/7
{
  echo "--- eks-121/demo-reader ---"
  kubectl get sa demo-reader -n eks-121 \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
  echo
  echo "--- default/demo-reader-broken ---"
  kubectl get sa demo-reader-broken -n default \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
  echo
  echo
  cat <<'TXT'
Both annotations point at the same IRSA role, but the role's trust policy checks the sub
condition on the STS token: system:serviceaccount:<namespace>:<serviceaccount>. For
demo-reader that's system:serviceaccount:eks-121:demo-reader - it matches the role's
condition, so the exchange is allowed. For demo-reader-broken the token carries
sub=system:serviceaccount:default:demo-reader-broken - a different namespace and a
different SA name, so the StringEquals condition doesn't match, and
sts:AssumeRoleWithWebIdentity is rejected regardless of the fact that the role ARN in the
annotation is the same.
TXT
} > /var/work/tests/artifacts/7/diagnostics.txt
cat /var/work/tests/artifacts/7/diagnostics.txt
```

## დავალება 8. შეჯამება: წვდომის ორი ღერძი

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/summary.txt <<'EOF'
The human axis (tasks 2-4) lives in the chain kubectl - IAM - EKS authenticator - RBAC:
Unauthorized means the IAM identity couldn't be proven or mapped into the cluster at all
(fixed via an access entry or aws-auth), while Forbidden means the identity is already
known, but RBAC didn't allow that specific action (fixed via Role/ClusterRoleBinding). The
pod axis (tasks 5-7) lives in the chain pod - ServiceAccount - STS - IAM role: AccessDenied
or WebIdentityErr means the role's trust policy didn't match the ServiceAccount token's sub
(fixed by editing the sub condition in the trust policy or the SA annotation). The key
difference: on the first axis the fix is RBAC inside the cluster, on the second axis the fix
is the IAM role's trust policy in AWS, and the two must not be confused.
EOF
cat /var/work/tests/artifacts/8/summary.txt
```

## სწრაფი შემოწმება

```bash
check_result
```
