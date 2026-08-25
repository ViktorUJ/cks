[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 101 — solution de référence (bases : pods, Deployment, namespaces, Service)

## Tâche 1. Namespace `ckad-101`

```bash
kubectl create namespace ckad-101
```

## Tâche 2. Pod `web` (viktoruj/ping_pong, label `tier=frontend`) dans `ckad-101`

```bash
kubectl run web --image=viktoruj/ping_pong:latest --labels="tier=frontend" -n ckad-101
```

Vérification :

```bash
kubectl get po web -n ckad-101 --show-labels
```

## Tâche 3. Deployment `api` (viktoruj/ping_pong, 4 réplicas) dans `ckad-101`

On le crée avec 3 réplicas, puis on met à l'échelle à 4 (ou directement `--replicas=4`) :

```bash
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=3 -n ckad-101
kubectl scale deployment api --replicas=4 -n ckad-101
```

Vérification (attendre qu'ils soient prêts) :

```bash
kubectl get deploy api -n ckad-101 -w
```

## Tâche 4. Service `api-svc` (ClusterIP, port 80 → targetPort 8080) pour le deployment `api`

```bash
kubectl expose deployment api --name=api-svc --port=80 --target-port=8080 -n ckad-101
```

Vérifier que le service est bien lié aux pods (Endpoints non vides) :

```bash
kubectl get svc api-svc -n ckad-101
kubectl get endpoints api-svc -n ckad-101
```

## Tâche 5. Service `web-np` (NodePort, port 80 → targetPort 8080, nodePort 30101)

```bash
kubectl expose deployment api --name=web-np --type=NodePort --port=80 --target-port=8080 -n ckad-101
# fixer un nodePort précis (par défaut, un port aléatoire est attribué)
kubectl patch svc web-np -n ckad-101 -p '{"spec":{"ports":[{"port":80,"targetPort":8080,"nodePort":30101}]}}'
```

Vérification :

```bash
kubectl get svc web-np -n ckad-101
```

## Tâche 6. JSONPath : noms des pods dans un fichier

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl get pods -n ckad-101 -o jsonpath='{.items[*].metadata.name}' \
  > /var/work/tests/artifacts/6/pods.txt
cat /var/work/tests/artifacts/6/pods.txt
```

## Auto-vérification rapide par génération de manifestes (pour travailler la vitesse)

```bash
export do="--dry-run=client -o yaml"
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=4 $do -n ckad-101 > api.yaml
kubectl apply -f api.yaml
```
