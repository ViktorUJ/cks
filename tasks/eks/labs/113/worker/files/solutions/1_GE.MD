[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 113 - ეტალონური გადაწყვეტა (კლასტერის upgrade და rollback)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე (worker) SSH-ის მეშვეობით. kubectl და aws cli
უკვე კონფიგურირებულია ლაბის კლასტერზე. ჯერ შეინახეთ კლასტერის სახელი ცვლადში - ის
გამოგვადგება ფაქტობრივად ყველა ბრძანებაში:

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
echo "$CLUSTER"
```

## დავალება 1. Namespace და კლასტერის საწყისი ვერსია

```bash
kubectl create namespace eks-113

aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

მოსალოდნელი output - `"1.35"`. ამ ლაბის კლასტერი განზრახ იწყება ერთი minor ქვემოთ
მიმდინარე GA-ვერსიაზე `1.36`-ზე, რათა შემდეგ ფაქტობრივად გავიაროთ upgrade და rollback.

დამატებით (არ ტესტირდება, მაგრამ სასარგებლოა upgrade-ის წინ): დავხედოთ, რომელ
`apiVersion`-ს ემსახურება ამჯერად API server, რომ შემდეგ, upgrade-ის შემდეგ,
შევადაროთ:

```bash
kubectl get --raw /apis | grep -o '"groupVersion":"[^"]*"'
```

## დავალება 2. Upgrade readiness-ის შემოწმება

Upgrade insights არის EKS-ის ჩაშენებული შემოწმება, რომელიც ეძებს ისეთ ნიშნებს, რაც
შესაძლოა დაბლოკოს upgrade: API-ების გამოყენება, რომლებიც ამოღებული იქნება
target-ვერსიაში, და კლასტერის საერთო მდგომარეობა. კლასტერის insights-ების სია
`--filter`-ის გარეშე შეიცავს ყველა კატეგორიას, upgrade-ის ჩათვლით:

```bash
mkdir -p /var/work/tests/artifacts/2
aws eks list-insights --cluster-name "$CLUSTER" \
  > /var/work/tests/artifacts/2/upgrade_insights.json
cat /var/work/tests/artifacts/2/upgrade_insights.json
```

შემოწმდეს, რომ insights-ებში არ არსებობს `ERROR` სტატუსი (ის აჩერებს upgrade-ს, სანამ
არ გამოსწორდება):

```bash
grep '"status"' /var/work/tests/artifacts/2/upgrade_insights.json
```

თუ რომელიმე insight-ს აქვს სტატუსი `WARNING` - ეს არ არის ბლოკერი, მაგრამ ღირს
წაკითხვა რეკომენდაციისთვის `aws eks describe-insight --cluster-name "$CLUSTER" --id
<insight-id>`-ის მეშვეობით. თუ არსებობს `ERROR`, გამოასწორეთ მიზეზი (ხშირად deprecated
`apiVersion` მანიფესტებში) და გაუშვით `aws eks list-insights` ხელახლა - EKS განაახლებს
insights-ებს ყოველ 24 საათში ერთხელ, განახლების ძალდატანება შესაძლებელია
`aws eks start-insights-refresh --cluster-name "$CLUSTER"`-ის მეშვეობით.

## დავალება 3. Control plane-ის upgrade 1.36-ზე

Upgrade მოძრაობს მხოლოდ ერთი minor-ით ერთდროულად: `1.35` -> `1.36`. დაუშვათ და შეინახეთ
update-ის `id`:

```bash
UPDATE_ID=$(aws eks update-cluster-version --name "$CLUSTER" --kubernetes-version 1.36 \
  --query 'update.id' --output text)
echo "$UPDATE_ID"
```

Control plane-ის განახლება მიდის ფონურად და შესაძლოა დასჭირდეს 20-40 წუთი. დაელოდეთ
სტატუსს `Successful`:

```bash
while true; do
  status=$(aws eks describe-update --name "$CLUSTER" --update-id "$UPDATE_ID" \
    --query 'update.status' --output text)
  echo "status=$status"
  [[ "$status" == "Successful" || "$status" == "Failed" || "$status" == "Cancelled" ]] && break
  sleep 30
done
```

დაადასტურეთ ახალი ვერსია:

```bash
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

მოსალოდნელი output - `"1.36"`. ნოუდები და add-on-ები ამ ეტაპზე ვერსიას ჯერ არ
ცვლიან - ეს შემდეგი ნაბიჯია.

## დავალება 4. ძირეული add-on-ების upgrade ვერსიებზე 1.36-ისთვის

Control plane განახლდა, მაგრამ `kube-proxy` და `coredns` ავტომატურად არ მისდევენ
მას - ისინი განახლდებიან ცალკე, ახალ minor-თან თანხვედრილ ვერსიებზე. შემოწმდეს ზუსტი
თანხვედრილი ვერსიები ასე (თუ კურსის ცხრილი ხელთ არ არის):

```bash
aws eks describe-addon-versions --addon-name kube-proxy --kubernetes-version 1.36 \
  --query 'addons[].addonVersions[].{Version:addonVersion,Default:compatibilities[0].defaultVersion}'
aws eks describe-addon-versions --addon-name coredns --kubernetes-version 1.36 \
  --query 'addons[].addonVersions[].{Version:addonVersion,Default:compatibilities[0].defaultVersion}'
```

განაახლეთ ორივე add-on (იგივე ვერსიები, რაც ლაბა 101-ში, სადაც კლასტერი პირდაპირ
იწყება `1.36`-ზე):

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --addon-version v1.36.0-eksbuild.14
aws eks update-addon --cluster-name "$CLUSTER" --addon-name coredns \
  --addon-version v1.14.3-eksbuild.3
```

დაელოდეთ `ACTIVE`-ს თითოეულისთვის:

```bash
for addon in kube-proxy coredns; do
  while true; do
    status=$(aws eks describe-addon --cluster-name "$CLUSTER" --addon-name "$addon" \
      --query 'addon.status' --output text)
    echo "$addon status=$status"
    [[ "$status" == "ACTIVE" || "$status" == "DEGRADED" ]] && break
    sleep 10
  done
done
```

შემოწმდეს მიღებული ვერსიები:

```bash
aws eks describe-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --query 'addon.addonVersion'
aws eks describe-addon --cluster-name "$CLUSTER" --addon-name coredns \
  --query 'addon.addonVersion'
```

`vpc-cni` და `eks-pod-identity-agent` არც ისე მკაცრადაა მიბმული Kubernetes-ის
minor-ვერსიაზე, როგორც `kube-proxy` და `coredns`, ამიტომ ამ ლაბის ფარგლებში მათი
ხელუხლებელი დატოვება შესაძლებელია - მაგრამ ნამდვილ ოპერირებაში მაინც ღირს მათი
ვერსიების შემოწმება `describe-addon-versions`-ის მეშვეობით.

## დავალება 5. Rollback readiness-ის შემოწმება

Rollback readiness insights ჩნდება მხოლოდ upgrade-ის შემდეგ და ცოცხლობს ზუსტად 7
დღეს - rollback-ის ფანჯარა. დავხედოთ მათ კატეგორია-ფილტრით:

```bash
mkdir -p /var/work/tests/artifacts/5
aws eks list-insights --cluster-name "$CLUSTER" \
  --filter '{"categories": ["ROLLBACK_READINESS"]}' \
  > /var/work/tests/artifacts/5/rollback_readiness.json
cat /var/work/tests/artifacts/5/rollback_readiness.json
```

შემოწმდეს სტატუსები - `ERROR` და `UNKNOWN` აჩერებენ rollback-ს:

```bash
grep '"status"' /var/work/tests/artifacts/5/rollback_readiness.json
```

თუ ახლახან გამოასწორეთ ერთი ბლოკერებიდან და არ გსურთ დღიური განახლების მოლოდინი:

```bash
aws eks start-insights-refresh --cluster-name "$CLUSTER"
```

## დავალება 6. Control plane-ის rollback 1.35-ზე

დავალება 4-ში ჩვენ განვაახლეთ `kube-proxy` `1.36`-თან თანხვედრილ ვერსიაზე. თუ ახლა
ამწონად ცადოთ control plane-ის rollback, EKS ხელახლა გამოთვლის rollback readiness
insights-ს ზუსტად იმ მომენტში, როცა გამოძახებულია `update-cluster-version`, და
პოულობს `ERROR`-ს `kube-proxy version rollback compatibility` შემოწმებაზე:
`kube-proxy`-ის ვერსია `1.36`, control plane-ის `1.35`-ზე rollback-ის შემდეგ,
გახდებოდა control plane-ზე უფრო ახალი, რაც ეწინააღმდეგება version skew-ის პოლიტიკას.
ეს ზუსტად ის მიზეზია, რის გამოც თავი 39 ამბობს "დააბრუნეთ ნოუდები/add-on-ები
control plane-ზე ადრე, თუ add-on-ის ვერსია target-ვერსიაზე წინაა" - `aws eks
list-insights` upgrade-ის ჯერ ხელახლა არ გამოაჩენს ამ პრობლემას (rollback insights
ხელახლა გამოითვლება კლასტერის მიმდინარე მდგომარეობის მიმართ), მაგრამ ის გამოჩნდება,
თუ მათ ხელახლა მოითხოვთ add-on-ის განახლების შემდეგ.

სწორი რიგია, ჯერ დააბრუნოთ `kube-proxy` `1.35`-თან თანხვედრილ ვერსიაზე, და მხოლოდ
შემდეგ დააბრუნოთ control plane:

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --addon-version v1.35.3-eksbuild.13

while true; do
  status=$(aws eks describe-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
    --query 'addon.status' --output text)
  echo "kube-proxy status=$status"
  [[ "$status" == "ACTIVE" || "$status" == "DEGRADED" ]] && break
  sleep 10
done
```

შემოწმდეს, რომ kube-proxy-ის insight გახდა `PASSING` (გამოთვლის ძალდატანება
შესაძლებელია, თუ დღის მოლოდინი არ გსურთ):

```bash
aws eks start-insights-refresh --cluster-name "$CLUSTER"
sleep 30
aws eks list-insights --cluster-name "$CLUSTER" \
  --filter '{"categories": ["ROLLBACK_READINESS"]}' \
  --query 'insights[].{name:name,status:insightStatus.status}'
```

ახლა control plane-ის rollback შესაძლებელია `--force`-ის გარეშე - სტანდარტული
გზით, იგივე upgrade-ის მსგავსად, მაგრამ წინა ვერსიით:

```bash
ROLLBACK_ID=$(aws eks update-cluster-version --name "$CLUSTER" --kubernetes-version 1.35 \
  --query 'update.id' --output text)
echo "$ROLLBACK_ID"

aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
  --query 'update.type'
```

Update-ის ტიპი პასუხში არის `VersionRollback`, არა ჩვეულებრივი `VersionUpdate`.
შეინახეთ ეს არტეფაქტში:

```bash
mkdir -p /var/work/tests/artifacts/6
aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
  --query 'update.type' --output text > /var/work/tests/artifacts/6/rollback_update.txt
cat /var/work/tests/artifacts/6/rollback_update.txt
```

Rollback-იც მიდის ფონურად და შესაძლოა დასჭირდეს 20-40 წუთი. დაელოდეთ `Successful`-ს:

```bash
while true; do
  status=$(aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
    --query 'update.status' --output text)
  echo "status=$status"
  [[ "$status" == "Successful" || "$status" == "Failed" || "$status" == "Cancelled" ]] && break
  sleep 30
done
```

დაადასტურეთ, რომ control plane დაბრუნდა `1.35`-ზე:

```bash
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

მოსალოდნელი output - `"1.35"`. etcd-ის მონაცემები, დატვირთვები და persistent volume-ები
rollback-ის დროს ხელუხლებელია - მხოლოდ control plane-ის ვერსია ბრუნდება უკან, ეს არ
არის backup-ის შემცვლელი.

## სწრაფი შემოწმება

```bash
check_result
```
