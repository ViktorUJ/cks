[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 29 - საცნობარო გადაწყვეტა

Istio `1.29.1` დაინსტალირებულია (ingress gateway-ის HTTPS NodePort-ზე `32443`). PKI
წინასწარ არის შექმნილი:
- gateway სერვერის სერტიფიკატი `myapp.local`-ისთვის + კლიენტის CA → secret `myapp-credential`
  (`istio-system`);
- კლიენტის სერტიფიკატების ნაკრები → secret `client-certs` (`app`);
- TLS სერტიფიკატი `passthrough.local`-ისთვის → secret `backend-tls` (`backend`).

სამუშაო დატვირთვები: `ping-pong` (namespace `app`, ინექციით) და მხოლოდ TLS-ის მქონე `secure-backend`
(namespace `backend`, თავად ასრულებს TLS-ს, პასუხობს `secure-ok`).

## მიზანი

დააკონფიგურირეთ ingress gateway ორი TLS რეჟიმით 443 პორტზე, რომლებიც SNI-ის მიხედვით შეირჩევა:
- **MUTUAL** `myapp.local`-ისთვის - დაასრულოს TLS და მოითხოვოს კლიენტის სერტიფიკატი (mTLS
  საზღვარზე);
- **PASSTHROUGH** `passthrough.local`-ისთვის - დაშიფრული ნაკადი გადაამისამართოს backend-ზე,
  რომელიც ასრულებს TLS-ს.

## ნაბიჯი 1. Gateway MUTUAL + PASSTHROUGH სერვერებით

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: edge-gateway
  namespace: app
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        name: https-mutual
        protocol: HTTPS
      tls:
        mode: MUTUAL
        credentialName: myapp-credential
      hosts:
        - "myapp.local"
    - port:
        number: 443
        name: https-passthrough
        protocol: HTTPS
      tls:
        mode: PASSTHROUGH
      hosts:
        - "passthrough.local"
EOF
```

## ნაბიჯი 2. MUTUAL host-ის მარშრუტიზაცია (HTTP დასრულების შემდეგ)

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: myapp
  namespace: app
spec:
  hosts:
    - "myapp.local"
  gateways:
    - edge-gateway
  http:
    - route:
        - destination:
            host: ping-pong
            port:
              number: 8080
EOF
```

## ნაბიჯი 3. PASSTHROUGH host-ის მარშრუტიზაცია (TLS, SNI-ის მიხედვით)

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: passthrough
  namespace: app
spec:
  hosts:
    - "passthrough.local"
  gateways:
    - edge-gateway
  tls:
    - match:
        - sniHosts:
            - "passthrough.local"
      route:
        - destination:
            host: secure-backend.backend.svc.cluster.local
            port:
              number: 443
EOF
```

## ნაბიჯი 4. შემოწმება

```bash
# MUTUAL - without a client cert the handshake is rejected
curl -sk -o /dev/null -w "%{http_code}\n" https://myapp.local:32443/        # not 200

# MUTUAL - with the client cert it succeeds
kubectl get secret client-certs -n app -o jsonpath='{.data.client\.crt}' | base64 -d > /tmp/c.crt
kubectl get secret client-certs -n app -o jsonpath='{.data.client\.key}' | base64 -d > /tmp/c.key
curl -sk --cert /tmp/c.crt --key /tmp/c.key https://myapp.local:32443/      # 200

# PASSTHROUGH - TLS terminates at the backend
curl -sk https://passthrough.local:32443/                                   # secure-ok
```

## TLS რეჟიმების მოკლე მიმოხილვა

| რეჟიმი | ვინ ასრულებს TLS-ს | კლიენტის სერტიფიკატი | ტიპური გამოყენება |
|---|---|---|---|
| `SIMPLE` (ლაბორატორია 13) | gateway | არა | სტანდარტული HTTPS ingress |
| `MUTUAL` | gateway | **სავალდებულოა** (`ca.crt`-ის მიმართ მოწმდება) | mTLS საზღვარზე, B2B/პარტნიორთა API-ები |
| `PASSTHROUGH` | backend | არ გამოიყენება gateway-ზე | გამჭოლი დაშიფვრა, gateway-ს არ შეუძლია/არ უნდა ხედავდეს ღია ტექსტს |
| `ISTIO_MUTUAL` | gateway (Istio-ს სერტიფიკატები) | იმართება Istio-ს მიერ | gateway-ის შიდა ტრაფიკი mesh-ში |

## როგორ მუშაობს

- ერთ `Gateway`-ს შეუძლია **ერთსა და იმავე პორტზე რამდენიმე სერვერი** ჰქონდეს; Istio სერვერს
  TLS-ის **SNI**-ის მიხედვით ირჩევს (`myapp.local` და `passthrough.local`).
- **MUTUAL**: gateway წარადგენს თავის სერვერის სერტიფიკატს და მოითხოვს კლიენტის სერტიფიკატს,
  რომელსაც `myapp-credential`-ში არსებული `ca.crt`-ის მიმართ ამოწმებს. დასრულების შემდეგ მარშრუტიზაცია
  ჩვეულებრივი L7-ია (`http` route).
- **PASSTHROUGH**: gateway არ გაშიფრავს; ის SNI-ის მიხედვით L4 დონეზე მარშრუტიზაციას ახორციელებს
  `VirtualService.tls` + `sniHosts` შესაბამისობის გამოყენებით და დაუმუშავებელ TLS-ს backend-ზე აგზავნის, რომელიც
  ფლობს სერტიფიკატს და ასრულებს TLS-ს.
