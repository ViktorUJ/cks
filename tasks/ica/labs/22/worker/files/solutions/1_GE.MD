[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 22 - საცნობარო გადაწყვეტა

Istio `1.29.1` დაინსტალირებულია. namespace `external`-ში განთავსებულია "გარე", **მხოლოდ HTTPS-ის მხარდამჭერი** backend-ი (sidecar-ის გარეშე): nginx ასრულებს TLS-ის ტერმინაციას `8443` პორტზე, ხოლო Service
`httpsvc` მას ხელმისაწვდომს ხდის ღია ტექსტის `80` პორტზე (`targetPort: 8443`). service mesh-ში ჩართული კლიენტი
`app-client` მუშაობს namespace `app`-ში.

## მიზანი

service mesh-მა გარე სერვისთან კავშირისთვის **TLS-ის ინიციირება** უნდა მოახდინოს: აპლიკაცია
`httpsvc.external:80`-ს ღია HTTP-ით უკავშირდება, ხოლო მისი sidecar კავშირს backend-მდე
მიღწევამდე TLS-ზე გადაიყვანს.

## ნაბიჯი 1. დააკვირდით შეცდომას ინიციირების გარეშე

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://httpsvc.external.svc.cluster.local/
# -> 400 : plaintext hit the TLS-only port
```

## ნაბიჯი 2. TLS-ის ინიციირების კონფიგურაცია DestinationRule-ის მეშვეობით

backend-ი იყენებს თვითხელმოწერილ სერტიფიკატს, ამიტომ upstream-ის შემოწმებას
`insecureSkipVerify: true` პარამეტრით გამოვტოვებთ. საწარმოო გარემოში მის ნაცვლად `caCertificates` უნდა მიუთითოთ იმ CA-ზე,
რომელმაც upstream-ის სერტიფიკატს ხელი მოაწერა.

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: httpsvc-tls-origination
  namespace: app
spec:
  host: httpsvc.external.svc.cluster.local
  trafficPolicy:
    portLevelSettings:
    - port:
        number: 80
      tls:
        mode: SIMPLE
        insecureSkipVerify: true
EOF
```

## ნაბიჯი 3. შემოწმება

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -w "\nHTTP %{http_code}\n" http://httpsvc.external.svc.cluster.local/
# -> secure-ok
#    HTTP 200
```

## მუშაობის პრინციპი

- კლიენტი `httpsvc.external:80`-ს ღია **HTTP**-ით უკავშირდება. არ არის საჭირო აპლიკაციის კოდის შეცვლა ან
  აპლიკაციაში სერტიფიკატების მართვა.
- `DestinationRule`, რომელშიც `tls.mode: SIMPLE` მითითებულია 80-ე პორტისთვის, კლიენტის მხარეს არსებულ Envoy-ს
  upstream endpoint-ებთან (backend-ის `targetPort: 8443`) **TLS-ის ინიციირებას** ავალებს.
- backend-ი იღებს გამართულ TLS კავშირს და აბრუნებს `200`-ს.
- Istio-ში `SIMPLE` ნაგულისხმევად **ამოწმებს** upstream-ის სერტიფიკატს. ჩვენი backend-ი იყენებს
  თვითხელმოწერილ სერტიფიკატს, ამიტომ ვუთითებთ `insecureSkipVerify: true`-ს. საწარმოო გარემოში მის ნაცვლად
  upstream-ის შესამოწმებლად უნდა მიუთითოთ `caCertificates` (და, სურვილისამებრ, `subjectAltNames`), ან კლიენტის სერტიფიკატით
  ავთენტიფიკაციისთვის გამოიყენოთ `MUTUAL`.

## რატომ უნდა მოხდეს TLS-ის ინიციირება service mesh-ში

- აპლიკაციები შეიძლება მარტივი დარჩეს (ღია HTTP), ხოლო გარე/მემკვიდრეობით სერვისებთან ყველა TLS კავშირი
  service mesh-მა ერთგვაროვნად დაამუშაოს.
- **egress gateway**-სთან (ლაბორატორია 05) ერთად გამოყენებისას ინიციირება შეიძლება ცენტრალიზებულად შესრულდეს
  გამოყოფილ კვანძზე, რათა ყველა გამავალი TLS ტრაფიკი კლასტერს ტოვებდეს ერთი აუდიტირებული, პოლიტიკით
  კონტროლირებადი ჰოპის გავლით.
