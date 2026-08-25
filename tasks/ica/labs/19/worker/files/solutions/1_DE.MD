[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 19 - Referenzlösung

Der Cluster läuft, aber Istio ist **nicht** installiert. `istioctl 1.29.1` und `openssl` sind
auf dem Worker-PC verfügbar.

## Ziel

Anstatt istiod seine selbstsignierte CA verwenden zu lassen, bindest du deine **eigene**
Zertifizierungsstelle ein:
1. eine Root-CA und eine Intermediate-CA erzeugen;
2. sie als Secret `cacerts` in istio-system laden;
3. Istio installieren - istiod verwendet die Intermediate-CA, um alle Workload-Zertifikate zu signieren;
4. bestätigen, dass Workload-Zertifikate zu deiner benutzerdefinierten Root-CA verkettet sind.

## Schritt 1. Eine Root-CA und eine Intermediate-CA erzeugen

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

## Schritt 2. Das Secret `cacerts` erstellen

```bash
kubectl create namespace istio-system
kubectl create secret generic cacerts -n istio-system \
  --from-file=ca-cert.pem \
  --from-file=ca-key.pem \
  --from-file=root-cert.pem \
  --from-file=cert-chain.pem
```

## Schritt 3. Istio installieren

```bash
istioctl install --set profile=default -y
```

istiod erkennt beim Start das Secret `cacerts` und verwendet die Intermediate-CA, um
Workload-Zertifikate auszustellen, anstatt eine selbstsignierte CA zu erzeugen.

## Schritt 4. Die Anwendung bereitstellen

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/19/k8s-1/scripts/1.yaml
kubectl rollout status deploy/ping-pong -n app
```

## Schritt 5. Die Vertrauenskette überprüfen

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

## So funktioniert es

- Istiod ist die Mesh-CA: Sie signiert die SPIFFE-Identitätszertifikate (`SVID`), die jeder
  Sidecar für mTLS verwendet. Standardmäßig signiert sie beim ersten Start selbst eine CA.
- Das Secret **`cacerts`** (`ca-cert.pem`, `ca-key.pem`, `root-cert.pem`,
  `cert-chain.pem`) ermöglicht dir, deine eigene Intermediate-CA bereitzustellen. istiod stellt dann
  Workload-Zertifikate aus *deiner* PKI aus, sodass das gesamte Mesh zu einer Root-CA verkettet ist, die du kontrollierst -
  unverzichtbar für die Integration mit einer Unternehmens-PKI oder einer gemeinsamen Multi-Cluster-Vertrauenswurzel.
- istiod **rotiert** Workload-Zertifikate weiterhin automatisch (kurzlebige SVIDs); du
  stellst nur die signierende CA bereit.

## Entwicklung für die Produktion: dynamische Ausstellung mit cert-manager + istio-csr

Das Einbinden eines statischen Secrets `cacerts` bedeutet, dass der Intermediate-Schlüssel im Cluster liegt und
du ihn manuell rotierst. In Produktionsumgebungen verwenden Teams häufig **cert-manager + istio-csr**:
istiod delegiert die Signierung an `istio-csr`, das Zertifikate von einem cert-manager
`Issuer` anfordert (gestützt durch Vault, eine ACME-CA oder eine Unternehmens-PKI). Dadurch bleibt der signierende Schlüssel
aus istiod heraus und eine automatisierte CA-Rotation wird ermöglicht.
