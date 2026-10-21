[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 102 - solución breve

Usamos `k` en lugar de `kubectl` (el alias ya está disponible en el examen). El contexto `cluster1-admin@cluster1` ya está seleccionado.

## 1. Namespace y Pods de laboratorio

```bash
k create ns cks-102
k -n cks-102 run backend --image=nginx:1.27-alpine -l app=backend --port=80
k -n cks-102 expose pod backend --port=80
k -n cks-102 run frontend --image=curlimages/curl:8.10.1 -l role=frontend --command -- sleep 3600
k -n cks-102 run client --image=curlimages/curl:8.10.1 -l role=untrusted --command -- sleep 3600
k -n cks-102 wait --for=condition=Ready pod/backend pod/frontend pod/client --timeout=120s
sleep 5
```

## 2. CiliumNetworkPolicy L3/L4

Comprobamos ANTES de la policy: ambos Pods deben alcanzar realmente backend:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'frontend HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'client HTTP:%{http_code}\n' -m5 http://backend/
```

```
frontend HTTP:200
client HTTP:200
```

Policy: selecciona `backend` y permite ingress solo desde `role=frontend` en TCP/80.

```bash
k apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-policy
  namespace: cks-102
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            role: frontend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
EOF
```

Comprobamos DESPUÉS de la policy:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'frontend HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'client HTTP:%{http_code}\n' -m5 http://backend/
```

```
frontend HTTP:200
client HTTP:000
curl: (28) Connection timed out after 5000 milliseconds
```

`client` -> transport-level deny (`000` y timeout), no simplemente "algo distinto de 200".

## 3. Restricción L7: solo GET /

Comprobamos ANTES (con la L4-only policy todavía en vigor): GET y POST deben llegar realmente a backend:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'GET HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec frontend -- curl -sS -X POST -o /dev/null -w 'POST HTTP:%{http_code}\n' -m5 http://backend/
```

```
GET HTTP:200
POST HTTP:405
```

Reemplazamos la regla (no añadimos una segunda regla L4 amplia al lado; de lo contrario el filtro L7 no funcionará):

```bash
k apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-policy
  namespace: cks-102
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            role: frontend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: GET
                path: "/"
EOF
```

Comprobamos DESPUÉS:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'GET HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec frontend -- curl -sS -X POST -o /dev/null -w 'POST HTTP:%{http_code}\n' -m5 http://backend/
```

```
GET HTTP:200
POST HTTP:403
```

POST es rechazado por el Envoy proxy de Cilium en L7 (`403`), no por un transport deny.

## 4. DNS-aware egress mediante toFQDNs

`allowed.cks102.test`/`blocked.cks102.test` son un lab-owned fixture que se resuelve a
`198.18.0.10`/`198.18.0.20` (IP sintéticas fuera del Kubernetes address space, un
network namespace aparte en el nodo control-plane, y NO un ClusterIP: `toFQDNs` en Cilium no aplica
la regla allow a una IP dentro del clúster), levantado e inscrito en CoreDNS ya durante el bootstrap:
a diferencia de `example.com`, estos nombres siempre están disponibles y no dependen de Internet. Comprobamos ANTES de la
policy: DNS y ambos endpoint de control deben ser realmente accesibles (`-k` - certificado
autofirmado del fixture):

```bash
k -n cks-102 exec frontend -- nslookup allowed.cks102.test
k -n cks-102 exec frontend -- curl -sSk -o /dev/null -w 'allowed:443 HTTP:%{http_code}\n' -m10 https://allowed.cks102.test/
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'allowed:80 HTTP:%{http_code}\n' -m5 http://allowed.cks102.test:80/
k -n cks-102 exec frontend -- curl -sSk -o /dev/null -w 'blocked:443 HTTP:%{http_code}\n' -m10 https://blocked.cks102.test/
```

```
allowed.cks102.test has address ...
allowed:443 HTTP:200
allowed:80 HTTP:200
blocked:443 HTTP:200
```

Tres reglas egress en un mismo objeto: (1) DNS a `kube-dns` mediante `rules.dns`; sin esto Cilium no construirá el FQDN-to-IP mapping; (2) el `backend` interno en TCP/80; sin él, el default-deny egress bloqueará el flujo ya permitido de las tareas 2-3; (3) `toFQDNs` solo a `allowed.cks102.test:443`.

```bash
k apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: frontend-fqdn
  namespace: cks-102
spec:
  endpointSelector:
    matchLabels:
      role: frontend
  egress:
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kube-system
            k8s:k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: ANY
          rules:
            dns:
              - matchPattern: "*"
    - toEndpoints:
        - matchLabels:
            app: backend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
    - toFQDNs:
        - matchName: allowed.cks102.test
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
EOF
```

Comprobamos DESPUÉS (espera un par de segundos, el FQDN-mapping no es instantáneo) y nos aseguramos de que backend de las tareas 2-3 no ha sufrido una regresión:

```bash
k -n cks-102 exec frontend -- curl -sSk -o /dev/null -w 'allowed:443 HTTP:%{http_code}\n' -m10 https://allowed.cks102.test/
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'allowed:80 HTTP:%{http_code}\n' -m5 http://allowed.cks102.test:80/
k -n cks-102 exec frontend -- curl -sSk -o /dev/null -w 'blocked:443 HTTP:%{http_code}\n' -m10 https://blocked.cks102.test/
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'GET HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec frontend -- curl -sS -X POST -o /dev/null -w 'POST HTTP:%{http_code}\n' -m5 http://backend/
```

```
allowed:443 HTTP:200
allowed:80 HTTP:000
blocked:443 HTTP:000
GET HTTP:200
POST HTTP:403
```

`allowed.cks102.test` HTTPS sigue dando `200`; `allowed.cks102.test:80` y `blocked.cks102.test:443` se quedan colgados/dan timeout (`000`); backend GET/POST - como en las tareas 2-3, no hay regresión.

## 5. Observación mediante Hubble

Relay ya lo habilitó worker.sh. Abrimos el port-forward y la observación, generamos GET y POST:

```bash
cilium hubble port-forward &
sleep 3
hubble observe --from-pod cks-102/frontend --to-pod cks-102/backend --protocol http --follow &
sleep 2

k -n cks-102 exec frontend -- curl -sS http://backend/ -o /dev/null
k -n cks-102 exec frontend -- curl -sS -X POST http://backend/ -o /dev/null
sleep 3
```

```
cks-102/frontend:xxxxx -> cks-102/backend:80 http-request FORWARDED (HTTP/1.1 GET http://backend/)
cks-102/frontend:xxxxx -> cks-102/backend:80 http-request DROPPED (HTTP/1.1 POST http://backend/)
```

Deben verse exactamente dos flow: `GET /` con verdict `FORWARDED` y `POST /` con verdict `DROPPED`. Si no aparecen, `hubble observe` no se lanzó durante las peticiones; repite.

## 6. L7 policy compuesta: public/private path scopes

Un segundo backend independiente con dos path-scope. Reemplazamos por completo la configuración de nginx
(`default.conf`), para que `location` devuelva `200` en un prefix concreto y `404` en todo lo
demás; sin esto no hay forma de distinguir "permitido" de "denegado" por el código HTTP.

```bash
k create ns production
k create ns finance

k create configmap portal-nginx-conf -n production --from-literal=default.conf='
server {
  listen 80;
  location /public/ { return 200 "public ok\n"; }
  location /private/ { return 200 "private ok\n"; }
  location / { return 404; }
}
'

k apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: portal
  namespace: production
  labels:
    app: portal
spec:
  containers:
  - name: nginx
    image: nginx:1.27-alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: conf
      mountPath: /etc/nginx/conf.d/default.conf
      subPath: default.conf
  volumes:
  - name: conf
    configMap:
      name: portal-nginx-conf
EOF
k expose pod portal -n production --port=80
k -n finance run finance-client --image=curlimages/curl:8.10.1 --command -- sleep 3600
k -n production wait --for=condition=Ready pod/portal --timeout=60s
k -n finance wait --for=condition=Ready pod/finance-client --timeout=60s
```

Baseline ANTES de la policy: ambos path desde ambos namespace deben devolver realmente `200`:

```bash
k -n finance exec finance-client -- curl -sS -o /dev/null -w 'public:%{http_code}\n' -m5 http://portal.production/public/
k -n finance exec finance-client -- curl -sS -o /dev/null -w 'private:%{http_code}\n' -m5 http://portal.production/private/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'public:%{http_code}\n' -m5 http://portal.production/public/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'private:%{http_code}\n' -m5 http://portal.production/private/
```

```
public:200
private:200
public:200
private:200
```

Policy: dos reglas ingress en el mismo puerto. **Una trampa importante de Cilium**: `fromEndpoints:
[{}]` (selector vacío) en una `CiliumNetworkPolicy` namespaced NO significa "cualquier identity en
todo el clúster": Cilium añade implícitamente la restricción por el namespace de LA PROPIA policy a cualquier
selector de `fromEndpoints` sin un namespace-label explícito, incluido un `{}` vacío. Es decir, `{}`
aquí, en la práctica, hace match solo con endpoints del namespace `production`, y no con `finance`/`cks-102`
- la comprobación en vivo lo confirma: con un `{}` literal el client externo recibe un transport
timeout en AMBOS path (la regla no se aplica en absoluto a su namespace), y `finance` recibe
`403` en `/public/*` (hace match solo con la regla 2, que permite únicamente `/private/*`).
Para hacer match realmente con cualquier identity con independencia del namespace, hace falta `matchExpressions` con
`operator: Exists` sobre el reserved-label `k8s:io.kubernetes.pod.namespace` (la mera presencia de
este label es cierta para absolutamente cualquier Pod, con independencia del valor); esto, y no un
`{}` vacío, da la aceptación cross-namespace para la regla 1:

```bash
k apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: portal-policy
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: portal
  ingress:
    - fromEndpoints:
        - matchExpressions:
            - key: k8s:io.kubernetes.pod.namespace
              operator: Exists
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: GET
                path: "/public/.*"
    - fromEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: finance
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: GET
                path: "/private/.*"
EOF
sleep 3
```

Con este selector, la regla 1 efectivamente hace match con ABSOLUTAMENTE cualquier identity (incluida
`finance`), por lo que el allow-set final para `finance` es la unión de `/public/*` (regla 1)
y `/private/*` (regla 2, hace match solo con `finance`). Para cualquier otro namespace
actúa solo la regla 1.

Comprobamos DESPUÉS de la policy:

```bash
k -n finance exec finance-client -- curl -sS -o /dev/null -w 'public:%{http_code}\n' -m5 http://portal.production/public/
k -n finance exec finance-client -- curl -sS -o /dev/null -w 'private:%{http_code}\n' -m5 http://portal.production/private/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'public:%{http_code}\n' -m5 http://portal.production/public/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'private:%{http_code}\n' -m5 http://portal.production/private/
```

```
public:200
private:200
public:200
private:403
```

`finance-client` -> ambos path `200`. `cks-102/client` (cualquier otro namespace) -> `/public/*`
sigue dando `200`, y `/private/*` - `403` (Envoy L7 deny, no un transport-level `000`: la regla 1
ya permitió la propia conexión TCP para todas las identity).

---

## Comprobación

```bash
check_result
```
