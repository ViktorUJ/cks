[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 102 - 簡易解答

`kubectl` の代わりに `k` を使います (このエイリアスは試験でもすでに利用可能です)。コンテキスト `cluster1-admin@cluster1` はすでに選択されています。

## 1. Namespace と学習用の Pod

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

policy の前に確認します - 両方の Pod が実際に backend に到達できる必要があります：

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'frontend HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'client HTTP:%{http_code}\n' -m5 http://backend/
```

```
frontend HTTP:200
client HTTP:200
```

Policy：`backend` を選択し、`role=frontend` からの TCP/80 への ingress のみを許可します。

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

policy の後に確認します：

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'frontend HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'client HTTP:%{http_code}\n' -m5 http://backend/
```

```
frontend HTTP:200
client HTTP:000
curl: (28) Connection timed out after 5000 milliseconds
```

`client` -> transport-level の deny (`000` とタイムアウト) であり、単なる「200 ではない」ではありません。

## 3. L7 の制限：GET / のみ

L7 に変更する前に確認します (L4-only policy がまだ有効な状態で) - GET と POST の両方が実際に backend に届く必要があります：

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'GET HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec frontend -- curl -sS -X POST -o /dev/null -w 'POST HTTP:%{http_code}\n' -m5 http://backend/
```

```
GET HTTP:200
POST HTTP:405
```

ルールを置き換えます (隣に 2 つ目の広い L4 ルールを追加しないでください - そうしないと L7 フィルターが動作しません)：

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

L7 に変更した後に確認します：

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'GET HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec frontend -- curl -sS -X POST -o /dev/null -w 'POST HTTP:%{http_code}\n' -m5 http://backend/
```

```
GET HTTP:200
POST HTTP:403
```

POST は Cilium の Envoy proxy によって L7 で拒否され (`403`)、transport deny ではありません。

## 4. toFQDNs による DNS-aware egress

`allowed.cks102.test`/`blocked.cks102.test` は lab-owned fixture で、
`198.18.0.10`/`198.18.0.20` に解決されます (Kubernetes address space の外にある合成 IP で、control-plane ノード上の別の
network namespace であり、ClusterIP ではありません：Cilium の `toFQDNs` はクラスター内部の IP に対しては
allow ルールを適用しません)。bootstrap の時点ですでに立ち上げられ CoreDNS に登録されています：
`example.com` とは異なり、これらの名前は常に利用可能で Internet に依存しません。policy の前に確認します：
DNS と 3 つの確認用 endpoint (`allowed:443`、`allowed:80`、`blocked:443`) のすべてに実際に到達できる必要があります (`-k` は fixture の
自己署名証明書のためです)：

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

1 つのオブジェクト内に 3 つの egress ルール：(1) `rules.dns` を持つ `kube-dns` への DNS - これがないと Cilium は FQDN-to-IP mapping を構築しません；(2) TCP/80 での内部 `backend` - これがないと default-deny egress が課題 2-3 ですでに許可されている通信をブロックします；(3) `allowed.cks102.test:443` のみの `toFQDNs`。

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

policy の適用後に確認し (数秒待ってください。FQDN-mapping は瞬時には行われません)、課題 2-3 の backend がリグレッションしていないことを確かめます：

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

`allowed.cks102.test` の HTTPS は `200` のままです。`allowed.cks102.test:80` と `blocked.cks102.test:443` はハングアップ/タイムアウトします (`000`)。backend の GET/POST は課題 2-3 と同じで、リグレッションはありません。

## 5. Hubble による観察

Relay は worker.sh によってすでに有効化されています。port-forward と観察を開き、GET と POST を生成します：

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

見えるはずの flow はちょうど 2 つです：verdict `FORWARDED` の `GET /` と、verdict `DROPPED` の `POST /`。見えない場合は、`hubble observe` がリクエストの最中に起動されていなかったということです。やり直してください。

## 6. 複合 L7 policy: public/private の path scopes

2 つの path-scope を持つ、2 つ目の独立した backend です。nginx の設定は完全に置き換えます
(`default.conf`)。`location` が特定の prefix には `200` を、それ以外には `404` を返すようにするためです -
これがないと、HTTP コードで「許可」と「拒否」を区別する方法がありません。

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

policy 適用前の baseline - 両方の namespace から両方の path が、実際に `200` を返す必要があります：

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

Policy：同じポートに 2 つの ingress ルール。**Cilium の重要な落とし穴**：namespaced な `CiliumNetworkPolicy` における `fromEndpoints:
[{}]` (空の selector) は、「クラスター全体の任意の identity」を意味しません -
Cilium は、明示的な namespace-label のない任意の `fromEndpoints` selector (空の `{}` を含む) に、
policy 自身の namespace による制限を暗黙的に追加します。つまり、ここでの `{}` は実際には
namespace `production` の endpoints にしかマッチせず、`finance`/`cks-102` にはマッチしません -
実機での確認がこれを裏付けています：文字どおりの `{}` では、外部 client は両方の path で transport
timeout を受け取り (ルールがそもそもその namespace に適用されない)、`finance` は
`/public/*` で `403` を受け取ります (ルール 2 にしかマッチせず、それは `/private/*` のみを許可します)。
namespace に関係なく本当に任意の identity にマッチさせるには、reserved-label `k8s:io.kubernetes.pod.namespace` に対する
`operator: Exists` を持つ `matchExpressions` が必要です (この label が存在するという事実は、値に関係なく
あらゆる Pod に対して真です) - 空の `{}` ではなくこれが、ルール 1 の cross-namespace な受け入れを実現します：

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

この selector では、ルール 1 は実際に、文字どおりあらゆる identity (`finance` を含む) にマッチするため、
`finance` の最終的な allow-set は、`/public/*` (ルール 1) と
`/private/*` (ルール 2、`finance` のみにマッチ) の和集合になります。それ以外の任意の namespace には
ルール 1 のみが適用されます。

policy の後に確認します：

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

`finance-client` -> 両方の path で `200`。`cks-102/client` (それ以外の任意の namespace) -> `/public/*` は
引き続き `200` で、`/private/*` は `403` (Envoy の L7 deny であり、transport-level の `000` ではありません：ルール 1 が
TCP コネクト自体をすべての identity に対してすでに許可しています)。

---

## 検証

```bash
check_result
```
