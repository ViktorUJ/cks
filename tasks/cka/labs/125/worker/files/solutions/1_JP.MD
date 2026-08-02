[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 125 - 参考解答（DNS と CoreDNS）

高速化のための設定：

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
```

## 1. namespace + deployment

```bash
kubectl create namespace dns
kubectl -n dns create deployment web --image=viktoruj/ping_pong:latest --replicas=2
```

## 2. ClusterIP web-svc（通常の A レコード → 単一の ClusterIP）

```bash
kubectl -n dns expose deployment web --name=web-svc --port=80 --target-port=8080
kubectl -n dns get svc web-svc            # ClusterIP を覚えておく（課題 6 で使う）
```

## 3. Headless web-h（A レコード → すべての Pods の IP）

```bash
kubectl -n dns create service clusterip web-h --clusterip="None" --tcp=80:8080
kubectl -n dns patch svc web-h -p '{"spec":{"selector":{"app":"web"}}}'
kubectl -n dns get endpoints web-h        # web の Pods の IP が現れるはず
```

DNS の確認（任意、一時的な Pod から実行）：

```bash
kubectl -n dns run tmp --rm -it --image=busybox --restart=Never -- \
  sh -c 'nslookup web-svc; echo ---; nslookup web-h'
# web-svc → 単一の ClusterIP；web-h → すべての Pods の IP 一覧
```

## 4. dnsConfig ndots=2 を持つ Pod client

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

この Pod から直接 DNS を確認する（`alpine` タグには `nslookup`/`wget` があります）：

```bash
kubectl -n dns exec client -- nslookup web-svc
kubectl -n dns exec client -- nslookup web-h
```

## 5. CoreDNS：ドメイン mycorp.local を 10.10.0.10 へ forward

ConfigMap `coredns` を編集し、そのドメイン用の stub ブロックを追加します：

```bash
kubectl -n kube-system edit configmap coredns
```

Corefile に独立したブロックを追加します（メインの `.:53 { ... }` の隣に）：

```
mycorp.local:53 {
    errors
    cache 30
    forward . 10.10.0.10
}
```

変更を適用します：

```bash
kubectl -n kube-system rollout restart deployment coredns
```

## 6. JSONPath：web-svc の ClusterIP をファイルへ

```bash
mkdir -p /home/ubuntu/answers
kubectl -n dns get svc web-svc -o jsonpath='{.spec.clusterIP}' \
  > /home/ubuntu/answers/clusterip.txt
```

ドキュメント：
[DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)、
[Customizing DNS](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/)、
[Pod dnsConfig](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-dns-config)。

## チェック

```bash
check_result
```
