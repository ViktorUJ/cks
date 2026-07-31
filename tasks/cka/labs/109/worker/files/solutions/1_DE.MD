[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 109 — Referenzlösung (Observability: Probes, Logs, Debugging, Deprecations)

## Aufgabe 1. Pod `app1233` mit livenessProbe (exec)

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

## Aufgabe 2. Drei Probes für eine langsam startende Anwendung (`web-probes`)

Die Anwendung `ping_pong` mit `DELAY_START=30` beginnt erst nach 30 Sekunden auf `:8080` zu
lauschen — das ist die Nachbildung eines langen Starts. Die startupProbe gibt die Reserve für den
Start, liveness/readiness greifen erst nach ihrem Erfolg.

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
      failureThreshold: 12      # Reserve 5 × 12 = 60 s für den Start
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
# zunächst 0/1 (die startupProbe läuft), nach etwa 30 s — Ready
kubectl -n web-ns get pod web-probes -w
```

Der Fall „startupProbe gegen `initialDelaySeconds`“ wird im README behandelt.

## Aufgabe 3. Export der Pod-Logs in eine Datei

```bash
# den Namespace des Pods finden
kubectl get po -A | grep app-xyz3322
# die Logs exportieren
kubectl logs app-xyz3322 -n app-logs > /opt/logs/app-xyz123.log
cat /opt/logs/app-xyz123.log
```

## Aufgabe 4. CLI-Skripte (top, events)

```bash
mkdir -p /var/work/artifact
echo 'kubectl top pods -A --sort-by=cpu' > /var/work/artifact/top.sh
echo "kubectl get events -A --sort-by='.metadata.creationTimestamp'" > /var/work/artifact/events.sh
```

## Aufgabe 5. Veraltetes Manifest reparieren und deployen

Die Datei `/var/work/109/app-old.yaml` verwendet die entfernte `apps/v1beta1` und enthält keinen
erforderlichen `selector`. Wir korrigieren sie auf die aktuelle Version:

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

Die aktuelle API-Version lässt sich mit `kubectl explain deployment` und
`kubectl api-versions` nachsehen.
