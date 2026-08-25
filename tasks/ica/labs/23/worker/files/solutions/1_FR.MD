[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 23 - Solution de référence

Istio `1.29.1` est installé (passerelle d'entrée sur NodePort `32080`). L'application `ping-pong`
est déployée dans l'espace de noms `app` et exposée à `http://myapp.local:32080/`.

## Objectif

Étendez le plan de données Envoy avec un module **WebAssembly** : chargez l'extension Wasm
communautaire `basic_auth` sur la passerelle d'entrée afin que les requêtes nécessitent une authentification HTTP Basic.

> Istio `1.29` utilise l'API `WasmPlugin` (`extensions.istio.io/v1alpha1`). Dans `1.30+`,
> elle est remplacée par l'API `TrafficExtension`.

## Étape 1. Référence (aucune authentification requise)

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## Étape 2. Appliquer le WasmPlugin

```bash
kubectl apply -f - <<'EOF'
apiVersion: extensions.istio.io/v1alpha1
kind: WasmPlugin
metadata:
  name: basic-auth
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  phase: AUTHN
  url: oci://ghcr.io/istio-ecosystem/wasm-extensions/basic_auth:1.12.0
  pluginConfig:
    basic_auth_rules:
      - prefix: "/"
        request_methods:
          - "GET"
        credentials:
          - "ok:test"
          - "YWRtaW4zOmFkbWluMw=="
EOF
```

L'agent Istio sur la passerelle d'entrée télécharge l'image OCI Wasm, la met en cache localement,
et l'injecte en tant que filtre HTTP. Attendez quelques secondes.

## Étape 3. Vérifier

```bash
# no credentials -> 401
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/

# valid credentials -> 200  (base64 of admin3:admin3)
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Basic YWRtaW4zOmFkbWluMw==" http://myapp.local:32080/
```

## Fonctionnement

- **WebAssembly (Wasm)** permet d'ajouter une logique personnalisée à Envoy sans reconstruire le proxy
  et de la charger dynamiquement à l'exécution.
- **`url: oci://...`** : le module est fourni comme artefact OCI ; l'agent Istio le récupère et
  le met en cache. Vous pouvez aussi utiliser `file://` (intégré à l'image) ou `http(s)://`.
- **`phase: AUTHN`** place le filtre tôt dans la chaîne (avant le routage/l'authz).
- **`selector`** limite la portée du plugin aux charges de travail par étiquettes (ici la passerelle d'entrée). Un
  WasmPlugin dans `istio-system` avec un sélecteur de passerelle n'affecte que la passerelle.
- **`pluginConfig`** est transmis au module. Le module `basic_auth` lit
  `basic_auth_rules` (préfixe de chemin, méthodes et informations d'identification acceptées).

## Quand utiliser Wasm

- Authentification personnalisée, enrichissement d'en-têtes, validation des requêtes ou logique de protocole que les
  CRD intégrées d'Istio (`AuthorizationPolicy`, `EnvoyFilter`) ne peuvent pas exprimer.
- Préférez d'abord les API intégrées ; utilisez Wasm uniquement lorsque vous avez réellement besoin de code personnalisé dans le plan de
  données. Gardez à l'esprit le coût opérationnel : distribution des modules, gestion des versions et récupération à l'exécution
  (`failStrategy` contrôle le comportement si le téléchargement échoue).