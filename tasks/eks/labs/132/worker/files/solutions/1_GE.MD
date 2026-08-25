[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 132 - ეტალონური გადაწყვეტა (Cilium CNI chaining რეჟიმში VPC CNI-ს ზემოთ)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე (worker) SSH-ის საშუალებით. kubectl და helm
უკვე კონფიგურირებულია (kubeconfig შედგენილია `aws eks update-kubeconfig`-ის საშუალებით
მანქანის ჩატვირთვისას).

> Cilium-ის ვერსიები და chaining-რეჟიმის values-ფლაგების ზუსტი სახელები სწრაფად
> იცვლება რელიზებს შორის. ქვემოთ მოცემული ბრძანებები გადამოწმებულია ცოცხალ სტენდზე
> Cilium `1.20.0`-ითა და EKS `1.36`-ით. თუ სხვა ვერსიას იღებთ, გადაამოწმეთ სინტაქსი
> Cilium-ის დოკუმენტაციასთან
> (`https://docs.cilium.io/en/stable/installation/cni-chaining-aws-cni/`).

## დავალება 1. Namespace `eks-132`

```bash
kubectl create namespace eks-132
```

## დავალება 2. დატვირთვა პულზე `cilium-demo` Cilium-ის გარეშე

NodePool `cilium-demo` უკვე არსებობს როგორც კოდი (taint `dedicated=cilium-demo:NoSchedule`,
label `work_type=cilium-demo`), მაგრამ სანამ მასზე toleration-იანი pod არ მოვა,
Karpenter არც ერთ ნოუდს არ ამოაყენებს. Deployment `api` და `client` ვქმნით
`nodeSelector`-ითა და toleration-ით მაშინვე, რომ ზუსტად იქ მოხვდნენ:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: eks-132
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      nodeSelector:
        work_type: cilium-demo
      tolerations:
        - key: dedicated
          operator: Equal
          value: cilium-demo
          effect: NoSchedule
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: eks-132
spec:
  selector:
    app: api
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
  namespace: eks-132
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
  template:
    metadata:
      labels:
        app: client
    spec:
      nodeSelector:
        work_type: cilium-demo
      tolerations:
        - key: dedicated
          operator: Equal
          value: cilium-demo
          effect: NoSchedule
      containers:
      - name: curl
        image: curlimages/curl:latest
        command: ["sleep", "3600"]
EOF

kubectl rollout status deployment/api -n eks-132
kubectl rollout status deployment/client -n eks-132
```

Karpenter ამოაყენებს ახალ ნოუდს პულში `cilium-demo` (ჩვეულებრივ 60-90 წამი). როგორც
კი `rollout status` დაადასტურებს მზადყოფნას, ვამოწმებთ connectivity-ს შტატული VPC
CNI-ის მეშვეობით - Cilium ჯერ არ დაყენებულა:

```bash
mkdir -p /var/work/tests/artifacts/2
CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 8 \
  -w "HTTP_CODE=%{http_code}\n" http://api.eks-132.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/2/connectivity_before.txt
cat /var/work/tests/artifacts/2/connectivity_before.txt
```

## დავალება 3. Cilium Helm-ის საშუალებით CNI chaining რეჟიმში, მხოლოდ `cilium-demo`-ზე

ვამატებთ Cilium-ის რეპოზიტორს და ვამზადებთ values-ფაილს. საკვანძო პარამეტრია
`cni.chainingMode: aws-cni`: VPC CNI (`aws-node`) რჩება ძირითად IPAM-ად, Cilium ერთვება
ჯაჭვში და ამატებს eBPF-პროგრამებს pod-ის უკვე კონფიგურირებული ინტერფეისის ზემოთ.

სამი ბლოკი `nodeSelector`/`tolerations` (ზედა დონე აგენტისთვის, `envoy` და
`operator`) შემოისღვედს Cilium-ის ყველა კომპონენტს პულით `cilium-demo`. ზედა
`nodeSelector` ერიდება მხოლოდ DaemonSet `cilium`-ს; `cilium-envoy`-სა და
`cilium-operator`-ს თავიანთი სექციები აქვთ, და მათ გარეშე Envoy-ის pod-ები დაიკიდება
`Pending`-ში ყველა დანარჩენ ნოუდზე, ხოლო `cilium status` აჩვენებს
`Envoy DaemonSet: 1 errors`-ს.

ცალკე ვთამაშებთ `operator.unmanagedPodWatcher.restart`-ს. ეს ასეთი სტენდისთვის
სავალდებული ფლაგია, არა წვრილი ტიუნინგი: ნაგულისხმევად ოპერატორი ყოველ 15 წამში
წაშლის pod-ებს, რომლებსაც არ აქვთ `CiliumEndpoint`, რათა თავიდან ამოვდგნენ და
მოხვდნენ CNI-ის ჯაჭვში. `coredns`-ის pod-ები ცხოვრობს Fargate-ზე, სადაც Cilium-ის
აგენტი არ არსებობს და ვერც იარსებებს, ამიტომ managed არასდროს ხდებიან - ოპერატორი
ბოლო-გარეშედ ანადგურებს მათ, ყოველ ჯერზე ამოაყენებს ახალ Fargate-ნოუდს, და DNS
კლასტერში ჩავარდება (დეტალები - ქვემოთ, „ხაფანგები“ ნაწილში).

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

cat <<'EOF' > /tmp/cilium-values.yaml
cni:
  chainingMode: aws-cni
  exclusive: false
enableIPv4Masquerade: false
routingMode: native
nodeSelector:
  work_type: cilium-demo
tolerations:
  - key: dedicated
    operator: Equal
    value: cilium-demo
    effect: NoSchedule
envoy:
  nodeSelector:
    work_type: cilium-demo
  tolerations:
    - key: dedicated
      operator: Equal
      value: cilium-demo
      effect: NoSchedule
operator:
  nodeSelector:
    work_type: cilium-demo
  tolerations:
    - key: dedicated
      operator: Equal
      value: cilium-demo
      effect: NoSchedule
  unmanagedPodWatcher:
    restart: false
EOF

helm install cilium cilium/cilium --version 1.20.0 \
  --namespace kube-system \
  -f /tmp/cilium-values.yaml

kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
kubectl get pods -n kube-system -l k8s-app=cilium -o wide
```

`api`-ისა და `client`-ის pod-ები ამოქმედდნენ Cilium-ის დაყენებამდე, ამიტომ CNI
chaining მათზე ჯერ არ ამოქმედდა (Cilium-ის დოკუმენტაცია პირდაპირ აფრთხილებს ამის
შესახებ: არსებული pod-ები საჭიროებენ ხელახლა გაშვებას). ხელახლა ვუშვებთ ორივე
Deployment-ს:

```bash
kubectl rollout restart deployment/api -n eks-132
kubectl rollout restart deployment/client -n eks-132
kubectl rollout status deployment/api -n eks-132
kubectl rollout status deployment/client -n eks-132
```

ვაინსტალირებთ Cilium CLI-ს და ვამოწმებთ მდგომარეობას:

```bash
CILIUM_CLI_VERSION=$(curl -fsSL https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"
sudo tar xzvfC "cilium-linux-${CLI_ARCH}.tar.gz" /usr/local/bin
rm "cilium-linux-${CLI_ARCH}.tar.gz"

mkdir -p /var/work/tests/artifacts/3
cilium status | tee /var/work/tests/artifacts/3/cilium_status.txt
```

გამოსავალში უნდა იყოს `Cilium: OK`, `Operator: OK` და `Envoy DaemonSet: OK`, ხოლო
ორივე DaemonSet-ის `Desired`-ის რიცხვი უნდა ემთხვეოდეს `cilium-demo`-ის ნოუდების
რაოდენობას.

## დავალება 4. Chaining-ის დამტკიცება: მისამართები კვლავ VPC CNI-დან

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl get pods -n eks-132 -o wide > /var/work/tests/artifacts/4/podips.txt
cat /var/work/tests/artifacts/4/podips.txt
```

`api`-ისა და `client`-ის pod-ების IP CIDR `10.10.0.0/16`-იდან - იმ დიაპაზონისგან,
რაც თავად VPC-ს აქვს. თუ ეს ყოფილიყო VPC CNI-ის სრული ჩანაცვლება overlay-რეჟიმით,
მისამართები ცალკე ვირტუალური პულიდან (`cluster-pool`) მოვიდოდა, არა ნოუდის
ქვექსელიდან. აქ IPAM დარჩა VPC CNI-ს ხელში - ეს არის chaining-ის სუბსტანცია
(chapter 8).

## დავალება 5. L7-პოლიტიკა: მხოლოდ GET

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: cilium-l7-allow-get
  namespace: eks-132
spec:
  endpointSelector:
    matchLabels:
      app: api
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: client
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/.*"
EOF

kubectl get ciliumnetworkpolicies.cilium.io cilium-l7-allow-get -n eks-132
```

ვამოწმებთ ნებადართულ GET-სა და დაბლოკილ POST-ს:

```bash
mkdir -p /var/work/tests/artifacts/5
CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 8 \
  -w "HTTP_CODE=%{http_code}\n" http://api.eks-132.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/allowed_get.txt
cat /var/work/tests/artifacts/5/allowed_get.txt

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 8 -X POST \
  -w "HTTP_CODE=%{http_code}\n" http://api.eks-132.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/blocked_post.txt || true
cat /var/work/tests/artifacts/5/blocked_post.txt
```

GET გადის (`HTTP_CODE=200`), POST იბლოკება Cilium-ის Envoy-პროქსის მიერ L7-დონეზე
(`HTTP_CODE=403`, წვდომა უარყოფილია მანამ, სანამ მოთხოვნა აპლიკაციამდე მივა).
ჩაშენებულ VPC CNI NetworkPolicy-ს ასეთი HTTP-მეთოდის ფილტრი არ აქვს - მხოლოდ
L3/L4 (chapter 8).

გამოიყენეთ სრული სახელი `ciliumnetworkpolicies.cilium.io`: მოკლე `cnp` ამ
კლასტერში არაცალსახაა, რადგან VPC CNI მოიტანს თავის რესურსს
`clusternetworkpolicies.networking.k8s.aws`, და kubectl ამის შესახებ
გაფრთხილებას გამოსცემს.

## დავალება 6. FQDN-პოლიტიკა: egress მხოლოდ `aws.amazon.com`-ზე

ორი ადგილი, სადაც ეს პოლიტიკა ისე არ ვითარდება, როგორც დოკუმენტაციის ტიპურ
მაგალითში.

პირველი: DNS-ის წესის დაწერა `toEndpoints`-ით ლეიბლ `k8s-app: kube-dns`-ზე არ
შეიძლება. `toEndpoints` მუშაობს Cilium-ის identity-ის მიხედვით, ხოლო `coredns`-ის
pod-ები ამ კლასტერში ცხოვრობს Fargate-ზე, სადაც Cilium-ის აგენტი არ არსებობს - მათ
არ აქვთ `CiliumEndpoint`, არ ხვდებიან `ipcache`-ში და პოლიტიკის თვალსაზრისით
ჩნდებიან როგორც `reserved:world`. ლეიბლის მიხედვით წესი არასდროს დაემატჩება, DNS
დაიხურება default-deny-ით, და `curl`-ს სახელის დარეზოლვაც არ შესძლებია. ამიტომ DNS
ვუშვებთ CIDR-ის მიხედვით: კლასტერის სერვისული დიაპაზონი (`172.20.0.0/16`, სადაც
ClusterIP `kube-dns`) და VPC-ის CIDR (`10.10.0.0/16`, სადაც თავად `coredns`-ის
pod-ები). L7-წესები `rules.dns` `toCIDRSet`-ზე შტატულად მუშაობს - ზუსტად ასე
დოკუმენტირებულია Cilium-ის მიერ გარეშე DNS-სერვერის შემთხვევა.

მეორე: `endpointSelector` `app: client`-ზე ჩართავს default-deny-ს ამ pod-ის მთელ
egress-ზე. თუ დავტოვებთ მხოლოდ `toFQDNs`-სა და DNS-ს, ჩავარდება GET `api`-მდე
დავალება 5-იდან - მისი პაკეტები დაიდროპება. ამიტომ მესამე ბლოკად ცალსახად ვუშვებთ
egress-ს `api:8080`-ზე. ასე სტენდის საბოლოო მდგომარეობა თანმიმდევრულია: ერთდროულად
ჭეშმარიტია დავალება 5 და დავალება 6.

ბლოკების მიმდევრობა მნიშვნელოვანია: `toFQDNs` უნდა დარჩეს პირველი (`egress[0]`),
ავტოტესტი ზუსტად იქით ცხვდება.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: cilium-fqdn-allow-aws
  namespace: eks-132
spec:
  endpointSelector:
    matchLabels:
      app: client
  egress:
  - toFQDNs:
    - matchName: "aws.amazon.com"
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP
  - toCIDRSet:
    - cidr: 172.20.0.0/16
    - cidr: 10.10.0.0/16
    toPorts:
    - ports:
      - port: "53"
        protocol: ANY
      rules:
        dns:
        - matchPattern: "*"
  - toEndpoints:
    - matchLabels:
        app: api
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
EOF

kubectl get ciliumnetworkpolicies.cilium.io cilium-fqdn-allow-aws -n eks-132
```

ვამოწმებთ:

```bash
mkdir -p /var/work/tests/artifacts/6
CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 10 \
  -w "HTTP_CODE=%{http_code}\n" https://aws.amazon.com \
  > /var/work/tests/artifacts/6/allowed_fqdn.txt || true
cat /var/work/tests/artifacts/6/allowed_fqdn.txt

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 10 \
  -w "HTTP_CODE=%{http_code}\n" https://example.com \
  > /var/work/tests/artifacts/6/blocked_other_domain.txt || true
cat /var/work/tests/artifacts/6/blocked_other_domain.txt
```

`aws.amazon.com` რეზოლვდება და `curl` გადის - `HTTP_CODE=200`. `example.com`-იც
რეზოლვდება (DNS დაშვებულია), მაგრამ TCP-სესია მისი მისამართზე არ ხვდება
`toFQDNs`-ში, პაკეტები დაიდროპება, და `curl` ეკიდება `--max-time`-მდე -
`HTTP_CODE=000`. ასეთი DNS-სახელის პოლიტიკა ჩაშენებულ VPC CNI NetworkPolicy-ს
სულაც არ აქვს - მხოლოდ `ipBlock` IP/CIDR-ის მიხედვით (chapter 8).

## დავალება 7. Hubble: ნაკადების დაკვირვებადობა verdict-ით

ვრთავთ Hubble relay-ს უკვე დაყენებულ Cilium-ის ზემოთ, იმავე `nodeSelector`-ით
`cilium-demo`-ზე:

```bash
cat <<'EOF' >> /tmp/cilium-values.yaml
hubble:
  relay:
    enabled: true
    nodeSelector:
      work_type: cilium-demo
    tolerations:
      - key: dedicated
        operator: Equal
        value: cilium-demo
        effect: NoSchedule
EOF

helm upgrade cilium cilium/cilium --version 1.20.0 \
  --namespace kube-system \
  -f /tmp/cilium-values.yaml

kubectl -n kube-system rollout status deployment/hubble-relay --timeout=240s
```

ვაინსტალირებთ Hubble CLI-ს:

```bash
HUBBLE_VERSION=$(curl -fsSL https://raw.githubusercontent.com/cilium/hubble/main/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-${HUBBLE_ARCH}.tar.gz"
sudo tar xzvfC "hubble-linux-${HUBBLE_ARCH}.tar.gz" /usr/local/bin
rm "hubble-linux-${HUBBLE_ARCH}.tar.gz"
```

ვამაღლებთ port-forward-ს relay-ზე (`4245`), ვიმეორებთ დაბლოკილ მოთხოვნებს
დავალება 5-დან და 6-დან, რათა მივიღოთ `DROPPED` მოვლენები, და ვკითხავთ ნაკადს:

```bash
setsid nohup kubectl -n kube-system port-forward service/hubble-relay 4245:80 \
  </dev/null >/tmp/pf.log 2>&1 &
sleep 5

CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')
for i in 1 2 3; do
  kubectl exec -n eks-132 "$CLIENT_POD" -- \
    curl -s -o /dev/null --connect-timeout 3 --max-time 5 -X POST \
    http://api.eks-132.svc.cluster.local:8080 >/dev/null 2>&1 || true
  kubectl exec -n eks-132 "$CLIENT_POD" -- \
    curl -s -o /dev/null --connect-timeout 3 --max-time 5 \
    https://example.com >/dev/null 2>&1 || true
done

mkdir -p /var/work/tests/artifacts/7
hubble observe --server localhost:4245 -n eks-132 --last 200 \
  | tee /var/work/tests/artifacts/7/hubble_denied.txt
grep -c DROPPED /var/work/tests/artifacts/7/hubble_denied.txt
```

Port-forward აუცილებლად გაუშვით `setsid nohup ... </dev/null &`-ის საშუალებით:
ჩვეულებრივი `kubectl port-forward &` ჩაპყრობს SSH-სესიას და ის გამოსვლისთანავე
წყდება.

ფაილში უნდა შეხვდეთ სტრიქონები verdict `DROPPED`-ით - ეს არის დადროპილი SYN-ები
`example.com`-ის მისამართებზე (`policy-verdict:none ... Policy denied DROPPED`).
ასეთი per-flow verdict-იანი ნაკადების რუკა ჩაშენებულ VPC CNI network policy-ს არ
აქვს - მხოლოდ `aws-network-policy-agent`-ის ლოგები და მეტრიკები (chapter 8).

## დავალება 8. შედარება: VPC CNI NP Cilium-ის წინააღმდეგ ამ ლაბაში

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/comparison.txt <<'EOF'
რას შეუძლია ჩაშენებულ VPC CNI NetworkPolicy-ს - რა დაამატა Cilium-მა - რას იხდით:

1. VPC CNI NetworkPolicy ფარავს მხოლოდ L3/L4-ს. Cilium-მა ამ ლაბაში დაამატა
   L7-წესი HTTP-მეთოდის მიხედვით: GET ნებადართული (200), POST უარყოფილია
   Envoy-პროქსის მიერ კოდით 403.

2. VPC CNI NP-ს არ აქვს DNS-სახელის პოლიტიკები. Cilium-მა დაამატა
   CiliumNetworkPolicy toFQDNs-ით - egress დაშვებულია მხოლოდ aws.amazon.com-ზე,
   example.com დაიდროპება (HTTP_CODE=000).

3. ჩაშენებული VPC CNI NP-ის დიაგნოსტიკა - მხოლოდ აგენტის ლოგები და მეტრიკები.
   Cilium-მა მოიტანა Hubble: per-flow verdict-იანი (FORWARDED/DROPPED) ნაკადების
   რუკა hubble observe-ის საშუალებით.

4. ამის ფასი: საკუთარი Helm-რელიზი Cilium-ისთვის თავისი აპგრეიდებით, გუნდისთვის
   მეორე CRD-მოდელი, დამატებითი შრე დატაპასში, ასევე ის, რომ პულ cilium-demo-ს
   გარეთ pod-ები (მაგალითად coredns Fargate-ზე) რჩება Cilium-ის დატაპასის გარეთ და
   პოლიტიკებში ჩნდება მხოლოდ როგორც reserved:world - label-ის მიხედვით წესები მათზე
   არ ვრცელდება.

5. VPC CNI-ის სრული ჩანაცვლება (როცა aws-node წაიშლება და Cilium თავად ხდება IPAM)
   ამ ლაბის ფარგლებში არ შედის: CNI-ის შეცვლა ცოცხალ კლასტერზე - ეს არის
   blue/green ახალი ნოუდების საშუალებით, არა flag-ის გადართვა გავარდნის დროს
   (chapter 8, 8.8 ნაწილი). აქ ამუშავებულია მხოლოდ უსაფრთხო ვარიანტი - CNI chaining.
EOF
cat /var/work/tests/artifacts/8/comparison.txt
```

## სისწრაფის შემოწმება

```bash
check_result
```

## ხაფანგები, რომლებზეც ეს ლაბა გადადგებით

ოთხივე პუნქტი გადამოწმებულია ცოცხალ სტენდზე.

1. `cilium-operator` წაიღებს კლასტერის DNS-ს. ნაგულისხმევად
   `operator.unmanagedPodWatcher.restart=true`: ოპერატორი ყოველ 15 წამში წაშლის
   pod-ებს `CiliumEndpoint`-ის გარეშე. `coredns` Fargate-ზე ასეთი არასდროს გახდება,
   ამიტომ მისი pod-ები წირწილდება წრეზე, ყოველზე ახალი Fargate-მიკრო-VM ბადება, და
   DNS კლასტერში ხან არის, ხან არა. სიმპტომი pod-ის მხრიდან: `nslookup` აჩვენებს
   `connection timed out; no servers could be reached`-ს. ვინ ზუსტად წაშლის
   pod-ებს, ჩანს control plane-ის audit-ლოგში: ჩანაწერებში `verb: delete`
   `coredns`-ის pod-ებზე დგას `user.username =
   system:serviceaccount:kube-system:cilium-operator` და `userAgent =
   cilium-operator-generic/1.20.0`. მკურნალობა - ფლაგი
   `operator.unmanagedPodWatcher.restart=false` (`cilium-config`-ში გამოჩნდება
   `unmanaged-pod-watcher-interval: "0"`).

2. Fargate-პროფილს არ ესმის `nodeSelector`. თუ პროფილი მთლიანად ფარავს namespace
   `kube-system`-ს (`selectors = [{ namespace = "kube-system" }]`), Fargate-webhook
   ანიშნავს თავის პროფილს ნებისმიერ pod-ს, რომელსაც ამ namespace-ში მოგვიანებით
   დაამატებთ, `cilium-operator`-ის ჩათვლით. შემდეგ pod-ს სქედულს უწევს მხოლოდ
   `fargate-scheduler`, რომელსაც არ ესმის ვერც `hostNetwork`, ვერც `nodeSelector`
   და არასდროს ბრუნდება ჩვეულებრივ scheduler-ზე. სიმპტომები: `Pod not supported
   on Fargate: fields not supported: HostNetwork, port contains HostIP or
   HostPort`, ხოლო `operator.hostNetwork=false`-ის შემდეგ -
   `MatchNodeSelector failed: Fargate profile kube-system cannot satisfy pod's
   node selector/affinity requirements`. ამ ლაბაში პროფილი ამიტომ ვიწროვდება
   label-სელექტორით `eks.amazonaws.com/component: coredns` (იხ.
   `eks_fargate_system/terragrunt.hcl`).

3. Fargate-პროფილი ხელახლა შექმნილია - ხელახლა გაუშვათ pod-ები, რომლებიც მან
   უნდა ამოიცნოს. pod-ის მუტაცია ხდება მხოლოდ მისი შექმნის მომენტში, ამიტომ pod
   `karpenter`, შექმნილი მანამ, სანამ ახალი პროფილი გახდებოდა `ACTIVE`, სამუდამოდ
   დარჩება `Pending`-ში `0/N nodes are available: N node(s) had untolerated
   taint(s)`-ით. მკურნალობა - `kubectl delete pod` ამ pod-ისთვის.

4. `cilium-envoy`-ის pod-ები დაიკიდება `Pending`-ში, თუ მითითებულია მხოლოდ ზედა
   `nodeSelector`. DaemonSet `cilium-envoy`-ს თავისი სექცია `envoy.nodeSelector` /
   `envoy.tolerations` აქვს; მის გარეშე ის ცხვდება ყველა ლინუქს-ნოუდზე, და
   `cilium status` აჩვენებს `Envoy DaemonSet: 1 errors`-ს.
