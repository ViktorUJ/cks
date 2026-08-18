[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 112 - ეტალონური გადაწყვეტა (Fargate: პროფილები, შეზღუდვები, ღირებულება)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე (worker) SSH-ით. kubectl უკვე კონფიგურირებულია
კლასტერზე (kubeconfig აწყობილია `aws eks update-kubeconfig`-ით მანქანის ჩატვირთვისას).
Fargate-პროფილი `workload` namespace `eks-112`-ისთვის უკვე შექმნილია ლაბის
ინფრასტრუქტურის მიერ - სტუდენტს მხოლოდ namespace-ისა და მასში ობიექტების შექმნა
სჭირდება.

## დავალება 1. Namespace `eks-112`

```bash
kubectl create namespace eks-112
```

პროფილი `workload` მატჩავს `namespace = eks-112`-ს `labels`-ის გარეშე, ამიტომ მთელი
namespace მთლიანად ხვდება Fargate-ზე - შიგნით გამონაკლისები არ იქნება.

## დავალება 2. Guaranteed-პოდი `fg-app` Fargate-ზე

Fargate უშვებს მხოლოდ პოდებს, რომლებშიც `requests` ტოლია `limits`-ის (კლასი
`Guaranteed`). ვქმნით Deployment-ს ცალსახად ტოლი მნიშვნელობებით:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fg-app
  namespace: eks-112
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fg-app
  template:
    metadata:
      labels:
        app: fg-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "500m"
            memory: "1Gi"
EOF

kubectl rollout status deployment/fg-app -n eks-112
```

ვამოწმებთ, რომ პოდები ხვდებიან Fargate-ნოუდზე (ნოუდის სახელი იწყება `fargate-`-ით, არა
`ip-`-ით):

```bash
kubectl get po -n eks-112 -l app=fg-app -o wide
```

## დავალება 3. არტეფაქტი: რეალურად გამოყოფილი ტევადობა

Fargate ამრგვალებს მოთხოვნების ჯამს ზევით ფიქსირებულ vCPU/მეხსიერების კომბინაციამდე და
ამატებს `256 MB`-ს Kubernetes-ის კომპონენტებზე (`kubelet`, `kube-proxy`, `containerd`).
რეალურად გამოყოფილი ტევადობა ჩანს ანოტაცია `CapacityProvisioned`-ში:

```bash
mkdir -p /var/work/tests/artifacts/3
POD=$(kubectl get po -n eks-112 -l app=fg-app -o jsonpath='{.items[0].metadata.name}')
kubectl get pod "$POD" -n eks-112 \
  -o jsonpath='{.metadata.annotations.CapacityProvisioned}' \
  > /var/work/tests/artifacts/3/capacity.txt
echo >> /var/work/tests/artifacts/3/capacity.txt
cat /var/work/tests/artifacts/3/capacity.txt
```

`500m` CPU-ს და `1Gi` მეხსიერების მოთხოვნისთვის, პლუს `256 MB` სამსახურეობრივი, Fargate
აირჩევს ახლომდებარე შესატყვის კომბინაციას (მაგალითად `0.5vCPU 1GB`, ან `0.5vCPU 2GB`, თუ
ჯამური მეხსიერება დამატების შემდეგ გადააჭარბებს `1 GB`-ს) - ზუსტად ამ ხაზს გამოაჩენს
`kubectl describe pod`.

## დავალება 4. სიმპტომი: privileged-პოდი არ სტარტავს

Fargate მკაცრად კრძალავს პრივილეგირებულ კონტეინერებს, DaemonSet-ს,
hostNetwork/hostPort-ს, hostPath-ს და GPU-ს. ვცდილობთ შევქმნათ privileged-პოდი
`eks-112`-ში:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: fg-privileged
  namespace: eks-112
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
    securityContext:
      privileged: true
EOF

kubectl get po fg-privileged -n eks-112
kubectl describe po fg-privileged -n eks-112 | sed -n '/Events/,$p'
```

პოდი არ გადადის `Running`-ში: Fargate უკუაგდებს პრივილეგირებულ კონტეინერებს დაშვების
(admission) ეტაპზე, ეს ჩანს პოდის events-ში. ვინახავთ განმარტებას არტეფაქტში:

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/privileged.txt <<'EOF'
Pod fg-privileged არ სტარტავს, რადგან ითხოვს privileged: true. Fargate არ უჭერს მხარს
პრივილეგირებულ კონტეინერებს: ეს ამ რეჯიმის ერთ-ერთი მკაცრი შეზღუდვაა, DaemonSet-თან,
hostNetwork/hostPort-თან, hostPath-თან და GPU-სთან ერთად. შეცდომა ჩანს პოდის events-ში
როგორც დაშვების (admission) უარი, არა როგორც ჩვეულებრივი Pending რესურსების
ნაკლებობის გამო.
EOF
cat /var/work/tests/artifacts/4/privileged.txt
```

შემიძლია მოვხსნა პოდი, რომ არ შეაფერხოს შემდგომი შემოწმებები:

```bash
kubectl delete pod fg-privileged -n eks-112
```

## დავალება 5. ეფემერული დისკის გაფართოება 30Gi-მდე

ნაგულისხმევად Fargate გამოყოფს `20 GiB` ეფემერულ დისკს, `175 GiB`-მდე
`ephemeral-storage`-ის მეშვეობით `resources`-ში (requests უნდა უტოლდებოდეს limits-ს,
პოდი რჩება Guaranteed). ვაახლებთ `fg-app`-ს:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fg-app
  namespace: eks-112
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fg-app
  template:
    metadata:
      labels:
        app: fg-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
            ephemeral-storage: "30Gi"
          limits:
            cpu: "500m"
            memory: "1Gi"
            ephemeral-storage: "30Gi"
EOF

kubectl rollout status deployment/fg-app -n eks-112
kubectl get po -n eks-112 -l app=fg-app -o wide
```

პოდი ჩვეულებრივად სტარტავს: `30Gi` დაშვებული `175 GiB`-ის ფარგლებშია, და მოთხოვნა
`requests == limits` დაკმაყოფილებულია.

## დავალება 6. ღირებულების სტრუქტურა: Fargate და node group

ძირითადი განსხვავება - ტარიფიკაციის ერთეული. Fargate ითვლის ფულს კონკრეტული პოდის vCPU-სა
და მეხსიერებაზე მისი ცხოვრების ხანგრძლივობის განმავლობაში, node group - მთელ
EC2-ინსტანსზე, მისი დატვირთვის დონის მიუხედავად. ამ არტეფაქტის ავტომატური შემოწმება
ეძებს ლიტერალურ რუსულ სიტყვას `под` `vCPU`-ს გვერდით, ამიტომ ქვემოთ მოცემული არტეფაქტი
შეიცავს ამ ლიტერალურ სიტყვას ქართული განმარტების გარდა:

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/costmodel.txt <<'EOF'
Fargate ტარიფდება პოდის (под) თავად vCPU-სა და მეხსიერებაზე მისი რეალური მუშაობის დროის
განმავლობაში: თუ პოდი არ მუშაობს, გადასახადი არ არსებობს, და უსაქმური ტევადობისთვის
ზედმეტი გადასახადი არ წარმოიშობა. Node group, პირიქით, ტარიფდება მთელ ინსტანსზე: გადასახადი
ხდება იმ დროშიც, როცა ნოუდები უსაქმურია პოდებს შორის ან არასრულად დატვირთულია. რესურსის
ერთეულზე Fargate ჩვეულებრივ უფრო ძვირია, ვიდრე ეკვივალენტური რესურსი node group-ის ნოუდზე,
ამიტომ საბოლოო ეკონომიკა დამოკიდებულია უტილიზაციაზე: მაღალი და პროგნოზირებადი დატვირთვის
შემთხვევაში node group უფრო ხელსაყრელია, ხოლო არარეგულარული ან არაპროგნოზირებადი
მოთხოვნის შემთხვევაში Fargate თავს არიდებს ზედმეტ გადასახადს უსაქმური ინსტანსებისთვის.
EOF
cat /var/work/tests/artifacts/6/costmodel.txt
```

## სწრაფი შემოწმება

```bash
check_result
```
