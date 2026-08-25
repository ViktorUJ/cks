[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 23 - საცნობარო გადაწყვეტა

Istio `1.29.1` დაინსტალირებულია (ingress gateway განთავსებულია NodePort `32080`-ზე). აპლიკაცია `ping-pong`
განთავსებულია namespace `app`-ში და ხელმისაწვდომია მისამართზე `http://myapp.local:32080/`.

## მიზანი

გააფართოეთ Envoy-ის data plane **WebAssembly** მოდულით: ingress gateway-ზე ჩატვირთეთ საზოგადოების მიერ შექმნილი
`basic_auth` Wasm გაფართოება, რათა მოთხოვნებს HTTP Basic ავტორიზაცია დასჭირდეს.

> Istio `1.29` იყენებს `WasmPlugin` API-ს (`extensions.istio.io/v1alpha1`). `1.30+` ვერსიაში
> მას `TrafficExtension` API ანაცვლებს.

## ნაბიჯი 1. საწყისი მდგომარეობა (ავტორიზაცია არ არის საჭირო)

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## ნაბიჯი 2. WasmPlugin-ის გამოყენება

```bash
kubectl apply -f - <<'EOF'
apiVersion: extensions.istio.io/v1alpha1
kind: WasmPlugin
metadata:
  name: basic-auth
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  phase: AUTHN
  url: oci://ghcr.io/istio-ecosystem/wasm-extensions/basic_auth:1.12.0
  pluginConfig:
    basic_auth_rules:
      - prefix: "/"
        request_methods:
          - "GET"
        credentials:
          - "ok:test"
          - "YWRtaW4zOmFkbWluMw=="
EOF
```

ingress gateway-ზე გაშვებული Istio agent ჩამოტვირთავს OCI Wasm image-ს, ადგილობრივად შეინახავს cache-ში
და HTTP filter-ის სახით ჩასვამს. დაელოდეთ რამდენიმე წამი.

## ნაბიჯი 3. შემოწმება

```bash
# no credentials -> 401
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/

# valid credentials -> 200  (base64 of admin3:admin3)
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Basic YWRtaW4zOmFkbWluMw==" http://myapp.local:32080/
```

## მუშაობის პრინციპი

- **WebAssembly (Wasm)** საშუალებას გაძლევთ, proxy-ის ხელახლა აგების გარეშე დაამატოთ Envoy-ს მორგებული ლოგიკა
  და შესრულების დროს დინამიკურად ჩატვირთოთ იგი.
- **`url: oci://...`** - მოდული ვრცელდება OCI artifact-ის სახით; Istio agent მას ჩამოტვირთავს და
  cache-ში შეინახავს. ასევე შეგიძლიათ გამოიყენოთ `file://` (image-ში ჩაშენებული) ან `http(s)://`.
- **`phase: AUTHN`** filter-ს ჯაჭვის დასაწყისში ათავსებს (routing/authz-მდე).
- **`selector`** plugin-ის მოქმედების არეალს workload-ების label-ების მიხედვით განსაზღვრავს (აქ ingress gateway). `istio-system`-ში
  gateway selector-ით განთავსებული WasmPlugin მხოლოდ gateway-ზე მოქმედებს.
- **`pluginConfig`** გადაეცემა მოდულს. `basic_auth` მოდული კითხულობს
  `basic_auth_rules`-ს (path prefix, methods და accepted credentials).

## როდის უნდა გამოიყენოთ Wasm

- მორგებული auth, header/enrichment, request validation ან protocol logic, რომელთა გამოხატვაც Istio-ს
  ჩაშენებული CRD-ებით (`AuthorizationPolicy`, `EnvoyFilter`) შეუძლებელია.
- პირველ რიგში უპირატესობა მიანიჭეთ ჩაშენებულ API-ებს; Wasm გამოიყენეთ მაშინ, როცა data
  plane-ში ნამდვილად გჭირდებათ მორგებული კოდი. გაითვალისწინეთ საოპერაციო ხარჯი: მოდულის გავრცელება, ვერსიების მართვა და runtime
  fetch (`failStrategy` განსაზღვრავს ქცევას, თუ ჩამოტვირთვა ვერ მოხერხდება).
