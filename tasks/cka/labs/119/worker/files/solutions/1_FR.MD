[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 119 — solution de référence (exercices de vitesse + JSONPath)

L'objectif de ce lab est de gagner en vitesse avec les commandes impératives et `--dry-run`,
ainsi que de s'entraîner à `-o jsonpath`. Les fichiers de réponses sont enregistrés dans
`/home/ubuntu/answers/`.

Accélérateurs (à ajouter à votre session) :

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
```

## Exercices

```bash
# 1. namespace
kubectl create namespace drill

# 2. deployment api, 3 réplicas
kubectl -n drill create deployment api --image=viktoruj/ping_pong:latest --replicas=3

# 3. service ClusterIP pour api sur le port 80
kubectl -n drill expose deployment api --name=api-svc --port=80 --target-port=8080

# 4. configmap et secret
kubectl -n drill create configmap cfg --from-literal=APP_COLOR=blue
kubectl -n drill create secret generic sec --from-literal=PASSWORD=s3cr3t
```

## JSONPath

```bash
mkdir -p /home/ubuntu/answers

# 5. versions de kubelet de tous les nodes
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}' \
  > /home/ubuntu/answers/versions.txt

# 6. images de tous les conteneurs des pods du namespace drill
kubectl -n drill get pods -o jsonpath='{.items[*].spec.containers[*].image}' \
  > /home/ubuntu/answers/images.txt

# 7. ClusterIP du service api-svc
kubectl -n drill get svc api-svc -o jsonpath='{.spec.clusterIP}' \
  > /home/ubuntu/answers/api-ip.txt
```

Astuces JSONPath utiles pour l'examen :

```bash
# sortie triée
kubectl get pods -A --sort-by=.metadata.creationTimestamp
# custom-columns
kubectl get pods -n drill -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[*].image
# range dans jsonpath
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.kubeletVersion}{"\n"}{end}'
```

Documentation : [JSONPath Support](https://kubernetes.io/docs/reference/kubectl/jsonpath/),
[kubectl Quick Reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/).

## Vérification

```bash
check_result
```
