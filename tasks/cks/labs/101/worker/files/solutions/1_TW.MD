[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 101 - 簡要解答

我們使用 `k` 取代 `kubectl`(別名在考試中已經可用)。

開始之前(如有需要)，先刪除舊的 namespace:
```bash
k delete ns cks-101 cks-101-legacy imds-control --ignore-not-found
```

## 1. 應用程式

取得映像目前的 digest:
```bash
k run digest --image=viktoruj/ping_pong:latest
k wait --for=condition=Ready pod/digest --timeout=60s
digest=$(k get pod digest -o yaml | grep imageID | cut -d'@' -f2)
k delete pod digest
```

建立 namespace、Deployments 與 Service:
```bash
k create ns cks-101
k -n cks-101 create deployment frontend --image=viktoruj/ping_pong@$digest --replicas=1 --port=8080
k -n cks-101 create deployment backend --image=viktoruj/ping_pong@$digest --replicas=1 --port=8080
k -n cks-101 expose deployment backend --port=8080
k -n cks-101 wait --for=condition=Available deploy/frontend deploy/backend --timeout=60s
```

確認映像一致：
```bash
k -n cks-101 get deploy frontend backend -o yaml | grep 'image:'
```

## 2. Default-deny 與 baseline 檢查

建立用於測試的 probe:
```bash
k -n cks-101 run probe --image=curlimages/curl:8.11.1 -l app=frontend --command -- sleep 3600
k -n cks-101 wait --for=condition=Ready pod/probe --timeout=60s
```

為 control 建立獨立的 namespace:
```bash
k create ns imds-control
k -n imds-control run imds-control --image=curlimages/curl:8.11.1 --command -- sleep 3600
k -n imds-control wait --for=condition=Ready pod/imds-control --timeout=60s
```

default-deny 之前的 Baseline:
```bash
# Baseline:default-deny 之前 backend 可達
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://backend:8080/
echo $?

# Baseline:從 frontend 可達 IMDS
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# imds-control 可正常運作
k -n imds-control exec imds-control -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

套用 default-deny:
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

在 default-deny 之後檢查：
```bash
# IMDS 被阻擋
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# imds-control 仍然可正常運作
k -n imds-control exec imds-control -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

## 3. DNS

先允許 DNS egress:
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

從單獨的 BusyBox Pod 檢查 DNS:
```bash
k -n cks-101 run dns-probe \
  --image=busybox:1.36.1 \
  -l app=frontend \
  --command -- sleep 3600

k -n cks-101 wait --for=condition=Ready pod/dns-probe --timeout=60s

k -n cks-101 exec dns-probe -- \
  nslookup kubernetes.default.svc.cluster.local
```

DNS 恢復之後，backend 此時仍必須保持封閉：
```bash
k -n cks-101 exec probe -- \
  curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://backend:8080/
echo $?
```

預期：
```
HTTP:000
curl exit 7 或 28
```

## 4. 應用程式允許的流量

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

透過 Service DNS 檢查：

```bash
k -n cks-101 exec probe -- \
  curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://backend:8080/
echo $?
```

## 5. IMDS 最終驗證

```bash
# control:IMDS 可達
k -n imds-control exec imds-control -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# deny:在 cks-101 中 IMDS 被阻擋
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

## 6. Legacy AND 與 IMDS except

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

檢查：
```bash
# 對 legacy 而言 IMDS 被阻擋
k -n cks-101-legacy exec deploy/legacy-client -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# 透過 Service DNS 可達 backend
k -n cks-101-legacy exec deploy/legacy-client -- curl -sS -m 5 http://backend.cks-101:8080/
```

## 7. 觀察 hostNetwork

```bash
k -n cks-101 run hostnetwork-probe --image=curlimages/curl:8.11.1 -l app=frontend \
  --overrides='{"spec":{"hostNetwork":true,"dnsPolicy":"ClusterFirstWithHostNet"}}' \
  --command -- sleep 3600
k -n cks-101 wait --for=condition=Ready pod/hostnetwork-probe --timeout=60s
```

```bash
# hostNetwork probe - 結果可能與一般 Pod 不同
k -n cks-101 exec hostnetwork-probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

---

## 檢查

```bash
check_result
```
