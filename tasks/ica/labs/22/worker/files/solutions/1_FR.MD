[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratoire 22 - Solution de référence

Istio `1.29.1` est installé. Un backend « externe », **HTTPS uniquement**, est déployé dans
l'espace de noms `external` (sans sidecar) : nginx termine TLS sur le port `8443` et le Service
`httpsvc` l'expose sur le port texte brut `80` (`targetPort: 8443`). Un client dans le mesh
`app-client` s'exécute dans l'espace de noms `app`.

## Objectif

Faire en sorte que le mesh **initie TLS** vers le service externe : l'application parle HTTP en clair à
`httpsvc.external:80`, et son sidecar met à niveau la connexion vers TLS avant d'atteindre le
backend.

## Étape 1. Observer l'échec sans origination

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://httpsvc.external.svc.cluster.local/
# -> 400 : plaintext hit the TLS-only port
```

## Étape 2. Configurer l'origination TLS avec une DestinationRule

Le backend utilise un certificat auto-signé, nous ignorons donc la vérification en amont avec
`insecureSkipVerify: true`. En production, vous définiriez plutôt `caCertificates` sur l'AC qui a
signé le serveur en amont.

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

## Étape 3. Vérifier

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -w "\nHTTP %{http_code}\n" http://httpsvc.external.svc.cluster.local/
# -> secure-ok
#    HTTP 200
```

## Fonctionnement

- Le client envoie du **HTTP** en clair à `httpsvc.external:80`. Aucun changement de code dans
  l'application, aucun certificat à gérer dans l'application.
- La `DestinationRule` avec `tls.mode: SIMPLE` sur le port 80 indique à l'Envoy côté client
  d'**initier TLS** vers les points de terminaison en amont (le `targetPort: 8443` du backend).
- Le backend reçoit une connexion TLS correcte et renvoie `200`.
- Dans Istio, `SIMPLE` **vérifie** le certificat du serveur en amont par défaut. Notre backend utilise un
  certificat auto-signé, nous définissons donc `insecureSkipVerify: true`. En production, vous définiriez plutôt
  `caCertificates` (et éventuellement `subjectAltNames`) pour vérifier le serveur en amont, ou utiliseriez
  `MUTUAL` pour l'authentification par certificat client.

## Pourquoi initier TLS dans le mesh

- Les applications peuvent rester simples (HTTP en clair) tandis que tout TLS vers les services
  externes/hérités est géré uniformément par le mesh.
- Combinée à une **passerelle egress** (Lab 05), l'origination peut être centralisée sur un
  nœud dédié afin que tout TLS sortant quitte le cluster via un saut unique, audité et contrôlé
  par des politiques.
