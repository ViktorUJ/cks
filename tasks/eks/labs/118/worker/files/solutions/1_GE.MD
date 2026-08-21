[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 118 - ეტალონური გადაწყვეტა (GitOps: Argo CD, drift და self-heal, sync waves)

ყველა ბრძანება სრულდება worker-მანქანაზე SSH-ის მეშვეობით. kubectl უკვე
კონფიგურირებულია კლასტერისთვის (kubeconfig იკრიბება `aws eks
update-kubeconfig`-ის მეშვეობით მანქანის ჩართვისას).

## დავალება 1. Argo CD-ის დაყენება Helm-ის მეშვეობით

```bash
kubectl create namespace argocd

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd -n argocd

kubectl rollout status deployment/argocd-server -n argocd
```

ვამოწმებთ, რომ სერვერი წამოვარდა:

```bash
kubectl get deploy argocd-server -n argocd
kubectl get pods -n argocd
```

## დავალება 2. Namespace `eks-118` და Application ობიექტი

```bash
kubectl create namespace eks-118
```

Application აკავშირებს Git-წყაროს (თვითონ კურსის რეპოზიტორია, ბრენჩი
`AG-155`, path `tasks/eks/labs/118/gitops-demo`) სამიზნე კლასტერთან და
namespace `eks-118`-თან. `selfHeal: true` აბრუნებს ხელით რედაქტირებას,
`prune: true` შლის კლასტერიდან რესურსებს, რომლებიც Git-იდან მოიშორდა:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/ViktorUJ/cks.git
    targetRevision: AG-155
    path: tasks/eks/labs/118/gitops-demo
  destination:
    server: https://kubernetes.default.svc
    namespace: eks-118
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
EOF
```

ველოდებით, სანამ Application მიაღწევს `Synced`-ს და `Healthy`-ს:

```bash
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}'
echo
kubectl get application demo-app -n argocd -o jsonpath='{.status.health.status}'
echo
```

ორივე ბრძანება საბოლოოდ უნდა დააბრუნოს `Synced` და `Healthy` შესაბამისად
(Argo CD ითხოვს Git-ს და გამოსცემს მანიფესტებს ავტომატურად, auto-sync
ნაგულისხმევად ჩართულია).

## დავალება 3. ობიექტების ნამდვილად გამოცემის შემოწმება

```bash
kubectl get deployment demo-app -n eks-118
kubectl get configmap demo-config -n eks-118 -o yaml
kubectl rollout status deployment/demo-app -n eks-118
```

Deployment `demo-app` (image `viktoruj/ping_pong:latest`, 2 რეპლიკა) და
ConfigMap `demo-config` მოვიდა Git-იდან Argo CD-ის მეშვეობით, არა
სტუდენტის ხელით `kubectl apply`-ით.

## დავალება 4. Drift და self-heal

მნიშვნელოვანი დეტალი, რომელიც მხოლოდ ცოცხალ კლასტერზე ჩანს: ჩართული
`selfHeal`-ის შემთხვევაში კონტროლერი აბრუნებს drift-ს წამებში, და
`OutOfSync`-ის თვალით დანახვა პრაქტიკულად შეუძლებელია (ხელით `kubectl
scale` ბრუნდება ჯერ ისევ პირველ `kubectl get application`-მდე). ამიტომ
drift ჩვენდება ორ ეტაპში: თავდაპირველად გამოირთვება self-healing,
ხდება `OutOfSync`-ის დაფიქსირება, შემდეგ self-healing ისევ ჩაირთვება
და დაკვირდება rollback-ს.

ეტაპი 1. გამოვირთავთ მხოლოდ `selfHeal`-ს, `prune` დარჩენილია ჩართული:

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":false,"prune":true}}}}'
```

ეტაპი 2. ვამტვრევთ ცოცხალ მდგომარეობას Git-ის გავლის გარეშე და
ვაფიქსირებთ drift-ს:

```bash
kubectl scale deployment demo-app -n eks-118 --replicas=5

for i in $(seq 1 20); do
  status=$(kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}')
  [[ "$status" == "OutOfSync" ]] && break
  sleep 3
done

mkdir -p /var/work/tests/artifacts/4
{
  echo "=== drift selfHeal=false-ის დროს (ხელით kubectl scale --replicas=5) ==="
  kubectl get application demo-app -n argocd \
    -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
  echo
  kubectl get deploy demo-app -n eks-118 -o jsonpath='replicas={.spec.replicas}'
  echo
} > /var/work/tests/artifacts/4/drift.txt
```

self-heal-ის გარეშე Application რჩება `OutOfSync`-ად: auto-sync
რეაგირებს Git-ში ცვლილებებზე, ხოლო კლასტერში შექმნილ განსხვავებას
განკურნავს ზუსტად `selfHeal`.

ეტაპი 3. დავაბრუნებთ `selfHeal`-ს და დავაკვირდებით ავტომატურ rollback-ს
Git-იდან მდგომარეობაზე:

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true,"prune":true}}}}'

for i in $(seq 1 40); do
  status=$(kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}')
  replicas=$(kubectl get deploy demo-app -n eks-118 -o jsonpath='{.spec.replicas}')
  [[ "$status" == "Synced" ]] && [[ "$replicas" == "2" ]] && break
  sleep 3
done

{
  echo "=== selfHeal-ის ჩართვის შემდეგ: rollback Git-იდან მდგომარეობაზე ==="
  kubectl get application demo-app -n argocd \
    -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
  echo
  kubectl get deploy demo-app -n eks-118 -o jsonpath='replicas={.spec.replicas}'
  echo
} >> /var/work/tests/artifacts/4/drift.txt

cat /var/work/tests/artifacts/4/drift.txt
```

ფაილში არსებობს ორივე - `OutOfSync` (drift self-healing-ის გარეშე) და
`Synced` (self-heal-მა დააბრუნა Git-იდან მდგომარეობა). `replicas`
ბოლოს ისევ `2`-ია.

## დავალება 5. Sync waves: გამოცემის რიგითობა

`gitops-demo/configmap.yaml`-ზეა ანოტაცია `argocd.argoproj.io/sync-wave:
"0"`, ხოლო `gitops-demo/deployment.yaml`-ზე - `argocd.argoproj.io/sync-wave:
"1"`. პატარა ტალღის ნომერი გამოიცემა უფრო ადრე, ამიტომ ConfigMap
გარანტირებულად ხვდება კლასტერში Deployment-ზე ადრე (ეს მნიშვნელოვანია, თუ
Deployment კითხავს მნიშვნელობებს ConfigMap-იდან `envFrom`-ის მეშვეობით):

```bash
kubectl get configmap demo-config -n eks-118 \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}'
echo
kubectl get deployment demo-app -n eks-118 \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}'
echo
```

დავრწმუნდებით, რომ ორივე ობიექტი საბოლოოდ სინქრონიზებულია, სხვადასხვა
ტალღების მიუხედავად:

```bash
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}'
echo
kubectl get application demo-app -n argocd -o jsonpath='{.status.resources}' | head -c 400
```

## დავალება 6. რას შლის prune და რას არა: რესურსის მფლობელობა

`prune: true` უკვე ჩართული იყო დავალება 2-ში. ხელით ვქმნით `eks-118`-ში
ConfigMap-ს, რომელიც არ არსებობს `gitops-demo/`-ში - ჩვეულებრივ ხელით
შექმნილ ობიექტს, თითქოს ვინმემ ის Git-ის გავლის გარეშე შექმნა:

```bash
kubectl create configmap manual-extra -n eks-118 --from-literal=note=manual

kubectl patch application demo-app -n argocd --type=merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

sleep 30
kubectl get configmap manual-extra -n eks-118
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}'; echo
```

მოულოდნელი შედეგი: `prune=true` ჩართულია, მაგრამ `manual-extra` **არ
იშლება**, ხოლო Application რჩება `Synced`-ად. მიზეზი მფლობელობის
მოდელშია: Argo CD მართავს მხოლოდ ობიექტებს, რომლებიც მონიშნულია
აპლიკაციის კუთვნილებად. Argo CD 3.x-ში ეს ანოტაცია
`argocd.argoproj.io/tracking-id` - შეხედე, როგორ არის მონიშნული
ობიექტი, რომელიც Git-იდან მოვიდა:

```bash
kubectl get configmap demo-config -n eks-118 \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}'; echo
# demo-app:/ConfigMap:eks-118/demo-config
```

ხელით შექმნილ ობიექტს ეს მონიშვნა არ ჰყავს, ის Argo CD-სთვის უცხოა
(orphaned) და prune-ის ფარგლებში არ ხვდება. ვაფიქსირებთ ამ დაკვირვებას:

```bash
mkdir -p /var/work/tests/artifacts/6
{
  echo "=== tracking ანოტაციის გარეშე prune არ ეხება ობიექტს ==="
  echo "manual-extra: $(kubectl get configmap manual-extra -n eks-118 -o jsonpath='{.metadata.name}')"
  echo "sync: $(kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}')"
} > /var/work/tests/artifacts/6/prune.txt
```

ახლა ConfigMap-ს ვნიშნავთ როგორც აპლიკაციის კუთვნილს. მნიშვნელობის
ფორმატია `<app>:<group>/<Kind>:<namespace>/<name>`, core-რესურსებისთვის
group ცარიელია:

```bash
kubectl annotate configmap manual-extra -n eks-118 \
  'argocd.argoproj.io/tracking-id=demo-app:/ConfigMap:eks-118/manual-extra' --overwrite

kubectl patch application demo-app -n argocd --type=merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

for i in $(seq 1 20); do
  kubectl get configmap manual-extra -n eks-118 >/dev/null 2>&1 || break
  sleep 5
done

kubectl get configmap manual-extra -n eks-118 2>&1
```

ახლა ობიექტი ტრეკირდება აპლიკაციის მიერ, Git-ში ის არ არსებობს - და
prune შლის მას. ამასთანავე `demo-config` და `demo-app` თავიანთ
ადგილზე რჩება, რადგან ისინი აღწერილია `gitops-demo/`-ში:

```bash
{
  echo "=== tracking ანოტაციის დამატების შემდეგ prune-მ ობიექტი ამოშალა ==="
  echo "manual-extra: $(kubectl get configmap manual-extra -n eks-118 2>&1 | tail -n1)"
  echo "demo-config: $(kubectl get configmap demo-config -n eks-118 -o jsonpath='{.metadata.name}')"
  echo "demo-app: $(kubectl get deploy demo-app -n eks-118 -o jsonpath='{.metadata.name}')"
  echo
  echo "prune შლის მხოლოდ tracking-რებულ რესურსებს, რომლებიც არ არსებობს Git-ში."
  echo "ხელით შექმნილი ობიექტი tracking ანოტაციის გარეშე Argo CD-სთვის უცხოა"
  echo "(orphaned) და prune-ის ფარგლებში არ ხვდება - ეს იყო პირველი დაკვირვებული"
  echo "შედეგი. demo-config და demo-app თავიანთ ადგილზე დარჩა, რადგან ისინი"
  echo "აღწერილია gitops-demo/-ში და Argo CD გრძელობს მათ სინქრონიზაციას."
} >> /var/work/tests/artifacts/6/prune.txt

cat /var/work/tests/artifacts/6/prune.txt
```

## დავალება 7. დიაგნოსტიკა: sync status და health status - ორი განსხვავებული ღერძი

გამოვირთავთ auto-sync-ს (და მასთან ერთად self-heal-ს, რომელიც იმავე
ბლოკში ცხოვრობს), რომ სიმპტომი გამოვიწვიოთ სპოკოინად, დაუყოვნებელი
rollback-ის გარეშე:

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'
```

ვამტვრევთ კონტეინერის readinessProbe-ს პირდაპირ კლასტერში. ყურადღება:
სასწავლო image `ping_pong` პასუხობს `200`-ს ნებისმიერ path-ზე, ამიტომ
პრობი "არარსებულ URL"-ზე წარმატებით გავლის და სიმპტომს არ გვაძლევს.
მიმართავთ პრობს დახურულ პორტ `9999`-ს - იქ არავინ ისმენს:

```bash
kubectl patch deployment demo-app -n eks-118 --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/readinessProbe","value":{
    "httpGet": {"path": "/healthz", "port": 9999},
    "initialDelaySeconds": 2,
    "periodSeconds": 3,
    "failureThreshold": 2
  }}
]'
```

ველოდებით და ვაფიქსირებთ სტატუსებს. Sync და health დამოუკიდებელი
ღერძებია: sync ასახავს განსხვავებას Git-სა და ცოცხალ მდგომარეობას
შორის, health არის რესურსების ნამდვილი ჯანმრთელობა (პოდების მზაობა და
სხვა):

```bash
sleep 30
mkdir -p /var/work/tests/artifacts/7
{
  echo "=== დაკვირვებული სტატუსები ხელით readinessProbe რედაქტირების შემდეგ ==="
  kubectl get application demo-app -n argocd \
    -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
  echo
  echo
  echo "=== განმარტება: sync status და health status განსხვავებული ღერძებია ==="
  echo "Sync status (Synced/OutOfSync) ადარებს ობიექტების ცოცხალ მდგომარეობას იმას,"
  echo "რაც Git-შია დაცემული: ემთხვევა - Synced, განშორდება - OutOfSync."
  echo "Health status (Healthy/Progressing/Degraded/Missing) არის რესურსის"
  echo "ნამდვილი ჯანმრთელობა დღეს: მზად არიან თუ არა პოდები, გაივლიან თუ არა"
  echo "readiness/liveness პრობებს."
  echo "დახურულ პორტზე პრობის გამო ახალი demo-app-ის პოდები readiness-ს ვერ"
  echo "გაივლიან, ამიტომ health მიუვალს Progressing-თან (და Degraded გახდება"
  echo "progressDeadlineSeconds-ის ამოწურვის შემდეგ), ხოლო sync Synced რჩება."
  echo "მიზეზი: readinessProbe ველი Git-მანიფესტში არ არის აღწერილი, და ხელით"
  echo "დამატებული ველი განსხვავებაში არ ხდება; ხოლო replicas Git-ში არსებობს,"
  echo "ამიტომ მათი ხელით რედაქტირება დავალება 4-ში OutOfSync-ს გვაძლევდა."
  echo "ეს ამტკიცებს, რომ ორივე ღერძი დამოუკიდებლად განისახლვდება: შესაძლებელია"
  echo "იქვეს Synced და Degraded/Progressing ერთდროულად, ისევე როგორც OutOfSync"
  echo "და Healthy ერთდროულად."
} > /var/work/tests/artifacts/7/health.txt

cat /var/work/tests/artifacts/7/health.txt
```

დავაბრუნებთ auto-sync-ს და self-heal-ს:

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true,"prune":true}}}}'
```

მნიშვნელოვანი დაკვირვება: self-heal ამ ავარიას **არ განკურნავს**. Argo
CD-სთვის Git-თან განსხვავება არ არსებობს (`sync=Synced`), ამიტომ
განსაკურნებელი არაფერია - ამასთანავე `health` პატიოსნად აჩვენებს
`Progressing`-ს, შემდეგ `Degraded`-ს. პრაქტიკული დასკვნა: `Synced` არ
ნიშნავს, რომ კლასტერი ბაიტობით ემთხვევა Git-ს; ველები, რომლებიც
მანიფესტში არ არსებობს, ოპერატორის პასუხისმგებლობად რჩება. ამიტომ
ვაშორებთ პრობს ხელით:

```bash
kubectl patch deployment demo-app -n eks-118 --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/containers/0/readinessProbe"}]'

for i in $(seq 1 20); do
  health=$(kubectl get application demo-app -n argocd -o jsonpath='{.status.health.status}')
  ready=$(kubectl get deploy demo-app -n eks-118 -o jsonpath='{.status.readyReplicas}')
  [[ "$health" == "Healthy" ]] && [[ "$ready" == "2" ]] && break
  sleep 5
done

kubectl get application demo-app -n argocd \
  -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
echo
```

## სწრაფი შემოწმება

```bash
check_result
```
