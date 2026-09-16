# Lab 101 - краткое решение

Используем `k` вместо `kubectl` (алиас уже доступен на экзамене).

Перед началом (если нужно) удаляем старые namespace:
```bash
k delete ns cks-101 cks-101-legacy imds-control --ignore-not-found
```

## 1. Приложение

Получаем актуальный digest образа:
```bash
k run digest --image=viktoruj/ping_pong:latest --restart=Never
k wait --for=condition=Ready pod/digest --timeout=60s
digest=$(k get pod digest -o yaml | grep imageID | cut -d'@' -f2)
k delete pod digest
```

Создаём namespace, Deployments и Service:
```bash
k create ns cks-101
k -n cks-101 create deployment frontend --image=viktoruj/ping_pong@$digest --replicas=1 --port=8080
k -n cks-101 create deployment backend --image=viktoruj/ping_pong@$digest --replicas=1 --port=8080
k -n cks-101 expose deployment backend --port=8080
k -n cks-101 wait --for=condition=Available deploy/frontend deploy/backend --timeout=60s
```

Проверяем что образы совпадают:
```bash
k -n cks-101 get deploy frontend backend -o yaml | grep 'image:'
```

## 2. Default-deny и baseline проверка

Создаём probe для тестов:
```bash
k -n cks-101 run probe --image=curlimages/curl:8.11.1 --restart=Never -l app=frontend --command -- sleep 3600
k -n cks-101 wait --for=condition=Ready pod/probe --timeout=60s
```

Создаём независимый namespace для control:
```bash
k create ns imds-control
k -n imds-control run imds-control --image=curlimages/curl:8.11.1 --restart=Never --command -- sleep 3600
k -n imds-control wait --for=condition=Ready pod/imds-control --timeout=60s
```

Baseline ДО default-deny:
```bash
# Baseline: IMDS достижим из frontend
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# imds-control работает
k -n imds-control exec imds-control -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

Применяем default-deny:
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

Проверяем после default-deny:
```bash
# frontend -> backend заблокирован
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://backend:8080/
echo $?

# IMDS заблокирован
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# imds-control по-прежнему работает
k -n imds-control exec imds-control -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

## 3. DNS (т.к. default-deny egress блокирует DNS - разрешаем сначала)

Создаём DNS probe с busybox:
```bash
k -n cks-101 run dns-probe --image=busybox:1.36.1 -l app=frontend --command -- sleep 3600
k -n cks-101 wait --for=condition=Ready pod/dns-probe --timeout=60s
k -n cks-101 exec dns-probe -- nslookup kubernetes.default.svc.cluster.local
```

Применяем DNS policy:
```bash
k -n cks-101 apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-dns
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes: [Egress]
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

## 4. Разрешённые потоки приложения

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

Проверяем через Service DNS:

```bash
k -n cks-101 exec probe -- \
  curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://backend:8080/
echo $?
```

## 5. IMDS final verification

```bash
# control: IMDS достижим
k -n imds-control exec imds-control -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# deny: IMDS заблокирован в cks-101
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

## 6. Legacy AND и IMDS except

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

Проверяем:
```bash
# IMDS заблокирован для legacy
k -n cks-101-legacy exec deploy/legacy-client -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# backend достижим через Service DNS
k -n cks-101-legacy exec deploy/legacy-client -- curl -sS -m 5 http://backend.cks-101:8080/
```

## 7. hostNetwork observation

```bash
k -n cks-101 run hostnetwork-probe --image=curlimages/curl:8.11.1 --restart=Never -l app=frontend \
  --overrides='{"spec":{"hostNetwork":true,"dnsPolicy":"ClusterFirstWithHostNet"}}' \
  --command -- sleep 3600
k -n cks-101 wait --for=condition=Ready pod/hostnetwork-probe --timeout=60s
```

```bash
# hostNetwork probe - результат может отличаться от обычного Pod
k -n cks-101 exec hostnetwork-probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

---

## Проверка

```bash
check_result
```