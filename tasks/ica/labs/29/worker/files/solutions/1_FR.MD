[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 29 - Solution de référence

Istio `1.29.1` est installé (HTTPS de la passerelle d'entrée sur le NodePort `32443`). Une PKI est
précréée :
- certificat serveur de passerelle pour `myapp.local` + une AC cliente → secret `myapp-credential`
  (`istio-system`) ;
- bundle de certificats client → secret `client-certs` (`app`) ;
- certificat TLS pour `passthrough.local` → secret `backend-tls` (`backend`).

Charges de travail : `ping-pong` (espace de noms `app`, injecté) et un `secure-backend` uniquement TLS
(espace de noms `backend`, termine lui-même TLS, répond `secure-ok`).

## Objectif

Configurez la passerelle d'entrée avec deux modes TLS sur le port 443, sélectionnés par SNI :
- **MUTUAL** pour `myapp.local` - terminez TLS et exigez un certificat client (mTLS à
  la périphérie) ;
- **PASSTHROUGH** pour `passthrough.local` - transférez le flux chiffré au backend,
  qui termine TLS.

## Étape 1. Gateway avec serveurs MUTUAL + PASSTHROUGH

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: edge-gateway
  namespace: app
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        name: https-mutual
        protocol: HTTPS
      tls:
        mode: MUTUAL
        credentialName: myapp-credential
      hosts:
        - "myapp.local"
    - port:
        number: 443
        name: https-passthrough
        protocol: HTTPS
      tls:
        mode: PASSTHROUGH
      hosts:
        - "passthrough.local"
EOF
```

## Étape 2. Routez l'hôte MUTUAL (HTTP après la terminaison)

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: myapp
  namespace: app
spec:
  hosts:
    - "myapp.local"
  gateways:
    - edge-gateway
  http:
    - route:
        - destination:
            host: ping-pong
            port:
              number: 8080
EOF
```

## Étape 3. Routez l'hôte PASSTHROUGH (TLS, par SNI)

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: passthrough
  namespace: app
spec:
  hosts:
    - "passthrough.local"
  gateways:
    - edge-gateway
  tls:
    - match:
        - sniHosts:
            - "passthrough.local"
      route:
        - destination:
            host: secure-backend.backend.svc.cluster.local
            port:
              number: 443
EOF
```

## Étape 4. Vérifiez

```bash
# MUTUAL - without a client cert the handshake is rejected
curl -sk -o /dev/null -w "%{http_code}\n" https://myapp.local:32443/        # not 200

# MUTUAL - with the client cert it succeeds
kubectl get secret client-certs -n app -o jsonpath='{.data.client\.crt}' | base64 -d > /tmp/c.crt
kubectl get secret client-certs -n app -o jsonpath='{.data.client\.key}' | base64 -d > /tmp/c.key
curl -sk --cert /tmp/c.crt --key /tmp/c.key https://myapp.local:32443/      # 200

# PASSTHROUGH - TLS terminates at the backend
curl -sk https://passthrough.local:32443/                                   # secure-ok
```

## Modes TLS en un coup d'œil

| Mode | Qui termine TLS | Certificat client | Utilisation typique |
|---|---|---|---|
| `SIMPLE` (Lab 13) | passerelle | non | entrée HTTPS standard |
| `MUTUAL` | passerelle | **requis** (vérifié par rapport à `ca.crt`) | mTLS à la périphérie, API B2B/partenaires |
| `PASSTHROUGH` | le backend | n/a à la passerelle | chiffrement de bout en bout, la passerelle ne peut/ne doit pas voir le texte en clair |
| `ISTIO_MUTUAL` | passerelle (certificats Istio) | géré par Istio | trafic de passerelle interne au maillage |

## Fonctionnement

- Un seul `Gateway` peut héberger **plusieurs serveurs sur le même port** ; Istio choisit le
  serveur selon le **SNI** TLS (`myapp.local` vs `passthrough.local`).
- **MUTUAL** : la passerelle présente son certificat serveur et demande un certificat client, en le validant
  par rapport au `ca.crt` dans `myapp-credential`. Après la terminaison, le routage est L7
  normal (route `http`).
- **PASSTHROUGH** : la passerelle ne déchiffre pas ; elle route par SNI à L4 à l'aide d'une
  correspondance `VirtualService.tls` + `sniHosts` et transfère le TLS brut au backend, qui
  possède le certificat et termine TLS.
