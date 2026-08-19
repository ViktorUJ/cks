[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 124 - ეტალონური გადაწყვეტა (HPA, KEDA, Prometheus)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე SSH-ის მეშვეობით. kubectl და helm უკვე
კონფიგურირებულია (kubeconfig იწყობა `aws eks update-kubeconfig`-ით მანქანის
ჩატვირთვისას).

## დავალება 1. Namespace `eks-124`

```bash
kubectl create namespace eks-124
```

## დავალება 2. kube-prometheus-stack namespace `monitoring`-ში

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.enabled=false \
  --set alertmanager.enabled=false \
  --set prometheus.prometheusSpec.resources.requests.cpu=200m \
  --set prometheus.prometheusSpec.resources.requests.memory=512Mi
```

ეს სამი ფლაგი კოსმეტიკა არ არის. ლაბას Grafana და Alertmanager არ სჭირდება, ხოლო
Grafana ჩარტის ყველაზე მძიმე პოდია (დაახლოებით 325 MiB სტენდზე). ცალსახა
`requests` Prometheus-ს `BestEffort`-იდან `Burstable`-ში გადაყავს: მისი
საჭიროებები დაინახავს როგორც scheduler-მა, ისევე Karpenter-მაც, რომელიც
ნოუდის ზომას `requests`-ის ჯამის მიხედვით ირჩევს. ამის გარეშე მონიტორინგის
სტეკი ეშვება ყველაზე ეკონომიურ instance-ზე, და kubelet Prometheus-ს
ითვისტირებს მეხსიერების ნაკლებობისას - დაწვრილებითი განხილვა ლაბის README-ში.

ველოდებით პოდების მზაობას:

```bash
kubectl get pods -n monitoring -w
```

ველოდებით, სანამ ყველა პოდი გადავა `Running`-ში და `1/1` (ან `2/2`) Ready-ში -
ეს ჩვეულებრივ 2-3 წუთს მოითხოვს. ვამოწმებთ Service-ს, რომელსაც KEDA უყურებს, და
პოდის QoS-კლასს:

```bash
kubectl get svc -n monitoring kube-prometheus-stack-prometheus
kubectl get pod -n monitoring prometheus-kube-prometheus-stack-prometheus-0 \
  -o jsonpath='{.status.qosClass}{"\n"}'
```

მეორე ბრძანების მოსალოდნელი output არის `Burstable`.

## დავალება 3. KEDA namespace `keda`-ში

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm install keda kedacore/keda --namespace keda --create-namespace
```

ვამოწმებთ, რომ operator და metrics apiserver ჩართულია:

```bash
kubectl get pods -n keda
```

მოსალოდნელი შედეგი: პოდები სახელებით `keda-operator-...` და
`keda-operator-metrics-apiserver-...` `Running` სტატუსში.

## დავალება 4. Deployment `demo-app`

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: eks-124
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "200m"
            memory: "128Mi"
EOF

kubectl rollout status deployment/demo-app -n eks-124
```

## დავალება 5. ScaledObject `prometheus` scaler-ით

cAdvisor-ის მეტრიკა `container_cpu_usage_seconds_total` კრებულია
kube-prometheus-stack-ის მიერ ყველა პოდიდან პირდაპირ, ServiceMonitor-ის
გარეშე. ჩვენ ვითვლით დავალება 6-ის დატვირთვის გენერატორის პოდების ჯამურ
CPU-ხარჯვას, არა თავად `demo-app`-ს: აპლიკაცია მასშტაბირდება სხვისი
დატვირთვის მიხედვით, და ჩვეულებრივ CPU-ს მიხედვით HPA-ს ეს არ შეუძლია -
ზუსტად ამისთვის არსებობს გარეშე მეტრიკები.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: demo-app
  namespace: eks-124
spec:
  scaleTargetRef:
    name: demo-app
  minReplicaCount: 1
  maxReplicaCount: 5
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://kube-prometheus-stack-prometheus.monitoring.svc:9090
      query: sum(rate(container_cpu_usage_seconds_total{namespace="eks-124", pod=~"stress-generator.*"}[1m]))
      threshold: "0.1"
EOF
```

შემოწმება, რომ query რეალურად აბრუნებს რაღაცას, შესაძლებელია პირდაპირ
კლასტერიდან (სანამ გენერატორი არ არსებობს, პასუხი ცარიელი იქნება, და ეს
ნორმალურია - ამ შემთხვევაში KEDA HPA-ს ნულს აბრუნებს):

```bash
kubectl run promq --rm -i --restart=Never -n default --image=curlimages/curl -- \
  -sG --data-urlencode \
  'query=sum(rate(container_cpu_usage_seconds_total{namespace="eks-124",pod=~"stress-generator.*"}[1m]))' \
  http://kube-prometheus-stack-prometheus.monitoring.svc:9090/api/v1/query
```

ვამოწმებთ, რომ KEDA-მ ScaledObject-ი მართვაში აიღო და HPA შექმნა:

```bash
kubectl get scaledobject demo-app -n eks-124
kubectl get hpa -A | grep keda-hpa
kubectl get hpa keda-hpa-demo-app -n eks-124
```

HPA-ს ეწოდება `keda-hpa-demo-app` - ეს დამტკიცება არის იმისა, რომ KEDA არ
ცვლის HPA-ს, ის კაპოტის ქვეშ ქმნის და ვარაუდობს ჩვეულებრივ
`HorizontalPodAutoscaler`-ს.

## დავალება 6. დატვირთვის ტესტი: მასშტაბირება ზევით

ჯერ ვინახავთ მდგომარეობას დატვირთვამდე:

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/6/hpa_before.txt
cat /var/work/tests/artifacts/6/hpa_before.txt
```

ვქმნით დატვირთვის გენერატორს. მას საკუთარი label აქვს (`app=stress-generator`) -
PromQL-query დავალება 5-იდან პოდებს არჩევს სახელით, არა label-ით, ამიტომ
გენერატორის ჩარევა `demo-app`-ის სელექტორში არასაჭირო და საზიანოა: ორი
Deployment გადამფარავი სელექტორებით არის ანტი-პატერნი. `limits.cpu`
სავალდებულოა, სხვანაირად ოთხი CPU-ვორკერი აცილებს პროცესორს kubelet-ს და
ნოუდი გადადის `NotReady`-ში. `nodeSelector` საჭიროა იმიტომ, რომ
`polinux/stress` აწყობილია მხოლოდ `amd64`-ისთვის, ხოლო ამ ლაბის NodePool
`arm64`-საც უშვებს:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stress-generator
  namespace: eks-124
spec:
  replicas: 2
  selector:
    matchLabels:
      app: stress-generator
  template:
    metadata:
      labels:
        app: stress-generator
    spec:
      nodeSelector:
        kubernetes.io/arch: amd64
      containers:
      - name: stress
        image: polinux/stress
        command: ["stress"]
        args: ["--cpu", "2"]
        resources:
          requests:
            cpu: "200m"
          limits:
            cpu: "500m"
EOF
```

ვაკვირდებით, როგორ იზრდება მეტრიკა და რეპლიკების რაოდენობა:

```bash
watch kubectl get hpa keda-hpa-demo-app -n eks-124
```

ველოდებით 1-2 წუთს (KEDA ეკითხება Prometheus-ს, HPA ითვლის რეპლიკებს,
Karpenter საჭიროებისამებრ ამატებს ნოუდს). სტენდზე ეს ასე გამოიყურებოდა:

```
06:36:41 replicas=1 0/100m (avg)
06:37:04 replicas=1 1251m/100m (avg)
06:37:26 replicas=4 382m/100m (avg)
```

როგორც კი `REPLICAS` გახდება `1`-ზე მეტი, ვინახავთ:

```bash
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/6/hpa_after.txt
cat /var/work/tests/artifacts/6/hpa_after.txt
```

## დავალება 7. დატვირთვის მოხსნა: მასშტაბირება ქვევით

```bash
kubectl delete deployment stress-generator -n eks-124
```

გენერატორის პოდები ქრება, მათი სერიები Prometheus-იდან ქრება, KEDA HPA-ს
ნულს აბრუნებს. `TARGETS`-ის მნიშვნელობა ნულდება დაახლოებით 30 წამში, მაგრამ
რეპლიკების რაოდენობა ჩერდება: `stabilizationWindowSeconds` scaleDown-ისთვის
HPA-ზე ნაგულისხმევად არის 300 წამი. სტენდის გაზომვა - მეტრიკა ნული 06:40:07-ზე,
რეპლიკები `5 -> 2 -> 1` 06:44:40-ზე და 06:45:07-ზე:

```bash
watch kubectl get hpa keda-hpa-demo-app -n eks-124
```

როგორც კი `REPLICAS` დაბრუნდება `1`-ზე, ვინახავთ არტეფაქტს:

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/7/hpa_after_cooldown.txt
cat /var/work/tests/artifacts/7/hpa_after_cooldown.txt
```

## დავალება 8. ჩვეულებრივი HPA KEDA-ს მიერ შექმნილი HPA-ს წინააღმდეგ

```bash
kubectl get hpa -A
```

output-ში HPA `keda-hpa-demo-app` სვეტების მიხედვით არაფრით არ განსხვავდება
ჩვეულებრივი HPA-სგან - იგივე `TARGETS`, `MINPODS`, `MAXPODS`, `REPLICAS`.
განსხვავება მხოლოდ სახელშია (პრეფიქსი `keda-hpa-`) და იმაში, ვინ მას მართავს:
ჩვეულებრივ HPA-ს ინჟინერი ქმნის და რედაქტირებს პირდაპირ
`HorizontalPodAutoscaler`-ის მანიფესტით, ხოლო `keda-hpa-demo-app` შექმნილია
და იმართება (control) KEDA operator-ის მიერ `ScaledObject`-ის
რესურსის მიხედვით - წაშალეთ `ScaledObject`, და KEDA ამ HPA-საც მასთან ერთად
წაშლის.

ვინახავთ განმარტებას არტეფაქტში:

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/hpa_compare.txt <<'EOF'
kubectl get hpa -A-ის output-ში ჩვეულებრივი HPA და HPA keda-hpa-demo-app სვეტების
მიხედვით ერთნაირად გამოიყურება: TARGETS/MINPODS/MAXPODS/REPLICAS - განსხვავება
მხოლოდ სახელშია და ობიექტის წარმომავლობაშია.

KEDA არ ცვლის HPA-ს: KEDA operator ადევნებს თვალს ScaledObject-ს და თავად ქმნის
და მართავს (control) ჩვეულებრივ HorizontalPodAutoscaler-ს სახელით
keda-hpa-<ScaledObject-ის სახელი>, ხოლო KEDA-ს metrics adapter მას მეტრიკის
მნიშვნელობას აწვდის external.metrics.k8s.io-ის მეშვეობით. რეპლიკებს ჯერ
კიდევ ითვლის იგივე HPA-ის მექანიზმი, რაც ყოველთვის.
EOF
cat /var/work/tests/artifacts/8/hpa_compare.txt
```

## სწრაფი შემოწმება

```bash
check_result
```
