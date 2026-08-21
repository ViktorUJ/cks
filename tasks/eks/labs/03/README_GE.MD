[Русская версия](README_RUS.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)


# ლაბორატორიული სამუშაო: აპლიკაციის ავტომასშტაბირება KEDA-სა და Prometheus-ის გამოყენებით

## აღწერა

ეს ლაბორატორიული სამუშაო გვიჩვენებს, როგორ დავამასშტაბიროთ ვებაპლიკაცია ავტომატურად Amazon EKS-ში **KEDA**-ს (Kubernetes Event-Driven Autoscaling) გამოყენებით, **Prometheus**-ის მეტრიკების საფუძველზე. აპლიკაცია საკუთარ მოთხოვნის მეტრიკებს ექსპორტირებს, Prometheus აგროვებს მათ, ხოლო KEDA განლაგებას ზრდის და ამცირებს წამში მოთხოვნების რეალური რაოდენობის (RPS) მიხედვით.

კლასტერი უკვე მომზადებულია **Karpenter**-ითა და ორი გამოყოფილი NodePool-ით:
- `monitoring` — მონიტორინგის სტეკისთვის (Prometheus, KEDA, metrics-server)
- `default` — სატესტო აპლიკაციისთვის

**რას შეისწავლით:**
- როგორ დავაყენოთ ოფიციალური Prometheus Operator (kube-prometheus-stack) Helm-ის მეშვეობით
- როგორ მივამაგროთ დატვირთვები გამოყოფილ ნოდებს nodeAffinity-ისა და tolerations-ის გამოყენებით
- როგორ გამოვაქვეყნოთ Prometheus LoadBalancer-ის მეშვეობით სწრაფი წვდომისთვის
- როგორ შევაგროვოთ აპლიკაციის მომხმარებლის მეტრიკები ServiceMonitor-ის მეშვეობით
- როგორ დავაყენოთ KEDA და მოვაწყოთ ScaledObject Prometheus-ის მოთხოვნის საფუძველზე
- როგორ შევქმნათ დატვირთვა და დავაკვირდეთ ავტომატურ ზრდას/შემცირებას
- როგორ წავშალოთ ღრუბლოვანი რესურსები სწორად (LoadBalancer, Karpenter-ის ნოდები)

## სარჩევი
- [გარემოს მომზადება](#გარემოს-მომზადება)
  - [ლაბორატორიული სამუშაოს გაშვება](#ლაბორატორიული-სამუშაოს-გაშვება)
  - [შესაქმნელი რესურსები](#შესაქმნელი-რესურსები)
  - [წინაპირობები](#წინაპირობები)
- [NodePool-ების დათვალიერება](#nodepool-ების-დათვალიერება)
- [მონიტორინგის სტეკის დაყენება](#მონიტორინგის-სტეკის-დაყენება)
  - [Prometheus Operator და metrics-server](#prometheus-operator-და-metrics-server)
  - [დაყენების შემოწმება](#დაყენების-შემოწმება)
- [აპლიკაციის განთავსება](#აპლიკაციის-განთავსება)
- [აპლიკაციის მეტრიკების შეგროვება](#აპლიკაციის-მეტრიკების-შეგროვება)
  - [ServiceMonitor-ის შექმნა](#servicemonitor-ის-შექმნა)
  - [სამიზნის შემოწმება](#სამიზნის-შემოწმება)
  - [მეტრიკების შემოწმება Prometheus-ში](#მეტრიკების-შემოწმება-prometheus-ში)
- [KEDA-ს დაყენება](#keda-ს-დაყენება)
- [ავტომასშტაბირების კონფიგურაცია](#ავტომასშტაბირების-კონფიგურაცია)
  - [აპლიკაციის ხელმისაწვდომი მეტრიკები](#აპლიკაციის-ხელმისაწვდომი-მეტრიკები)
  - [ScaledObject-ის შექმნა](#scaledobject-ის-შექმნა)
- [დატვირთვის გენერირება და მასშტაბირებაზე დაკვირვება](#დატვირთვის-გენერირება-და-მასშტაბირებაზე-დაკვირვება)
- [რესურსების გასუფთავება](#რესურსების-გასუფთავება)
- [დასკვნა](#დასკვნა)


## გარემოს მომზადება

### ლაბორატორიული სამუშაოს გაშვება
[პლატფორმის გაშვება docker-ის მეშვეობით](https://github.com/ViktorUJ/cks/blob/master/docs%2Frun_from_docker.MD)

ლაბორატორიული სამუშაოს გასაშვებად შეასრულეთ ბრძანება:

```bash
TASK=03 make run_eks_task
```

**რა ხდება ამ ბრძანების გაშვებისას:**
- Terraform/Terragrunt ავტომატურად განათავსებს AWS-ში მთელ საჭირო ინფრასტრუქტურას
- პროცესს დაახლოებით 15-20 წუთი სჭირდება
- ბრძანების გამონატანში ნაჩვენები იქნება მნიშვნელოვანი ინფორმაცია (SSH-კავშირი, რესურსების სახელები)

### შესაქმნელი რესურსები

ბრძანების გაშვებისას განთავსდება შემდეგი AWS ინფრასტრუქტურა:

#### ქსელური ინფრასტრუქტურა (VPC)
- **VPC** CIDR-ბლოკით `10.10.0.0/16` რეგიონში `eu-central-1`
- **საჯარო ქვექსელები** ინტერნეტთან წვდომის მქონე რესურსებისთვის (`eks-AZ-1`, `eks-AZ-2`)
- **კერძო ქვექსელები** EKS-ის ნოდებისა და RDS-ისთვის
- **NAT Gateway** კერძო ქვექსელებიდან გამავალი ინტერნეტტრაფიკისთვის

#### EKS-კლასტერი
- **EKS Control Plane** ვერსია `1.35`
- **Fargate-პროფილი** სისტემური პოდებისთვის (`kube-system`, `karpenter`) — გაითვალისწინეთ: CoreDNS მუშაობს Fargate-ზე
- **Karpenter** ვერსია `1.8.1` (ავტომასშტაბირების კონტროლერი)
- **EKS Add-ons**: coredns, kube-proxy, vpc-cni, eks-pod-identity-agent

#### წინასწარ კონფიგურირებული Karpenter NodePool-ები
- **`default`** — აპლიკაციის დატვირთვებისთვის (ცარიელ ნოდებს აერთიანებს 30წმ-ის შემდეგ)
- **`monitoring`** — გამოყოფილია მონიტორინგის სტეკისთვის, taint-ით `dedicated=monitoring:NoSchedule` და label-ით `work_type=monitoring` (აერთიანებს 300წმ-ის შემდეგ)

#### კონფიგურაციის ძირითადი ფაილი

ინფრასტრუქტურის ყველა პარამეტრი მოცემულია ფაილში `tasks/eks/labs/03/env.hcl`. კონფიგურაციის შესაცვლელად ჩაასწორეთ შესაბამისი პარამეტრები ამ ფაილში.

### წინაპირობები

დარწმუნდით, რომ გაქვთ:
- **AWS CLI** შესაბამისი წვდომის უფლებებით
- რეგიონში `eu-central-1` ნოდების გაზრდილი ლიმიტები (საჭიროების შემთხვევაში)
- worker-ნოდთან SSH-ით კავშირი (კავშირის სტრიქონი იხილეთ `make run_eks_task`-ის გამონატანში)
- worker-ნოდზე ხელმისაწვდომი `kubectl`, `helm` და `jq`


## NodePool-ების დათვალიერება

ორი NodePool უკვე მომზადებულია. შევამოწმოთ ისინი:

```bash
kubectl get nodepools.karpenter.sh
```

**მოსალოდნელი შედეგი:**
```
NAME         NODECLASS    NODES   READY   AGE
default      default      0       True    2m46s
monitoring   monitoring   0       True    2m43s
```

- **`monitoring`** — Prometheus-ის, KEDA-სა და metrics-server-ისთვის
- **`default`** — სატესტო აპლიკაციისთვის

უფრო დეტალურად ვნახოთ NodePool `monitoring`:

```bash
kubectl get nodepools.karpenter.sh monitoring -o yaml
```

**სპეციფიკაციის ძირითადი ნაწილები:**
```yaml
spec:
  template:
    metadata:
      labels:
        work_type: monitoring        # გამოიყენება nodeAffinity-ში
    spec:
      taints:
      - effect: NoSchedule
        key: dedicated
        value: monitoring            # აქ მოხვდება მხოლოდ შესაბამისი toleration-ის მქონე პოდები
```

**რას ნიშნავს ეს:** მონიტორინგის პოდებს უნდა ჰქონდეთ როგორც `nodeAffinity` `work_type=monitoring`-ზე, ასევე `toleration` `dedicated=monitoring:NoSchedule`-ისთვის. ეს უზრუნველყოფს, რომ მონიტორინგის სტეკი საკუთარ ნოდებზე მუშაობდეს და იქ ზედმეტი არაფერი მოხვდეს.


## მონიტორინგის სტეკის დაყენება

### Prometheus Operator და metrics-server

Helm-ის მეშვეობით ვაყენებთ **kube-prometheus-stack**-ს (ოფიციალურ Prometheus Operator-ს) და **metrics-server**-ს. Grafana გამორთულია. ყველა კომპონენტი მიმაგრებულია NodePool `monitoring`-ზე `nodeAffinity` + `tolerations`-ის მეშვეობით.

> **შენიშვნა უსაფრთხოების შესახებ:** ქვემოთ Prometheus-ის Service ქვეყნდება საჯარო LoadBalancer-ის მეშვეობით **ავთენტიფიკაციის გარეშე**. ეს გაკეთებულია მხოლოდ ლაბორატორიული სამუშაოს მოხერხებულობისთვის. production-ში Prometheus დაცული უნდა იყოს (ავთენტიფიკაცია / OAuth2 proxy, IP-ის მიხედვით შეზღუდვა Security Groups-ის ან NetworkPolicy-ის მეშვეობით, Ingress TLS-ით).

```bash
# ვამატებთ Helm-რეპოზიტორიებს
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# ვქმნით values-ფაილს Prometheus-ისთვის
cat <<'EOF' > prometheus-values.yaml
# ყურადღება: Prometheus-ის LoadBalancer ღიაა ავთენტიფიკაციის გარეშე.
# ეს მხოლოდ ლაბორატორიული სამუშაოსთვისაა. production-ში დაიცავით Prometheus
# ავთენტიფიკაციით, IP-ის მიხედვით შეზღუდვით (Security Groups / NetworkPolicy) და TLS-ით.

grafana:
  enabled: false

kubeStateMetrics:
  enabled: true

nodeExporter:
  enabled: true

prometheus:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    loadBalancerSourceRanges:
      - "0.0.0.0/0"
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorNamespaceSelector: {}
    serviceMonitorSelector: {}
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: work_type
                  operator: In
                  values:
                    - monitoring
    tolerations:
      - key: dedicated
        value: monitoring
        effect: NoSchedule

prometheusOperator:
  admissionWebhooks:
    patch:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: work_type
                    operator: In
                    values:
                      - monitoring
      tolerations:
        - key: dedicated
          value: monitoring
          effect: NoSchedule
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: work_type
                operator: In
                values:
                  - monitoring
  tolerations:
    - key: dedicated
      value: monitoring
      effect: NoSchedule

alertmanager:
  alertmanagerSpec:
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: work_type
                  operator: In
                  values:
                    - monitoring
    tolerations:
      - key: dedicated
        value: monitoring
        effect: NoSchedule

kube-state-metrics:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: work_type
                operator: In
                values:
                  - monitoring
  tolerations:
    - key: dedicated
      value: monitoring
      effect: NoSchedule

prometheus-node-exporter:
  tolerations:
    - key: dedicated
      value: monitoring
      effect: NoSchedule
EOF

# ვქმნით values-ფაილს metrics-server-ისთვის
cat <<'EOF' > metrics-server-values.yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: work_type
              operator: In
              values:
                - monitoring
tolerations:
  - key: dedicated
    value: monitoring
    effect: NoSchedule
EOF

# ვაყენებთ Prometheus Operator-ს
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f prometheus-values.yaml

# ვაყენებთ metrics-server-ს
helm install metrics-server metrics-server/metrics-server \
  --namespace monitoring \
  -f metrics-server-values.yaml
```

**values-ის განმარტებები:**
- `serviceMonitorSelectorNilUsesHelmValues: false` + ცარიელი სელექტორები Prometheus-ს საშუალებას აძლევს, ServiceMonitor-ები **ყველა** namespace-იდან აიღოს (ეს საჭიროა მოგვიანებით აპლიკაციის მეტრიკების შესაგროვებლად).
- თითოეული კომპონენტი აცხადებს `nodeAffinity`-ს (`work_type=monitoring`), ამიტომ იგეგმება **მხოლოდ** მონიტორინგის ნოდებზე. მხოლოდ `nodeSelector` საკმარისი არ არის — affinity განთავსებას უზრუნველყოფს.
- `node-exporter` იღებს მხოლოდ toleration-ს (ის თითოეულ ნოდზე DaemonSet-ის სახით უნდა მუშაობდეს).

### დაყენების შემოწმება

```bash
# მონიტორინგის ყველა პოდი მონიტორინგის ნოდებზე Running მდგომარეობაში უნდა იყოს
kubectl get pods -n monitoring -o wide

# მონიტორინგის ნოდები გაშვებული უნდა იყოს
kubectl get nodes -l work_type=monitoring

# metrics-server უნდა მუშაობდეს
kubectl top nodes

# ვიღებთ Prometheus-ის LoadBalancer-ის მისამართს (Prometheus-ის UI 9090 პორტზე)
kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' ; echo
```

Prometheus-ის UI-ზე წვდომისთვის ბრაუზერში გახსენით `http://<LB-ADDRESS>:9090`.


## აპლიკაციის განთავსება

განათავსეთ სატესტო აპლიკაცია (`ping_pong`). Service აქვეყნებს ორ პორტს: `http` (80 → 8080) და `metrics` (9090 → 9090).

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/03/worker/files/tasks/1.yaml
```

შეამოწმეთ, რომ აპლიკაცია გაეშვა:

```bash
kubectl get po -n team-19
```

**მოსალოდნელი შედეგი:**
```
NAME                     READY   STATUS    RESTARTS   AGE
team19-598dc8484-vlqkd   1/1     Running   0          2m54s
```

შეამოწმეთ NodeClaim — მონიტორინგისთვის და აპლიკაციისთვის ცალ-ცალკე ნოდები უნდა არსებობდეს:

```bash
kubectl get nodeclaims.karpenter.sh
```

**მოსალოდნელი შედეგი:**
```
NAME               TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-n5mxw      t4g.small   spot       eu-central-1a   ip-10-10-15-217.eu-central-1.compute.internal   True    16m
monitoring-rlm6f   t4g.small   spot       eu-central-1a   ip-10-10-15-53.eu-central-1.compute.internal    True    24m
```


## აპლიკაციის მეტრიკების შეგროვება

### ServiceMonitor-ის შექმნა

აპლიკაციას Prometheus-ის მეტრიკები ექსპორტზე გააქვს `9090` პორტზე, `/metrics` ბილიკით. `metrics` პორტი უკვე განსაზღვრულია აპლიკაციის Service-ში, ამიტომ საჭიროა მხოლოდ ServiceMonitor. Label `release: prometheus` Prometheus Operator-ს მისი აღმოჩენის საშუალებას აძლევს.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: team19
  namespace: team-19
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: team19
  endpoints:
  - port: metrics
    interval: 15s
    path: /metrics
EOF
```

### სამიზნის შემოწმება

```bash
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# სამიზნე უნდა არსებობდეს და გამართულად მუშაობდეს (health: up)
curl -s "http://${PROM_URL}:9090/api/v1/targets" \
  | jq '.data.activeTargets[] | select(.labels.namespace=="team-19") | {endpoint: .scrapeUrl, health: .health}'
```

### მეტრიკების შემოწმება Prometheus-ში

```bash
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# ვამოწმებთ requests_total მეტრიკას
curl -s "http://${PROM_URL}:9090/api/v1/query" \
  --data-urlencode 'query=requests_total{namespace="team-19"}' | jq '.data.result'
```

თუ შედეგი ცარიელია `[]` — ეს ნიშნავს, რომ ServiceMonitor ჯერ არ აღმოჩენილა. ცოტა ხანს დაელოდეთ და გაიმეორეთ, ან ზემოთ სამიზნის მდგომარეობა შეამოწმეთ.

ასევე შეგიძლიათ ბრაუზერში გახსნათ `http://<PROM_URL>:9090` და Expression ველში შეიყვანოთ `requests_total`.

> **მინიშნება:** მეტრიკის მნიშვნელობა ბრუნდება ფორმატით `"value": [<timestamp>, "<მნიშვნელობა>"]`. პირველი რიცხვი შეგროვების დროა, მეორე (სტრიქონი) — თავად მნიშვნელობა. ის იქნება `0`, სანამ აპლიკაციისკენ ტრაფიკი არ წავა.


## KEDA-ს დაყენება

KEDA იმავე ნოდებზე მუშაობს, რომლებზეც Prometheus (NodePool `monitoring`). KEDA-ს Helm-ჩარტი ზედა დონის `tolerations`-სა და `affinity`-ს თავის **ყველა** კომპონენტზე იყენებს (operator, metrics apiserver, webhooks).

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

cat <<'EOF' > keda-values.yaml
# გლობალური tolerations და affinity KEDA-ს ყველა კომპონენტისთვის
tolerations:
  - key: dedicated
    value: monitoring
    effect: NoSchedule

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: work_type
              operator: In
              values:
                - monitoring
EOF

helm install keda kedacore/keda \
  --namespace monitoring \
  -f keda-values.yaml
```

### KEDA-ს შემოწმება

```bash
# KEDA-ს პოდები მონიტორინგის ნოდებზე Running მდგომარეობაში უნდა იყოს
kubectl get pods -n monitoring -l app.kubernetes.io/instance=keda -o wide

# KEDA-ს CRD-ები დაყენებული უნდა იყოს
kubectl get crd | grep keda
```

> **შენიშვნა:** KEDA-ს `metrics-apiserver` — KEDA-ს შიდა კომპონენტია (ის Kubernetes HPA-ს გარე მეტრიკებს აწვდის). ეს **არ არის** იგივე, რაც ადრე დაყენებული კლასტერული `metrics-server` — საჭიროა ორივე.


## ავტომასშტაბირების კონფიგურაცია

### აპლიკაციის ხელმისაწვდომი მეტრიკები

აპლიკაცია `ping_pong` ექსპორტზე გაიტანს Prometheus-ის შემდეგ მეტრიკებს (პორტი 9090, ბილიკი `/metrics`):

| მეტრიკა | ტიპი | აღწერა |
|---------|-----|----------|
| `requests_total` | Counter | მოთხოვნების საერთო რაოდენობა |
| `requests_per_second` | Gauge | მყისიერი RPS (ხმაურიანია, უმოქმედობისას 0-ზე არ ჩამოდის) |
| `requests_per_minute` | Gauge | მყისიერი RPM |
| `goroutines` | Gauge | გორუტინების მიმდინარე რაოდენობა |

მასშტაბირებისთვის ვიყენებთ **`rate(requests_total[1m])`**-ს და არა დაუმუშავებელ gauge-ს `requests_per_second`. მთვლელზე დაფუძნებული `rate()` იძლევა ნამდვილ, გასაშუალოებულ RPS-ს, რომელიც დატვირთვასთან ერთად წრფივად იზრდება და ტრაფიკის შეწყვეტისას სამართლიანად ეცემა 0-მდე — ამის წყალობით ზღვრის შერჩევა ადვილია.

### ScaledObject-ის შექმნა

წესი: რეპლიკები = `ceil(sum(rate(requests_total[1m])) / threshold)`. `behavior`-ის მეშვეობით კონფიგურირებულია სწრაფი შემცირება, რათა დატვირთვის ვარდნის შემდეგ პოდები სწრაფად წაიშალოს.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: team19-scaledobject
  namespace: team-19
spec:
  scaleTargetRef:
    name: team19
  minReplicaCount: 1
  maxReplicaCount: 10
  pollingInterval: 10
  cooldownPeriod: 10
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          # სწრაფი შემცირება: სტაბილიზაციის ფანჯარა 10წმ, შესაძლებელია პოდების 100%-მდე წაშლა
          stabilizationWindowSeconds: 10
          policies:
          - type: Percent
            value: 100
            periodSeconds: 10
        scaleUp:
          stabilizationWindowSeconds: 0
          policies:
          - type: Percent
            value: 100
            periodSeconds: 10
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
      # rate(requests_total[1m]) -> მთვლელიდან მიღებული ნამდვილი RPS; sum ყველა პოდზე.
      # რეპლიკები = ceil(sum(rate) / threshold)
      query: sum(rate(requests_total{namespace="team-19", service="team19"}[1m]))
      threshold: "10"
      activationThreshold: "3"
EOF
```

**განმარტებები:**
- `threshold` — მიზნობრივი RPS **თითო პოდზე**, რომლის შენარჩუნებასაც HPA ცდილობს.
- `activationThreshold: 3` ნიშნავს, რომ KEDA ერთ რეპლიკას ინარჩუნებს, სანამ ჯამური RPS 3-ს არ გადააჭარბებს, რაც უმოქმედობისას რყევას გამორიცხავს.
- `query`-ში გამოიყენება `sum(...)` (ჯამური RPS, არ არის დამოკიდებული რეპლიკების რაოდენობაზე), ამიტომ რეპლიკების სასურველი რაოდენობა სტაბილურია. აქ `avg(...)`-ის გამოყენება პოდების დამატებისას ოსცილაციას გამოიწვევდა.

შეამოწმეთ ScaledObject და მის მიერ შექმნილი HPA:

```bash
kubectl get scaledobject -n team-19
kubectl get hpa -n team-19
```


## დატვირთვის გენერირება და მასშტაბირებაზე დაკვირვება

გაუშვით პოდი, რომელიც აპლიკაციის Service-ზე დატვირთვას ქმნის. შიდა ციკლი აგზავნის N მოთხოვნას, გარე `sleep 1` კი ტემპს განსაზღვრავს — ამიტომ `seq 1 N`-ში რიცხვი დაახლოებით მიზნობრივ RPS-ს უდრის.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: traffic-generator
  namespace: team-19
spec:
  containers:
  - name: loader
    image: busybox
    command:
    - /bin/sh
    - -c
    - |
      echo "Starting traffic generation..."
      while true; do
        for i in $(seq 1 50); do
          wget -q -O /dev/null http://team19.team-19.svc.cluster.local:80/ &
        done
        sleep 1
      done
EOF
```

### მასშტაბირებაზე დაკვირვება

ერთი `watch` ერთდროულად აჩვენებს პოდებს, HPA-სა და Prometheus-იდან თითო პოდზე RPS-ს. PromQL მოთხოვნა URL-კოდირებულია (`--data-urlencode`), წინააღმდეგ შემთხვევაში სიმბოლოები `{`, `}` და `=` პარსერს არღვევს.

```bash
export PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

watch 'kubectl get pods -n team-19 ; echo ; kubectl get hpa -n team-19 ; echo ; echo -n "rps per pod = " ; curl -s "http://${PROM_URL}:9090/api/v1/query" --data-urlencode "query=sum(rate(requests_total{namespace=\"team-19\", service=\"team19\"}[1m])) / count(up{namespace=\"team-19\", service=\"team19\"})" | jq -r ".data.result[0].value[1]"'
```

**რა უნდა დაინახოთ:** დატვირთვის ზრდასთან ერთად პოდების რაოდენობა მიისწრაფვის `ceil(ჯამური_rps / threshold)`-ისკენ. HPA-ს `TARGETS` სვეტი (RPS თითო პოდზე) ემთხვევა `rps per pod`-ს, რომელსაც watch აჩვენებს.

> **მინიშნება შერჩევისთვის:** პოდები ≈ (რიცხვი `seq 1 N`-ში) / threshold. `seq 1 50`-ითა და `threshold: 10`-ით მიიღება დაახლოებით 5 პოდი. გაზარდეთ რიცხვი მეტი პოდის მისაღებად.

### დატვირთვის შეჩერება

```bash
kubectl delete pod traffic-generator -n team-19
```

ტრაფიკის შეჩერების შემდეგ `rate(requests_total[1m])` 0-მდე მცირდება. `cooldownPeriod`-ის (10წმ) და შემცირების სტაბილიზაციის ფანჯრის (10წმ) განმავლობაში KEDA კვლავ `minReplicaCount: 1`-მდე ამცირებს მასშტაბს.


## რესურსების გასუფთავება

### აპლიკაციის წაშლა

```bash
# ვშლით ScaledObject-ს (KEDA შეწყვეტს HPA-ს მართვას)
kubectl delete scaledobject team19-scaledobject -n team-19

# ვშლით ტრაფიკის გენერატორს (თუ ჯერ კიდევ გაშვებულია)
kubectl delete pod traffic-generator -n team-19 --ignore-not-found

# ვშლით ServiceMonitor-ს
kubectl delete servicemonitor team19 -n team-19 --ignore-not-found

# ვშლით თავად აპლიკაციას (deployment, service, namespace)
kubectl delete -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/03/worker/files/tasks/1.yaml
```

### Prometheus-ის წაშლა (მნიშვნელოვანია: შლის LoadBalancer-ს)

Helm-რელიზის წაშლა შლის LoadBalancer ტიპის Service-ს და AWS ათავისუფლებს ELB-ს.

```bash
# ვშლით prometheus-ს (ეს წაშლის Service LoadBalancer-ს -> AWS ELB)
helm uninstall prometheus -n monitoring

# ვშლით metrics-server-სა და keda-ს
helm uninstall metrics-server -n monitoring
helm uninstall keda -n monitoring
```

ვამოწმებთ, რომ LoadBalancer (ELB) ნამდვილად წაიშალა:

```bash
# Service prometheus არ უნდა არსებობდეს
kubectl get svc -n monitoring | grep prometheus

# AWS-ში ვადასტურებთ, რომ ELB წაშლილია
aws elb describe-load-balancers --region eu-central-1 \
  --query "LoadBalancerDescriptions[].DNSName"
```

თუ Service რაიმე მიზეზით დარჩა და ELB-ის წაშლას ბლოკავს, ხელით წაშალეთ:

```bash
kubectl delete svc prometheus-kube-prometheus-prometheus -n monitoring --ignore-not-found
```

შემდეგ წაშალეთ namespace:

```bash
kubectl delete namespace monitoring
```

> **მნიშვნელოვანია:** ყოველთვის წაშალეთ LoadBalancer ტიპის Service ნოდების ან კლასტერის წაშლამდე.
> თუ ჯერ ნოდებს/კლასტერს წაშლით, AWS ELB შესაძლოა დარჩეს „ჩამოკიდებული“, როგორც orphaned-რესურსი,
> და მისი ხელით წაშლა მოგიწევთ კონსოლის ან CLI-ის მეშვეობით.

### შემოწმება, რომ Karpenter-მა ყველა ნოდი წაშალა

ყველა დატვირთვის წაშლის შემდეგ `default` და `monitoring` ნოდები ცარიელდება და Karpenter-მა ისინი უნდა გააერთიანოს (წაშალოს).

```bash
# ვაკვირდებით, როგორ მცირდება nodeclaims-ის რაოდენობა ნულამდე
watch kubectl get nodeclaims.karpenter.sh
```

Karpenter ცარიელ ნოდებს თითოეული NodePool-ის `consolidateAfter`-ის მიხედვით შლის
(`default` = 30წმ, `monitoring` = 300წმ), ამიტომ მონიტორინგის ნოდების წაშლას მეტი დრო სჭირდება.

დაელოდეთ, სანამ ორივე ბრძანება ცარიელ შედეგს დააბრუნებს:

```bash
kubectl get nodeclaims.karpenter.sh
kubectl get nodes -l work_type
```

თუ ნოდი არ იშლება — შეამოწმეთ პოდები, რომლებიც გაერთიანებას უშლის ხელს (მაგალითად, კონტროლერის გარეშე პოდები ან `karpenter.sh/do-not-disrupt`-ის მქონე პოდები):

```bash
kubectl get pods -A -o wide --field-selector spec.nodeName=<имя-ноды>
```

### ინფრასტრუქტურის წაშლა

მხოლოდ მას შემდეგ, რაც Karpenter ყველა ნოდს წაშლის, წაშალეთ ლაბორატორიული სამუშაოს ინფრასტრუქტურა:

```bash
TASK=03 make delete_eks_task
```

დასადასტურებლად შეიყვანეთ `y`. წაშლას დაახლოებით 10-15 წუთი სჭირდება.

> ინფრასტრუქტურის წაშლამ მანამდე, სანამ Karpenter საკუთარ ნოდებს წაშლის, შესაძლოა orphaned EC2-ინსტანსები დატოვოს.


## დასკვნა

გილოცავთ! თქვენ EKS-ზე მოვლენებზე დაფუძნებული ავტომასშტაბირების სისტემა ააწყვეთ.

**რა გააკეთეთ:**

1. **მონიტორინგის სტეკი** — დააყენეთ ოფიციალური Prometheus Operator და metrics-server, nodeAffinity-ისა და tolerations-ის მეშვეობით გამოყოფილ ნოდებზე მათი მიმაგრებით
2. **გამოქვეყნება** — სწრაფი წვდომისთვის Prometheus LoadBalancer-ის მეშვეობით გამოაქვეყნეთ (მხოლოდ ლაბორატორიული სამუშაოსთვის, ავთენტიფიკაციის გარეშე)
3. **მომხმარებლის მეტრიკები** — ServiceMonitor-ის მეშვეობით შეაგროვეთ აპლიკაციის მოთხოვნების საკუთარი მეტრიკები
4. **KEDA** — დააყენეთ KEDA და Prometheus-ის მოთხოვნის საფუძველზე ScaledObject დააკონფიგურირეთ
5. **ავტომასშტაბირება** — აპლიკაცია რეალური RPS-ის მიხედვით `rate(requests_total[1m])`-ის მეშვეობით, სწრაფი შემცირებით დაასქეილეთ
6. **გასუფთავება** — სწორად წაშალეთ LoadBalancer და ინფრასტრუქტურის წაშლამდე Karpenter-ს ნოდების გათავისუფლების საშუალება მიეცით

**ძირითადი დასკვნები:**

- სტაბილური, პროგნოზირებადი ავტომასშტაბირებისთვის ხმაურიანი მყისიერი gauge-ის ნაცვლად გამოიყენეთ მთვლელზე დაფუძნებული `rate()`
- სკეილერის მოთხოვნაში გამოიყენეთ `sum(...)` (`avg(...)`-ის ნაცვლად), რათა პოდების დამატებისას რეპლიკების სასურველი რაოდენობა არ ირყეოდეს
- ინფრასტრუქტურული დატვირთვები გამოყოფილ ნოდებს მიამაგრეთ როგორც nodeAffinity-ის, ასევე tolerations-ის მეშვეობით
- orphaned ELB-ის თავიდან ასაცილებლად ყოველთვის წაშალეთ LoadBalancer ტიპის Service კლასტერის წაშლამდე

**დამატებითი რესურსები:**
- [KEDA-ს დოკუმენტაცია](https://keda.sh/docs/)
- [Prometheus scaler KEDA-ში](https://keda.sh/docs/latest/scalers/prometheus/)
- [kube-prometheus-stack-ის ჩარტი](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Karpenter-ის დოკუმენტაცია](https://karpenter.sh/docs/)
