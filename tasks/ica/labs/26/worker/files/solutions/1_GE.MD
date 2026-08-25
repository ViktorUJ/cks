[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 26 - საცნობარო გადაწყვეტა

პლატფორმა უკვე გამართულია სერტიფიკატების დინამიკური გაცემისთვის:
- **cert-manager** დაყენებულია;
- თვითხელმოწერილი ძირეული CA და CA `Issuer` სახელად `istio-ca` არსებობს `istio-system`-ში;
- **istio-csr** (`cert-manager-istio-csr`) გაშვებულია `cert-manager`-ში და უზრუნველყოფს Istio CA-ის
  gRPC API-ს, რომელიც იყენებს `istio-ca` Issuer-ს;
- **Istio** დაყენებულია ისე, რომ მისი ჩაშენებული CA **გამორთულია** (`ENABLE_CA_SERVER=false`), ხოლო
  `global.caAddress` მიუთითებს istio-csr-ზე, ამიტომ istiod ყველა ხელმოწერას cert-manager-ს გადასცემს.

`istioctl` ხელმისაწვდომია worker PC-ზე.

## მიზანი

განათავსეთ workload და დაადასტურეთ, რომ მისი იდენტობის სერტიფიკატი (`SVID`) გაცემულია
**cert-manager**-ის მიერ istio-csr-ის გავლით და არა istiod-ის თვითხელმოწერილი CA-ის მიერ.

## ნაბიჯი 1. აპლიკაციის განთავსება

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/26/k8s-1/scripts/1.yaml
kubectl rollout status deploy/ping-pong -n app
```

## ნაბიჯი 2. დააკვირდით, როგორ გასცემს cert-manager სერტიფიკატს

```bash
# Every sidecar cert request becomes a CertificateRequest in istio-system
kubectl get certificaterequests.cert-manager.io -n istio-system

# istio-csr logs show the CSRs it forwards to cert-manager
kubectl logs -n cert-manager deploy/cert-manager-istio-csr --tail=20
```

## ნაბიჯი 3. შეამოწმეთ, რომ workload-ის სერტიფიკატი cert-manager-იდანაა

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config secret "$POD" -n app -o json \
  | jq -r '.dynamicActiveSecrets[] | select(.name=="default") | .secret.tlsCertificate.certificateChain.inlineBytes' \
  | base64 -d | openssl x509 -noout -issuer -ext subjectAltName
# issuer=O = cluster.local, O = cert-manager, CN = istio-ca
# X509v3 Subject Alternative Name: URI:spiffe://cluster.local/ns/app/sa/default
```

გამცემი შეიცავს `cert-manager` / `istio-ca` მნიშვნელობებს, რაც ნიშნავს, რომ workload-ის SVID
ხელმოწერილია თქვენი cert-manager CA-ის მიერ, ხოლო SPIFFE იდენტობა უცვლელია.

## მუშაობის პრინციპი

```
sidecar (istio-agent)
    │  CSR over gRPC
    ▼
istio-csr (cert-manager-istio-csr)      # implements the Istio CA API
    │  creates CertificateRequest
    ▼
cert-manager  ──uses──►  Issuer "istio-ca"  ──►  signs the cert
    │
    ▼
sidecar receives its SVID (rotated automatically)
```

- istiod სერტიფიკატებს აღარ აწერს ხელს (`ENABLE_CA_SERVER=false`); ის აგენტებს მიუთითებს
  `caAddress: cert-manager-istio-csr.cert-manager.svc:443` მისამართზე.
- **istio-csr** ახორციელებს Istio CA gRPC API-ს. თითოეული workload CSR-ისთვის ის ქმნის
  cert-manager-ის `CertificateRequest`-ს, რომელსაც cert-manager ხელს აწერს კონფიგურირებული
  `Issuer`-ით.
- ხელმოწერის გასაღები ინახება cert-manager-ის `Issuer`-ში (აქ ეს არის თვითხელმოწერილი CA-ის secret,
  თუმცა შეიძლება იყოს **Vault**, **ACME** CA ან კორპორაციული PKI) და არა istiod-ში.

## რატომ სჯობს ეს სტატიკურ `cacerts`-ს (ლაბორატორია 19)

| | ლაბორატორია 19 (`cacerts` secret) | ეს ლაბორატორია (cert-manager + istio-csr) |
|---|---|---|
| ხელმოწერის გასაღების მდებარეობა | შუალედური გასაღები ინახება istiod-ში | რჩება cert-manager-ის `Issuer`-ში (Vault/PKI) |
| CA-ის როტაცია | ხელით (secret-ის ხელახლა შექმნა + restart) | ავტომატიზებულია cert-manager-ის მიერ |
| backend-ები | მხოლოდ სტატიკური PEM | Vault, ACME, კორპორაციული PKI და სხვ. |
| აუდიტის შესაძლებლობა | არ არის | თითოეული სერტიფიკატი `CertificateRequest` ობიექტია |

ორივე შემთხვევაში mesh უკავშირდება თქვენს მიერ კონტროლირებულ CA-ს; istio-csr არის საწარმოო დონის,
ავტომატიზებადი განვითარება.
