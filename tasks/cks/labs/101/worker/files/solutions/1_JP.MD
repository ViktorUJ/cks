[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 101 - 簡易解答

`kubectl` の代わりに `k` を使います (このエイリアスは試験でもすでに利用可能です)。

開始前に (必要であれば) 古い namespace を削除します：
```bash
k delete ns cks-101 cks-101-legacy imds-control --ignore-not-found
```

## 1. アプリケーション

イメージの最新の digest を取得します：
```bash
k run digest --image=viktoruj/ping_pong:latest
k wait --for=condition=Ready pod/digest --timeout=60s
digest=$(k get pod digest -o yaml | grep imageID | cut -d'@' -f2)
k delete pod digest
```

namespace、Deployments、Service を作成します：
```bash
k create ns cks-101
k -n cks-101 create deployment frontend --image=viktoruj/ping_pong@$digest --replicas=1 --port=8080
k -n cks-101 create deployment backend --image=viktoruj/ping_pong@$digest --replicas=1 --port=8080
k -n cks-101 expose deployment backend --port=8080
k -n cks-101 wait --for=condition=Available deploy/frontend deploy/backend --timeout=60s
```

イメージが一致していることを確認します：
```bash
k -n cks-101 get deploy frontend backend -o yaml | grep 'image:'
```

## 2. Default-deny と baseline の確認

テスト用の probe を作成します：
```bash
k -n cks-101 run probe --image=curlimages/curl:8.11.1 -l app=frontend --command -- sleep 3600
k -n cks-101 wait --for=condition=Ready pod/probe --timeout=60s
```

control 用の独立した namespace を作成します：
```bash
k create ns imds-control
k -n imds-control run imds-control --image=curlimages/curl:8.11.1 --command -- sleep 3600
k -n imds-control wait --for=condition=Ready pod/imds-control --timeout=60s
```

default-deny の前の Baseline：
```bash
# Baseline: default-deny の前は backend に到達できる
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://backend:8080/
echo $?

# Baseline: frontend から IMDS に到達できる
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# imds-control は動作する
k -n imds-control exec imds-control -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

default-deny を適用します：
```bash
k -n cks-101 apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
EOF
```

default-deny の後を確認します：
```bash
# IMDS はブロックされている
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# imds-control は引き続き動作する
k -n imds-control exec imds-control -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

## 3. DNS

まず DNS の egress を許可します：
```bash
k -n cks-101 apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-dns
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF
```

別の BusyBox Pod から DNS を確認します：
```bash
k -n cks-101 run dns-probe \
  --image=busybox:1.36.1 \
  -l app=frontend \
  --command -- sleep 3600

k -n cks-101 wait --for=condition=Ready pod/dns-probe --timeout=60s

k -n cks-101 exec dns-probe -- \
  nslookup kubernetes.default.svc.cluster.local
```

DNS を復活させた後も、backend はまだ閉じたままでなければなりません：
```bash
k -n cks-101 exec probe -- \
  curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://backend:8080/
echo $?
```

期待される結果：
```
HTTP:000
curl exit 7 または 28
```

## 4. アプリケーションの許可された通信

```bash
k -n cks-101 apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-egress-to-backend
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 8080
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-ingress-from-frontend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
EOF
```

Service DNS 経由で確認します：

```bash
k -n cks-101 exec probe -- \
  curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://backend:8080/
echo $?
```

## 5. IMDS の最終確認

```bash
# control: IMDS に到達できる
k -n imds-control exec imds-control -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# deny: cks-101 では IMDS がブロックされている
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

## 6. Legacy AND と IMDS except

```bash
k create ns cks-101-legacy
k -n cks-101-legacy create deployment legacy-client --image=curlimages/curl:8.11.1 --replicas=1 -- sleep 3600
k -n cks-101-legacy wait --for=condition=Available deploy/legacy-client --timeout=60s
```

```bash
k -n cks-101 apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-ingress-from-legacy
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: cks-101-legacy
          podSelector:
            matchLabels:
              app: legacy-client
      ports:
        - protocol: TCP
          port: 8080
EOF
```

```bash
k -n cks-101-legacy apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-legacy-egress
spec:
  podSelector:
    matchLabels:
      app: legacy-client
  policyTypes: [Egress]
  egress:
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 169.254.169.254/32
EOF
```

確認します：
```bash
# legacy からは IMDS がブロックされている
k -n cks-101-legacy exec deploy/legacy-client -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# backend には Service DNS 経由で到達できる
k -n cks-101-legacy exec deploy/legacy-client -- curl -sS -m 5 http://backend.cks-101:8080/
```

## 7. hostNetwork の観察

```bash
k -n cks-101 run hostnetwork-probe --image=curlimages/curl:8.11.1 -l app=frontend \
  --overrides='{"spec":{"hostNetwork":true,"dnsPolicy":"ClusterFirstWithHostNet"}}' \
  --command -- sleep 3600
k -n cks-101 wait --for=condition=Ready pod/hostnetwork-probe --timeout=60s
```

```bash
# hostNetwork probe - 結果は通常の Pod と異なる場合がある
k -n cks-101 exec hostnetwork-probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

---

## 検証

```bash
check_result
```