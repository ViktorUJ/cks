[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 18 - Solution de référence

Istio `1.29.1` est installé (passerelle d'entrée sur NodePort `32080`) avec le traçage distribué
connecté au fournisseur d'extension `zipkin` (`zipkin.istio-system:9411`). L'extension
**Jaeger** est déployée comme backend de traçage. L'application `ping-pong` est déployée dans
l'espace de noms `app` et exposée à l'adresse `http://myapp.local:32080/`. La journalisation
des accès est **désactivée** par défaut et aucune ressource `Telemetry` n'existe encore.

## Objectif

Utilisez l'**API Telemetry** pour :
- activer la journalisation des accès Envoy pour l'espace de noms `app` (fournisseur intégré `envoy`) ;
- activer le traçage via le fournisseur `zipkin` avec un échantillonnage à 100 % afin que les traces soient effectivement
  collectées dans Jaeger.

## Étape 1. Confirmer que les journaux d'accès sont désactivés

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
curl -s -o /dev/null http://myapp.local:32080/
kubectl logs -n app "$POD" -c istio-proxy --tail=50   # no access log lines
```

## Étape 2. Configurer les journaux + les traces via Telemetry

```bash
cat > telemetry.yaml <<'EOF'
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: app-telemetry
  namespace: app
spec:
  accessLogging:
    - providers:
        - name: envoy
  tracing:
    - providers:
        - name: zipkin
      randomSamplingPercentage: 100.0
EOF

kubectl apply -f telemetry.yaml
```

## Étape 3. Générer du trafic

```bash
for i in $(seq 30); do curl -s -o /dev/null http://myapp.local:32080/; done
```

## Étape 4. Vérifier la collecte

Journaux d'accès (dans stdout du sidecar) :

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n app "$POD" -c istio-proxy --tail=50 | grep 'GET / HTTP'
```

Traces (dans Jaeger, interrogé depuis l'intérieur du cluster) :

```bash
kubectl exec -n app deploy/curl-client -- \
  curl -s 'http://tracing.istio-system:80/jaeger/api/services' | tr ',' '\n' | grep ping-pong
```

Vous pouvez également effectuer un port-forward vers l'interface Jaeger :

```bash
kubectl -n istio-system port-forward svc/tracing 16686:80
# open http://localhost:16686/jaeger and pick the ping-pong service
```

## Destination des journaux et des traces

| Signal | Fournisseur | Destination |
|---|---|---|
| Journaux d'accès | `envoy` (intégré) | stdout du sidecar → `kubectl logs -c istio-proxy` |
| Traces | fournisseur d'extension `zipkin` | Jaeger (`zipkin.istio-system:9411`) → interface Jaeger |

## Fonctionnement

- L'**API Telemetry** (`telemetry.istio.io`) configure déclarativement les journaux, les métriques
  et les traces, et prend en charge une hiérarchie de portées : à l'échelle du mesh (espace de noms racine) → espace de noms →
  charge de travail (`selector`).
- **`accessLogging.providers.name: envoy`** écrit les journaux d'accès dans stdout du sidecar.
- **`tracing.providers.name: zipkin`** oriente les spans vers le fournisseur d'extension `zipkin`
  déclaré dans `meshConfig.extensionProviders`, qui les transfère à Jaeger.
  Sans référence à un fournisseur, la politique d'échantillonnage n'aurait aucun endroit où envoyer les spans.
- **`randomSamplingPercentage: 100`** trace chaque requête (utilisez une faible valeur en
  production pour contrôler la surcharge).
