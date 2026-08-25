[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 125 — solution de référence (DNS et CoreDNS)

Accélérateurs :

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
```

## 1. namespace + deployment

```bash
kubectl create namespace dns
kubectl -n dns create deployment web --image=viktoruj/ping_pong:latest --replicas=2
```

## 2. ClusterIP web-svc (enregistrement A ordinaire → un seul ClusterIP)

```bash
kubectl -n dns expose deployment web --name=web-svc --port=80 --target-port=8080
kubectl -n dns get svc web-svc            # noter le ClusterIP (utile pour la tâche 6)
```

## 3. Headless web-h (enregistrements A → IP de tous les Pods)

```bash
kubectl -n dns create service clusterip web-h --clusterip="None" --tcp=80:8080
kubectl -n dns patch svc web-h -p '{"spec":{"selector":{"app":"web"}}}'
kubectl -n dns get endpoints web-h        # les IP des Pods web doivent apparaître
```

Vérification du DNS (facultatif, depuis un Pod temporaire) :

```bash
kubectl -n dns run tmp --rm -it --image=busybox --restart=Never -- \
  sh -c 'nslookup web-svc; echo ---; nslookup web-h'
# web-svc → un seul ClusterIP ; web-h → la liste des IP de tous les Pods
```

## 4. Pod client avec dnsConfig ndots=2

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

Vérifier le DNS directement depuis ce Pod (le tag `alpine` contient `nslookup`/`wget`) :

```bash
kubectl -n dns exec client -- nslookup web-svc
kubectl -n dns exec client -- nslookup web-h
```

## 5. CoreDNS : forward du domaine mycorp.local vers 10.10.0.10

Nous modifions le ConfigMap `coredns` et ajoutons un bloc stub pour le domaine :

```bash
kubectl -n kube-system edit configmap coredns
```

Ajouter au Corefile un bloc séparé (à côté du bloc principal `.:53 { ... }`) :

```
mycorp.local:53 {
    errors
    cache 30
    forward . 10.10.0.10
}
```

Appliquer les changements :

```bash
kubectl -n kube-system rollout restart deployment coredns
```

## 6. JSONPath : le ClusterIP de web-svc dans un fichier

```bash
mkdir -p /home/ubuntu/answers
kubectl -n dns get svc web-svc -o jsonpath='{.spec.clusterIP}' \
  > /home/ubuntu/answers/clusterip.txt
```

Documentation :
[DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/),
[Customizing DNS](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/),
[Pod dnsConfig](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-dns-config).

## Vérification

```bash
check_result
```
