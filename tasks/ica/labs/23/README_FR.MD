[RU version](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD)

# Lab 23 - WasmPlugin : étendre le data plane via WebAssembly

## Aperçu

Parfois les CRD intégrés d'Istio (`AuthorizationPolicy`, `EnvoyFilter`) ne suffisent pas -
il faut sa propre logique directement dans le data plane. Pour cela, il y a
**WebAssembly (Wasm)** : vous écrivez (ou récupérez) un module, et Envoy le charge
dynamiquement au runtime, sans recompiler le proxy.

Dans ce lab, vous allez brancher le module communautaire **`basic_auth`** sur l'ingress
gateway, pour que les requêtes exigent une authentification HTTP Basic.

> Istio `1.29` utilise l'API `WasmPlugin` (`extensions.istio.io/v1alpha1`). En `1.30+`,
> elle est remplacée par l'API `TrafficExtension`.

Istio est déjà installé (ingress gateway sur le NodePort `32080`), l'application
`ping-pong` est déployée dans le namespace `app` et publiée sur
`http://myapp.local:32080/`.

```mermaid
flowchart LR
    C["client"] --> GW["istio-ingressgateway<br>+ WasmPlugin basic_auth"]
    GW -->|"pas de creds/creds invalides"| R["401 Unauthorized"]
    GW -->|"creds valides"| A["ping-pong<br>200 OK"]
    OCI["oci://ghcr.io/.../basic_auth:1.12.0"] -.pull.-> GW
```

## Infrastructure

| Composant | Type | Qté | Rôle |
|---|---|---|---|
| control-plane | `t3.medium` | 1 | master + istiod + ingress gateway |
| worker | `t3.small` | 1 | capacité pour l'application |
| worker PC | `t3.small` | 1 | poste de travail : `kubectl`, `curl`, `check_result` |

Région : `eu-central-1` (AZ `eu-central-1a` / `eu-central-1b`).

## Déploiement

```bash
TASK=23 make run_ica_task
```

## Qu'est-ce que WebAssembly (pour ceux qui n'y ont jamais touché)

En bref : **WebAssembly (Wasm)** est un format de petits programmes compilés que l'on
peut exécuter en toute sécurité à l'intérieur d'un autre programme. Wasm a d'abord été
conçu pour les navigateurs (pour faire tourner du code C++/Rust à côté de JavaScript),
mais aujourd'hui on l'utilise partout, y compris à l'intérieur de proxys réseau.

Décomposons étape par étape ce qui se passe ici :

- **Ce que sont le data plane et Envoy.** Dans Istio, à côté de chaque pod tourne un proxy
  **Envoy** (le fameux « sidecar »). Tout le trafic réseau du pod passe par lui - entrant
  et sortant. L'ensemble de ces proxys s'appelle le *data plane*. C'est Envoy qui applique
  réellement les règles : mTLS, routage, limites, autorisation.
- **Le problème.** Envoy sait faire beaucoup « prêt à l'emploi », mais on ne peut pas tout
  prévoir. Avant, pour ajouter sa propre logique, il fallait recompiler Envoy en C++ et
  remplacer l'image du proxy - c'est long, risqué et cassant lors des mises à jour.
- **L'idée du plugin Wasm.** Au lieu de recompiler, vous écrivez un petit module dans un
  langage pratique (**Rust, C++, Go/TinyGo, AssemblyScript**), vous le compilez en `.wasm`
  et vous le « donnez à manger » à Envoy. Envoy charge ce module **à la volée, sans
  redémarrage ni recompilation**, et commence à faire passer les requêtes à travers lui.
- **Le bac à sable (sandbox).** Le module Wasm s'exécute dans un environnement isolé : il
  n'a pas d'accès direct à la mémoire d'Envoy ni à l'hôte et communique avec le proxy
  uniquement via une interface strictement définie. Même si le module « plante », il ne
  fait pas tomber le proxy. Cela rend l'exécution de code tiers/maison dans les proxys
  relativement sûre.
- **L'ABI proxy-wasm.** L'interaction « Envoy ↔ module Wasm » est standardisée par le
  protocole **proxy-wasm** (un ensemble de fonctions-hooks : « une requête est arrivée »,
  « un en-tête est arrivé », « un corps est arrivé », etc.). Grâce à ce standard commun,
  un même module fonctionne sur différentes versions d'Envoy/Istio et même dans d'autres
  proxys supportant proxy-wasm.
- **Comment le module arrive dans le proxy.** Le module est empaqueté dans une **image
  OCI** (comme une image Docker classique) et déposé dans un registre. Dans le
  `WasmPlugin`, vous indiquez `url: oci://...`, et istio-agent télécharge lui-même le
  module, le met en cache sur le nœud et le branche à Envoy comme filtre HTTP.

Analogie : c'est comme un « plugin/extension de navigateur », sauf qu'ici le plugin ne
s'installe pas dans le navigateur mais dans un proxy réseau, et il ne traite pas des pages
web mais des requêtes réseau entre services. Dans ce lab, ce « plugin » sera le module
prêt à l'emploi `basic_auth`, qui exige un login/mot de passe (HTTP Basic auth) à l'entrée
du maillage.

## Modules prêts à l'emploi et comment faire le sien

**Modules Wasm prêts à l'emploi (pas besoin d'écrire du code).** Souvent la fonctionnalité
voulue a déjà été écrite par quelqu'un - il suffit d'indiquer le lien vers l'image dans le
`WasmPlugin` :

- **istio-ecosystem/wasm-extensions** - exemples officiels de la communauté Istio
  (`basic_auth` et autres), publiés dans `ghcr.io/istio-ecosystem/wasm-extensions/...`
  (c'est celui qu'on utilise dans le lab).
- **Modules produit prêts à l'emploi** de fournisseurs (par exemple coraza-WAF en Wasm,
  OPA, divers filtres auth/rate-limit), distribués comme images OCI.
- **WebAssembly Hub / registres OCI** - les modules sont empaquetés comme des images OCI
  classiques, on peut donc les stocker dans n'importe quel registre (ghcr, Docker Hub,
  ECR, Harbor privé).

La règle est simple : si le module existe comme image OCI - vous écrivez simplement
`url: oci://...`, et pas besoin d'écrire de code.

**S'il faut son propre module - la voie rapide.** Sa propre logique s'écrit dans un
langage qui compile en Wasm, en utilisant le SDK proxy-wasm :

1. **Choisir le langage et le SDK.** Populaires : **Rust**
   (`proxy-wasm/proxy-wasm-rust-sdk`), **Go/TinyGo** (`proxy-wasm-go-sdk`), C++ ou
   AssemblyScript. Pour la prod, on prend le plus souvent Rust (`.wasm` rapide et compact).
2. **Écrire les hooks.** Dans le SDK, vous implémentez les callbacks du cycle de vie de la
   requête, par exemple `on_http_request_headers` (les en-têtes de la requête sont
   arrivés), `on_http_response_headers`, etc. À l'intérieur - votre logique : vérifier un
   en-tête, l'ajouter/le modifier, renvoyer une erreur.
3. **Compiler en Wasm.** Par exemple pour Rust :
   ```bash
   rustup target add wasm32-wasip1
   cargo build --release --target wasm32-wasip1
   # résultat : target/wasm32-wasip1/release/my_plugin.wasm
   ```
4. **Empaqueter dans une image OCI et pousser.** Istio attend le Wasm à l'intérieur d'un
   artefact OCI. Pratique à assembler avec des outils comme `buildah`/`docker` ou
   `func-e`/`wasme` ; ensuite `docker push <registry>/my-plugin:1.0`.
5. **Brancher via WasmPlugin.** Vous indiquez `url: oci://<registry>/my-plugin:1.0` et, si
   besoin, `pluginConfig` avec vos paramètres - exactement comme dans ce lab.

Exemple minimal de logique en Rust (on ajoute un en-tête de réponse) :

```rust
use proxy_wasm::traits::*;
use proxy_wasm::types::*;

proxy_wasm::main! {{
    proxy_wasm::set_http_context(|_, _| -> Box<dyn HttpContext> { Box::new(MyPlugin) });
}}

struct MyPlugin;
impl Context for MyPlugin {}
impl HttpContext for MyPlugin {
    fn on_http_response_headers(&mut self, _n: usize, _eos: bool) -> Action {
        self.set_http_response_header("x-my-plugin", Some("hello"));
        Action::Continue
    }
}
```

Pour du développement réel, consultez les guides du dépôt
`istio-ecosystem/wasm-extensions` (comment écrire, tester et assembler les images OCI).

## Exercice

1. Vérifier que sans le plugin, l'application est accessible (`200`).
2. Appliquer un `WasmPlugin` qui, sur l'ingress gateway (`selector: istio=ingressgateway`),
   charge le module `basic_auth` depuis un registre OCI et exige une authentification
   Basic.
3. Vérifier que sans identifiants la requête est rejetée avec `401`, et qu'avec des
   identifiants corrects elle passe avec `200`.

## Étape 1. Comportement de base (sans auth)

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

L'istio-agent sur l'ingress gateway télécharge l'image OCI Wasm, la met en cache
localement et l'intègre comme filtre HTTP. Laissez quelques secondes.

## Étape 3. Vérification

```bash
# sans identifiants -> 401
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/

# avec identifiants corrects -> 200  (base64 de admin3:admin3)
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Basic YWRtaW4zOmFkbWluMw==" http://myapp.local:32080/
```

## Comment ça marche

- **WebAssembly (Wasm)** permet d'ajouter à Envoy une logique personnalisée sans
  recompiler le proxy et de la charger dynamiquement au runtime.
- **`url: oci://...`** - le module est livré comme artefact OCI ; istio-agent le
  télécharge et le met en cache. Sont aussi supportés `file://` (embarqué dans l'image) et
  `http(s)://`.
- **`phase: AUTHN`** place le filtre tôt dans la chaîne (avant le routage/l'autorisation).
- **`selector`** limite le plugin aux workloads par labels (ici - l'ingress gateway).
- **`pluginConfig`** est transmis au module ; `basic_auth` lit `basic_auth_rules` (préfixe
  de chemin, méthodes, identifiants autorisés).

## Quand c'est utile (scénarios réels)

- **Authentification/autorisation personnalisée** : Basic auth, vérification de clé API,
  signature HMAC de la requête, intégration avec un IdP non standard - ce qui ne
  s'exprime pas via `RequestAuthentication`/`AuthorizationPolicy`.
- **Manipulation des requêtes/réponses** : enrichissement des en-têtes depuis une source
  externe, calcul de signature, édition du corps (masquage de PII), normalisation des
  chemins.
- **Logique protocolaire et métier à la frontière** : rate limiting spécifique par clé
  personnalisée, feature flags, A/B basé sur des règles complexes, décodage d'un protocole
  propriétaire.
- **Conformité et sécurité** : audit-logging dans un format particulier, vérifications de
  type WAF, blocage par signatures personnalisées.
- **Sortir la logique de l'application** : une même logique transverse (auth, logging,
  en-têtes) est implémentée une seule fois dans le maillage, plutôt que dans chaque service
  et dans chaque langage.

## Avantages par rapport aux alternatives

| Approche | Avantages | Inconvénients / quand c'est pire que Wasm |
|---|---|---|
| **CRD intégrés** (`AuthorizationPolicy`, `RequestAuthentication`, `Telemetry`, `EnvoyFilter` local ratelimit) | Simple, déclaratif, supporté par Istio | Limités aux capacités prédéfinies ; une logique arbitraire n'est pas exprimable |
| **`EnvoyFilter` + Lua** (voir lua-scripts) | Sans recompilation, script inline | Uniquement Lua ; les tâches lourdes sont plus lentes ; pas de typage strict/tests ; logique « éparpillée » dans le YAML |
| **`EnvoyFilter` avec filtre natif C++** | Vitesse maximale | Nécessite une recompilation d'Envoy et une image de proxy personnalisée ; incompatible avec les mises à niveau ; barrière d'entrée élevée |
| **Logique dans l'application elle-même** | Contrôle total | Dupliquée dans chaque service et dans chaque langage ; difficile d'assurer l'uniformité et la mise à jour |
| **Service externe (ext_authz / callout)** | N'importe quel langage, déploiement séparé | Hop réseau supplémentaire et latence sur chaque requête ; un composant de plus à exploiter |
| **WasmPlugin (ce lab)** | Votre code dans n'importe quel langage compilable en Wasm (C++, Rust, Go/TinyGo, AssemblyScript) ; chargement **au runtime sans recompilation d'Envoy et sans redémarrage** ; exécution **in-process** (pas de hop réseau, contrairement à ext_authz) ; bac à sable Wasm - isolation et sécurité ; portabilité entre versions d'Envoy/Istio grâce à l'ABI proxy-wasm stable ; versionnage et livraison via un registre OCI | Statut Alpha de l'API ; surcoût de chargement runtime et de mise en cache du module ; votre code doit être maintenu, testé et versionné ; débogage plus complexe qu'avec des CRD déclaratifs |

**En bref :** Wasm l'emporte quand il faut une logique *arbitraire* dans le data plane,
tout en tenant à une faible latence (in-process, sans hop superflu comme ext_authz), à la
sécurité (bac à sable) et à la possibilité de déployer/mettre à jour le filtre
dynamiquement sans recompiler le proxy.

**Ordre de choix en pratique :** d'abord les CRD intégrés → si insuffisant, `EnvoyFilter`
(dont Lua pour le simple) → un `ext_authz` externe si la logique est plus simple à garder
comme service séparé et que la latence n'est pas critique → **Wasm**, quand il faut son
propre code rapide in-process dans le proxy lui-même. Tenez compte du coût opérationnel du
Wasm : livraison du module, versionnage et chargement au runtime (`failStrategy` définit
le comportement en cas d'échec de chargement - fail-open ou fail-close).

## Vérification du résultat

Lancez sur le worker PC :

```bash
check_result
```

## Bilan

Vous avez étendu le data plane avec votre propre module Wasm, chargé depuis un registre
OCI, et ajouté une authentification Basic à la frontière du maillage sans modifier
l'application. Travailler avec `WasmPlugin` est une compétence senior pour les cas où les
capacités intégrées d'Istio ne suffisent pas.
