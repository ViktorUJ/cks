[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 102 - 簡要解答

我們使用 `k` 取代 `kubectl`(別名在考試中已經可用)。`cluster1-admin@cluster1` context 已經選好。

## 1. Namespace 與學習用的 Pod

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

在套用 policy「之前」檢查 - 兩個 Pod 都必須確實能到達 backend:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'frontend HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'client HTTP:%{http_code}\n' -m5 http://backend/
```

```
frontend HTTP:200
client HTTP:200
```

Policy:選取 `backend`,只允許來自 `role=frontend`、對 TCP/80 的 ingress。

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

在 policy「之後」檢查:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'frontend HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'client HTTP:%{http_code}\n' -m5 http://backend/
```

```
frontend HTTP:200
client HTTP:000
curl: (28) Connection timed out after 5000 milliseconds
```

`client` -> transport-level deny(`000` 與逾時),而不只是「不是 200」。

## 3. L7 限制:只允許 GET /

在「之前」檢查(此時僅 L4 的 policy 仍然有效)- GET 與 POST 都必須確實能到達 backend:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'GET HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec frontend -- curl -sS -X POST -o /dev/null -w 'POST HTTP:%{http_code}\n' -m5 http://backend/
```

```
GET HTTP:200
POST HTTP:405
```

取代規則(不要在旁邊再加一條寬鬆的 L4 規則 - 否則 L7 過濾不會生效):

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

在「之後」檢查:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'GET HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec frontend -- curl -sS -X POST -o /dev/null -w 'POST HTTP:%{http_code}\n' -m5 http://backend/
```

```
GET HTTP:200
POST HTTP:403
```

POST 是被 Cilium 的 Envoy proxy 在 L7 拒絕的(`403`),而不是 transport deny。

## 4. 透過 toFQDNs 的 DNS-aware egress

`allowed.cks102.test`/`blocked.cks102.test` 是由實驗自行提供的 fixture,會解析為
`198.18.0.10`/`198.18.0.20`(位於 Kubernetes address space 之外的合成 IP,是 control-plane 節點上獨立的
network namespace,而「不是」ClusterIP:Cilium 的 `toFQDNs` 不會對叢集內部的 IP
套用 allow 規則),在 bootstrap 期間就已經啟動並寫入 CoreDNS:
和 `example.com` 不同,這些名稱始終可用,而且不依賴 Internet。在 policy「之前」檢查 -
DNS 與兩個測試 endpoint 都必須確實可存取(`-k` - fixture 使用自簽憑證):

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

同一個物件中的三條 egress 規則:(1) 透過 `rules.dns` 對 `kube-dns` 的 DNS - 沒有它 Cilium 無法建立 FQDN-to-IP mapping;(2) 內部的 `backend`,TCP/80 - 沒有它,default-deny egress 會封鎖任務 2-3 中已被允許的流量;(3) `toFQDNs` 只限 `allowed.cks102.test:443`。

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

在「之後」檢查(請等待幾秒鐘,FQDN-mapping 不是瞬間完成的),並確認任務 2-3 中的 backend 沒有退化:

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

`allowed.cks102.test` 的 HTTPS 仍然是 `200`;`allowed.cks102.test:80` 與 `blocked.cks102.test:443` 會卡住/逾時(`000`);backend 的 GET/POST - 與任務 2-3 相同,沒有退化。

## 5. 透過 Hubble 觀察

Relay 已經由 worker.sh 啟用。開啟 port-forward 與觀察,並產生 GET 與 POST:

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

應該恰好看到兩個 flow:`GET /` 的 verdict 為 `FORWARDED`,`POST /` 的 verdict 為 `DROPPED`。如果沒有看到 - 表示 `hubble observe` 不是在發出請求期間啟動的;請重做一次。

## 6. 複合 L7 policy:public/private path scopes

第二個、獨立的 backend,具有兩個 path-scope。nginx 設定整個取代
(`default.conf`),讓 `location` 對特定 prefix 回傳 `200`,而對其他所有 path 回傳 `404` -
沒有它,就無法從 HTTP 狀態碼區分「被允許」與「被禁止」。

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

在 policy「之前」的 Baseline - 兩個 namespace 的兩個 path 都必須確實回傳 `200`:

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

Policy:同一個埠上的兩條 ingress 規則。**Cilium 的重要陷阱**:在 namespaced `CiliumNetworkPolicy` 中,
`fromEndpoints: [{}]`(空的 selector)「並不」代表「整個叢集中的任何 identity」-
Cilium 會對任何沒有明確 namespace-label 的 `fromEndpoints` selector(包括空的 `{}`),
隱含地加上 policy「自己」所在 namespace 的限制。也就是說,`{}`
在這裡實際上只比對 namespace `production` 中的 endpoints,而不比對 `finance`/`cks-102`
- 實際測試證實了這一點:使用字面上的 `{}` 時,外部 client 在「兩個」path 上都會得到 transport
timeout(規則根本不會套用到它的 namespace),而 `finance` 在 `/public/*` 上會得到
`403`(只符合規則 2,而規則 2 只允許 `/private/*`)。
要真正比對任何 namespace 的任何 identity,需要對 reserved-label `k8s:io.kubernetes.pod.namespace`
使用帶有 `operator: Exists` 的 `matchExpressions`(這個 label 的存在,對絕對任何 Pod 都成立,與其值無關)-
是這個,而不是空的 `{}`,為規則 1 帶來跨 namespace 的 acceptance:

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

有了這個 selector,規則 1 確實會比對「絕對任何」identity(包括
`finance`),因此 `finance` 最終的 allow-set 是 `/public/*`(規則 1)
與 `/private/*`(規則 2,只比對 `finance`)的聯集。對於任何其他 namespace,
只有規則 1 生效。

在 policy「之後」檢查:

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

`finance-client` -> 兩個 path 都是 `200`。`cks-102/client`(任何其他 namespace)-> `/public/*`
仍然是 `200`,而 `/private/*` 是 `403`(Envoy L7 deny,不是 transport-level 的 `000`:規則 1
已經對所有 identity 允許了 TCP 連線本身)。

---

## 檢查

```bash
check_result
```
