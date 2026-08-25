[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 120 - 參考解答(networking 速度練習)

加速器:

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
```

## 速度練習

```bash
# 1. namespace + deployment
kubectl create namespace net
kubectl -n net create deployment web --image=viktoruj/ping_pong:latest --replicas=2

# 2. ClusterIP
kubectl -n net expose deployment web --name=web-svc --port=80 --target-port=8080

# 3. NodePort 30080
kubectl -n net expose deployment web --name=web-np --port=80 --target-port=8080 --type=NodePort $do \
  | sed 's/nodePort: .*/&/' > /tmp/np.yaml
# 更簡單的做法 - 先建立再修補 nodePort:
kubectl -n net create service nodeport web-np --tcp=80:8080 --node-port=30080

# 4. Headless 服務
kubectl -n net create service clusterip web-h --clusterip="None" --tcp=80:8080
# 對應到 web 的 Pod(selector):
kubectl -n net patch svc web-h -p '{"spec":{"selector":{"app":"web"}}}'

# 5. Ingress web.local -> web-svc:80
kubectl -n net create ingress web-ing --rule="web.local/*=web-svc:80"

# 6. NetworkPolicy default-deny ingress
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: net
spec:
  podSelector: {}
  policyTypes: [Ingress]
EOF
```

## JSONPath

```bash
mkdir -p /home/ubuntu/answers
kubectl -n net get svc web-np -o jsonpath='{.spec.ports[0].nodePort}' \
  > /home/ubuntu/answers/nodeport.txt
```

文件:[Service](https://kubernetes.io/docs/concepts/services-networking/service/)、
[Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)、
[NetworkPolicies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)。

## 檢查

```bash
check_result
```
