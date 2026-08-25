[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratoire 26 - Solution de référence

La plateforme est déjà configurée pour l'émission dynamique de certificats :
- **cert-manager** est installé ;
- une AC racine auto-signée + un `Issuer` d'AC nommé `istio-ca` existent dans `istio-system` ;
- **istio-csr** (`cert-manager-istio-csr`) s'exécute dans `cert-manager` et fournit l'API gRPC
  d'AC Istio, soutenue par l'Issuer `istio-ca` ;
- **Istio** est installé avec son AC intégrée **désactivée** (`ENABLE_CA_SERVER=false`) et
  `global.caAddress` pointant vers istio-csr, de sorte qu'istiod délègue toute signature à cert-manager.

`istioctl` est disponible sur le PC de travail.

## Objectif

Déployez une charge de travail et confirmez que son certificat d'identité (`SVID`) est émis par
**cert-manager** via istio-csr, et non par l'AC auto-signée d'istiod.

## Étape 1. Déployer l'application

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/26/k8s-1/scripts/1.yaml
kubectl rollout status deploy/ping-pong -n app
```

## Étape 2. Observer cert-manager émettre le certificat

```bash
# Every sidecar cert request becomes a CertificateRequest in istio-system
kubectl get certificaterequests.cert-manager.io -n istio-system

# istio-csr logs show the CSRs it forwards to cert-manager
kubectl logs -n cert-manager deploy/cert-manager-istio-csr --tail=20
```

## Étape 3. Vérifier que le certificat de la charge de travail provient de cert-manager

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config secret "$POD" -n app -o json \
  | jq -r '.dynamicActiveSecrets[] | select(.name=="default") | .secret.tlsCertificate.certificateChain.inlineBytes' \
  | base64 -d | openssl x509 -noout -issuer -ext subjectAltName
# issuer=O = cluster.local, O = cert-manager, CN = istio-ca
# X509v3 Subject Alternative Name: URI:spiffe://cluster.local/ns/app/sa/default
```

L'émetteur contient `cert-manager` / `istio-ca` : le SVID de la charge de travail a été signé par votre
AC cert-manager, et l'identité SPIFFE est intacte.

## Fonctionnement

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

- istiod ne signe plus les certificats (`ENABLE_CA_SERVER=false`) ; il oriente les agents vers
  `caAddress: cert-manager-istio-csr.cert-manager.svc:443`.
- **istio-csr** implémente l'API gRPC d'AC Istio. Pour chaque CSR de charge de travail, il crée un
  `CertificateRequest` cert-manager, que cert-manager signe avec l'`Issuer` configuré.
- La clé de signature réside dans l'`Issuer` de cert-manager (ici un secret d'AC auto-signée, mais il
  pourrait s'agir de **Vault**, d'une AC **ACME** ou d'une PKI d'entreprise), et non dans istiod.

## Pourquoi ceci surpasse un `cacerts` statique (Laboratoire 19)

| | Laboratoire 19 (secret `cacerts`) | Ce laboratoire (cert-manager + istio-csr) |
|---|---|---|
| Emplacement de la clé de signature | la clé intermédiaire se trouve dans istiod | reste dans l'`Issuer` cert-manager (Vault/PKI) |
| Rotation de l'AC | manuelle (recréer le secret + redémarrer) | automatisée par cert-manager |
| Backends | PEM statique uniquement | Vault, ACME, PKI d'entreprise, etc. |
| Auditabilité | aucune | chaque certificat est un objet `CertificateRequest` |

Les deux permettent au maillage d'établir une chaîne vers une AC que vous contrôlez ; istio-csr est
l'évolution automatisable adaptée à la production.
