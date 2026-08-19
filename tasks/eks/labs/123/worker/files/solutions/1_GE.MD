[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 123 - ეტალონური გადაწყვეტა (Karpenter: NodePool, consolidation, StatefulSet)

ყველა ბრძანება მუშავდება worker მანქანაზე SSH-ით. kubectl უკვე კონფიგურირებულია
კლასტერზე (kubeconfig შედგენილია `aws eks update-kubeconfig`-ის მეშვეობით მანქანის
ჩატვირთვისას).

## დავალება 1. Namespace `eks-123`

```bash
kubectl create namespace eks-123
```

## დავალება 2. NodePool, EC2NodeClass, NodeClaim-ის ინვენტარიზაცია

ვხედავთ, რა pool-ები არის უკვე კონფიგურირებული კლასტერში: ნაგულისხმევი `default` (spot
და on-demand) და ახალი `stateful` (მხოლოდ on-demand, taint `dedicated=stateful`):

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "=== nodepools ==="
  kubectl get nodepools -o wide
  echo "=== ec2nodeclasses ==="
  kubectl get ec2nodeclasses
  echo "=== nodeclaims ==="
  kubectl get nodeclaims
} > /var/work/tests/artifacts/2/inventory.txt

cat /var/work/tests/artifacts/2/inventory.txt
```

გამონატანში უნდა იყოს სტრიქონები სახელებით `default` და `stateful` - ეს ორი
დამოუკიდებელი NodePool-ია, თითოეული საკუთარი `EC2NodeClass`-ით (თავი 12.2-12.3).

## დავალება 3. StatefulSet `db` `stateful` pool-ზე

Pool `stateful` დახურულია taint-ით `dedicated=stateful:NoSchedule`, ამიტომ pod-ს
სჯირდება toleration. Volume-ები აქ სავალდებულო არ არის ლაბის მიზნებისთვის - ფოკუსი
disruption-ზეა, არა EBS-ზე (StatefulSet-ის volume საკუთარი PVC-ით განხილულია თავი
23-ში):

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
  namespace: eks-123
spec:
  serviceName: db
  replicas: 3
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      tolerations:
        - key: dedicated
          operator: Equal
          value: stateful
          effect: NoSchedule
      containers:
        - name: app
          image: viktoruj/ping_pong:latest
          resources:
            requests:
              cpu: "250m"
              memory: "128Mi"
EOF

kubectl rollout status statefulset/db -n eks-123
```

ვამოწმებთ, რომ ყველა replica მოხვდა `stateful` pool-ზე (node-ის label
`work_type=stateful`):

```bash
kubectl get po -n eks-123 -l app=db -o wide
kubectl get nodes -L work_type
```

## დავალება 4. PodDisruptionBudget `db-pdb`

`maxUnavailable: 1` - ნებაყოფლობითი გამოძევების ძირითადი ტორმოზი. Karpenter დრეინავს
Eviction API-ის მეშვეობით, ამიტომ PDB არ დაანებებს ერთდროულად ერთზე მეტი replica-ს
გამოძევებას:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: db-pdb
  namespace: eks-123
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: db
EOF

kubectl get pdb db-pdb -n eks-123
```

## დავალება 5. სიმპტომი: გამოძევების უფლების არმქონე PDB ბლოკავს consolidation-ს

`stateful` pool-ის node-ები უკვე დაუტვირთავია: სამი replica თითო `250m`-ით
გადანაწილდა ორ `m6g.medium` node-ზე, და Karpenter `consolidateAfter: 30s`-ით
მუდმივად ცდილობს მათ consolidation-ს. დატვირთვის ძალდობა საჭირო არ არის - საჭიროა
მხოლოდ დანახვა, რა აჭერს consolidation-ს.

მნიშვნელოვანია: `maxUnavailable: 1`-ის დროს PDB არ ბლოკავს consolidation-ს. ის
ანებებს ერთ გამოძევებას ერთ დროს (`ALLOWED DISRUPTIONS=1`), Karpenter დრეინავს
node-ს replica-ს დამატებით და მშვიდად წაშლის მას. ბლოკირება ხდება მხოლოდ მაშინ, როცა
PDB არც ერთ გამოძევებას არ ანებებს. ვამკაცრებთ დაცვას სავსემდე - `minAvailable: 3`
სამი replica-ს დროს:

```bash
kubectl patch pdb db-pdb -n eks-123 --type=merge \
  -p '{"spec":{"maxUnavailable":null,"minAvailable":3}}'

kubectl get pdb db-pdb -n eks-123
```

სვეტი `ALLOWED DISRUPTIONS` ახლა არის `0`. 1-2 წუთის შემდეგ pool-ის node-ებზე
ჩნდება ბლოკირების event. მიაქციეთ ყურადღება: ეს არ არის `Unconsolidatable`, არამედ
ცალკე `DisruptionBlocked`:

```bash
for n in $(kubectl get nodes -l work_type=stateful -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== $n ==="
  kubectl describe node "$n" | grep -A2 DisruptionBlocked
done
```

მოსალოდნელი სტრიქონი: `Pdb prevents pod evictions (PodDisruptionBudget=[eks-123/db-pdb])`.
თავად კონტროლერის ლოგები დგება namespace `karpenter`-ში (არა `kube-system`-ში - იქ
მხოლოდ add-on-ებია, Karpenter განლაგებულია ცალკე release-ით Fargate profile-ზე):

```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=500 \
  | grep -i "disrupting node"
```

ვინახავთ დაკვირვებას artifact-ში - `get pdb`-ის გამონატანი პლუს node-ის რეალური
event:

```bash
mkdir -p /var/work/tests/artifacts/5
{
  echo "სიმპტომი: PDB, რომელიც არც ერთ გამოძევებას არ ანებებს, ბლოკავს consolidation-ს."
  echo "db-pdb გამკაცრებულია minAvailable=3-მდე 3 replica-ში -> ALLOWED DISRUPTIONS=0."
  kubectl get pdb db-pdb -n eks-123
  echo
  echo "=== events pool stateful-ის node-ებზე ==="
  for n in $(kubectl get nodes -l work_type=stateful -o jsonpath='{.items[*].metadata.name}'); do
    kubectl describe node "$n" | grep -E "DisruptionBlocked|Unconsolidatable" | sed "s|^|$n |"
  done
} > /var/work/tests/artifacts/5/consolidation.txt

cat /var/work/tests/artifacts/5/consolidation.txt
```

ვაბრუნებთ PDB-ს სამუშაო მდგომარეობაში, თუ არა დავალება 4 არ გავლენ, ხოლო pool-ის
node ვერასდროს წავა:

```bash
kubectl patch pdb db-pdb -n eks-123 --type=merge \
  -p '{"spec":{"minAvailable":null,"maxUnavailable":1}}'

kubectl get pdb db-pdb -n eks-123
```

`ALLOWED DISRUPTIONS` კვლავ `1`-ია. დასკვნა ექსპლუატაციისთვის: `minAvailable`,
replica-თა რაოდენობის ტოლი (ან `maxUnavailable: 0`), აჩერებს არა მხოლოდ
consolidation-ს, არამედ ნებისმიერ drain-ს - მაშასადამე, node-ების განახლებასაც და
კლასტერის upgrade-საც (თავი 12.6, თავი 40).

## დავალება 6. ჩასწორება: წერტილოვანი `do-not-disrupt`

StatefulSet-ის სწორი დაცვა არის სამი ნაწილის კომბინაცია (თავი 12.7), არა ერთი
ანოტაცია ყველაფერზე. PDB (დავალება 4) უკვე იძლევა ცალკეულ გამოძევებას. `stateful`
pool-ის disruption budget (`nodes: 50%` `eks_karpenter_stateful_vng/terragrunt.hcl`-ში)
შემოსაზღვრავს ტემპს, რომ Karpenter არ შეეხოს pool-ის ყველა node-ს ერთდროულად. მესამე
ნაწილია `do-not-disrupt` წერტილოვნად, მხოლოდ იმ replica-ზე, სადაც შეწყვეტა ამჯერად
მიუღებელია (მაგალითად `db-0`-ს ჰყავს leadership ან ხანგრძლივი ოპერაცია), არა მთელ
StatefulSet-ზე:

```bash
kubectl annotate pod db-0 -n eks-123 karpenter.sh/do-not-disrupt=true
kubectl get po db-0 db-1 db-2 -n eks-123 \
  -o custom-columns=NAME:.metadata.name,DO_NOT_DISRUPT:'.metadata.annotations.karpenter\.sh/do-not-disrupt'
```

`db-1` და `db-2` ანოტაციას არ იღებენ - წინააღმდეგ შემთხვევაში დაცვა გახდებოდა სავსე
და დაბლოკავდა არა მხოლოდ consolidation-ს, არამედ drift-საც (AMI-ის განახლება), როგორც
აღწერილია თავი 12.8-ში.

რომ ანოტაცია რეალურად მუშაობს, ჩანს იმავე მექანიზმით, რაც PDB დავალება 5-ში -
Karpenter წერს ცალკე event-ს node-ზე, რომელზეც არის `db-0`:

```bash
NODE=$(kubectl get po db-0 -n eks-123 -o jsonpath='{.spec.nodeName}')
kubectl describe node "$NODE" | grep -A1 'do-not-disrupt'
```

მოსალოდნელი სტრიქონი: `DisruptionBlocked ... Pod has "karpenter.sh/do-not-disrupt"
annotation (Pod=eks-123/db-0)`. ესეიგი, წერტილოვანი ანოტაცია აჩერებს consolidation-ს
მხოლოდ იმ node-ისთვის, რომელზეც დგება დაცული replica, ხოლო pool-ის სხვა node-ებს
Karpenter შეეხება.

ვინახავთ განმარტებას artifact-ში:

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/fix.txt <<'EOF'
StatefulSet db-ის სწორი დაცვა consolidation-ის დროს არის სამი დამოუკიდებელი ნაწილი,
არა ერთი სავსე ანოტაცია:

1. PDB db-pdb (maxUnavailable: 1) - ცალკეული გამოძევება, quorum არასდროს იკარგება.
   ზუსტად ეს მნიშვნელობა ტოვებს ALLOWED DISRUPTIONS=1-ს. სავსე დაცვა (minAvailable=3
   სამი replica-ს დროს) იძლევა ALLOWED DISRUPTIONS=0-ს და DisruptionBlocked "Pdb
   prevents pod evictions" event-ს - სამუდამოდ, სანამ თავად PDB არ გასწორდება
   (დავალება 5).
2. stateful pool-ის disruption budget (nodes: 50%) - შემოსაზღვრავს, რამდენ node-ს
   pool-ში Karpenter შეიძლება ერთდროულად შეეხოს, არ ანებებს მთელი pool-ის
   ერთდროულ consolidation-ს.
3. karpenter.sh/do-not-disrupt=true წერტილოვნად db-0-ზე - იცავს კონკრეტულ replica-ს,
   სადაც შეწყვეტა ამჯერად მიუღებელია, არა მთელ StatefulSet-ს.

do-not-disrupt თუ იქნებოდა db-0, db-1 და db-2-ზე ერთდროულად, ეს დაბლოკავდა არა
მხოლოდ consolidation-ს, არამედ drift-საც: ახალი AMI-ის გამოსვლისას stateful
pool-ის node-ები ვერ შეძლებდნენ განახლებას, და დაგროვდებოდა CVE-ის ვალი (თავი 12.8).
ამიტომ ანოტაცია დგება მხოლოდ ერთ replica-ზე და ხსნის მას, როცა კრიტიკული ოპერაცია
დამთავრდება.
EOF

cat /var/work/tests/artifacts/6/fix.txt
```

## სწრაფი შემოწმება

```bash
check_result
```
