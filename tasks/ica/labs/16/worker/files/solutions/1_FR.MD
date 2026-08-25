[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 16 - Solution de référence

Istio `1.29.1` est déjà installé (profil par défaut) et les CRD de l'API Kubernetes Gateway
(`v1.2.1`) sont présentes. L'application (`ping-pong-v1` / `ping-pong-v2`) est déployée dans
l'espace de noms `app`.

## Étape 1. Déployer l'application

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/16/k8s-1/scripts/1.yaml
kubectl get pods -n app
```

Chaque pod doit être à `2/2` (application + sidecar istio-proxy).

## Étape 2. Créer une Gateway (API Kubernetes Gateway)

La Gateway est annotée afin qu'Istio provisionne un Service **NodePort** pour celle-ci (cet
environnement de test n'a pas d'équilibreur de charge cloud).

```bash
cat > gateway.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gateway
  namespace: app
  annotations:
    networking.istio.io/service-type: NodePort
spec:
  gatewayClassName: istio
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same
EOF

kubectl apply -f gateway.yaml
```

Istio provisionne automatiquement un Deployment et un Service nommés `web-gateway-istio` dans
l'espace de noms `app` :

```bash
kubectl get gateway web-gateway -n app
kubectl get deploy,svc web-gateway-istio -n app
```

## Étape 3. Créer une HTTPRoute

Acheminez l'en-tête `x-version: canary` vers **v2**, et tout le reste vers **v1**.

```bash
cat > httproute.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ping-pong-route
  namespace: app
spec:
  parentRefs:
    - name: web-gateway
  rules:
    - matches:
        - headers:
            - name: x-version
              value: canary
      backendRefs:
        - name: ping-pong-v2
          port: 8080
    - backendRefs:
        - name: ping-pong-v1
          port: 8080
EOF

kubectl apply -f httproute.yaml
```

## Étape 4. Vérifier le routage

```bash
NODEPORT=$(kubectl get svc web-gateway-istio -n app -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')

# default -> v1
curl -s http://myapp.local:${NODEPORT}/

# canary header -> v2
curl -s -H "x-version: canary" http://myapp.local:${NODEPORT}/
```

Résultat attendu : la requête par défaut retourne `Ping-Pong-V1 (Stable)`, et la requête avec
l'en-tête `x-version: canary` retourne `Ping-Pong-V2 (Canary)`.

## API Istio vs API Gateway

| Concept | API Istio | API Kubernetes Gateway |
|---|---|---|
| Point d'entrée | `Gateway` (networking.istio.io) | `Gateway` (gateway.networking.k8s.io) |
| Règles de routage | `VirtualService` | `HTTPRoute` |
| Backend | `host` + `subset` (+ `DestinationRule`) | `backendRefs` |
| Pod Gateway | `istio-ingressgateway` partagé | provisionné automatiquement par `Gateway` |
| Portabilité | spécifique à Istio | neutre vis-à-vis du fournisseur, portable entre les meshes/ingress |
