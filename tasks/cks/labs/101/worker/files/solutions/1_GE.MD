[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 101 - მოკლე ამოხსნა

`kubectl`-ის ნაცვლად ვიყენებთ `k`-ს (alias უკვე ხელმისაწვდომია გამოცდაზე).

დაწყებამდე (საჭიროების შემთხვევაში) ვშლით ძველ namespace-ებს:
```bash
k delete ns cks-101 cks-101-legacy imds-control --ignore-not-found
```

## 1. აპლიკაცია

ვიღებთ image-ის მიმდინარე digest-ს:
```bash
k run digest --image=viktoruj/ping_pong:latest
k wait --for=condition=Ready pod/digest --timeout=60s
digest=$(k get pod digest -o yaml | grep imageID | cut -d'@' -f2)
k delete pod digest
```

ვქმნით namespace-ს, Deployments-სა და Service-ს:
```bash
k create ns cks-101
k -n cks-101 create deployment frontend --image=viktoruj/ping_pong@$digest --replicas=1 --port=8080
k -n cks-101 create deployment backend --image=viktoruj/ping_pong@$digest --replicas=1 --port=8080
k -n cks-101 expose deployment backend --port=8080
k -n cks-101 wait --for=condition=Available deploy/frontend deploy/backend --timeout=60s
```

ვამოწმებთ, რომ image-ები ემთხვევა:
```bash
k -n cks-101 get deploy frontend backend -o yaml | grep 'image:'
```

## 2. Default-deny და baseline შემოწმება

ვქმნით probe-ს ტესტებისთვის:
```bash
k -n cks-101 run probe --image=curlimages/curl:8.11.1 -l app=frontend --command -- sleep 3600
k -n cks-101 wait --for=condition=Ready pod/probe --timeout=60s
```

ვქმნით დამოუკიდებელ namespace-ს control-ისთვის:
```bash
k create ns imds-control
k -n imds-control run imds-control --image=curlimages/curl:8.11.1 --command -- sleep 3600
k -n imds-control wait --for=condition=Ready pod/imds-control --timeout=60s
```

Baseline default-deny-მდე:
```bash
# Baseline: backend ხელმისაწვდომია default-deny-მდე
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://backend:8080/
echo $?

# Baseline: IMDS ხელმისაწვდომია frontend-იდან
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# imds-control მუშაობს
k -n imds-control exec imds-control -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

ვრთავთ default-deny-ს:
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

ვამოწმებთ default-deny-ის შემდეგ:
```bash
# IMDS დაბლოკილია
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# imds-control კვლავ მუშაობს
k -n imds-control exec imds-control -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

## 3. DNS

ჯერ ვუშვებთ DNS egress-ს:
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

ვამოწმებთ DNS-ს ცალკე BusyBox Pod-იდან:
```bash
k -n cks-101 run dns-probe \
  --image=busybox:1.36.1 \
  -l app=frontend \
  --command -- sleep 3600

k -n cks-101 wait --for=condition=Ready pod/dns-probe --timeout=60s

k -n cks-101 exec dns-probe -- \
  nslookup kubernetes.default.svc.cluster.local
```

DNS-ის დაბრუნების შემდეგ backend ჯერ კიდევ დახურული უნდა დარჩეს:
```bash
k -n cks-101 exec probe -- \
  curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://backend:8080/
echo $?
```

მოსალოდნელია:
```
HTTP:000
curl exit 7 ან 28
```

## 4. აპლიკაციის დაშვებული ნაკადები

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

ვამოწმებთ Service DNS-ის გავლით:

```bash
k -n cks-101 exec probe -- \
  curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://backend:8080/
echo $?
```

## 5. IMDS final verification

```bash
# control: IMDS ხელმისაწვდომია
k -n imds-control exec imds-control -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# deny: IMDS დაბლოკილია cks-101-ში
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

## 6. Legacy AND და IMDS except

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

ვამოწმებთ:
```bash
# IMDS დაბლოკილია legacy-სთვის
k -n cks-101-legacy exec deploy/legacy-client -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# backend ხელმისაწვდომია Service DNS-ით
k -n cks-101-legacy exec deploy/legacy-client -- curl -sS -m 5 http://backend.cks-101:8080/
```

## 7. hostNetwork observation

```bash
k -n cks-101 run hostnetwork-probe --image=curlimages/curl:8.11.1 -l app=frontend \
  --overrides='{"spec":{"hostNetwork":true,"dnsPolicy":"ClusterFirstWithHostNet"}}' \
  --command -- sleep 3600
k -n cks-101 wait --for=condition=Ready pod/hostnetwork-probe --timeout=60s
```

```bash
# hostNetwork probe - შედეგი შეიძლება განსხვავდებოდეს ჩვეულებრივი Pod-ისგან
k -n cks-101 exec hostnetwork-probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

---

## შემოწმება

```bash
check_result
```
