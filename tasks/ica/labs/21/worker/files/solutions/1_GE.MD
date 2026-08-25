[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 21 - საცნობარო გადაწყვეტა

Istio `1.29.1` დაინსტალირებულია. განთავსებულია ორი სახელთა სივრცე:
- `app`, რომელშიც არის `ping-pong` (sidecar ინიექციით);
- `other`, რომელშიც არის `backend` (sidecar ინიექციით).

ნაგულისხმევად, ყველა sidecar იღებს Envoy-ის კონფიგურაციას mesh-ში არსებული **ყველა** სერვისისთვის, ამიტომ
`app` proxy ასევე შეიცავს cluster-ს `backend.other`-ისთვის, მიუხედავად იმისა, რომ მას არასდროს უკავშირდება.

## მიზანი

`Sidecar` რესურსის გამოყენებით შეზღუდეთ `app` სახელთა სივრცის proxy-ები, რათა მათ კონფიგურაცია მიიღონ
მხოლოდ საკუთარი სახელთა სივრცისა და `istio-system`-ისთვის.

## ნაბიჯი 1. დააკვირდით ნაგულისხმევ (შეუზღუდავ) კონფიგურაციას

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config clusters "$POD" -n app | grep backend.other
# a cluster for backend.other.svc.cluster.local is present
```

## ნაბიჯი 2. egress-ის შესაზღუდად გამოიყენეთ Sidecar რესურსი

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: app
spec:
  egress:
    - hosts:
        - "./*"
        - "istio-system/*"
EOF
```

- `./*` - **ლოკალურ** სახელთა სივრცეში (`app`) არსებული ყველა სერვისი;
- `istio-system/*` - control-plane-ის სახელთა სივრცე (საჭიროა telemetry-სთვის და ა.შ.).

`Sidecar` სახელად `default`, რომელსაც `workloadSelector` არ აქვს, სახელთა სივრცეში არსებულ ყველა workload-ზე
ვრცელდება.

## ნაბიჯი 3. შეამოწმეთ, რომ კონფიგურაციის მოცულობა შემცირდა

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')

# 'other' namespace clusters are gone
istioctl proxy-config clusters "$POD" -n app | grep backend.other || echo "pruned ✅"

# own namespace clusters remain
istioctl proxy-config clusters "$POD" -n app | grep ping-pong.app
```

## როგორ მუშაობს და რატომ არის მნიშვნელოვანი

- **`Sidecar`** რესურსი აკონტროლებს იმ კონფიგურაციის ფარგლებს, რომელსაც istiod proxy-ს უგზავნის.
  `egress.hosts` განსაზღვრავს იმ სერვისების ნებადართულ სიას, რომელთა შესახებაც proxy იღებს ინფორმაციას.
- ნაგულისხმევად, mesh არის "full mesh": თითოეულმა proxy-მ ყველა სერვისის შესახებ იცის. დიდ
  cluster-ში (ათასობით სერვისით) ეს ნიშნავს Envoy-ის უზარმაზარ კონფიგურაციებს, თითოეულ pod-ზე მეხსიერების
  მაღალ მოხმარებას და ყოველი ცვლილებისას istiod-ის CPU-ს დიდ დატვირთვას.
- `Sidecar` რესურსებით proxy-ების ფარგლების შეზღუდვა Istio-ს მასშტაბირების სტანდარტული გზაა:
  უფრო მცირე კონფიგურაციები, უფრო სწრაფი გაგზავნა, istiod-ის ნაკლები დატვირთვა და egress-ის უფრო მკაცრი საზღვრები.
- `Sidecar`-ის შიგნით `outboundTrafficPolicy`-ს დამატებით შეუძლია თითოეულ სახელთა სივრცეში დააყენოს
  `REGISTRY_ONLY`, რათა გამოუცხადებელი egress დაიბლოკოს.

> შენიშვნა: ფარგლების შეზღუდვა ეხება *კონფიგურაციის განაწილებას* და არა ავტორიზაციას. გამოძახებების რეალურად ასაკრძალად
> გამოიყენეთ `AuthorizationPolicy` (ლაბორატორია 04) ან `outboundTrafficPolicy: REGISTRY_ONLY`.
