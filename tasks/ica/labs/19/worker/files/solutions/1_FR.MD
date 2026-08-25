[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 19 - Solution de référence

Le cluster est opérationnel, mais Istio n'est **pas** installé. `istioctl 1.29.1` et `openssl` sont
disponibles sur le PC worker.

## Objectif

Au lieu de laisser istiod utiliser son AC auto-signée, configurez votre **propre** autorité de
certification :
1. générez une AC racine et une AC intermédiaire ;
2. chargez-les dans istio-system en tant que secret `cacerts` ;
3. installez Istio - istiod utilise l'intermédiaire pour signer tous les certificats de charge de travail ;
4. confirmez que les certificats de charge de travail sont chaînés à votre racine personnalisée.

## Étape 1. Générez une AC racine et une AC intermédiaire

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

## Étape 2. Créez le secret `cacerts`

```bash
kubectl create namespace istio-system
kubectl create secret generic cacerts -n istio-system \
  --from-file=ca-cert.pem \
  --from-file=ca-key.pem \
  --from-file=root-cert.pem \
  --from-file=cert-chain.pem
```

## Étape 3. Installez Istio

```bash
istioctl install --set profile=default -y
```

istiod détecte le secret `cacerts` au démarrage et utilise l'AC intermédiaire pour émettre
les certificats de charge de travail au lieu de générer une AC auto-signée.

## Étape 4. Déployez l'application

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/19/k8s-1/scripts/1.yaml
kubectl rollout status deploy/ping-pong -n app
```

## Étape 5. Vérifiez la chaîne de confiance

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

## Fonctionnement

- Istiod est l'AC du maillage : il signe les certificats d'identité SPIFFE (`SVID`) que chaque
  sidecar utilise pour mTLS. Par défaut, il auto-signe une AC lors du premier démarrage.
- Le secret **`cacerts`** (`ca-cert.pem`, `ca-key.pem`, `root-cert.pem`,
  `cert-chain.pem`) vous permet de fournir votre propre AC intermédiaire. istiod émet alors
  les certificats de charge de travail depuis *votre* PKI, de sorte que l'ensemble du maillage est chaîné à une racine que vous contrôlez -
  essentiel pour l'intégration à une PKI d'entreprise ou à une racine de confiance multi-cluster partagée.
- istiod **renouvelle** toujours automatiquement les certificats de charge de travail (SVID de courte durée) ; vous
  fournissez uniquement l'AC de signature.

## Évolution en production : émission dynamique avec cert-manager + istio-csr

L'ajout d'un secret `cacerts` statique signifie que la clé intermédiaire réside dans le cluster et
que vous la renouvelez manuellement. En production, les équipes utilisent souvent **cert-manager + istio-csr** :
istiod délègue la signature à `istio-csr`, qui demande des certificats à un `Issuer` cert-manager
(s'appuyant sur Vault, une AC ACME ou une PKI d'entreprise). Cela maintient la clé de signature
hors d'istiod et permet la rotation automatisée des AC.
