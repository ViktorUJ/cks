[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 125 — Referenzlösung (DNS und CoreDNS)

Beschleuniger:

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
```

## 1. namespace + deployment

```bash
kubectl create namespace dns
kubectl -n dns create deployment web --image=viktoruj/ping_pong:latest --replicas=2
```

## 2. ClusterIP web-svc (normaler A-Record → eine ClusterIP)

```bash
kubectl -n dns expose deployment web --name=web-svc --port=80 --target-port=8080
kubectl -n dns get svc web-svc            # ClusterIP notieren (wird in Aufgabe 6 gebraucht)
```

## 3. Headless web-h (A-Records → IPs aller Pods)

```bash
kubectl -n dns create service clusterip web-h --clusterip="None" --tcp=80:8080
kubectl -n dns patch svc web-h -p '{"spec":{"selector":{"app":"web"}}}'
kubectl -n dns get endpoints web-h        # die IPs der web-Pods sollten erscheinen
```

DNS-Prüfung (optional, aus einem temporären Pod):

```bash
kubectl -n dns run tmp --rm -it --image=busybox --restart=Never -- \
  sh -c 'nslookup web-svc; echo ---; nslookup web-h'
# web-svc → eine ClusterIP; web-h → die Liste der IPs aller Pods
```

## 4. Pod client mit dnsConfig ndots=2

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: dns
spec:
  dnsPolicy: ClusterFirst
  dnsConfig:
    options:
    - name: ndots
      value: "2"
  containers:
  - name: client
    image: viktoruj/ping_pong:alpine
EOF
```

DNS direkt aus diesem Pod prüfen (im Tag `alpine` sind `nslookup`/`wget` enthalten):

```bash
kubectl -n dns exec client -- nslookup web-svc
kubectl -n dns exec client -- nslookup web-h
```

## 5. CoreDNS: forward der Domain mycorp.local an 10.10.0.10

Wir bearbeiten die ConfigMap `coredns` und fügen einen Stub-Block für die Domain hinzu:

```bash
kubectl -n kube-system edit configmap coredns
```

Im Corefile einen separaten Block hinzufügen (neben dem Haupt-Block `.:53 { ... }`):

```
mycorp.local:53 {
    errors
    cache 30
    forward . 10.10.0.10
}
```

Änderungen anwenden:

```bash
kubectl -n kube-system rollout restart deployment coredns
```

## 6. JSONPath: ClusterIP von web-svc in eine Datei

```bash
mkdir -p /home/ubuntu/answers
kubectl -n dns get svc web-svc -o jsonpath='{.spec.clusterIP}' \
  > /home/ubuntu/answers/clusterip.txt
```

Dokumentation:
[DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/),
[Customizing DNS](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/),
[Pod dnsConfig](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-dns-config).

## Prüfung

```bash
check_result
```
