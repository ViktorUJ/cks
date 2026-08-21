[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 130 - ეტალონური გამოსავალი (ECR და supply chain)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე (worker) SSH-ის მეშვეობით. AWS CLI
უკვე დაკონფიგურირებულია საჭირო ანგარიშზე ინსტანსის როლის მეშვეობით
(დამატებითი `aws configure` არ არის საჭირო), kubectl - ლაბის კლასტერზე.
`docker`-ის ნაცვლად ვიყენებთ `podman`-ს (უკვე დაინსტალირებულია worker-ზე).

განვსაზღვროთ account id და პრივატული რეესტრის მისამართი ერთხელ:

```bash
export AWS_REGION=eu-central-1
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_HOST="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo "$ECR_HOST"
```

## დავალება 1. რეპოზიტორი IMMUTABLE ტეგებით და scanOnPush-ით

```bash
aws ecr create-repository \
  --repository-name eks-lab130/app \
  --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true \
  --region "$AWS_REGION"

aws ecr describe-repositories --repository-names eks-lab130/app --region "$AWS_REGION"
```

დარწმუნდით, რომ გამოტანაში არის `imageTagMutability: IMMUTABLE` და
`imageScanningConfiguration.scanOnPush: true`.

## დავალება 2. იმიჯის push ტეგით v1

ვშედით რეესტრში 12-საათიანი ტოკენით და ხელახლა ვატეგირებთ საჯარო იმიჯს:

```bash
aws ecr get-login-password --region "$AWS_REGION" \
  | podman login --username AWS --password-stdin "$ECR_HOST"

podman pull docker.io/library/alpine:3.19
podman tag docker.io/library/alpine:3.19 "$ECR_HOST/eks-lab130/app:v1"
podman push "$ECR_HOST/eks-lab130/app:v1"

aws ecr describe-images --repository-name eks-lab130/app --region "$AWS_REGION"
```

`describe-images`-ის გამოტანაში უნდა იყოს ერთი იმიჯი ტეგით `v1`.

ორი პრაქტიკული მომენტი. პირველი: `alpine` აქ არჩეულია არა „ნაკლები წონისთვის“,
არამედ იმის გამო, რომ ECR-ის საბაზისო სკანირებას შეუძლია მისი პაკეტების ბაზის
დაშლა - დავალება 4-ში იქნება ნამდვილი findings (გადამოწმებულია: HIGH 1,
MEDIUM 1, LOW 2 `alpine:3.19`-ზე). მეორე: დავალებები 2-6 ერთ SSH-სესიაში
შეასრულეთ. `podman login` ტოკენს წერს `$XDG_RUNTIME_DIR/containers/auth.json`-ში,
ხოლო ეს დირექტორია იშლება მომხმარებლის სესიასთან ერთად, ამიტომ ხელახალი
დაკავშირების შემდეგ push პასუხობს `unauthorized: authentication required`-ით
ECR-ის ცოცხალი 12-საათიანი ტოკენის ფონზეც.

## დავალება 3. სიმპტომი: v1 ტეგის ხელახალი push უარყოფილია

ვიღებთ სხვა იმიჯს, ვატეგირებთ იმავე `v1`-ით და ვცდილობთ გადავწეროთ:

```bash
podman pull docker.io/library/busybox:1.36
podman tag docker.io/library/busybox:1.36 "$ECR_HOST/eks-lab130/app:v1"

mkdir -p /var/work/tests/artifacts/3
podman push "$ECR_HOST/eks-lab130/app:v1" 2>&1 \
  | tee /var/work/tests/artifacts/3/denied.txt
```

push მთავრდება რეესტრის უარით (გადამოწმებულია სტენდზე):

```
tag invalid: The image tag 'v1' already exists in the 'eks-lab130/app' repository
and cannot be overwritten because the tag is immutable.
```

ზუსტად ასე მუშაობს IMMUTABLE: ტეგი `v1` უკვე დაკავებულია პირველი იმიჯით და მისი
გადაწერა შეუძლებელია. გამოტანა გრძელი იქნება - `podman` თანმიმდევრობით ცდის
რამდენიმე მანიფესტის ფორმატს (OCI, docker v2, docker v1) და ყოველ ჯერზე იღებს
იმავე უარს; არტეფაქტ `denied.txt`-ში საჭირო სტრიქონი ყოველ ცდაშია. გაითვალისწინეთ,
რომ ამ დროისთვის layer-ები უკვე ჩატვირთულია: IMMUTABLE იცავს ზუსტად ტეგის
მიბმას, არა blob-საცავს.

## დავალება 4. სკანირების findings (scan on push)

სკანირება ავტომატურად იწყება push-ის დროს (დავალება 2). ველოდებით დასრულებას
retry-ციკლის მეშვეობით (ამ CLI ვერსიაში არსებობს მზა ლოდინის ბრძანება):

```bash
aws ecr wait image-scan-complete \
  --repository-name eks-lab130/app --image-id imageTag=v1 --region "$AWS_REGION"

mkdir -p /var/work/tests/artifacts/4
aws ecr describe-image-scan-findings \
  --repository-name eks-lab130/app --image-id imageTag=v1 --region "$AWS_REGION" \
  --query '{status: imageScanStatus.status, bySeverity: imageScanFindings.findingSeverityCounts}' \
  > /var/work/tests/artifacts/4/scan-summary.txt

cat /var/work/tests/artifacts/4/scan-summary.txt
```

თუ `aws ecr wait image-scan-complete` თქვენს CLI ვერსიაში მიუწვდომელია,
შეცვალეთ ხელით retry-ციკლით:

```bash
for i in $(seq 1 30); do
  status=$(aws ecr describe-image-scan-findings \
    --repository-name eks-lab130/app --image-id imageTag=v1 --region "$AWS_REGION" \
    --query 'imageScanStatus.status' --output text 2>/dev/null)
  [[ "$status" == "COMPLETE" ]] && break
  sleep 5
done
```

`findingSeverityCounts` გამოაჩენს findings-ის რაოდენობას severity-ის მიხედვით -
`alpine:3.19`-ზე ეს იყო `{"HIGH": 1, "MEDIUM": 1, "LOW": 2}` (გადამოწმებულია
სტენდზე, კონკრეტული რიცხვები დამოკიდებულია სკანირების თარიღზე და
მოწყვლადობების ბაზაზე).

მნიშვნელოვანი გამოყენებადობის საზღვარი, რომელიც თავად უნდა შეამოწმოთ. ECR-ის
საბაზისო სკანირება კითხულობს ცნობილი დისტრიბუციების პაკეტების ბაზას, ამიტომ
იმიჯი, რომელიც აწყობილია `FROM scratch`-ით (მაგალითად, სტატიკური Go-ბინარული
ფაილი) ან distroless-ით, მას სკანირება არ შესძლება:

```bash
aws ecr describe-image-scan-findings --repository-name eks-lab130/app \
  --image-id imageTag=<scratch-იმიჯის ტეგი> --region "$AWS_REGION" \
  --query 'imageScanStatus' --output json
# {
#   "status": "FAILED",
#   "description": "UnsupportedImageError: The operating system and/or package manager
#                   are not supported."
# }
```

აქედან პრაქტიკული დასკვნა: „სკანერს არ ჰპოვა მოწყვლადობები“ და „სკანერს არ
შესძლო დათვალვა“ - ეს სხვადასხვა რაღაცეებია, ხოლო შემაჯამებელ ანგარიშებში ისინი
ადვილად ერწყმის ერთმანეთს „შენიშვნები არ არის“-ში. თუ gate-პოლიტიკას საჭიროა
სუფთა სკანი, ამოწმეთ ზუსტად სტატუსი და არა მხოლოდ findings-ის რაოდენობა.

## დავალება 5. Deploy digest-ით

`v1` იმიჯის digest შესაძლებელია ECR-იდან ავიღოთ (უფრო საიმედოა, ვიდრე
`podman inspect`, რადგან ეს ზუსტად იმ მანიფესტის digest-ია, რომელიც რეესტრშია):

```bash
DIGEST=$(aws ecr describe-images --repository-name eks-lab130/app --image-ids imageTag=v1 \
  --region "$AWS_REGION" --query 'imageDetails[0].imageDigest' --output text)
echo "$DIGEST"

kubectl create namespace eks-130 --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: digest-app
  namespace: eks-130
  labels:
    app: digest-app
spec:
  nodeSelector:
    kubernetes.io/arch: amd64
  containers:
  - name: app
    image: ${ECR_HOST}/eks-lab130/app@${DIGEST}
    command: ["sh", "-c", "sleep 86400"]
EOF

kubectl wait --for=condition=Ready pod/digest-app -n eks-130 --timeout=600s
kubectl get po -n eks-130 digest-app -o wide
```

`nodeSelector` აქ სავალდებულოა და ეს ხაფანგია, რომელშიც ადვილად შესაძლოა
ჩავარდნა. სამუშაო მანქანა - x86_64-ია, ამიტომ `podman push`-მა ECR-ში
გაგზავნა ერთარქიტექტურული მანიფესტი (მხოლოდ `amd64`), ხოლო ლაბის NodePool
უშვებს `arm64`-საც. გადამოწმებულია სტენდზე: სელექტორის გარეშე Karpenter-მა
ამწია `t4g.small`, იმიჯი წყნარად ჩამოტვირთა, მაგრამ კონტეინერი დაიხოცა
`exitCode 255`-ით და ცარიელი ლოგებით - `CrashLoopBackOff` გასაგები მიზეზის
გარეშე. იმავე კლასის პრობლემა განხილულია ლაბა 124-ში (იმიჯი
`polinux/stress` იყო მხოლოდ `amd64`). დასკვნა პროდაქშენისთვის: ან
ააწყობთ მულტიარქიტექტურულ მანიფესტებს, ან ცალსახად მიაბამთ დატვირთვას
არქიტექტურას.

Karpenter-ის node-ის როლი უკვე ატარებს managed policy
`AmazonEC2ContainerRegistryReadOnly`-ს (კონფიგურირებულია `eks_v2_karpenter`
მოდულში), ამიტომ pod წარმატებით იზიდავს იმიჯს და გადადის `Running`-ში
`imagePullSecrets`-ის გარეშე. `@sha256:`-ით მითითება ზუსტად აფიქსირებს იმ
ბაიტების ნაკრებს, რომელიც დავალებებში 2-4 დასკანირეთ და შეამოწმეთ - ტეგს
შესძლო წასულიყო, digest-ს არ შესძლია.

## დავალება 6. Pull through cache registry.k8s.io-სთვის

წესი ავთენტიფიკაციის გარეშე - upstream საჯაროა:

```bash
aws ecr create-pull-through-cache-rule \
  --ecr-repository-prefix k8s-cache \
  --upstream-registry-url registry.k8s.io \
  --region "$AWS_REGION"
```

ანგარიშში პირველი წესის შექმნისას ECR ამზადებს service-linked role
`AWSServiceRoleForECRPullThroughCache`-ს, ამიტომ გამომძახებელს სჭირდება
უფლება `iam:CreateServiceLinkedRole` (სამუშაო მანქანის პოლიტიკაში ის
არსებობს, პირობით `iam:AWSServiceName = pullthroughcache.ecr.amazonaws.com`).
მის გარეშე ECR პასუხობს არა პირდაპირ IAM-მომხმარებელზე, არამედ შემოხვევით,
რომლის მიღება ადვილია პარამეტრების შეცდომად:
`ValidationException ... The Amazon ECR action failed due to an IAM exception: ... is not
authorized to perform: iam:CreateServiceLinkedRole` (რეპროდუცირებულია სტენდზე).

პირველი pull cache-ის მეშვეობით ქმნის თქვენს ECR-ში რეპოზიტორს
`k8s-cache/pause` და cache-ავს იმიჯს:

```bash
podman pull "${ECR_HOST}/k8s-cache/pause:3.9"

aws ecr describe-repositories --region "$AWS_REGION" \
  --query "repositories[?starts_with(repositoryName,'k8s-cache/pause')].repositoryName"
```

## დავალება 7. Docker Hub pull through cache secret-ით (ნამდვილი pull-ის გარეშე)

ლაბის თემა მოითხოვს ზუსტად secret-ს, ამიტომ ჩვენ ვქმნით მას ნამდვილად, მაგრამ
placeholder-ით ნამდვილი Docker Hub ტოკენის ნაცვლად: ნამდვილი pull ამ
credential-ებით არ გაივლის, კონფიგურაცია (secret პლუს cache rule) ამის გამო
არ ფუჭდება და მთლიანად ამოწმდება.

```bash
aws secretsmanager create-secret \
  --name ecr-pullthroughcache/dockerhub-creds \
  --description "Docker Hub creds for ECR pull through cache (lab placeholder)" \
  --secret-string '{"username":"lab-placeholder-user","accessToken":"lab-placeholder-token"}' \
  --region "$AWS_REGION"

SECRET_ARN=$(aws secretsmanager describe-secret \
  --secret-id ecr-pullthroughcache/dockerhub-creds --region "$AWS_REGION" \
  --query 'ARN' --output text)
echo "$SECRET_ARN"

aws ecr create-pull-through-cache-rule \
  --ecr-repository-prefix docker-hub \
  --upstream-registry-url registry-1.docker.io \
  --credential-arn "$SECRET_ARN" \
  --region "$AWS_REGION"

aws ecr describe-pull-through-cache-rules --region "$AWS_REGION"
```

secret-ს აუცილებლად უნდა ჰქონდეს პრეფიქსი `ecr-pullthroughcache/` - სხვანაირად
ECR მას cache rule-ისთვის არ მიღებს. ნამდვილი `podman pull` `docker-hub/...`-ის
მეშვეობით ამ placeholder-ით მოსალოდნელად ჩავარდება (credential-ები ნამდვილი
არ არის) - დავალება ამოწმებს კონფიგურაციას (secret და წესი არსებობს), არა
წარმატებული pull-ის ფაქტს. წარმატებული pull-ის ფაქტისთვის cache-ის მეშვეობით
ემსახურება დავალება 6 (registry.k8s.io, ავთენტიფიკაციის გარეშე).

მნიშვნელოვანია: არ გამოიყენოთ აქ ნამდვილი Docker Hub credential-ები. secret
ემსახურება მხოლოდ ამ ლაბის საკუთარი კონფიგურაციის შემოწმებას.

## დავალება 8. Lifecycle policy

წესი: არ შეინახოთ 5-ზე მეტი იმიჯი ტეგით `v.*`, დანარჩენი წაშალეთ ტეგის ასაკის
მიხედვით:

```bash
cat <<'EOF' > /tmp/lifecycle.json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "keep last 5 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 5
      },
      "action": { "type": "expire" }
    }
  ]
}
EOF

aws ecr put-lifecycle-policy \
  --repository-name eks-lab130/app \
  --lifecycle-policy-text file:///tmp/lifecycle.json \
  --region "$AWS_REGION"

aws ecr get-lifecycle-policy --repository-name eks-lab130/app --region "$AWS_REGION"
aws ecr start-lifecycle-policy-preview \
  --repository-name eks-lab130/app --region "$AWS_REGION" >/dev/null
sleep 5
aws ecr get-lifecycle-policy-preview \
  --repository-name eks-lab130/app --region "$AWS_REGION"
```

`get-lifecycle-policy-preview`-მ შესაძლოა შედეგი დაუყოვნებლივ არ დააბრუნოს
(preview ითვლება ასინქრონულად) - თუ სტატუსი ჯერ კიდევ `IN_PROGRESS`-ია,
გაიმეორეთ მოთხოვნა რამდენიმე წამში.

## სწრაფი შემოწმება

```bash
check_result
```
