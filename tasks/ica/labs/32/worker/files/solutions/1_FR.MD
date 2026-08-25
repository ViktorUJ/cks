[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratoire 32 - Solution de référence

Istio `1.29.1` (profil par défaut) est installé. L'espace de noms `app` (avec
istio-injection activé) exécute l'image `viktoruj/ping_pong`, qui utilise gRPC
(`PingPong.Echo` renvoie le nom d'hôte du pod qui répond) :

- **grpc-server** - le serveur gRPC Echo/Health, **3 répliques** (gRPC sur le
  port `8079`) ;
- **grpc-client** - la même image, utilisée pour générer une charge gRPC
  (`/app -grpc-client ...`).

Le Service grpc-server porte volontairement un nom de port incorrect, tcp ;
c'est pourquoi Istio voit le port 8079 comme du L4 TCP, la connexion gRPC en
HTTP/2 (longue durée) reste épinglée sur un seul pod et l'équilibrage par
requête n'a pas lieu.

## Objectif

1. Faire en sorte qu'Istio reconnaisse le port gRPC afin qu'il effectue un
   équilibrage de charge **par requête** (HTTP/2) entre tous les pods backend.
2. Ajouter un `VirtualService` pour `grpc-server` avec des **retries** gRPC et
   un **timeout**.

## Étape 1. Corriger le nommage du port Service

gRPC est HTTP/2, pas du TCP brut. Istio détecte le protocole à partir du
**préfixe du nom** du port (`grpc`, `http2`, ...) ou du champ explicite
`appProtocol`. Renommez le port en `grpc` (et/ou définissez `appProtocol: grpc`) :

```bash
kubectl -n app patch svc grpc-server --type=json -p='[
  {"op":"replace","path":"/spec/ports/0/name","value":"grpc"},
  {"op":"add","path":"/spec/ports/0/appProtocol","value":"grpc"}
]'
```

Manifest complet équivalent :

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: grpc-server
  namespace: app
  labels:
    app: grpc-server
spec:
  selector:
    app: grpc-server
  ports:
    - name: grpc
      appProtocol: grpc
      port: 8079
      targetPort: 8079
EOF
```

Dès qu'Istio voit un cluster HTTP/2 (gRPC), Envoy équilibre **chaque requête**
à l'intérieur de la connexion partagée entre tous les endpoints, sans
configuration supplémentaire.

## Étape 2. VirtualService avec retries gRPC + timeout

gRPC fonctionne sur HTTP, il est donc configuré via le bloc `http` (et non
`tcp`) : les retries, les timeouts, le routage d'en-têtes et l'équilibrage de
charge par requête s'appliquent tous.

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: grpc-server
  namespace: app
spec:
  hosts:
    - grpc-server
  http:
    - route:
        - destination:
            host: grpc-server
            port:
              number: 8079
      timeout: 2s
      retries:
        attempts: 3
        perTryTimeout: 1s
        retryOn: connect-failure,refused-stream,unavailable,cancelled,deadline-exceeded
EOF
```

- `retryOn` utilise des conditions compatibles avec gRPC : `unavailable`,
  `cancelled`, `deadline-exceeded` correspondent à des codes de statut gRPC ;
  `refused-stream` et `connect-failure` couvrent les problèmes de transport.
- `timeout` limite l'ensemble de la requête ; `perTryTimeout` limite chaque
  tentative.

## Étape 3. (facultatif) Fixer la politique d'équilibrage de charge

L'équilibrage par requête est activé par défaut dès que le port est gRPC. Pour
rendre la politique explicite :

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: grpc-server
  namespace: app
spec:
  host: grpc-server
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
EOF
```

## Étape 4. Vérifier

Générez une charge gRPC depuis le client et confirmez que les requêtes
atteignent **les trois** pods backend (équilibrage par requête) :

```bash
kubectl exec -n app deploy/grpc-client -c ping-pong -- \
  /app -grpc-client -target grpc-server:8079 -n 180 -c 4
```

Fin attendue :

```
--- summary ---
requests: 180  ok: 180  errors: 0
distinct servers: 3
host grpc-server-xxxx-aaaa: 60
host grpc-server-xxxx-bbbb: 60
host grpc-server-xxxx-cccc: 60
```

`distinct servers: 3` prouve que les requêtes sont équilibrées par requête.
Avant la correction (port nommé `tcp`), la même commande indique `distinct servers: 1`.

## Pourquoi cela fonctionne

- **gRPC est HTTP/2, pas TCP.** Avec une vue L4/TCP, Envoy équilibre les
  *connexions* : un client gRPC conserve une seule connexion longue durée, donc
  chaque appel reste sur un pod. Déclarer le port comme `grpc` fait analyser
  HTTP/2 par Envoy et équilibrer **chaque requête** (stream) entre les endpoints.
- **Le nommage du port est le commutateur.** Le port doit être nommé `grpc` /
  `grpc-*` (ou `http2`), ou comporter `appProtocol: grpc`. Un nom neutre
  (`tcp`, sans nom) supprime chaque fonctionnalité L7 : pas de LB par requête,
  pas de retries, pas de timeouts, pas de métriques gRPC.
- **Les fonctionnalités L7 s'appliquent à gRPC.** Comme il s'agit de HTTP,
  gRPC bénéficie de retries `http` (avec un `retryOn` compatible avec gRPC), de
  `timeout`/`perTryTimeout`, du routage d'en-têtes, de l'injection de pannes et
  d'une télémétrie riche, exactement comme pour HTTP simple.
