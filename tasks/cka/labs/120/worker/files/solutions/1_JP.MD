[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 120 - 参考解答（networking ドリル）

高速化のための設定：

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
```

## ドリル

```bash
# 1. namespace + deployment
kubectl create namespace net
kubectl -n net create deployment web --image=viktoruj/ping_pong:latest --replicas=2

# 2. ClusterIP
kubectl -n net expose deployment web --name=web-svc --port=80 --target-port=8080

# 3. NodePort 30080
kubectl -n net expose deployment web --name=web-np --port=80 --target-port=8080 --type=NodePort $do \
  | sed 's/nodePort: .*/&/' > /tmp/np.yaml
# もっと簡単なのは - 作成してから nodePort をパッチする：
kubectl -n net create service nodeport web-np --tcp=80:8080 --node-port=30080

# 4. Headless サービス
kubectl -n net create service clusterip web-h --clusterip="None" --tcp=80:8080
# web の Pod に紐づける（selector）：
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

ドキュメント：[Service](https://kubernetes.io/docs/concepts/services-networking/service/)、
[Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)、
[NetworkPolicies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)。

## チェック

```bash
check_result
```
