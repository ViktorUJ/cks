[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 19 - Solución de referencia

El clúster está en funcionamiento, pero Istio **no** está instalado. `istioctl 1.29.1` y `openssl` están
disponibles en el PC de trabajo.

## Objetivo

En lugar de permitir que istiod use su CA autofirmada, incorpora tu **propia** autoridad
certificadora:
1. genera una CA raíz y una CA intermedia;
2. cárgalas en istio-system como el secreto `cacerts`;
3. instala Istio: istiod usa la CA intermedia para firmar todos los certificados de las cargas de trabajo;
4. confirma que los certificados de las cargas de trabajo se encadenan a tu raíz personalizada.

## Paso 1. Genera una CA raíz y una CA intermedia

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

## Paso 2. Crea el secreto `cacerts`

```bash
kubectl create namespace istio-system
kubectl create secret generic cacerts -n istio-system \
  --from-file=ca-cert.pem \
  --from-file=ca-key.pem \
  --from-file=root-cert.pem \
  --from-file=cert-chain.pem
```

## Paso 3. Instala Istio

```bash
istioctl install --set profile=default -y
```

istiod detecta el secreto `cacerts` durante el inicio y utiliza la CA intermedia para emitir
certificados de cargas de trabajo en lugar de generar una CA autofirmada.

## Paso 4. Despliega la aplicación

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/19/k8s-1/scripts/1.yaml
kubectl rollout status deploy/ping-pong -n app
```

## Paso 5. Verifica la cadena de confianza

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

## Cómo funciona

- Istiod es la CA de la malla: firma los certificados de identidad SPIFFE (`SVID`) que cada
  sidecar utiliza para mTLS. De forma predeterminada, se autofirma una CA en el primer inicio.
- El secreto **`cacerts`** (`ca-cert.pem`, `ca-key.pem`, `root-cert.pem`,
  `cert-chain.pem`) te permite proporcionar tu propia CA intermedia. istiod emite entonces
  certificados de cargas de trabajo desde *tu* PKI, de modo que toda la malla se encadena a una raíz que controlas:
  esencial para integrarse con una PKI empresarial o una raíz de confianza compartida entre varios clústeres.
- istiod sigue **rotando** automáticamente los certificados de las cargas de trabajo (SVID de corta duración); solo
  proporcionas la CA de firma.

## Evolución para producción: emisión dinámica con cert-manager + istio-csr

Incorporar un secreto `cacerts` estático implica que la clave intermedia reside en el clúster y
la rotas manualmente. En producción, los equipos suelen usar **cert-manager + istio-csr**:
istiod delega la firma en `istio-csr`, que solicita certificados a un `Issuer` de cert-manager
(respaldado por Vault, una CA ACME o una PKI corporativa). Esto mantiene la clave de firma
fuera de istiod y habilita la rotación automatizada de la CA.
