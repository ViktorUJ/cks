[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 102 - Kurzlösung

Wir verwenden `k` statt `kubectl` (der Alias ist in der Prüfung bereits verfügbar). Der Kontext `cluster1-admin@cluster1` ist bereits ausgewählt.

## 1. Namespace und Lern-Pods

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

Prüfung VOR der policy - beide Pods müssen das backend tatsächlich erreichen:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'frontend HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'client HTTP:%{http_code}\n' -m5 http://backend/
```

```
frontend HTTP:200
client HTTP:200
```

Policy: wählt `backend` aus, erlaubt ingress nur von `role=frontend` auf TCP/80.

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

Prüfung NACH der policy:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'frontend HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'client HTTP:%{http_code}\n' -m5 http://backend/
```

```
frontend HTTP:200
client HTTP:000
curl: (28) Connection timed out after 5000 milliseconds
```

`client` -> transport-level deny (`000` und Timeout), nicht einfach „nicht 200“.

## 3. L7-Einschränkung: nur GET /

Prüfung VORHER (bei noch geltender reiner L4-policy) - GET und POST müssen beide tatsächlich das backend erreichen:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'GET HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec frontend -- curl -sS -X POST -o /dev/null -w 'POST HTTP:%{http_code}\n' -m5 http://backend/
```

```
GET HTTP:200
POST HTTP:405
```

Wir ersetzen die Regel (wir fügen nicht daneben eine zweite breite L4-Regel hinzu - sonst funktioniert der L7-Filter nicht):

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

Prüfung NACHHER:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'GET HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec frontend -- curl -sS -X POST -o /dev/null -w 'POST HTTP:%{http_code}\n' -m5 http://backend/
```

```
GET HTTP:200
POST HTTP:403
```

POST wird vom Envoy proxy von Cilium auf L7 abgelehnt (`403`), nicht durch ein transport deny.

## 4. DNS-aware egress über toFQDNs

`allowed.cks102.test`/`blocked.cks102.test` sind lab-owned fixtures und werden zu
`198.18.0.10`/`198.18.0.20` aufgelöst (synthetische IPs außerhalb des Kubernetes address space, ein separater
network namespace auf dem control-plane Node, und KEINE ClusterIP: `toFQDNs` in Cilium wendet die
allow-Regel nicht auf IPs innerhalb des Clusters an); die fixtures wurden bereits während des bootstrap hochgefahren und in CoreDNS eingetragen:
Anders als `example.com` sind diese Namen immer verfügbar und hängen nicht vom Internet ab. Prüfung VOR der
policy - DNS und alle drei Kontroll-Endpoints (`allowed:443`, `allowed:80`, `blocked:443`) müssen tatsächlich erreichbar sein (`-k` - selbstsigniertes
Zertifikat der fixture):

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

Drei egress-Regeln in einem Objekt: (1) DNS zu `kube-dns` über `rules.dns` - ohne dies baut Cilium kein FQDN-to-IP mapping auf; (2) das interne `backend` auf TCP/80 - ohne dies blockiert default-deny egress den bereits erlaubten Flow aus den Aufgaben 2-3; (3) `toFQDNs` nur auf `allowed.cks102.test:443`.

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

Prüfung NACHHER (warte ein paar Sekunden, das FQDN-mapping erfolgt nicht augenblicklich); dabei stellen wir sicher, dass das backend aus den Aufgaben 2-3 nicht regressiert ist:

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

`allowed.cks102.test` HTTPS bleibt `200`; `allowed.cks102.test:80` und `blocked.cks102.test:443` hängen/laufen in den Timeout (`000`); backend GET/POST - wie in den Aufgaben 2-3, keine Regression.

## 5. Beobachtung über Hubble

Relay wurde bereits von worker.sh aktiviert. Wir öffnen port-forward und Beobachtung und generieren GET und POST:

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

Du solltest genau zwei flows sehen: `GET /` mit verdict `FORWARDED` und `POST /` mit verdict `DROPPED`. Wenn sie fehlen, wurde `hubble observe` nicht während der Anfragen gestartet; wiederhole es.

## 6. Zusammengesetzte L7 policy: public/private path scopes

Ein zweites, unabhängiges backend mit zwei path-scopes. Die nginx-Konfiguration ersetzen wir vollständig
(`default.conf`), damit `location` für ein konkretes prefix `200` und für alles
andere `404` zurückgibt - ohne dies gibt es keine Möglichkeit, „erlaubt“ von „verboten“ am HTTP-Code zu unterscheiden.

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

Baseline VOR der policy - beide paths aus beiden Namespaces müssen tatsächlich `200` liefern:

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

Policy: zwei ingress-Regeln auf demselben Port. **Wichtige Falle von Cilium**: `fromEndpoints:
[{}]` (leerer selector) in einer namespaced `CiliumNetworkPolicy` bedeutet NICHT „jede identity im
gesamten Cluster“ - Cilium fügt implizit die Namespace-Einschränkung der policy SELBST zu jedem
`fromEndpoints`-selector ohne explizites Namespace-Label hinzu, einschließlich des leeren `{}`. Das heißt, `{}`
matcht hier in der Praxis nur Endpoints im Namespace `production` und nicht `finance`/`cks-102` -
die Live-Prüfung bestätigt das: Mit dem buchstäblichen `{}` erhält der externe client einen transport
timeout auf BEIDEN paths (die Regel wird auf seinen Namespace gar nicht angewendet), und `finance` erhält
`403` auf `/public/*` (matcht nur Regel 2, die lediglich `/private/*` erlaubt).
Um tatsächlich jede identity unabhängig vom Namespace zu matchen, braucht es `matchExpressions` mit
`operator: Exists` auf das reserved-label `k8s:io.kubernetes.pod.namespace` (das Vorhandensein
dieses Labels trifft auf absolut jeden Pod zu, unabhängig vom Wert) - das, und nicht das leere
`{}`, liefert die Cross-Namespace-acceptance für Regel 1:

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

Mit diesem selector matcht Regel 1 tatsächlich ABSOLUT jede identity (einschließlich
`finance`), daher ist das finale allow-set für `finance` die Vereinigung aus `/public/*` (Regel 1)
und `/private/*` (Regel 2, matcht nur `finance`). Für jeden anderen Namespace
gilt nur Regel 1.

Prüfung NACH der policy:

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

`finance-client` -> beide paths `200`. `cks-102/client` (jeder andere Namespace) -> `/public/*`
weiterhin `200`, und `/private/*` - `403` (Envoy L7 deny, nicht transport-level `000`: Regel 1
hat den TCP-Connect für alle identities bereits erlaubt).

---

## Prüfung

```bash
check_result
```
