[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 32 - ეტალონური ამოხსნა

დაინსტალირებულია Istio `1.29.1` (ნაგულისხმევი პროფილი). Namespace `app`
(ჩართულია istio-injection) იყენებს `viktoruj/ping_pong` image-ს, რომელიც gRPC-ს
გამოიყენებს (`PingPong.Echo` აბრუნებს მომსახურე pod-ის hostname-ს):

- **grpc-server** - gRPC Echo/Health server, **3 replica** (gRPC `8079` port-ზე);
- **grpc-client** - იგივე image, რომელიც გამოიყენება gRPC დატვირთვის შესაქმნელად
  (`/app -grpc-client ...`).

`grpc-server` **Service** შექმნილია **არასწორად დასახელებული** port-ით (`tcp`).
ამის გამო Istio `8079` port-ს აღიქვამს როგორც დაუმუშავებელ L4 TCP-ს: ერთი
ხანგრძლივი HTTP/2 gRPC connection ერთ pod-ზე ფიქსირდება, ამიტომ client მხოლოდ
**ერთ** განსხვავებულ server-ს ხედავს და თითოეული request-ის balancing არ ხდება.

## მიზანი

1. Istio-მ ამოიცნოს gRPC port, რათა ყველა backend pod-ს შორის შეასრულოს
   **თითოეული request-ის** (HTTP/2) load balancing.
2. `grpc-server`-ისთვის დაამატეთ `VirtualService` gRPC **retry**-ებითა და
   **timeout**-ით.

## ნაბიჯი 1. Service port-ის სახელის გასწორება

gRPC არის HTTP/2 და არა დაუმუშავებელი TCP. Istio protocol-ს განსაზღვრავს port-ის
სახელის **prefix**-ით (`grpc`, `http2`, ...) ან ცხადად მითითებული `appProtocol`
ველით. port-ს დაარქვით `grpc` (და/ან მიუთითეთ `appProtocol: grpc`):

```bash
kubectl -n app patch svc grpc-server --type=json -p='[
  {"op":"replace","path":"/spec/ports/0/name","value":"grpc"},
  {"op":"add","path":"/spec/ports/0/appProtocol","value":"grpc"}
]'
```

სრული ეკვივალენტური manifest:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: grpc-server
  namespace: app
  labels:
    app: grpc-server
spec:
  selector:
    app: grpc-server
  ports:
    - name: grpc
      appProtocol: grpc
      port: 8079
      targetPort: 8079
EOF
```

როგორც კი Istio HTTP/2 (gRPC) cluster-ს დაინახავს, Envoy საზიარო connection-ში
**თითოეულ request-ს** ყველა endpoint-ს შორის აბალანსებს, დამატებითი
configuration საჭირო არ არის.

## ნაბიჯი 2. VirtualService gRPC retry-ებით + timeout-ით

gRPC დაფუძნებულია HTTP-ზე, ამიტომ მისი configuration ხდება `http` block-ის
მეშვეობით (და არა `tcp`): retry-ები, timeout-ები, header routing და თითოეული
request-ის balancing სრულად მოქმედებს.

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: grpc-server
  namespace: app
spec:
  hosts:
    - grpc-server
  http:
    - route:
        - destination:
            host: grpc-server
            port:
              number: 8079
      timeout: 2s
      retries:
        attempts: 3
        perTryTimeout: 1s
        retryOn: connect-failure,refused-stream,unavailable,cancelled,deadline-exceeded
EOF
```

- `retryOn` იყენებს gRPC-ის შესაბამის პირობებს: `unavailable`, `cancelled`,
  `deadline-exceeded` შეესაბამება gRPC status code-ებს; `refused-stream` და
  `connect-failure` transport-ის პრობლემებს ფარავს.
- `timeout` ზღუდავს მთლიან request-ს; `perTryTimeout` ზღუდავს თითოეულ მცდელობას.

## ნაბიჯი 3. (არასავალდებულო) load-balancing policy-ის დაფიქსირება

როგორც კი port gRPC გახდება, თითოეული request-ის balancing ნაგულისხმევად
ჩართულია. policy-ის ცხადად მისათითებლად:

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: grpc-server
  namespace: app
spec:
  host: grpc-server
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
EOF
```

## ნაბიჯი 4. შემოწმება

client-იდან შექმენით gRPC დატვირთვა და დაადასტურეთ, რომ request-ები backend-ის
**სამივე** pod-ს ხვდება (თითოეული request-ის balancing):

```bash
kubectl exec -n app deploy/grpc-client -c ping-pong -- \
  /app -grpc-client -target grpc-server:8079 -n 180 -c 4
```

მოსალოდნელი ბოლო ნაწილი:

```
--- summary ---
requests: 180  ok: 180  errors: 0
distinct servers: 3
host grpc-server-xxxx-aaaa: 60
host grpc-server-xxxx-bbbb: 60
host grpc-server-xxxx-cccc: 60
```

`distinct servers: 3` ადასტურებს, რომ request-ები თითოეული request-ის დონეზე
ბალანსდება. შესწორებამდე (port-ს ერქვა `tcp`) იგივე command აჩვენებს
`distinct servers: 1`.

## რატომ მუშაობს ეს

- **gRPC არის HTTP/2 და არა TCP.** L4/TCP წარმოდგენით Envoy აბალანსებს
  *connection*-ებს: ერთი gRPC client ინარჩუნებს ერთ ხანგრძლივ connection-ს,
  ამიტომ ყველა call ერთ pod-ზე რჩება. port-ის `grpc`-ად გამოცხადება Envoy-ს
  HTTP/2-ის დამუშავებისა და endpoint-ებს შორის **თითოეული request-ის** (stream)
  balancing-ის საშუალებას აძლევს.
- **port-ის სახელი გადამრთველია.** port-ს უნდა ერქვას `grpc` / `grpc-*` (ან
  `http2`), ან უნდა ჰქონდეს `appProtocol: grpc`. ნეიტრალური სახელი (`tcp`,
  უსახელო) ყველა L7 feature-ს აუქმებს: არ არის თითოეული request-ის LB, retry,
  timeout ან gRPC metric.
- **L7 feature-ები gRPC-ზეც ვრცელდება.** რადგან ის HTTP-ია, gRPC იღებს `http`
  retry-ებს (gRPC-ის შესაბამისი `retryOn`-ით), `timeout`/`perTryTimeout`, header
  routing-ს, fault injection-სა და მდიდარ telemetry-ს, ზუსტად ისე, როგორც
  ჩვეულებრივი HTTP.
