[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 26 - Solución de referencia

La plataforma ya está configurada para la emisión dinámica de certificados:
- **cert-manager** está instalado;
- existe una CA raíz autofirmada + un `Issuer` de CA llamado `istio-ca` en `istio-system`;
- **istio-csr** (`cert-manager-istio-csr`) se ejecuta en `cert-manager` y ofrece la API
  gRPC de la CA de Istio, respaldada por el Issuer `istio-ca`;
- **Istio** está instalado con su CA integrada **deshabilitada** (`ENABLE_CA_SERVER=false`) y
  `global.caAddress` apuntando a istio-csr, por lo que istiod delega toda la firma en cert-manager.

`istioctl` está disponible en el PC de trabajo.

## Objetivo

Despliega una carga de trabajo y confirma que su certificado de identidad (`SVID`) es emitido por
**cert-manager** mediante istio-csr, no por la CA autofirmada de istiod.

## Paso 1. Desplegar la aplicación

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/26/k8s-1/scripts/1.yaml
kubectl rollout status deploy/ping-pong -n app
```

## Paso 2. Observar cómo cert-manager emite el certificado

```bash
# Every sidecar cert request becomes a CertificateRequest in istio-system
kubectl get certificaterequests.cert-manager.io -n istio-system

# istio-csr logs show the CSRs it forwards to cert-manager
kubectl logs -n cert-manager deploy/cert-manager-istio-csr --tail=20
```

## Paso 3. Verificar que el certificado de la carga de trabajo proviene de cert-manager

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config secret "$POD" -n app -o json \
  | jq -r '.dynamicActiveSecrets[] | select(.name=="default") | .secret.tlsCertificate.certificateChain.inlineBytes' \
  | base64 -d | openssl x509 -noout -issuer -ext subjectAltName
# issuer=O = cluster.local, O = cert-manager, CN = istio-ca
# X509v3 Subject Alternative Name: URI:spiffe://cluster.local/ns/app/sa/default
```

El emisor contiene `cert-manager` / `istio-ca`: el SVID de la carga de trabajo fue firmado por tu
CA de cert-manager y la identidad SPIFFE permanece intacta.

## Cómo funciona

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

- istiod ya no firma certificados (`ENABLE_CA_SERVER=false`); dirige los agentes a
  `caAddress: cert-manager-istio-csr.cert-manager.svc:443`.
- **istio-csr** implementa la API gRPC de la CA de Istio. Para cada CSR de carga de trabajo crea un
  `CertificateRequest` de cert-manager, que cert-manager firma con el `Issuer` configurado.
- La clave de firma reside en el `Issuer` de cert-manager (aquí un secreto de CA autofirmada, pero
  podría ser **Vault**, una CA **ACME** o una PKI corporativa), no en istiod.

## Por qué esto supera a un `cacerts` estático (Laboratorio 19)

| | Laboratorio 19 (secreto `cacerts`) | Este laboratorio (cert-manager + istio-csr) |
|---|---|---|
| Ubicación de la clave de firma | la clave intermedia está en istiod | permanece en el `Issuer` de cert-manager (Vault/PKI) |
| Rotación de CA | manual (recrear el secreto + reiniciar) | automatizada por cert-manager |
| Backends | solo PEM estático | Vault, ACME, PKI corporativa, etc. |
| Auditabilidad | ninguna | cada certificado es un objeto `CertificateRequest` |

Ambos hacen que la malla encadene a una CA que controlas; istio-csr es la evolución de nivel de producción,
automatizable.
