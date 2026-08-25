[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratoire 20 : solution de référence

Istio `1.29.1` est installé. Trois charges de travail sont déployées :
- `ping-pong` dans l'espace de noms `app` (sidecar injecté, sert l'application) ;
- `mesh-client` dans l'espace de noms `app` (sidecar injecté, communique en mTLS) ;
- `legacy-client` dans l'espace de noms `legacy` (**sans** sidecar, trafic non chiffré uniquement).

Sans `PeerAuthentication`, mTLS est **PERMISSIVE** par défaut : le client du mesh
(mTLS) comme le client hérité (non chiffré) peuvent atteindre l'application.

## Objectif

Migrer l'espace de noms `app` vers mTLS **STRICT** afin que seul le trafic mTLS soit accepté,
sans perturber le client au sein du mesh.

## Étape 1. Observer l'état de référence PERMISSIVE

```bash
# in-mesh client -> app : works (mTLS)
kubectl exec -n app deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# legacy plaintext client -> app : ALSO works under PERMISSIVE
kubectl exec -n legacy deploy/legacy-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong.app.svc.cluster.local:8080/
# -> 200
```

## Étape 2. (recommandé) Rendre l'intention explicite avec PERMISSIVE

Une migration sûre fixe d'abord explicitement PERMISSIVE, puis bascule vers STRICT une fois que vous avez
confirmé (via les métriques) qu'il ne reste plus de trafic non chiffré :

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: app
spec:
  mtls:
    mode: PERMISSIVE
EOF
```

## Étape 3. Basculer l'espace de noms vers STRICT

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: app
spec:
  mtls:
    mode: STRICT
EOF
```

## Étape 4. Vérifier

```bash
# in-mesh client -> app : still works (mTLS)
kubectl exec -n app deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# legacy plaintext client -> app : now rejected (connection reset)
kubectl exec -n legacy deploy/legacy-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" --max-time 10 http://ping-pong.app.svc.cluster.local:8080/
# -> 000 (curl exit 56: reset by peer)
```

## Fonctionnement

- **PeerAuthentication** contrôle la manière dont le sidecar côté *serveur* accepte les
  connexions entrantes :
  - `PERMISSIVE` (valeur par défaut du mesh) accepte à la fois mTLS et le trafic non chiffré. Cela
    rend une migration sans interruption possible : vous pouvez intégrer progressivement des charges de travail au mesh
    tout en laissant les clients hérités non chiffrés fonctionner.
  - `STRICT` accepte uniquement mTLS ; les connexions non chiffrées sont réinitialisées.
- Hiérarchie des portées : un `PeerAuthentication` dans `istio-system` (racine) s'applique à l'ensemble du mesh ; un objet
  dans un espace de noms le remplace pour cet espace ; un objet avec un `selector` le remplace pour chaque charge de travail.
- **Recette de migration sûre** : conservez PERMISSIVE, surveillez la métrique
  `istio_requests_total{connection_security_policy="none"}` jusqu'à ce qu'elle tombe à
  zéro (plus aucun trafic non chiffré), puis basculez vers STRICT.

## Liens connexes

Le laboratoire 04 couvre l'état final STRICT associé à `AuthorizationPolicy` (qui peut appeler
qui). Ce laboratoire se concentre sur la transition elle-même et le rôle de PERMISSIVE.
