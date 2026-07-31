[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 119 — ეტალონური ამოხსნა (სიჩქარის დრილები + JSONPath)

ლაბორატორიის აზრი — სიჩქარის მომარჯვება იმპერატიული ბრძანებებით და `--dry-run`-ით, ასევე
`-o jsonpath`-ის გავარჯიშება. პასუხების ფაილებს ვინახავთ `/home/ubuntu/answers/`-ში.

ამაჩქარებლები (დაამატეთ სესიაში):

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
```

## დრილები

```bash
# 1. namespace
kubectl create namespace drill

# 2. deployment api, 3 რეპლიკა
kubectl -n drill create deployment api --image=viktoruj/ping_pong:latest --replicas=3

# 3. ClusterIP service api-სთვის 80 პორტზე
kubectl -n drill expose deployment api --name=api-svc --port=80 --target-port=8080

# 4. configmap და secret
kubectl -n drill create configmap cfg --from-literal=APP_COLOR=blue
kubectl -n drill create secret generic sec --from-literal=PASSWORD=s3cr3t
```

## JSONPath

```bash
mkdir -p /home/ubuntu/answers

# 5. ყველა node-ის kubelet-ის ვერსიები
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}' \
  > /home/ubuntu/answers/versions.txt

# 6. drill namespace-ის pod-ების ყველა კონტეინერის image-ები
kubectl -n drill get pods -o jsonpath='{.items[*].spec.containers[*].image}' \
  > /home/ubuntu/answers/images.txt

# 7. api-svc სერვისის ClusterIP
kubectl -n drill get svc api-svc -o jsonpath='{.spec.clusterIP}' \
  > /home/ubuntu/answers/api-ip.txt
```

სასარგებლო JSONPath-ხერხები გამოცდისთვის:

```bash
# დალაგებული გამოტანა
kubectl get pods -A --sort-by=.metadata.creationTimestamp
# custom-columns
kubectl get pods -n drill -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[*].image
# range jsonpath-ში
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.kubeletVersion}{"\n"}{end}'
```

დოკუმენტაცია: [JSONPath Support](https://kubernetes.io/docs/reference/kubectl/jsonpath/),
[kubectl Quick Reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/).

## შემოწმება

```bash
check_result
```
