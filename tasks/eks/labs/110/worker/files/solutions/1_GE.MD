[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 110 - ეტალონური გადაწყვეტა (VPC CNI ქსელური პოლიტიკა: ნაგულისხმევი აკრძალვა, ლეიბლი, egress)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე SSH-ით. kubectl უკვე კონფიგურირებულია
კლასტერზე (kubeconfig აშენდა `aws eks update-kubeconfig`-ის მეშვეობით მანქანის ჩართვისას).
`enableNetworkPolicy` უკვე ჩართულია `vpc-cni` add-on-ზე Terraform-ის მეშვეობით, ამიტომ
`aws-network-policy-agent` აგენტი `aws-node`-ში ნოუდებზე ხელმისაწვდომია დავალებების
დაწყებამდეც.

## დავალება 1. Namespace `eks-110`

```bash
kubectl create namespace eks-110
```

## დავალება 2. შემოწმება, რომ აღსრულებელი ჩართულია

ვამოწმებთ ორივე ფაქტს: აგენტის კონტეინერს DaemonSet `aws-node`-ში და add-on-ის
კონფიგურაციის ფლაგს.

```bash
mkdir -p /var/work/tests/artifacts/2

{
  echo "--- kubectl describe daemonset aws-node ---"
  kubectl describe daemonset aws-node -n kube-system | grep -A2 aws-network-policy-agent
  echo
  echo "--- aws eks describe-addon vpc-cni ---"
  CLUSTER=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' | sed 's|.*/||')
  aws eks describe-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
    --query "addon.configurationValues" --output text
} > /var/work/tests/artifacts/2/enforcer.txt

cat /var/work/tests/artifacts/2/enforcer.txt
```

output-ში უნდა შედიოდეს კონტეინერი `aws-network-policy-agent` `aws-node`-ში და ხაზი
მსგავსი `enableNetworkPolicy":"true"` add-on-ის კონფიგურაციაში. ეს ადასტურებს, რომ
control plane-ი და ნოუდის აგენტი რეალურად აღასრულებენ `NetworkPolicy` ობიექტებს, არა
მხოლოდ იღებენ მათ როგორც API ობიექტს.

## დავალება 3. სიმპტომი ყოველგვარი პოლიტიკის გარეშე: კავშირი ნაგულისხმევად დაშვებულია

ვქმნით `api`-ს (სერვერი) და `client`-ს (`kubectl exec curl`-ისთვის), პლუს Service-ს
`api`-სთვის:

```bash
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=2 -n eks-110
kubectl rollout status deployment/api -n eks-110

kubectl expose deployment api -n eks-110 --port=8080 --target-port=8080

kubectl create deployment client --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/client -n eks-110
```

ვამოწმებთ კავშირს: `client`-მა უნდა შესძლოს `api`-ს მიღწევა Service-ის სახელით.

```bash
mkdir -p /var/work/tests/artifacts/3
CLIENT=$(kubectl get po -n eks-110 -l app=client -o jsonpath='{.items[0].metadata.name}')

kubectl exec "$CLIENT" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/3/connectivity_before.txt

cat /var/work/tests/artifacts/3/connectivity_before.txt
```

ფაილი უნდა შეიცავდეს `HTTP_CODE=200`-ს: ყოველგვარი პოლიტიკის გარეშე VPC CNI აძლევს
დაშვებას ყველა east-west ტრაფიკზე - კლასტერში ჯერ არც ერთი `NetworkPolicy` ობიექტი არ
შექმნილა.

## დავალება 4. ნაგულისხმევი ingress-აკრძალვა

ვკრძალავთ ყველა შემომავალ ტრაფიკს namespace `eks-110`-ში:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: eks-110
spec:
  podSelector: {}
  policyTypes: ["Ingress"]
EOF
```

ვამოწმებთ, რომ `client` ვერ ახერხებს `api`-ს მიღწევას (ველოდებით timeout-ს, რომ არ
გავჭედოთ):

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec "$CLIENT" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/4/connectivity_denied.txt

cat /var/work/tests/artifacts/4/connectivity_denied.txt
```

ფაილში უნდა ჩნდებოდეს `HTTP_CODE=000` (კავშირი არ დამყარდა) - `podSelector: {}`
ნიშნავს "namespace-ის ყოველი პოდი", ხოლო `policyTypes: ["Ingress"]` `ingress` სექციის
გარეშე ნიშნავს "დააკრძალე ყველა შემომავალი ტრაფიკი". ეს არის კლასიკური ნაგულისხმევი
აკრძალვა, რომელსაც აღასრულებს `aws-network-policy-agent` აგენტი eBPF-ის მეშვეობით.

## დავალება 5. დაშვება ლეიბლის მიხედვით: `app: frontend` -> `app: api`

ვამატებთ პოლიტიკას, რომელიც აძლევს დაშვებას შემომავალ ტრაფიკზე პოდებზე `app: api`
მხოლოდ პოდებისგან, რომლებსაც აქვთ ლეიბლი `app: frontend`, პორტზე `8080`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-api
  namespace: eks-110
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
EOF
```

ვქმნით კლიენტს სწორი ლეიბლით (`frontend`) და კლიენტს მის გარეშე (`client-other`), რომ
შესძლოთ შედეგების შედარება:

```bash
kubectl create deployment frontend --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/frontend -n eks-110

kubectl create deployment client-other --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/client-other -n eks-110
```

`kubectl create deployment` ავტომატურად აყენებს ლეიბლს `app: <name>`, ამიტომ
`frontend`-ს უკვე აქვს `app: frontend`, ხოლო `client-other`-ს ენიჭება `app: client-other`
(რომელიც არ ემთხვევა წესს).

ვამოწმებთ ორივე შემთხვევას:

```bash
mkdir -p /var/work/tests/artifacts/5
FRONTEND=$(kubectl get po -n eks-110 -l app=frontend -o jsonpath='{.items[0].metadata.name}')
OTHER=$(kubectl get po -n eks-110 -l app=client-other -o jsonpath='{.items[0].metadata.name}')

kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/allowed_frontend.txt

kubectl exec "$OTHER" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/blocked_other.txt

cat /var/work/tests/artifacts/5/allowed_frontend.txt
cat /var/work/tests/artifacts/5/blocked_other.txt
```

`allowed_frontend.txt`-ში უნდა ჩნდებოდეს `HTTP_CODE=200` (ლეიბლი ემთხვევა
`podSelector` წესს `ingress.from`-ში), ხოლო `blocked_other.txt`-ში - `HTTP_CODE=000`
(იგივე `default-deny-ingress` დავალება 4-იდან ჯერ კიდევ ვრცელდება ყველა პოდზე,
რომლისთვისაც არ არსებობს ცალსახა დაშვების წესი).

## დავალება 6. Egress DNS-გამონაკლისით

ვზღუდავთ გამავალ ტრაფიკს `frontend`-იდან: ვაძლევთ დაშვებას მხოლოდ ტრაფიკზე პოდებზე
`app: api` და DNS-ზე (`kube-system`, პორტები `53` UDP/TCP). ყველა დანარჩენი (ნებისმიერი
გარეთა მისამართი) დაბლოკილია.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: eks-110
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes: ["Egress"]
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: api
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF
```

ვამოწმებთ, რომ სახელის `api` გახსნა და მასთან წვდომა ჯერ კიდევ მუშაობს (საჭიროა ორივე -
DNS და დაშვებული egress `api` პოდზე):

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/6/egress_dns_api.txt

cat /var/work/tests/artifacts/6/egress_dns_api.txt
```

`HTTP_CODE=200` ადასტურებს, რომ პოლიტიკის ჩანაწერი `to.podSelector: app: api` აძლევს
დაშვებას ტრაფიკზე `api`-ზე, ხოლო გამონაკლისი პორტზე `53` `kube-system`-ში საშუალებას
აძლევს `frontend`-ს გახსნას სახელი.

ახლა ვამოწმებთ, რომ თვითნებური გარეთა მისამართი (რომელიც არ ხვდება დაშვებულ წესებში)
დაბლოკილია:

```bash
kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://1.1.1.1 \
  > /var/work/tests/artifacts/6/egress_external_blocked.txt

cat /var/work/tests/artifacts/6/egress_external_blocked.txt
```

`HTTP_CODE=000` ადასტურებს აკრძალვას: `restrict-egress` განსაზღვრავს დაშვებული
დანიშნულებების სრულ ჩამონათვალს `app: frontend`-ისთვის, ყველა დანარჩენი აკრძალულია
(მათ შორის ინტერნეტი და ნებისმიერი სხვა პოდი კლასტერში `api`-ს გარდა).

## სწრაფი შემოწმება

```bash
check_result
```
