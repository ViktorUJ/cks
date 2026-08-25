[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratoire 21 - Solution de référence

Istio `1.29.1` est installé. Deux espaces de noms sont déployés :
- `app` avec `ping-pong` (sidecar injecté) ;
- `other` avec `backend` (sidecar injecté).

Par défaut, chaque sidecar reçoit la configuration Envoy pour **tous** les services du mesh, donc le
proxy `app` comporte également un cluster pour `backend.other` même s'il ne lui parle jamais.

## Objectif

Limiter les proxys de l'espace de noms `app` avec une ressource `Sidecar` afin qu'ils reçoivent uniquement la configuration
pour leur propre espace de noms et `istio-system`.

## Étape 1. Observer la configuration par défaut (non limitée)

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config clusters "$POD" -n app | grep backend.other
# a cluster for backend.other.svc.cluster.local is present
```

## Étape 2. Appliquer une ressource Sidecar pour limiter l'egress

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: app
spec:
  egress:
    - hosts:
        - "./*"
        - "istio-system/*"
EOF
```

- `./*` - chaque service dans l'espace de noms **local** (`app`) ;
- `istio-system/*` - l'espace de noms du plan de contrôle (nécessaire pour la télémétrie, etc.).

Une ressource `Sidecar` nommée `default` sans `workloadSelector` s'applique à toutes les charges de travail dans
l'espace de noms.

## Étape 3. Vérifier que la configuration a diminué

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')

# 'other' namespace clusters are gone
istioctl proxy-config clusters "$POD" -n app | grep backend.other || echo "pruned ✅"

# own namespace clusters remain
istioctl proxy-config clusters "$POD" -n app | grep ping-pong.app
```

## Fonctionnement et importance

- La ressource **`Sidecar`** contrôle la portée de la configuration qu'istiod envoie à un
  proxy. `egress.hosts` établit la liste blanche des services connus par le proxy.
- Par défaut, le mesh est un « full mesh » : chaque proxy connaît chaque service. Dans un grand
  cluster (des milliers de services), cela implique d'énormes configurations Envoy, une consommation mémoire élevée par pod,
  et une forte utilisation du CPU d'istiod à chaque changement.
- Limiter la portée des proxys avec des ressources `Sidecar` est la façon standard de faire évoluer Istio :
  des configurations plus petites, des envois plus rapides, une charge istiod réduite et des limites d'egress plus strictes.
- `outboundTrafficPolicy` dans `Sidecar` peut en outre définir `REGISTRY_ONLY` par
  espace de noms afin de bloquer l'egress non déclaré.

> Remarque : la limitation de portée concerne la *distribution de configuration*, et non l'autorisation. Pour réellement interdire
> les appels, utilisez `AuthorizationPolicy` (Laboratoire 04) ou `outboundTrafficPolicy: REGISTRY_ONLY`.