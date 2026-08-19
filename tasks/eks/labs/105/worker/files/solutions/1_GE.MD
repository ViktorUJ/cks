[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 105 - ეტალონური გადაწყვეტა (საიდუმლოებები: KMS envelope encryption, External Secrets)

ყველა ბრძანება სრულდება worker მანქანაზე SSH-ის მეშვეობით. kubectl უკვე კონფიგურირებულია
კლასტერზე, ხოლო terraform-მა უკვე შექმნა Secrets Manager-ის საიდუმლო და IRSA როლი ESO
კონტროლერისთვის - მათი სახელები და ARN-ები არის მინიშნების ფაილში
`/home/ubuntu/lab105_hints.txt`.

```bash
cat ~/lab105_hints.txt
```

ცვლადები მინიშნების ფაილიდან შემდეგი ბრძანებებისთვის:

```bash
export SECRET_NAME=$(grep '^secret_name' ~/lab105_hints.txt | awk '{print $3}')
export ROLE_ARN=$(grep '^role_arn' ~/lab105_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab105_hints.txt | awk '{print $3}')
```

## დავალება 1. Namespace `eks-105`

```bash
kubectl create namespace eks-105
```

## დავალება 2. შრე 1: KMS envelope encryption-ის შემოწმება

Kubernetes 1.28-იდან მოყოლებული, EKS ნაგულისხმევად შიფრავს ყველა API ობიექტს (მათ შორის
`Secret`-ს) AWS-ის გასაღებით, თქვენი მხრიდან რაიმე მოქმედების გარეშე. ვამოწმებთ
კლასტერის დაშიფვრის კონფიგურაციას:

```bash
mkdir -p /var/work/tests/artifacts/2
aws eks describe-cluster --name "${CLUSTER_NAME}" --query 'cluster.encryptionConfig' \
  > /var/work/tests/artifacts/2/encryption_config.txt
cat /var/work/tests/artifacts/2/encryption_config.txt
```

output-ში სიის ელემენტი შეიცავს `"resources": ["secrets"]` - ეს ადასტურებს, რომ შრე 1
(საიდუმლოების envelope encryption etcd-ში) ჩართულია. თუ AWS owned key-ის ნაცვლად საჭიროა
საკუთარი customer managed key (CMK), ეს კეთდება ცალკე ბრძანებით `aws eks
associate-encryption-config` - მაგრამ საკუთარი CMK-ის ჩართვა შესაძლებელია, ხოლო
დაშიფვრის გამორთვა შეუძლებელია (ეს არის შეუქცევადი ოპერაცია), ამიტომ აქ ვრჩებით AWS-ის
ნაგულისხმევ გასაღებზე.

## დავალება 3. External Secrets Operator-ის დაყენება Helm-ის მეშვეობით

როლი `role_arn` უკვე შექმნილია terraform-ის მიერ trust policy-ით, რომელიც ზუსტად ენდობა SA
`external-secrets`-ს namespace `external-secrets`-ში (თავი 16, IRSA). ვდგამთ ESO-ს Helm-ის
მეშვეობით და მაშინვე ვაბამთ როლს ანოტაციით ServiceAccount-ზე:

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets --create-namespace \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${ROLE_ARN}"

kubectl rollout status deployment/external-secrets -n external-secrets
kubectl get pods -n external-secrets
```

ვამოწმებთ, რომ ანოტაცია დაედო კონტროლერის SA-ს:

```bash
kubectl get sa external-secrets -n external-secrets -o yaml | grep -A1 annotations
```

## დავალება 4. SecretStore და ExternalSecret

ვქმნით `SecretStore`-ს (namespace-scoped - იზოლაცია გუნდების მიხედვით, თავი 18.5), შემდეგ
`ExternalSecret`-ს, რომელიც მიუთითებს terraform-ის დემო-საიდუმლოზე:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-sm
  namespace: eks-105
spec:
  provider:
    aws:
      service: SecretsManager
      region: eu-central-1
EOF

cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: eks-105
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: aws-sm
    kind: SecretStore
  target:
    name: db-credentials
  data:
    - secretKey: password
      remoteRef:
        key: ${SECRET_NAME}
        property: password
EOF
```

ველოდებით სინქრონიზაციას და ვამოწმებთ ნატიურ `Secret`-ს:

```bash
kubectl wait --for=jsonpath='{.status.conditions[0].reason}'=SecretSynced \
  externalsecret/db-credentials -n eks-105 --timeout=120s

kubectl get externalsecret db-credentials -n eks-105
kubectl get secret db-credentials -n eks-105 -o jsonpath='{.data.password}' | base64 -d
echo
```

მნიშვნელობა უნდა ემთხვეოდეს პაროლს, რომელიც terraform-მა ჩადო Secrets Manager-ში
(`S3cr3tPass123`). `refreshInterval: 1m` შერჩეულია განზრახ მცირე - დავალება 6-ში საჭიროა
სწრაფად დავინახოთ ხელახალი სინქრონიზაცია AWS-ში საიდუმლოს ხელით შეცვლის შემდეგ.

## დავალება 5. Pod ტომით: სინქრონიზაციის მდგრადი გზა

ვამაუნთებთ `Secret`-ს ტომად (volumeMount), და არა env-ის მეშვეობით - ზუსტად ეს არის
რაც თავი 18.5 ურჩევს იმ მნიშვნელობებისთვის, რომლებმაც უნდა განახლდნენ pod-ის ხელახლა
შექმნის გარეშე (kubelet თავად აახლებს ტომში ფაილებს, როცა `Secret` იცვლება):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: vol-reader
  namespace: eks-105
spec:
  containers:
  - name: app
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
    volumeMounts:
    - name: db-creds
      mountPath: /etc/db-creds
      readOnly: true
  volumes:
  - name: db-creds
    secret:
      secretName: db-credentials
EOF

kubectl wait --for=condition=Ready pod/vol-reader -n eks-105 --timeout=120s
```

ვკითხულობთ მნიშვნელობას ტომში არსებული ფაილიდან:

```bash
mkdir -p /var/work/tests/artifacts/5
kubectl exec vol-reader -n eks-105 -- cat /etc/db-creds/password \
  > /var/work/tests/artifacts/5/volume_password.txt
echo >> /var/work/tests/artifacts/5/volume_password.txt
cat /var/work/tests/artifacts/5/volume_password.txt
```

## დავალება 6. Pod env-ით: მოძველებული მნიშვნელობის სიმპტომი

ვქმნით მეორე pod-ს, რომელიც კითხულობს იმავე `Secret`-ს, მაგრამ environment ცვლადის
მეშვეობით:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: env-reader
  namespace: eks-105
spec:
  containers:
  - name: app
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
EOF

kubectl wait --for=condition=Ready pod/env-reader -n eks-105 --timeout=120s
kubectl exec env-reader -n eks-105 -- printenv DB_PASSWORD
```

ვცვლით საიდუმლოს მნიშვნელობას პირდაპირ Secrets Manager-ში (არა Kubernetes-ის მეშვეობით):

```bash
aws secretsmanager put-secret-value --secret-id "${SECRET_NAME}" \
  --secret-string '{"username":"appuser","password":"RotatedPass456"}'
```

ველოდებით `refreshInterval`-ს (დავალება 4-ში დაყენებული `1m`) პლუს მარაგი და ვამოწმებთ,
რომ ESO-მ ხელახლა დაასინქრონა ნატიური `Secret`:

```bash
sleep 90
kubectl get secret db-credentials -n eks-105 -o jsonpath='{.data.password}' | base64 -d
echo
```

მნიშვნელობა `Secret`-ში უკვე ახალია (`RotatedPass456`) - ESO-მ თავისი საქმე გააკეთა.
ახლა ვუყურებთ pod-ს env-ით, რომელიც შეიქმნა როტაციამდე:

```bash
kubectl exec env-reader -n eks-105 -- printenv DB_PASSWORD
```

pod ჯერ კიდევ აჩვენებს ძველ მნიშვნელობას (`S3cr3tPass123`). მიზეზი: კონტეინერის
environment ცვლადები ფიქსირდება პროცესის დაწყებისას, ამიტომ `Secret`-ის განახლება etcd-ში
მათზე გავლენას არ ახდენს - pod უნდა შეიქმნას ხელახლა (`kubectl rollout restart`
Deployment-ისთვის, ან ხელით წაშლა და შექმნა ცალკეული Pod-ისთვის), რათა ახალი მნიშვნელობა
env-ის მეშვეობით მიღებულ იქნას. ეს არ არის ESO-ს bug, ეს არის env-ის მუშაობის
თვისება Kubernetes-ში - განსხვავებით ტომისგან, რომელსაც kubelet აახლებს დისკზე pod-ის
ხელახლა შექმნის გარეშე (დავალება 5).

ვფიქსირებთ დაკვირვებას არტეფაქტში:

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/rotation.txt <<'EOF'
put-secret-value-ის შემდეგ Secrets Manager-ში და ExternalSecret-ის ხელახალი
სინქრონიზაციის შემდეგ, ნატიური Secret db-credentials etcd-ში განახლდა პაროლის ახალი
მნიშვნელობით - ESO-მ ჩვეულ რეჟიმში იმუშავა.

Pod env-reader კითხულობს პაროლს env-ის (secretKeyRef) მეშვეობით, ხოლო კონტეინერის
environment ცვლადები ფიქსირდება ერთხელ, პროცესის დაწყებისას. env-ის მნიშვნელობა არ
განახლდება Secret-ის ცვლილების შემდეგ pod-ის ხელახლა შექმნის გარეშე - ეს არ არის
ESO-ს გაუმართაობა, ეს არის env-ის თვისება Kubernetes-ში. Pod vol-reader (დავალება 5)
კითხულობს იმავე Secret-ს volumeMount-ის მეშვეობით - ასეთ ტომს kubelet აახლებს დისკზე
ავტომატურად, pod-ის ხელახლა შექმნის გარეშე.

მოკლედ ინგლისურად: the env value is stale and does not update until the pod is recreated.
EOF
cat /var/work/tests/artifacts/7/rotation.txt
```

## სწრაფი შემოწმება

```bash
check_result
```
