[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 125 — ეტალონური ამოხსნა (DNS და CoreDNS)

ამაჩქარებლები:

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
```

## 1. namespace + deployment

```bash
kubectl create namespace dns
kubectl -n dns create deployment web --image=viktoruj/ping_pong:latest --replicas=2
```

## 2. ClusterIP web-svc (ჩვეულებრივი A-ჩანაწერი → ერთი ClusterIP)

```bash
kubectl -n dns expose deployment web --name=web-svc --port=80 --target-port=8080
kubectl -n dns get svc web-svc            # დაიმახსოვრეთ ClusterIP (გამოგადგებათ დავალება 6-ში)
```

## 3. Headless web-h (A-ჩანაწერები → ყველა Pod-ის IP)

```bash
kubectl -n dns create service clusterip web-h --clusterip="None" --tcp=80:8080
kubectl -n dns patch svc web-h -p '{"spec":{"selector":{"app":"web"}}}'
kubectl -n dns get endpoints web-h        # უნდა გამოჩნდეს web Pod-ების IP
```

DNS-ის შემოწმება (სურვილისამებრ, დროებითი Pod-იდან):

```bash
kubectl -n dns run tmp --rm -it --image=busybox --restart=Never -- \
  sh -c 'nslookup web-svc; echo ---; nslookup web-h'
# web-svc → ერთი ClusterIP; web-h → ყველა Pod-ის IP-ების სია
```

## 4. Pod client dnsConfig ndots=2-ით

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

DNS-ის შემოწმება პირდაპირ ამ Pod-იდან (ტეგ `alpine`-ში არის `nslookup`/`wget`):

```bash
kubectl -n dns exec client -- nslookup web-svc
kubectl -n dns exec client -- nslookup web-h
```

## 5. CoreDNS: დომენ mycorp.local-ის forward 10.10.0.10-ზე

ვარედაქტირებთ ConfigMap `coredns`-ს და ვამატებთ stub-ბლოკს დომენისთვის:

```bash
kubectl -n kube-system edit configmap coredns
```

Corefile-ში დაამატეთ ცალკე ბლოკი (ძირითად `.:53 { ... }`-ის გვერდით):

```
mycorp.local:53 {
    errors
    cache 30
    forward . 10.10.0.10
}
```

ცვლილებების გამოყენება:

```bash
kubectl -n kube-system rollout restart deployment coredns
```

## 6. JSONPath: web-svc-ის ClusterIP ფაილში

```bash
mkdir -p /home/ubuntu/answers
kubectl -n dns get svc web-svc -o jsonpath='{.spec.clusterIP}' \
  > /home/ubuntu/answers/clusterip.txt
```

დოკუმენტაცია:
[DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/),
[Customizing DNS](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/),
[Pod dnsConfig](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-dns-config).

## შემოწმება

```bash
check_result
```
