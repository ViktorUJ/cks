[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labor 26 - Referenzlösung

Die Plattform ist bereits für die dynamische Ausstellung von Zertifikaten eingerichtet:
- **cert-manager** ist installiert;
- eine selbstsignierte Root-CA sowie ein CA-`Issuer` namens `istio-ca` existieren in `istio-system`;
- **istio-csr** (`cert-manager-istio-csr`) läuft in `cert-manager` und stellt die Istio-CA-
  gRPC-API bereit, die vom `istio-ca`-Issuer unterstützt wird;
- **Istio** ist mit **deaktivierter** integrierter CA installiert (`ENABLE_CA_SERVER=false`) und
  `global.caAddress` zeigt auf istio-csr, sodass istiod sämtliche Signierungen an cert-manager delegiert.

`istioctl` ist auf dem Worker-PC verfügbar.

## Ziel

Stellen Sie einen Workload bereit und bestätigen Sie, dass sein Identitätszertifikat (`SVID`) von
**cert-manager** über istio-csr ausgestellt wird - nicht von der selbstsignierten CA von istiod.

## Schritt 1. App bereitstellen

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/26/k8s-1/scripts/1.yaml
kubectl rollout status deploy/ping-pong -n app
```

## Schritt 2. Beobachten, wie cert-manager das Zertifikat ausstellt

```bash
# Every sidecar cert request becomes a CertificateRequest in istio-system
kubectl get certificaterequests.cert-manager.io -n istio-system

# istio-csr logs show the CSRs it forwards to cert-manager
kubectl logs -n cert-manager deploy/cert-manager-istio-csr --tail=20
```

## Schritt 3. Prüfen, ob das Workload-Zertifikat von cert-manager stammt

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config secret "$POD" -n app -o json \
  | jq -r '.dynamicActiveSecrets[] | select(.name=="default") | .secret.tlsCertificate.certificateChain.inlineBytes' \
  | base64 -d | openssl x509 -noout -issuer -ext subjectAltName
# issuer=O = cluster.local, O = cert-manager, CN = istio-ca
# X509v3 Subject Alternative Name: URI:spiffe://cluster.local/ns/app/sa/default
```

Der Aussteller enthält `cert-manager` / `istio-ca` - das Workload-SVID wurde von Ihrer
cert-manager-CA signiert und die SPIFFE-Identität ist intakt.

## Funktionsweise

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

- istiod signiert keine Zertifikate mehr (`ENABLE_CA_SERVER=false`); es verweist Agents auf
  `caAddress: cert-manager-istio-csr.cert-manager.svc:443`.
- **istio-csr** implementiert die Istio-CA-gRPC-API. Für jede Workload-CSR erstellt es eine
  cert-manager-`CertificateRequest`, die cert-manager mit dem konfigurierten `Issuer` signiert.
- Der Signaturschlüssel liegt im `Issuer` von cert-manager (hier ein selbstsigniertes CA-Secret, aber es
  könnte sich um **Vault**, eine **ACME**-CA oder eine Unternehmens-PKI handeln) - nicht in istiod.

## Warum dies besser ist als ein statisches `cacerts` (Labor 19)

| | Labor 19 (`cacerts` Secret) | Dieses Labor (cert-manager + istio-csr) |
|---|---|---|
| Speicherort des Signaturschlüssels | Zwischenzertifikatsschlüssel liegt in istiod | bleibt im `Issuer` von cert-manager (Vault/PKI) |
| CA-Rotation | manuell (Secret neu erstellen + Neustart) | durch cert-manager automatisiert |
| Backends | nur statisches PEM | Vault, ACME, Unternehmens-PKI usw. |
| Nachvollziehbarkeit | keine | jedes Zertifikat ist ein `CertificateRequest`-Objekt |

Beide sorgen dafür, dass die Mesh-Zertifikatskette zu einer von Ihnen kontrollierten CA führt; istio-csr ist die produktionsreife,
automatisierbare Weiterentwicklung.
