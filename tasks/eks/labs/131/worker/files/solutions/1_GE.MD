[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 131 - ეტალონური გადაწყვეტა (PDB ბლოკავს drain-ს, topology spread, matchLabelKeys)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე (worker) SSH-ის საშუალებით. kubectl უკვე
კონფიგურირებულია კლასტერზე (kubeconfig შედგენილია `aws eks update-kubeconfig`-ის
საშუალებით მანქანის ჩატვირთვისას).

## დავალება 1. Namespace `eks-131`

```bash
kubectl create namespace eks-131
```

## დავალება 2. Deployment `web` topology spread-ითა და matchLabelKeys-ით

ლაბის კლასტერი აშენებულია ორ ზონაში (`eu-central-1a` და `eu-central-1b`), პრივატული
ქვექსელებით `eks1`/`eks2` თითოეულისთვის. ეს საკმარისია, რომ Karpenter-მა ნოუდები ორ
ზონაზე გაანაწილოს, ხოლო `topologySpreadConstraints`-მა pod-ები მათზე გადანაწილოს.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: eks-131
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: web
          matchLabelKeys:
            - pod-template-hash
      containers:
        - name: app
          image: viktoruj/ping_pong:latest
EOF

kubectl rollout status deployment/web -n eks-131
```

ვამოწმებთ მზადყოფნას და ზონებზე განაწილებას:

```bash
kubectl get pods -n eks-131 -l app=web -o wide
kubectl get nodes -L topology.kubernetes.io/zone
```

სამი pod-ის `NODE` სვეტში მინიმუმ ორი სხვადასხვა ნოუდი უნდა ჩნდებოდეს, ხოლო ამ ნოუდებს -
სხვადასხვა `topology.kubernetes.io/zone` მნიშვნელობები. `matchLabelKeys:
[pod-template-hash]` ჯერჯერობით არ ახდენს გავლენას პირველ deployment-ზე (რევიზია ერთია),
ის თავს გამოაჩენს დავალება 6-ში.

## დავალება 3. სიმპტომი: ზედმეტად მკაცრი PDB ბლოკავს drain-ს

ვქმნით PDB-ს, რომელიც მოითხოვს, რომ ხელმისაწვდომი იყოს ყველა 3 რეპლიკა - ბიუჯეტი არ
ანებებს ერთი pod-ის გამოვევასაც:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-pdb
  namespace: eks-131
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: web
EOF
```

ვიღებთ ნოუდს `web`-ის ერთ-ერთი რეპლიკით და ვცდილობთ მის გამოყვანას:

```bash
NODE=$(kubectl get pod -n eks-131 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
echo "node: $NODE"

mkdir -p /var/work/tests/artifacts/3
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=60s \
  > /var/work/tests/artifacts/3/drain_blocked.txt 2>&1
echo "drain exit code: $?"
cat /var/work/tests/artifacts/3/drain_blocked.txt
```

ბრძანება არ გადის: `kubectl drain` ცდილობს გამოვიდოს eviction API `web` pod-ისთვის,
მაგრამ API პასუხობს `429`-ით ბიუჯეტის დარღვევის გამო, და `--timeout=60s`-ის შემდეგ drain
ჩავარდება შეცდომით `global timeout reached`. მიზეზი - PDB `web-pdb`, `minAvailable: 3`-ით,
რომელიც მოითხოვს 3 ხელმისაწვდომ რეპლიკას, როცა სულ არსებობს ზუსტად 3, ანუ ბიუჯეტი არასდროს
ანებებს ერთის გამოვევასაც: გამოვევა ვერასოდეს წავიდეს წინ, drain გაიჭედება, სანამ ბიუჯეტს
არ შემსუბუქებენ.

ვამატებთ განმარტებას იმავე არტეფაქტს:

```bash
cat >> /var/work/tests/artifacts/3/drain_blocked.txt <<'EOF'

განმარტება: PDB web-pdb აყალიბებს minAvailable: 3, რაც ტოლია Deployment web-ის
რეპლიკების რაოდენობის. ბიუჯეტი არ ანებებს ერთი pod-ის გამოვევასაც, ამიტომ eviction API
პასუხობს 429-ით, და kubectl drain ჩერდება/ტაიმაუთდება - ეს არის ზედმეტად მკაცრი PDB-ის
სიმპტომი, არა კლასტერის შეცდომა.
EOF
cat /var/work/tests/artifacts/3/drain_blocked.txt
```

## დავალება 4. გამოსწორება: ვასუბუქებთ PDB-ს და ვამეორებთ drain-ს

ჯერ ვაბრუნებთ ნოუდს სამუშაოში (drain-მა უკვე დააკორდონა):

```bash
kubectl uncordon "$NODE"
```

ვასუბუქებთ ბიუჯეტს: ახლა შესაძლებელია სამიდან ერთი რეპლიკის გამოყვანა
(`minAvailable: 2`):

```bash
kubectl patch pdb web-pdb -n eks-131 --type merge -p '{"spec":{"minAvailable":2}}'
kubectl get pdb web-pdb -n eks-131
```

ვამეორებთ drain-ს იმავე ნოუდზე - ახლა ბიუჯეტი ანებებს ერთი pod-ის გამოვევას, drain გადის:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=120s \
  > /var/work/tests/artifacts/4/drain_ok.txt 2>&1
echo "drain exit code: $?" >> /var/work/tests/artifacts/4/drain_ok.txt

echo "--- pdb status after drain ---" >> /var/work/tests/artifacts/4/drain_ok.txt
kubectl get pdb web-pdb -n eks-131 >> /var/work/tests/artifacts/4/drain_ok.txt
cat /var/work/tests/artifacts/4/drain_ok.txt
```

ვაბრუნებთ ნოუდს სამუშაოში და ველოდებით, რომ ყველა 3 რეპლიკა ისევ მზადაა (ჩანაცვლება
დადგა სხვა ნოუდზე):

```bash
kubectl uncordon "$NODE"
kubectl rollout status deployment/web -n eks-131
```

## დავალება 5. unhealthyPodEvictionPolicy: AlwaysAllow

ნაგულისხმევად PDB იყენებს პოლიტიკას `IfHealthyBudget`: არაჯანსაღი (არა `Ready`) pod-ის
გამოყვანა შესაძლებელია მხოლოდ იმ შემთხვევაში, თუ ბიუჯეტი მისი გარეშეც არ დაირღვევა. თუ
აპლიკაცია გატეხილია და pod ჩარჩენილა `CrashLoopBackOff`-ში, ასეთი pod თავად ბლოკავს
ბიუჯეტის გამოთვლას და სამუდამოდ ხელს უშლის drain-ს. `AlwaysAllow` ხსნის ამ ბლოკირებას:
არაჯანსაღი pod-ები ყოველთვის გამოვევდებიან, ჯანსაღები ბიუჯეტის დაცვის ქვეშ რჩება.

```bash
kubectl patch pdb web-pdb -n eks-131 --type merge \
  -p '{"spec":{"unhealthyPodEvictionPolicy":"AlwaysAllow"}}'

kubectl get pdb web-pdb -n eks-131 -o jsonpath='{.spec.unhealthyPodEvictionPolicy}'
echo
```

ვინახავთ განმარტებას არტეფაქტში:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/unhealthy_policy.txt <<'EOF'
unhealthyPodEvictionPolicy: AlwaysAllow დაემატა web-pdb-ს.

ნაგულისხმევად (IfHealthyBudget) არაჯანსაღი pod გამოვევდება მხოლოდ იმ შემთხვევაში, თუ
currentHealthy არ ჩავარდება desiredHealthy-ის ქვემოთ, ამიტომ CrashLoopBackOff-ში
ჩარჩენილი pod თავად ითვლება ბიუჯეტის ნაწილად და შესაძლოა სამუდამოდ დაბლოკოს drain, თუნდაც
აპლიკაცია აღარ მუშაობდეს.

AlwaysAllow ანებებს არაჯანსაღი pod-ის გამოვევას ბიუჯეტის მიუხედავად: CrashLoopBackOff-ში
გატეხილი pod უკვე არ აჭერს drain-ს, ხოლო ჯანსაღი რეპლიკები რჩება PDB-ის დაცვის ქვეშ.
EOF
cat /var/work/tests/artifacts/5/unhealthy_policy.txt
```

## დავალება 6. Rolling update: matchLabelKeys არ ანებებს ძველ pod-ებს განაწილების ხელისშეშლას

ვანახლებთ Deployment-ს, რათა გამოჩნდეს ახალი რევიზია (ახალი `pod-template-hash`):
ვამატებთ გარემოს ცვლადს. ძველი და ახალი pod-ები ატარებენ საერთო ლეიბლს `app: web`,
მაგრამ `matchLabelKeys: [pod-template-hash]` `topologySpreadConstraints`-ში ითვლის
skew-ს მხოლოდ საკუთარი რევიზიის შიგნით, ამიტომ ახალი pod-ები არ ბლოკირდება ძველი
რეპლიკებით.

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl set env deployment/web -n eks-131 RELEASE=v2

kubectl rollout status deployment/web -n eks-131 --timeout=180s \
  | tee /var/work/tests/artifacts/6/rollout.txt
```

ვამოწმებთ, რომ არ არსებობს ჩარჩენილი `Pending` pod-ები და განახლება რეალურად
შეესრულდა:

```bash
kubectl get pods -n eks-131 -l app=web -o wide
kubectl get deploy web -n eks-131 \
  -o jsonpath='{.status.readyReplicas}/{.status.updatedReplicas}'
echo
```

`matchLabelKeys: [pod-template-hash]`-ის გარეშე skew-ის დათვლაში მონაწილეობდნენ როგორც
ძველი, ისე ახალი pod-ები - მათ საერთო ლეიბლი `app: web` აქვთ. მისით სქედულერი
სელექტორს ამატებს რევიზიის ლეიბლს და ითვლის განაწილებას მხოლოდ საკუთარი რევიზიის
შიგნით.

გულწრფელი განმარტება, რომელიც უმჯობესია საკუთარ თავზე გადამოწმდეს და არ მიღებულ იქნას
რწმენაზე. ამ სტენდზე rollout წარმატებით გადის `matchLabelKeys`-ის გარეშეც - გამოცდით
გადამოწმებული: მეორე Deployment იმავე ტოპოლოგიით, მაგრამ ამ ველის გარეშე,
`maxUnavailable: 0`-ითა და `maxSurge: 1`-ით განახლდა იმავე დროში, `Pending` გაგრძელდა
ხუთ წამზე ნაკლები დროით და იყო სქედულერის ჩვეულებრივი მოლოდინი, არა skew-ის ბლოკირება.
მიზეზი მარტივია: სამი რეპლიკა ორ ზონაზე ითვლის განაწილებას 2 პლუს 1-ს, და დამატებითი
pod ყოველთვის ჯდება ნაკლები pod-ის ზონაში, ხოლო თუ ნოუდებზე ადგილი არ ჰყოფნის,
Karpenter კიდევ ერთს აღმართავს.

სად ხდება სხვაობა ნამდვილი: სტატიკური პარკი მარაგის ტევადობის გარეშე, ორზე მეტი ზონა
და ძველი რევიზიის არათანაბარი განაწილება. მაშინ ორივე რევიზიაზე ერთდროულად გამოთვლილი
skew ახალ pod-ს დაშვებულ ზონას არ ტოვებს, და ის ელოდება ძველი რეპლიკის მოცილებას -
დიდ პარკზე ეს გადაიქცევა ნელ rollout-ად გაუგებარი `Pending`-ებით. ამიტომ
`matchLabelKeys` დგება წინდაწინ, არა ინციდენტის შემდეგ. ის შედეგი, რომელიც ახლა
რეალურად ვამოწმებთ - რომ ახალი რევიზია დარჩა ზონებზე განაწილებული `maxSkew: 1`-ის
ფარგლებში:

```bash
HASH=$(kubectl get po -n eks-131 -l app=web \
  -o jsonpath='{.items[0].metadata.labels.pod-template-hash}')
for n in $(kubectl get po -n eks-131 -l app=web,pod-template-hash="$HASH" \
    -o jsonpath='{.items[*].spec.nodeName}'); do
  kubectl get node "$n" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}{"\n"}'
done | sort | uniq -c
```

## სისწრაფის შემოწმება

```bash
check_result
```
