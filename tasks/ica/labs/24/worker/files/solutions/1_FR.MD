[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratoire 24 - Solution de référence

Istio `1.29.1` est installé en mode **ambient** (istiod + istio-cni + ztunnel). L'espace de
noms `app` est inscrit dans ambient (`istio.io/dataplane-mode: ambient`) et exécute
`ping-pong` ainsi qu'un `app-client` - tous deux **sans** sidecars. `istioctl` est disponible sur
le PC de travail.

## Contexte

- **ztunnel** fournit à chaque workload ambient le mTLS L4 et une identité, mais il **ne**
  comprend **pas** HTTP. Les politiques L4 (autorisation/refus par identité/port) fonctionnent donc, mais les règles L7
  (méthodes HTTP, chemins, en-têtes) ne fonctionnent pas.
- Pour appliquer une politique **L7**, ajoutez un **waypoint proxy** - un Envoy par espace de noms (ou
  par service) à travers lequel le trafic ambient est routé pour le traitement L7.

## Objectif

Ajoutez un waypoint à l'espace de noms `app` et une `AuthorizationPolicy` L7 qui n'autorise que les
requêtes `GET` vers `ping-pong` (tout le reste → `403`).

## Étape 1. Provisionnez un waypoint

```bash
istioctl waypoint apply -n app --enroll-namespace
kubectl get gtw waypoint -n app
kubectl rollout status deploy/waypoint -n app
```

`--enroll-namespace` ajoute un label à l'espace de noms (`istio.io/use-waypoint: waypoint`), de sorte que le trafic
vers les services de `app` est routé à travers le waypoint.

## Étape 2. Appliquez une AuthorizationPolicy L7

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-get-only
  namespace: app
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: waypoint
  action: ALLOW
  rules:
    - to:
        - operation:
            methods: ["GET"]
EOF
```

Une politique `ALLOW` refuse par défaut tout ce qui ne lui correspond pas, donc seul `GET`
passe ; les autres méthodes reçoivent `403`.

## Étape 3. Vérifiez

```bash
# GET -> allowed
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -X GET http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# DELETE -> denied by the waypoint
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -X DELETE http://ping-pong.app.svc.cluster.local:8080/
# -> 403
```

## Fonctionnement

- **L4 sans sidecar (ztunnel)** gère le mTLS et l'identité pour tout l'espace de noms sans
  proxy par pod. Il est économique et toujours actif dans ambient.
- **Waypoint (L7)** est ajouté uniquement là où vous avez besoin de fonctionnalités de niveau HTTP : autorisation L7,
  routage, nouvelles tentatives, répartition du trafic. Vous utilisez un Envoy uniquement pour ces services.
- L'`AuthorizationPolicy` utilise `targetRefs` pour cibler le `Gateway` waypoint ; elle est donc appliquée au
  saut L7. La même politique attachée à un sidecar/ingress fonctionne aussi - ambient ne fait que déplacer le
  point d'application L7 vers le waypoint.
- Ce modèle en couches (ztunnel pour L4 partout, waypoint pour L7 là où nécessaire) est l'idée clé
  d'ambient : un coût de base inférieur à celui des sidecars, avec L7 activable à la demande.

## Ressources associées

Le laboratoire 09 couvre les bases d'ambient (ztunnel L4). Le laboratoire 04 couvre la même `AuthorizationPolicy`
dans le modèle sidecar.
