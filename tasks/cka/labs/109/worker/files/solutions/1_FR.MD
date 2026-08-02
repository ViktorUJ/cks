[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 109 — solution de référence (observabilité : probes, logs, débogage, deprecations)

## Tâche 1. Pod `app1233` avec livenessProbe (exec)

```bash
kubectl create namespace web-ns
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app1233
  namespace: web-ns
spec:
  containers:
  - name: app1233
    image: viktoruj/ping_pong:alpine
    livenessProbe:
      exec:
        command: ["ls", "/etc"]
      initialDelaySeconds: 10
      periodSeconds: 60
```

## Tâche 2. Trois probes pour une application à démarrage lent (`web-probes`)

L'application `ping_pong` avec `DELAY_START=30` ne commence à écouter sur `:8080` qu'au bout de
30 secondes — c'est l'imitation d'un démarrage long. Le startupProbe donne la marge nécessaire au
démarrage, et liveness/readiness ne s'activent qu'après son succès.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-probes
  namespace: web-ns
spec:
  containers:
  - name: web-probes
    image: viktoruj/ping_pong:latest
    ports:
    - containerPort: 8080
    env:
    - name: DELAY_START
      value: "30"
    startupProbe:
      httpGet:
        path: /
        port: 8080
      periodSeconds: 5
      failureThreshold: 12      # marge de 5 × 12 = 60 s pour le démarrage
    readinessProbe:
      httpGet:
        path: /
        port: 8080
      periodSeconds: 10
    livenessProbe:
      httpGet:
        path: /
        port: 8080
      periodSeconds: 10
```

```bash
kubectl apply -f web-probes.yaml
# 0/1 au début (le startupProbe est en cours), Ready au bout d'environ 30 s
kubectl -n web-ns get pod web-probes -w
```

Le cas « startupProbe face à `initialDelaySeconds` » est détaillé dans le README.

## Tâche 3. Exporter les logs du pod dans un fichier

```bash
# trouver le namespace du pod
kubectl get po -A | grep app-xyz3322
# exporter les logs
kubectl logs app-xyz3322 -n app-logs > /opt/logs/app-xyz123.log
cat /opt/logs/app-xyz123.log
```

## Tâche 4. Scripts CLI (top, events)

```bash
mkdir -p /var/work/artifact
echo 'kubectl top pods -A --sort-by=cpu' > /var/work/artifact/top.sh
echo "kubectl get events -A --sort-by='.metadata.creationTimestamp'" > /var/work/artifact/events.sh
```

## Tâche 5. Réparer le manifeste obsolète et le déployer

Le fichier `/var/work/109/app-old.yaml` utilise la version supprimée `apps/v1beta1` et ne
contient pas le `selector` obligatoire. Nous le corrigeons vers la version actuelle :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-21
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-21
  template:
    metadata:
      labels:
        app: app-21
    spec:
      containers:
      - name: app-21
        image: viktoruj/ping_pong:alpine
```

```bash
kubectl apply -f /var/work/109/app-old.yaml
kubectl get deploy app-21
```

La version actuelle de l'API peut être consultée avec `kubectl explain deployment` et
`kubectl api-versions`.
