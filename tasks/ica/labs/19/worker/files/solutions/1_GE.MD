[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 19 - საცნობარო გადაწყვეტა

კლასტერი გაშვებულია, მაგრამ Istio **არ არის** დაინსტალირებული. `istioctl 1.29.1` და `openssl`
ხელმისაწვდომია worker PC-ზე.

## მიზანი

იმის ნაცვლად, რომ istiod-მა საკუთარი თვითხელმოწერილი CA გამოიყენოს, ჩართეთ თქვენი **საკუთარი**
სერტიფიკაციის ცენტრი:
1. შექმენით root CA და intermediate CA;
2. ჩატვირთეთ ისინი istio-system-ში `cacerts` secret-ის სახით;
3. დააინსტალირეთ Istio - istiod ყველა workload certificate-ის ხელმოსაწერად intermediate CA-ს იყენებს;
4. დაადასტურეთ, რომ workload certificate-ების ჯაჭვი თქვენს custom root-მდე მიდის.

## ნაბიჯი 1. შექმენით root CA და intermediate CA

```bash
mkdir -p ~/ca && cd ~/ca

# Root CA
openssl genrsa -out root-key.pem 4096
openssl req -x509 -new -nodes -key root-key.pem -sha256 -days 3650 \
  -subj "/O=CKS-Lab/CN=CKS-Lab Root CA" -out root-cert.pem

# Intermediate CA, signed by the root
openssl genrsa -out ca-key.pem 4096
openssl req -new -key ca-key.pem -subj "/O=CKS-Lab/CN=CKS-Lab Intermediate CA" -out ca.csr

cat > ext.cnf <<'EOF'
basicConstraints=critical,CA:TRUE,pathlen:0
keyUsage=critical,digitalSignature,keyCertSign,cRLSign
subjectAltName=DNS:istiod.istio-system.svc
EOF

openssl x509 -req -in ca.csr -CA root-cert.pem -CAkey root-key.pem -CAcreateserial \
  -days 1825 -sha256 -extfile ext.cnf -out ca-cert.pem

# Istio expects the chain = intermediate + root
cat ca-cert.pem root-cert.pem > cert-chain.pem
```

## ნაბიჯი 2. შექმენით `cacerts` secret

```bash
kubectl create namespace istio-system
kubectl create secret generic cacerts -n istio-system \
  --from-file=ca-cert.pem \
  --from-file=ca-key.pem \
  --from-file=root-cert.pem \
  --from-file=cert-chain.pem
```

## ნაბიჯი 3. დააინსტალირეთ Istio

```bash
istioctl install --set profile=default -y
```

გაშვებისას istiod აღმოაჩენს `cacerts` secret-ს და თვითხელმოწერილი CA-ს შექმნის ნაცვლად
workload certificate-ების გასაცემად intermediate CA-ს იყენებს.

## ნაბიჯი 4. განათავსეთ აპლიკაცია

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/19/k8s-1/scripts/1.yaml
kubectl rollout status deploy/ping-pong -n app
```

## ნაბიჯი 5. შეამოწმეთ ნდობის ჯაჭვი

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')

# The root of trust the sidecar validates against - should be our custom root
istioctl proxy-config secret "$POD" -n app -o json \
  | jq -r '.dynamicActiveSecrets[] | select(.name=="ROOTCA") | .secret.validationContext.trustedCa.inlineBytes' \
  | base64 -d | openssl x509 -noout -subject -issuer
# subject/issuer -> O=CKS-Lab, CN=CKS-Lab Root CA

# The workload certificate itself, signed by our intermediate
istioctl proxy-config secret "$POD" -n app -o json \
  | jq -r '.dynamicActiveSecrets[] | select(.name=="default") | .secret.tlsCertificate.certificateChain.inlineBytes' \
  | base64 -d | openssl x509 -noout -issuer
# issuer -> O=CKS-Lab, CN=CKS-Lab Intermediate CA
```

## როგორ მუშაობს

- Istiod არის mesh CA: ის ხელს აწერს SPIFFE identity certificate-ებს (`SVID`), რომლებსაც ყველა
  sidecar mTLS-ისთვის იყენებს. ნაგულისხმევად, პირველი გაშვებისას ის CA-ს თვითონ აწერს ხელს.
- **`cacerts`** secret (`ca-cert.pem`, `ca-key.pem`, `root-cert.pem`,
  `cert-chain.pem`) საშუალებას გაძლევთ, საკუთარი intermediate CA მიაწოდოთ. ამის შემდეგ istiod
  workload certificate-ებს *თქვენი* PKI-დან გასცემს, ამიტომ მთელი mesh-ის ჯაჭვი თქვენ მიერ მართულ root-მდე მიდის -
  ეს აუცილებელია enterprise PKI-სთან ან გაზიარებულ multi-cluster trust root-თან ინტეგრაციისთვის.
- istiod კვლავ ავტომატურად **აახლებს** workload certificate-ებს (ხანმოკლე SVID-ებს); თქვენ
  მხოლოდ signing CA-ს აწვდით.

## საწარმოო განვითარება: დინამიკური გაცემა cert-manager + istio-csr-ის გამოყენებით

სტატიკური `cacerts` secret-ის ჩართვა ნიშნავს, რომ intermediate key კლასტერში ინახება და
მას ხელით აახლებთ. საწარმოო გარემოში გუნდები ხშირად იყენებენ **cert-manager + istio-csr**-ს:
istiod ხელმოწერას გადასცემს `istio-csr`-ს, რომელიც certificate-ებს cert-manager-ის
`Issuer`-ისგან ითხოვს (რომლის უკანაც Vault, ACME CA ან corporate PKI დგას). ამგვარად signing key
istiod-ის გარეთ რჩება და CA-ს ავტომატური განახლება ხდება შესაძლებელი.
