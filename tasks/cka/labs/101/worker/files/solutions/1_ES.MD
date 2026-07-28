[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 101 — solución de referencia (fundamentos: pods, Deployment, namespaces, Service)

## Tarea 1. Namespace `ckad-101`

```bash
kubectl create namespace ckad-101
```

## Tarea 2. Pod `web` (viktoruj/ping_pong, label `tier=frontend`) en `ckad-101`

```bash
kubectl run web --image=viktoruj/ping_pong:latest --labels="tier=frontend" -n ckad-101
```

Comprobación:

```bash
kubectl get po web -n ckad-101 --show-labels
```

## Tarea 3. Deployment `api` (viktoruj/ping_pong, 4 réplicas) en `ckad-101`

Lo creamos con 3 réplicas y luego escalamos a 4 (o directamente `--replicas=4`):

```bash
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=3 -n ckad-101
kubectl scale deployment api --replicas=4 -n ckad-101
```

Comprobación (esperar a que estén listas):

```bash
kubectl get deploy api -n ckad-101 -w
```

## Tarea 4. Service `api-svc` (ClusterIP, puerto 80 → targetPort 8080) para el deployment `api`

```bash
kubectl expose deployment api --name=api-svc --port=80 --target-port=8080 -n ckad-101
```

Comprobar que el servicio se ha enlazado con los pods (Endpoints no vacíos):

```bash
kubectl get svc api-svc -n ckad-101
kubectl get endpoints api-svc -n ckad-101
```

## Tarea 5. Service `web-np` (NodePort, puerto 80 → targetPort 8080, nodePort 30101)

```bash
kubectl expose deployment api --name=web-np --type=NodePort --port=80 --target-port=8080 -n ckad-101
# fijar un nodePort concreto (por defecto se asigna uno aleatorio)
kubectl patch svc web-np -n ckad-101 -p '{"spec":{"ports":[{"port":80,"targetPort":8080,"nodePort":30101}]}}'
```

Comprobación:

```bash
kubectl get svc web-np -n ckad-101
```

## Tarea 6. JSONPath: nombres de los pods a un fichero

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl get pods -n ckad-101 -o jsonpath='{.items[*].metadata.name}' \
  > /var/work/tests/artifacts/6/pods.txt
cat /var/work/tests/artifacts/6/pods.txt
```

## Autocomprobación rápida generando manifiestos (para entrenar la velocidad)

```bash
export do="--dry-run=client -o yaml"
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=4 $do -n ckad-101 > api.yaml
kubectl apply -f api.yaml
```
