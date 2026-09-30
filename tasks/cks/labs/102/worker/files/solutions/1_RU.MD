[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 102 - краткое решение

Используем `k` вместо `kubectl` (алиас уже доступен на экзамене). Контекст `cluster1-admin@cluster1` уже выбран.

## 1. Namespace и учебные Pod'ы

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

Проверяем ДО policy - оба Pod должны реально достигать backend:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'frontend HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'client HTTP:%{http_code}\n' -m5 http://backend/
```

```
frontend HTTP:200
client HTTP:200
```

Policy: выбирает `backend`, разрешает ingress только от `role=frontend` на TCP/80.

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

Проверяем ПОСЛЕ policy:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'frontend HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'client HTTP:%{http_code}\n' -m5 http://backend/
```

```
frontend HTTP:200
client HTTP:000
curl: (28) Connection timed out after 5000 milliseconds
```

`client` -> transport-level deny (`000` и таймаут), не просто "не 200".

## 3. Ограничение L7: только GET /

Проверяем ДО (при ещё действующей L4-only policy) - GET и POST оба должны реально дойти до backend:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'GET HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec frontend -- curl -sS -X POST -o /dev/null -w 'POST HTTP:%{http_code}\n' -m5 http://backend/
```

```
GET HTTP:200
POST HTTP:405
```

Заменяем правило (не добавляем второе широкое L4-правило рядом - иначе L7-фильтр не будет работать):

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

Проверяем ПОСЛЕ:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'GET HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec frontend -- curl -sS -X POST -o /dev/null -w 'POST HTTP:%{http_code}\n' -m5 http://backend/
```

```
GET HTTP:200
POST HTTP:403
```

POST отклонён Envoy proxy Cilium на L7 (`403`), а не transport deny.

## 4. DNS-aware egress через toFQDNs

`allowed.cks102.test`/`blocked.cks102.test` - lab-owned fixture, резолвится в
`198.18.0.10`/`198.18.0.20` (синтетические IP вне Kubernetes address space, отдельный
network namespace на control-plane узле, а НЕ ClusterIP: `toFQDNs` в Cilium не применяет
allow-правило к IP внутри кластера), поднятый и вписанный в CoreDNS ещё во время bootstrap:
в отличие от `example.com`, эти имена всегда доступны и не зависят от Internet. Проверяем ДО
policy - DNS и оба контрольных endpoint должны быть реально доступны (`-k` - самоподписанный
сертификат fixture):

```bash
k -n cks-102 exec frontend -- getent hosts allowed.cks102.test
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

Три egress-правила в одном объекте: (1) DNS к `kube-dns` через `rules.dns` - без этого Cilium не построит FQDN-to-IP mapping; (2) внутренний `backend` на TCP/80 - без него default-deny egress заблокирует уже разрешённый поток из заданий 2-3; (3) `toFQDNs` только на `allowed.cks102.test:443`.

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

Проверяем ПОСЛЕ (подождите пару секунд, FQDN-mapping не мгновенный) и убеждаемся, что backend из заданий 2-3 не регрессировал:

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

`allowed.cks102.test` HTTPS остаётся `200`; `allowed.cks102.test:80` и `blocked.cks102.test:443` зависают/таймаутят (`000`); backend GET/POST - как в заданиях 2-3, регрессии нет.

## 5. Наблюдение через Hubble

Relay уже включён worker.sh. Открываем port-forward и наблюдение, генерируем GET и POST:

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

Должны увидеть ровно два flow: `GET /` с verdict `FORWARDED` и `POST /` с verdict `DROPPED`. Если их нет - `hubble observe` был запущен не во время запросов; повторите.

## 6. Составная L7 policy: public/private path scopes

Второй, независимый backend с двумя path-scope. nginx-конфиг заменяем полностью
(`default.conf`), чтобы `location` возвращал `200` на конкретный prefix и `404` на всё
остальное - без него нет способа отличить "разрешено" от "запрещено" по HTTP-коду.

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

Baseline ДО policy - оба path с обоих namespace должны реально отдавать `200`:

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

Policy: два ingress-правила на одном порту. **Важная ловушка Cilium**: `fromEndpoints:
[{}]` (пустой selector) в namespaced `CiliumNetworkPolicy` НЕ означает "любая identity во
всём кластере" - Cilium неявно добавляет ограничение по namespace САМОЙ policy к любому
`fromEndpoints`-селектору без явного namespace-label, включая пустой `{}`. То есть `{}`
здесь на практике матчит только endpoints в namespace `production`, а не `finance`/`cks-102`
- живая проверка это подтверждает: с буквальным `{}` внешний client получает transport
timeout на ОБА path (правило вообще не применяется к его namespace), а `finance` получает
`403` на `/public/*` (matches только правило 2, которое разрешает лишь `/private/*`).
Чтобы реально матчить любую identity независимо от namespace, нужен `matchExpressions` с
`operator: Exists` по reserved-label `k8s:io.kubernetes.pod.namespace` (сам факт наличия
этого label истинен для абсолютно любого Pod, независимо от значения) - это, а не пустой
`{}`, даёт кросс-namespace acceptance для правила 1:

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

С этим селектором правило 1 действительно матчит АБСОЛЮТНО любую identity (включая
`finance`), поэтому итоговый allow-set для `finance` - объединение `/public/*` (правило 1)
и `/private/*` (правило 2, матчит только `finance`). Для любого другого namespace
действует только правило 1.

Проверяем ПОСЛЕ policy:

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

`finance-client` -> оба path `200`. `cks-102/client` (любой другой namespace) -> `/public/*`
всё ещё `200`, а `/private/*` - `403` (Envoy L7 deny, не transport-level `000`: правило 1
уже разрешило сам TCP-коннект для всех identity).

---

## Проверка

```bash
check_result
```
