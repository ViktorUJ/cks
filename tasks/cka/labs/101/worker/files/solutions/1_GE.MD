[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD)

# Lab 101 — ეტალონური ამოხსნა (საფუძვლები: pod-ები, Deployment, namespace-ები, Service)

## დავალება 1. Namespace `ckad-101`

```bash
kubectl create namespace ckad-101
```

## დავალება 2. Pod `web` (viktoruj/ping_pong, label `tier=frontend`) `ckad-101`-ში

```bash
kubectl run web --image=viktoruj/ping_pong:latest --labels="tier=frontend" -n ckad-101
```

შემოწმება:

```bash
kubectl get po web -n ckad-101 --show-labels
```

## დავალება 3. Deployment `api` (viktoruj/ping_pong, 4 რეპლიკა) `ckad-101`-ში

ვქმნით 3 რეპლიკით, შემდეგ ვამასშტაბირებთ 4-მდე (ან პირდაპირ `--replicas=4`):

```bash
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=3 -n ckad-101
kubectl scale deployment api --replicas=4 -n ckad-101
```

შემოწმება (დაელოდეთ მზადყოფნას):

```bash
kubectl get deploy api -n ckad-101 -w
```

## დავალება 4. Service `api-svc` (ClusterIP, პორტი 80 → targetPort 8080) deployment `api`-სთვის

```bash
kubectl expose deployment api --name=api-svc --port=80 --target-port=8080 -n ckad-101
```

შემოწმება, რომ სერვისი დაუკავშირდა pod-ებს (Endpoints არ არის ცარიელი):

```bash
kubectl get svc api-svc -n ckad-101
kubectl get endpoints api-svc -n ckad-101
```

## დავალება 5. Service `web-np` (NodePort, პორტი 80 → targetPort 8080, nodePort 30101)

```bash
kubectl expose deployment api --name=web-np --type=NodePort --port=80 --target-port=8080 -n ckad-101
# კონკრეტული nodePort-ის მითითება (ნაგულისხმევად შემთხვევითი ინიშნება)
kubectl patch svc web-np -n ckad-101 -p '{"spec":{"ports":[{"port":80,"targetPort":8080,"nodePort":30101}]}}'
```

შემოწმება:

```bash
kubectl get svc web-np -n ckad-101
```

## დავალება 6. JSONPath: pod-ების სახელები ფაილში

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl get pods -n ckad-101 -o jsonpath='{.items[*].metadata.name}' \
  > /var/work/tests/artifacts/6/pods.txt
cat /var/work/tests/artifacts/6/pods.txt
```

## სწრაფი თვითშემოწმება მანიფესტების გენერაციით (სიჩქარის ვარჯიშისთვის)

```bash
export do="--dry-run=client -o yaml"
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=4 $do -n ckad-101 > api.yaml
kubectl apply -f api.yaml
```
