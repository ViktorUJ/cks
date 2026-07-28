[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 119 — Referenzlösung (Speed-Drills + JSONPath)

Sinn des Labs ist es, Geschwindigkeit mit imperativen Befehlen und `--dry-run` aufzubauen und
zusätzlich `-o jsonpath` zu trainieren. Die Antwortdateien speichern wir in
`/home/ubuntu/answers/`.

Beschleuniger (in die Session aufnehmen):

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
```

## Drills

```bash
# 1. namespace
kubectl create namespace drill

# 2. deployment api, 3 Replicas
kubectl -n drill create deployment api --image=viktoruj/ping_pong:latest --replicas=3

# 3. ClusterIP-Service für api auf Port 80
kubectl -n drill expose deployment api --name=api-svc --port=80 --target-port=8080

# 4. configmap und secret
kubectl -n drill create configmap cfg --from-literal=APP_COLOR=blue
kubectl -n drill create secret generic sec --from-literal=PASSWORD=s3cr3t
```

## JSONPath

```bash
mkdir -p /home/ubuntu/answers

# 5. kubelet-Versionen aller Nodes
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}' \
  > /home/ubuntu/answers/versions.txt

# 6. Images aller Pod-Container im Namespace drill
kubectl -n drill get pods -o jsonpath='{.items[*].spec.containers[*].image}' \
  > /home/ubuntu/answers/images.txt

# 7. ClusterIP des Service api-svc
kubectl -n drill get svc api-svc -o jsonpath='{.spec.clusterIP}' \
  > /home/ubuntu/answers/api-ip.txt
```

Nützliche JSONPath-Tricks für die Prüfung:

```bash
# sortierte Ausgabe
kubectl get pods -A --sort-by=.metadata.creationTimestamp
# custom-columns
kubectl get pods -n drill -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[*].image
# range in jsonpath
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.kubeletVersion}{"\n"}{end}'
```

Dokumentation: [JSONPath Support](https://kubernetes.io/docs/reference/kubectl/jsonpath/),
[kubectl Quick Reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/).

## Prüfung

```bash
check_result
```
