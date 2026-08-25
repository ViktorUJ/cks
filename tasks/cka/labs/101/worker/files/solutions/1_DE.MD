[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 101 — Referenzlösung (Grundlagen: Pods, Deployment, Namespaces, Service)

## Aufgabe 1. Namespace `ckad-101`

```bash
kubectl create namespace ckad-101
```

## Aufgabe 2. Pod `web` (viktoruj/ping_pong, Label `tier=frontend`) in `ckad-101`

```bash
kubectl run web --image=viktoruj/ping_pong:latest --labels="tier=frontend" -n ckad-101
```

Prüfung:

```bash
kubectl get po web -n ckad-101 --show-labels
```

## Aufgabe 3. Deployment `api` (viktoruj/ping_pong, 4 Replicas) in `ckad-101`

Wir erstellen es mit 3 Replicas und skalieren dann auf 4 (oder direkt `--replicas=4`):

```bash
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=3 -n ckad-101
kubectl scale deployment api --replicas=4 -n ckad-101
```

Prüfung (auf Bereitschaft warten):

```bash
kubectl get deploy api -n ckad-101 -w
```

## Aufgabe 4. Service `api-svc` (ClusterIP, Port 80 → targetPort 8080) für das Deployment `api`

```bash
kubectl expose deployment api --name=api-svc --port=80 --target-port=8080 -n ckad-101
```

Prüfen, dass der Service an die Pods gebunden ist (Endpoints nicht leer):

```bash
kubectl get svc api-svc -n ckad-101
kubectl get endpoints api-svc -n ckad-101
```

## Aufgabe 5. Service `web-np` (NodePort, Port 80 → targetPort 8080, nodePort 30101)

```bash
kubectl expose deployment api --name=web-np --type=NodePort --port=80 --target-port=8080 -n ckad-101
# konkreten nodePort setzen (standardmäßig wird ein zufälliger vergeben)
kubectl patch svc web-np -n ckad-101 -p '{"spec":{"ports":[{"port":80,"targetPort":8080,"nodePort":30101}]}}'
```

Prüfung:

```bash
kubectl get svc web-np -n ckad-101
```

## Aufgabe 6. JSONPath: Pod-Namen in eine Datei

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl get pods -n ckad-101 -o jsonpath='{.items[*].metadata.name}' \
  > /var/work/tests/artifacts/6/pods.txt
cat /var/work/tests/artifacts/6/pods.txt
```

## Schnelle Selbstprüfung über Manifest-Generierung (Geschwindigkeitstraining)

```bash
export do="--dry-run=client -o yaml"
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=4 $do -n ckad-101 > api.yaml
kubectl apply -f api.yaml
```
