[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 102 - მოკლე ამოხსნა

`kubectl`-ის ნაცვლად ვიყენებთ `k`-ს (alias უკვე ხელმისაწვდომია გამოცდაზე). კონტექსტი `cluster1-admin@cluster1` უკვე არჩეულია.

## 1. Namespace და სასწავლო Pod-ები

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

ვამოწმებთ policy-მდე - ორივე Pod რეალურად უნდა აღწევდეს backend-ს:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'frontend HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'client HTTP:%{http_code}\n' -m5 http://backend/
```

```
frontend HTTP:200
client HTTP:200
```

Policy: ირჩევს `backend`-ს, უშვებს ingress-ს მხოლოდ `role=frontend`-იდან TCP/80-ზე.

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

ვამოწმებთ policy-ის შემდეგ:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'frontend HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec client -- curl -sS -o /dev/null -w 'client HTTP:%{http_code}\n' -m5 http://backend/
```

```
frontend HTTP:200
client HTTP:000
curl: (28) Connection timed out after 5000 milliseconds
```

`client` -> transport-level deny (`000` და timeout), და არა უბრალოდ "არა 200".

## 3. L7-შეზღუდვა: მხოლოდ GET /

ვამოწმებთ მანამდე (ჯერ კიდევ მოქმედი L4-only policy-ით) - GET-იც და POST-იც რეალურად უნდა აღწევდეს backend-ს:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'GET HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec frontend -- curl -sS -X POST -o /dev/null -w 'POST HTTP:%{http_code}\n' -m5 http://backend/
```

```
GET HTTP:200
POST HTTP:405
```

ვცვლით წესს (გვერდით მეორე ფართო L4-წესს არ ვამატებთ - წინააღმდეგ შემთხვევაში L7-ფილტრი არ იმუშავებს):

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

ვამოწმებთ შემდეგ:

```bash
k -n cks-102 exec frontend -- curl -sS -o /dev/null -w 'GET HTTP:%{http_code}\n' -m5 http://backend/
k -n cks-102 exec frontend -- curl -sS -X POST -o /dev/null -w 'POST HTTP:%{http_code}\n' -m5 http://backend/
```

```
GET HTTP:200
POST HTTP:403
```

POST უარყო Cilium-ის Envoy proxy-მ L7-ზე (`403`), და არა transport deny-მ.

## 4. DNS-aware egress toFQDNs-ით

`allowed.cks102.test`/`blocked.cks102.test` - lab-owned fixture, რომელიც resolve-დება
`198.18.0.10`/`198.18.0.20`-ზე (სინთეტიკური IP-ები Kubernetes address space-ის გარეთ, ცალკე
network namespace control-plane node-ზე, და არა ClusterIP: `toFQDNs` Cilium-ში არ ავრცელებს
allow-წესს კლასტერის შიგნით არსებულ IP-ზე), გაშვებული და CoreDNS-ში ჩაწერილი ჯერ კიდევ bootstrap-ის დროს:
`example.com`-ისგან განსხვავებით, ეს სახელები ყოველთვის ხელმისაწვდომია და Internet-ზე არ არის დამოკიდებული. ვამოწმებთ policy-მდე -
DNS და სამივე საკონტროლო endpoint (`allowed:443`, `allowed:80`, `blocked:443`) რეალურად ხელმისაწვდომი უნდა იყოს (`-k` - fixture-ის თვითხელმოწერილი
სერტიფიკატი):

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

სამი egress-წესი ერთ ობიექტში: (1) DNS `kube-dns`-ისკენ `rules.dns`-ით - ამის გარეშე Cilium ვერ ააგებს FQDN-to-IP mapping-ს; (2) შიდა `backend` TCP/80-ზე - მის გარეშე default-deny egress დაბლოკავს უკვე დაშვებულ ნაკადს დავალებები 2-3-დან; (3) `toFQDNs` მხოლოდ `allowed.cks102.test:443`-ზე.

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

ვამოწმებთ შემდეგ (დაელოდეთ რამდენიმე წამს, FQDN-mapping მყისიერი არ არის) და ვრწმუნდებით, რომ backend დავალებები 2-3-დან არ რეგრესირებულა:

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

`allowed.cks102.test` HTTPS რჩება `200`; `allowed.cks102.test:80` და `blocked.cks102.test:443` ჩერდება/timeout-დება (`000`); backend GET/POST - როგორც დავალებებში 2-3, რეგრესია არ არის.

## 5. დაკვირვება Hubble-ით

Relay უკვე ჩართულია worker.sh-ით. ვხსნით port-forward-სა და დაკვირვებას, ვაგენერირებთ GET-სა და POST-ს:

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

უნდა ვნახოთ ზუსტად ორი flow: `GET /` verdict-ით `FORWARDED` და `POST /` verdict-ით `DROPPED`. თუ ისინი არ ჩანან - `hubble observe` მოთხოვნების დროს არ იყო გაშვებული; გაიმეორეთ.

## 6. შედგენილი L7 policy: public/private path scopes

მეორე, დამოუკიდებელი backend ორი path-scope-ით. nginx-კონფიგს მთლიანად ვცვლით
(`default.conf`), რათა `location` აბრუნებდეს `200`-ს კონკრეტულ prefix-ზე და `404`-ს დანარჩენ ყველაფერზე -
მის გარეშე არ არსებობს გზა, რომ HTTP-კოდით განვასხვავოთ "დაშვებული" "აკრძალულისგან".

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

Baseline policy-მდე - ორივე path ორივე namespace-იდან რეალურად უნდა აბრუნებდეს `200`-ს:

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

Policy: ორი ingress-წესი ერთ პორტზე. **Cilium-ის მნიშვნელოვანი ხაფანგი**: `fromEndpoints:
[{}]` (ცარიელი selector) namespaced `CiliumNetworkPolicy`-ში **არ** ნიშნავს "ნებისმიერ identity-ს მთელ
კლასტერში" - Cilium იმპლიციტურად ამატებს თავად policy-ის namespace-ით შეზღუდვას ნებისმიერ
`fromEndpoints`-selector-ს აშკარა namespace-label-ის გარეშე, ცარიელი `{}`-ის ჩათვლით. ანუ `{}`
აქ პრაქტიკაში ემთხვევა მხოლოდ endpoints-ს namespace `production`-ში, და არა `finance`/`cks-102`-ს -
ცოცხალი შემოწმება ამას ადასტურებს: პირდაპირი `{}`-ით გარე client იღებს transport
timeout-ს ორივე path-ზე (წესი მის namespace-ზე საერთოდ არ ვრცელდება), ხოლო `finance` იღებს
`403`-ს `/public/*`-ზე (ემთხვევა მხოლოდ წესს 2, რომელიც უშვებს მხოლოდ `/private/*`-ს).
იმისთვის, რომ რეალურად დავემთხვეთ ნებისმიერ identity-ს namespace-ის მიუხედავად, საჭიროა `matchExpressions`
`operator: Exists`-ით reserved-label `k8s:io.kubernetes.pod.namespace`-ზე (ამ label-ის
არსებობის ფაქტი ჭეშმარიტია აბსოლუტურად ნებისმიერი Pod-ისთვის, მნიშვნელობის მიუხედავად) - სწორედ ეს, და არა ცარიელი
`{}`, იძლევა cross-namespace acceptance-ს წესი 1-ისთვის:

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

ამ selector-ით წესი 1 ნამდვილად ემთხვევა აბსოლუტურად ნებისმიერ identity-ს (`finance`-ის
ჩათვლით), ამიტომ `finance`-ის საბოლოო allow-set არის `/public/*`-ის (წესი 1)
და `/private/*`-ის (წესი 2, ემთხვევა მხოლოდ `finance`-ს) გაერთიანება. ნებისმიერი სხვა namespace-ისთვის
მოქმედებს მხოლოდ წესი 1.

ვამოწმებთ policy-ის შემდეგ:

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

`finance-client` -> ორივე path `200`. `cks-102/client` (ნებისმიერი სხვა namespace) -> `/public/*`
კვლავ `200`, ხოლო `/private/*` - `403` (Envoy L7 deny, და არა transport-level `000`: წესმა 1
უკვე დაუშვა თავად TCP-კავშირი ყველა identity-სთვის).

---

## შემოწმება

```bash
check_result
```
