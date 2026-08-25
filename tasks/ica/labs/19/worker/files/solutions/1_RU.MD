[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 19 - Эталонное решение

Кластер работает, но Istio **не** установлен. `istioctl 1.29.1` и `openssl`
доступны на рабочем ПК.

## Цель

Вместо того чтобы позволить istiod использовать его самоподписанный ЦС, подключите
**собственный** центр сертификации:
1. создайте корневой ЦС и промежуточный ЦС;
2. загрузите их в istio-system в качестве секрета `cacerts`;
3. установите Istio - istiod использует промежуточный ЦС для подписи всех сертификатов рабочих нагрузок;
4. подтвердите, что сертификаты рабочих нагрузок образуют цепочку к вашему пользовательскому корневому ЦС.

## Шаг 1. Создайте корневой ЦС и промежуточный ЦС

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

## Шаг 2. Создайте секрет `cacerts`

```bash
kubectl create namespace istio-system
kubectl create secret generic cacerts -n istio-system \
  --from-file=ca-cert.pem \
  --from-file=ca-key.pem \
  --from-file=root-cert.pem \
  --from-file=cert-chain.pem
```

## Шаг 3. Установите Istio

```bash
istioctl install --set profile=default -y
```

При запуске istiod обнаруживает секрет `cacerts` и использует промежуточный ЦС для выдачи
сертификатов рабочих нагрузок вместо создания самоподписанного ЦС.

## Шаг 4. Разверните приложение

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/19/k8s-1/scripts/1.yaml
kubectl rollout status deploy/ping-pong -n app
```

## Шаг 5. Проверьте цепочку доверия

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

## Как это работает

- Istiod является центром сертификации mesh: он подписывает сертификаты идентичности SPIFFE (`SVID`), которые каждый
  sidecar использует для mTLS. По умолчанию при первом запуске он самоподписывает ЦС.
- Секрет **`cacerts`** (`ca-cert.pem`, `ca-key.pem`, `root-cert.pem`,
  `cert-chain.pem`) позволяет предоставить собственный промежуточный ЦС. Затем istiod выдаёт
  сертификаты рабочих нагрузок из *вашей* PKI, поэтому весь mesh образует цепочку к контролируемому вами корневому ЦС -
  это необходимо для интеграции с корпоративной PKI или общим корнем доверия для нескольких кластеров.
- istiod по-прежнему автоматически **ротирует** сертификаты рабочих нагрузок (короткоживущие SVID); вы
  предоставляете только подписывающий ЦС.

## Развитие для production: динамическая выдача с cert-manager + istio-csr

Подключение статического секрета `cacerts` означает, что промежуточный ключ находится в кластере, и
его нужно ротировать вручную. В production команды часто используют **cert-manager + istio-csr**:
istiod делегирует подпись `istio-csr`, который запрашивает сертификаты у cert-manager
`Issuer` (на основе Vault, центра сертификации ACME или корпоративной PKI). Это позволяет хранить подписывающий ключ
вне istiod и включает автоматическую ротацию ЦС.
