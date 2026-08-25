[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labor 11 - Referenzlösung (RequestAuthentication + JWT)

Test-Tokens/Schlüssel stammen aus den Istio-Beispielen:
- issuer / JWKS: `testing@secure.istio.io`
- JWKS: `https://raw.githubusercontent.com/istio/istio/release-1.29/security/tools/jwt/samples/jwks.json`
- gültiges Token: `https://raw.githubusercontent.com/istio/istio/release-1.29/security/tools/jwt/samples/demo.jwt`

## Schritt 1. Sidecar-Injektion aktivieren

```bash
kubectl label namespace default istio-injection=enabled --overwrite
```

## Schritt 2. Die Anwendung bereitstellen

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/11/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl rollout status deployment/ping-pong -n default
```

## Schritt 3. RequestAuthentication (JWT validieren)

```yaml
# request-auth.yaml
apiVersion: security.istio.io/v1
kind: RequestAuthentication
metadata:
  name: jwt-ping-pong
  namespace: default
spec:
  selector:
    matchLabels:
      app: ping-pong
  jwtRules:
  - issuer: "testing@secure.istio.io"
    jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.29/security/tools/jwt/samples/jwks.json"
```

```bash
kubectl apply -f request-auth.yaml

# invalid token is rejected (401); no token still passes at this point (200)
kubectl exec -n default deploy/curl-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer bad" http://ping-pong:8080/   # 401
kubectl exec -n default deploy/curl-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong:8080/                                  # 200
```

## Schritt 4. AuthorizationPolicy (ein gültiges JWT verlangen)

```yaml
# require-jwt.yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
  namespace: default
spec:
  selector:
    matchLabels:
      app: ping-pong
  action: ALLOW
  rules:
  - from:
    - source:
        requestPrincipals: ["*"]   # any request carrying a valid JWT principal
```

```bash
kubectl apply -f require-jwt.yaml
```

## Überprüfen

```bash
TOKEN=$(curl -s https://raw.githubusercontent.com/istio/istio/release-1.29/security/tools/jwt/samples/demo.jwt)

# no token -> 403 (AuthorizationPolicy denies)
kubectl exec -n default deploy/curl-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong:8080/

# invalid token -> 401 (RequestAuthentication rejects)
kubectl exec -n default deploy/curl-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer bad" http://ping-pong:8080/

# valid token -> 200
kubectl exec -n default deploy/curl-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer ${TOKEN}" http://ping-pong:8080/
```

## (optional) Anspruchsbasierte Autorisierung

Einen spezifischen JWT-Claim (z. B. `groups`) mithilfe einer `when`-Bedingung verlangen:

```yaml
  rules:
  - from:
    - source:
        requestPrincipals: ["*"]
    when:
    - key: request.auth.claims[groups]
      values: ["group1"]
```
