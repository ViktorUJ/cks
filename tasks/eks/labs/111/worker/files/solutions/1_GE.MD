[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 111 - ეტალონური გადაწყვეტა (spot-ნოუდები: დივერსიფიკაცია, წყვეტები, graceful drain)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე SSH-ით. kubectl უკვე კონფიგურირებულია
კლასტერზე (kubeconfig აწყობილია `aws eks update-kubeconfig`-ის მეშვეობით მანქანის
ჩატვირთვისას).

## დავალება 1. Namespace `eks-111`

```bash
kubectl create namespace eks-111
```

## დავალება 2. Deployment `spotapp` spot-პულზე toleration-ითა და graceful shutdown-ით

პული `spot-lab` დაცულია taint-ით `dedicated=spot-lab:NoSchedule`, ამიტომ პოდს უნდა
ჰქონდეს შესატყვისი toleration, სხვანაირად Karpenter-ს არ შეეძლება მისი განთავსება ამ
NodePool-ზე. `terminationGracePeriodSeconds: 60` ჯდება ორწუთიან spot-წყვეტის
ფანჯარაში, ხოლო `preStop` `sleep 5`-ით აძლევს ბალანსერს დროს, გადმოწიოს ტრაფიკი
კონტეინერის გაჩერებამდე.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spotapp
  namespace: eks-111
spec:
  replicas: 4
  selector:
    matchLabels:
      app: spotapp
  template:
    metadata:
      labels:
        app: spotapp
    spec:
      terminationGracePeriodSeconds: 60
      tolerations:
        - key: "dedicated"
          value: "spot-lab"
          effect: "NoSchedule"
      containers:
        - name: app
          image: viktoruj/ping_pong:latest
          lifecycle:
            preStop:
              exec:
                command: ["sh", "-c", "sleep 5"]
EOF

kubectl rollout status deployment/spotapp -n eks-111
```

შემოწმება, რომ ყველა 4 რეპლიკა ავიდა spot-ნოუდებზე:

```bash
kubectl get po -n eks-111 -l app=spotapp -o wide
NODES=$(kubectl get po -n eks-111 -l app=spotapp -o jsonpath='{.items[*].spec.nodeName}')
for n in $NODES; do
  kubectl get node "$n" -L karpenter.sh/capacity-type --no-headers
done
```

Karpenter ახალ EC2-ნოუდს აღმართავს დაახლოებით 60-90 წამში, ამიტომ თავიდან პოდები
შესაძლოა ჩამოკიდებული იყვნენ `Pending`-ში. ველოდებით `rollout status`-ს, სანამ შემდეგ
გავალთ.

## დავალება 3. არტეფაქტი: spot-ნოუდები და NodePool-ის დივერსიფიკაცია

ვინახავთ ნოუდების ჩანაწერს capacity-ტიპის ლეიბლითა და instance-კატეგორიით, ასევე
NodePool `spot-lab`-ის requirements, რომ დავადასტუროთ ფართო ფამილიების ნაკრები
(დივერსიფიკაცია).

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl get nodes -L karpenter.sh/capacity-type -L karpenter.k8s.aws/instance-category \
  > /var/work/tests/artifacts/3/nodes.txt
cat /var/work/tests/artifacts/3/nodes.txt

kubectl get nodepool spot-lab -o yaml \
  | grep -A5 'instance-category' > /var/work/tests/artifacts/3/nodepool.txt
cat /var/work/tests/artifacts/3/nodepool.txt
```

`nodes.txt`-ში უნდა იყოს მინიმუმ ერთი ნოუდი `capacity-type=spot`-ით. `nodepool.txt`-ში
უნდა იყოს სამივე instance-კატეგორია `c`, `m`, `r` - ეს არის დივერსიფიკაციის
მოთხოვნა: `spot-lab` პული არ არის ვიწროდ დაყვანილი instance-ების ერთ ფამილიაზე.

## დავალება 4. PodDisruptionBudget `spotapp`-ისთვის

`minAvailable: 3` 4 რეპლიკიდან იცავს ჭარბი voluntary evict-ისგან:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: spotapp-pdb
  namespace: eks-111
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: spotapp
EOF

kubectl get pdb spotapp-pdb -n eks-111 -o yaml
```

## დავალება 5. სიმპტომი: drain ბლოკირდება PDB-ის მიერ, მაგრამ ეს არ იხსნის spot AWS-ისგან

ავირჩევთ ნოუდს, რომელზეც დგება მინიმუმ ერთი `spotapp` პოდი, კორდონს ვუკეთებთ და
ვცდილობთ drain-ს. 4 რეპლიკისა და `minAvailable: 3`-ის შემთხვევაში PDB უშვებს
ერთდროულად არაუმეტეს ერთი რეპლიკის evict-ს (`disruptionsAllowed` არ აჭარბებს 1-ს) -
drain ერთ რეპლიკაზე შორს არ წავა.

```bash
NODE=$(kubectl get po -n eks-111 -l app=spotapp -o jsonpath='{.items[0].spec.nodeName}')
kubectl cordon "$NODE"
kubectl get pdb spotapp-pdb -n eks-111 -o jsonpath='{.status.disruptionsAllowed}'
echo

# რა ცდილობს გამოსვლას, ნოუდის რეალური დრეინის გარეშე
kubectl drain "$NODE" --ignore-daemonsets --dry-run=client
```

ვფიქსირებთ სიმპტომსა და PDB-ის პასუხისმგებლობის საზღვრის განმარტებას არტეფაქტში:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/drain.txt <<'EOF'
ნოუდი დაკორდონილია, drain ცდილობს spotapp-ის პოდების evict-ს eviction API-ის
მეშვეობით. PDB spotapp-pdb minAvailable: 3-ით არ უშვებს ერთდროულად ერთი რეპლიკის
მეტის evict-ს (disruptionsAllowed <= 1, 4 რეპლიკის შემთხვევაში): ბიუჯეტის დარღვევის
მცდელობისას eviction ითხოვს უარს, და drain ერთ რეპლიკაზე შორს არ წავა.

მნიშვნელოვანი საზღვარი: PDB იცავს მხოლოდ voluntary evict-ს - kubectl
drain, ნოუდების განახლება, Karpenter-ის კონსოლიდაცია. ის არ იხსნის AWS-ის ფორსირებული
spot-ჩამორთმევისგან: თუ AWS რეალურად ჩამორთმევს instance-ს ორწუთიანი შეტყობინების
ვადის გასვლის შემდეგ, პოდები მასზე დასრულდება PDB-ის მიუხედავად, რადგან ეს არ არის
Kubernetes-ის voluntary მოქმედება, არამედ თავად instance-ის გაჩერება.
EOF
cat /var/work/tests/artifacts/5/drain.txt

kubectl uncordon "$NODE"
```

## დავალება 6. Karpenter-ის წყვეტების დამუშავების შემოწმება

Karpenter თავად ამუშავებს spot-წყვეტებს წყვეტების queue-ის მეშვეობით
(`interruptionQueue`, კონფიგურირებული მოდულ `eks_v2_karpenter`-ში, ამ ლაბისგან
დამოუკიდებლად). მექანიზმს ვადასტურებთ კონტროლერის ლოგებით - worker-ს შესაძლოა არ
ჰქონდეს უფლება `aws sqs list-queues`-ზე, ამიტომ ვიყენებთ `kubectl logs`-ს:

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=500 \
  | grep -i interrupt > /var/work/tests/artifacts/6/interruption.txt

# თუ წყვეტის event-ები ჯერ არ ყოფილა, ვაფიქსირებთ თავად მექანიზმის არსებობის ფაქტს:
if [[ ! -s /var/work/tests/artifacts/6/interruption.txt ]]; then
  echo "no interruption events yet, but Karpenter interruption handling is configured via interruptionQueue" \
    > /var/work/tests/artifacts/6/interruption.txt
fi
cat /var/work/tests/artifacts/6/interruption.txt
```

## სწრაფი შემოწმება

```bash
check_result
```
