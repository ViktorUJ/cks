[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 24 - ეტალონური გადაწყვეტა

Istio `1.29.1` დაინსტალირებულია **ambient** რეჟიმში (istiod + istio-cni + ztunnel).
namespace `app` ჩართულია ambient-ში (`istio.io/dataplane-mode: ambient`) და მასში გაშვებულია
`ping-pong` და `app-client` - ორივე **sidecar-ის გარეშე**. `istioctl` ხელმისაწვდომია
worker PC-ზე.

## წინაპირობები

- **ztunnel** ambient-ის თითოეულ workload-ს უზრუნველყოფს L4 mTLS-ითა და identity-ით, მაგრამ მას HTTP
  **არ** ესმის. ამიტომ L4 policy-ები (identity/port-ის მიხედვით დაშვება/აკრძალვა) მუშაობს, თუმცა L7 წესები
  (HTTP მეთოდები, paths, headers) არ მუშაობს.
- **L7** policy-ის აღსასრულებლად დაამატეთ **waypoint proxy** - თითო namespace-ზე (ან
  თითო service-ზე) განკუთვნილი Envoy, რომლის გავლითაც ambient traffic მარშრუტდება L7 დამუშავებისთვის.

## მიზანი

დაამატეთ waypoint namespace `app`-ს და L7 `AuthorizationPolicy`, რომელიც მხოლოდ
`GET` request-ებს დაუშვებს `ping-pong`-ზე (ყველა დანარჩენი → `403`).

## ნაბიჯი 1. Waypoint-ის მომზადება

```bash
istioctl waypoint apply -n app --enroll-namespace
kubectl get gtw waypoint -n app
kubectl rollout status deploy/waypoint -n app
```

`--enroll-namespace` namespace-ს ანიჭებს label-ს (`istio.io/use-waypoint: waypoint`), რათა traffic
`app`-ის service-ებისკენ waypoint-ის გავლით დამარშრუტდეს.

## ნაბიჯი 2. L7 AuthorizationPolicy-ის გამოყენება

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-get-only
  namespace: app
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: waypoint
  action: ALLOW
  rules:
    - to:
        - operation:
            methods: ["GET"]
EOF
```

`ALLOW` policy ყველა შეუსაბამო შემთხვევისთვის ნაგულისხმევად აკრძალვას ნიშნავს, ამიტომ მხოლოდ `GET`
გაივლის, ხოლო სხვა მეთოდები მიიღებს `403`-ს.

## ნაბიჯი 3. შემოწმება

```bash
# GET -> allowed
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -X GET http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# DELETE -> denied by the waypoint
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -X DELETE http://ping-pong.app.svc.cluster.local:8080/
# -> 403
```

## როგორ მუშაობს

- **Sidecar-less L4 (ztunnel)** მთელ namespace-ში mTLS-სა და identity-ს ამუშავებს თითო pod-ზე
  proxy-ის გარეშე. ის ეკონომიურია და ambient-ში ყოველთვის ჩართულია.
- **Waypoint (L7)** ემატება მხოლოდ იქ, სადაც HTTP დონის შესაძლებლობები გჭირდებათ: L7 authorization,
  routing, retries, traffic splitting. Envoy-ის რესურსს მხოლოდ ამ service-ებისთვის ხარჯავთ.
- `AuthorizationPolicy` `targetRefs`-ის საშუალებით მიმართავს waypoint `Gateway`-ს, ამიტომ ის
  L7 hop-ზე აღსრულდება. sidecar/ingress-ზე მიმაგრებული იგივე policy ასევე მუშაობს - ambient უბრალოდ
  L7 აღსრულების წერტილს waypoint-ზე გადაიტანს.
- ეს ფენებად დაყოფილი მოდელი (ztunnel L4-ისთვის ყველგან, waypoint L7-ისთვის საჭირო ადგილებში) ambient-ის
  ძირითადი იდეაა: sidecar-ებთან შედარებით ნაკლები საბაზისო დანახარჯი და არჩევითად ჩასართავი L7.

## დაკავშირებული მასალა

ლაბორატორია 09 მოიცავს ambient-ის საფუძვლებს (ztunnel L4). ლაბორატორია 04 მოიცავს იმავე `AuthorizationPolicy`-ს
sidecar მოდელში.
