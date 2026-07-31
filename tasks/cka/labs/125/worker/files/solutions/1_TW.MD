[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 125 - 參考解答(DNS 與 CoreDNS)

加速用設定:

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
```

## 1. namespace + deployment

```bash
kubectl create namespace dns
kubectl -n dns create deployment web --image=viktoruj/ping_pong:latest --replicas=2
```

## 2. ClusterIP web-svc(一般的 A 記錄 → 單一 ClusterIP)

```bash
kubectl -n dns expose deployment web --name=web-svc --port=80 --target-port=8080
kubectl -n dns get svc web-svc            # 記下 ClusterIP(任務 6 會用到)
```

## 3. Headless web-h(A 記錄 → 所有 Pods 的 IP)

```bash
kubectl -n dns create service clusterip web-h --clusterip="None" --tcp=80:8080
kubectl -n dns patch svc web-h -p '{"spec":{"selector":{"app":"web"}}}'
kubectl -n dns get endpoints web-h        # 應該會出現 web 的 Pods IP
```

檢查 DNS(選用,從臨時 Pod 執行):

```bash
kubectl -n dns run tmp --rm -it --image=busybox --restart=Never -- \
  sh -c 'nslookup web-svc; echo ---; nslookup web-h'
# web-svc → 單一 ClusterIP;web-h → 所有 Pods 的 IP 清單
```

## 4. 帶 dnsConfig ndots=2 的 Pod client

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

直接從這個 Pod 檢查 DNS(`alpine` 標籤中有 `nslookup`/`wget`):

```bash
kubectl -n dns exec client -- nslookup web-svc
kubectl -n dns exec client -- nslookup web-h
```

## 5. CoreDNS:把 mycorp.local 網域 forward 到 10.10.0.10

修改 ConfigMap `coredns`,為該網域加入 stub 區塊:

```bash
kubectl -n kube-system edit configmap coredns
```

在 Corefile 中加入一個獨立區塊(放在主要的 `.:53 { ... }` 旁邊):

```
mycorp.local:53 {
    errors
    cache 30
    forward . 10.10.0.10
}
```

套用變更:

```bash
kubectl -n kube-system rollout restart deployment coredns
```

## 6. JSONPath:把 web-svc 的 ClusterIP 寫入檔案

```bash
mkdir -p /home/ubuntu/answers
kubectl -n dns get svc web-svc -o jsonpath='{.spec.clusterIP}' \
  > /home/ubuntu/answers/clusterip.txt
```

文件:
[DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/),
[Customizing DNS](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/),
[Pod dnsConfig](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-dns-config)。

## 檢查

```bash
check_result
```
