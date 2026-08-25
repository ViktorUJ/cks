[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 28 - Solution de référence

Istio `1.29.1` est installé avec un TCP NodePort fixe `31400` sur la passerelle d'entrée. L'application
`tcp-echo` est déployée dans l'espace de noms `app` en deux versions :
- **v1** répond avec le préfixe `one` ;
- **v2** répond avec le préfixe `two`.

Les deux écoutent sur le port TCP brut `9000` (et non HTTP).

## Objectif

Router un service **TCP** brut via la passerelle d'entrée à l'aide d'un `Gateway` avec un écouteur
TCP et d'un `VirtualService` avec une route `tcp` (pondérée entre v1 et v2).

## Étape 1. Gateway avec un écouteur TCP

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: tcp-echo-gateway
  namespace: app
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 31400
        name: tcp
        protocol: TCP
      hosts:
        - "*"
EOF
```

## Étape 2. DestinationRule avec des sous-ensembles

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: tcp-echo
  namespace: app
spec:
  host: tcp-echo
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
EOF
```

## Étape 3. VirtualService avec une route TCP

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: tcp-echo
  namespace: app
spec:
  hosts:
    - "*"
  gateways:
    - tcp-echo-gateway
  tcp:
    - match:
        - port: 31400
      route:
        - destination:
            host: tcp-echo
            port:
              number: 9000
            subset: v1
          weight: 80
        - destination:
            host: tcp-echo
            port:
              number: 9000
            subset: v2
          weight: 20
EOF
```

## Étape 4. Vérifier

```bash
for i in $(seq 10); do
  echo "hello" | timeout 3 bash -c 'exec 3<>/dev/tcp/myapp.local/31400; cat >&3; head -n 1 <&3'
done
# ~80% "one hello", ~20% "two hello"
```

(Si `nc` est installé : `echo hello | nc myapp.local 31400`.)

## Fonctionnement

- Le **routage TCP** opère à la couche 4 : il n'y a ni hôte, ni chemin, ni en-tête HTTP, donc le routage
  s'appuie sur le **port de l'écouteur** (`match.port`). Un serveur `Gateway` avec `protocol: TCP` fait en sorte qu'
  Envoy ouvre un écouteur TCP simple ; la route `VirtualService.tcp` transfère la connexion vers le sous-ensemble backend
  choisi.
- **Le nom du port est important** : le port de service/passerelle doit être nommé `tcp` (ou `tcp-*`). Istio
  utilise le préfixe du nom du port pour détecter le protocole ; un nom sans préfixe ou `http-*`
  amènerait Istio à le traiter comme HTTP et le protocole brut ne fonctionnerait plus.
- Le TCP pondéré répartit les *connexions* (et non les requêtes) entre les sous-ensembles : chaque nouvelle connexion TCP
  est routée selon le poids.
- Les fonctionnalités L7 (nouvelles tentatives, routage par en-tête, injection de pannes) ne s'appliquent **pas** aux routes TCP :
  seules les politiques au niveau de la connexion (pool de connexions, délais d'attente) via `DestinationRule` s'appliquent.

## Protocoles associés

- **MongoDB/MySQL/Redis** : nommez le port `mongo-*` / `mysql-*` / `redis-*` afin qu'Envoy
  applique l'analyseur de protocole approprié ; le routage utilise toujours des routes `tcp`.
- **WebSocket** : bien qu'il soit de longue durée, il s'appuie sur HTTP `Upgrade`, utilisez donc les routes
  `http` normales et les noms de port `http-*`, et non TCP.