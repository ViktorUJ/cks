[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 125 — solución de referencia (DNS y CoreDNS)

Aceleradores:

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
```

## 1. namespace + deployment

```bash
kubectl create namespace dns
kubectl -n dns create deployment web --image=viktoruj/ping_pong:latest --replicas=2
```

## 2. ClusterIP web-svc (registro A normal → un único ClusterIP)

```bash
kubectl -n dns expose deployment web --name=web-svc --port=80 --target-port=8080
kubectl -n dns get svc web-svc            # anota el ClusterIP (servirá en la tarea 6)
```

## 3. Headless web-h (registros A → IP de todos los Pods)

```bash
kubectl -n dns create service clusterip web-h --clusterip="None" --tcp=80:8080
kubectl -n dns patch svc web-h -p '{"spec":{"selector":{"app":"web"}}}'
kubectl -n dns get endpoints web-h        # deben aparecer las IP de los Pods web
```

Comprobación del DNS (opcional, desde un Pod temporal):

```bash
kubectl -n dns run tmp --rm -it --image=busybox --restart=Never -- \
  sh -c 'nslookup web-svc; echo ---; nslookup web-h'
# web-svc → un único ClusterIP; web-h → la lista de IP de todos los Pods
```

## 4. Pod client con dnsConfig ndots=2

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

Comprobar el DNS directamente desde este Pod (el tag `alpine` incluye `nslookup`/`wget`):

```bash
kubectl -n dns exec client -- nslookup web-svc
kubectl -n dns exec client -- nslookup web-h
```

## 5. CoreDNS: forward del dominio mycorp.local a 10.10.0.10

Editamos el ConfigMap `coredns` y añadimos un bloque stub para el dominio:

```bash
kubectl -n kube-system edit configmap coredns
```

Añadir al Corefile un bloque aparte (junto al principal `.:53 { ... }`):

```
mycorp.local:53 {
    errors
    cache 30
    forward . 10.10.0.10
}
```

Aplicar los cambios:

```bash
kubectl -n kube-system rollout restart deployment coredns
```

## 6. JSONPath: el ClusterIP de web-svc a un fichero

```bash
mkdir -p /home/ubuntu/answers
kubectl -n dns get svc web-svc -o jsonpath='{.spec.clusterIP}' \
  > /home/ubuntu/answers/clusterip.txt
```

Documentación:
[DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/),
[Customizing DNS](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/),
[Pod dnsConfig](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-dns-config).

## Comprobación

```bash
check_result
```
