[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 101 - solución breve

Usamos `k` en lugar de `kubectl` (el alias ya está disponible en el examen).

Antes de empezar (si hace falta) eliminamos los namespace antiguos:
```bash
k delete ns cks-101 cks-101-legacy imds-control --ignore-not-found
```

## 1. Aplicación

Obtenemos el digest actual de la imagen:
```bash
k run digest --image=viktoruj/ping_pong:latest
k wait --for=condition=Ready pod/digest --timeout=60s
digest=$(k get pod digest -o yaml | grep imageID | cut -d'@' -f2)
k delete pod digest
```

Creamos el namespace, los Deployments y el Service:
```bash
k create ns cks-101
k -n cks-101 create deployment frontend --image=viktoruj/ping_pong@$digest --replicas=1 --port=8080
k -n cks-101 create deployment backend --image=viktoruj/ping_pong@$digest --replicas=1 --port=8080
k -n cks-101 expose deployment backend --port=8080
k -n cks-101 wait --for=condition=Available deploy/frontend deploy/backend --timeout=60s
```

Comprobamos que las imágenes coinciden:
```bash
k -n cks-101 get deploy frontend backend -o yaml | grep 'image:'
```

## 2. Default-deny y comprobación de baseline

Creamos un probe para las pruebas:
```bash
k -n cks-101 run probe --image=curlimages/curl:8.11.1 -l app=frontend --command -- sleep 3600
k -n cks-101 wait --for=condition=Ready pod/probe --timeout=60s
```

Creamos un namespace independiente para el control:
```bash
k create ns imds-control
k -n imds-control run imds-control --image=curlimages/curl:8.11.1 --command -- sleep 3600
k -n imds-control wait --for=condition=Ready pod/imds-control --timeout=60s
```

Baseline ANTES de default-deny:
```bash
# Baseline: backend es alcanzable antes de default-deny
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://backend:8080/
echo $?

# Baseline: IMDS es alcanzable desde frontend
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# imds-control funciona
k -n imds-control exec imds-control -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

Aplicamos default-deny:
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

Comprobamos después de default-deny:
```bash
# IMDS está bloqueado
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# imds-control sigue funcionando
k -n imds-control exec imds-control -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

## 3. DNS

Primero permitimos el egress de DNS:
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

Comprobamos DNS desde un BusyBox Pod aparte:
```bash
k -n cks-101 run dns-probe \
  --image=busybox:1.36.1 \
  -l app=frontend \
  --command -- sleep 3600

k -n cks-101 wait --for=condition=Ready pod/dns-probe --timeout=60s

k -n cks-101 exec dns-probe -- \
  nslookup kubernetes.default.svc.cluster.local
```

Tras restablecer DNS, backend todavía debe seguir cerrado:
```bash
k -n cks-101 exec probe -- \
  curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://backend:8080/
echo $?
```

Esperamos:
```
HTTP:000
curl exit 7 o 28
```

## 4. Flujos permitidos de la aplicación

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

Comprobamos a través del Service DNS:

```bash
k -n cks-101 exec probe -- \
  curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://backend:8080/
echo $?
```

## 5. Comprobación final de IMDS

```bash
# control: IMDS es alcanzable
k -n imds-control exec imds-control -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# deny: IMDS está bloqueado en cks-101
k -n cks-101 exec probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

## 6. Legacy AND e IMDS except

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

Comprobamos:
```bash
# IMDS está bloqueado para legacy
k -n cks-101-legacy exec deploy/legacy-client -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?

# backend es alcanzable a través del Service DNS
k -n cks-101-legacy exec deploy/legacy-client -- curl -sS -m 5 http://backend.cks-101:8080/
```

## 7. Observación de hostNetwork

```bash
k -n cks-101 run hostnetwork-probe --image=curlimages/curl:8.11.1 -l app=frontend \
  --overrides='{"spec":{"hostNetwork":true,"dnsPolicy":"ClusterFirstWithHostNet"}}' \
  --command -- sleep 3600
k -n cks-101 wait --for=condition=Ready pod/hostnetwork-probe --timeout=60s
```

```bash
# hostNetwork probe - el resultado puede diferir del de un Pod normal
k -n cks-101 exec hostnetwork-probe -- curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -m 5 http://169.254.169.254/
echo $?
```

---

## Comprobación

```bash
check_result
```
