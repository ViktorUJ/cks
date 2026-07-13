[RU version](ru.md) · [Eng version](en.md) · [Versión en español](es.md) · [Deutsche Version](de.md)

# Chapitre 11. Kubernetes Gateway API

> **Ce qui suit.** Dans les chapitres 5-10, nous gérions le trafic via des ressources Istio :
> Gateway et VirtualService. Mais un standard commun pour la même chose est apparu dans
> Kubernetes - Kubernetes Gateway API. Istio le prend pleinement en charge et le considère comme
> l'avenir de l'ingress. Dans ce chapitre, nous verrons ce que c'est, le comparerons aux
> ressources Istio et, surtout, comprendrons quoi utiliser et quand.

## 11.1. Pourquoi un standard distinct est devenu nécessaire

Les ressources `Gateway` et `VirtualService` de `networking.istio.io` fonctionnent très bien,
mais elles ont un inconvénient : c'est une API **spécifique à Istio**. Si demain vous décidez de
changer de maillage ou de contrôleur d'ingress, tous les manifestes devront être réécrits pour un
autre produit. Chaque solution (Istio, nginx, Traefik, gateways cloud) avait son propre ensemble
de ressources.

La communauté Kubernetes a résolu ce problème avec un standard unique - **Kubernetes Gateway
API** (`gateway.networking.k8s.io`). C'est une API indépendante des fournisseurs pour gérer le
trafic entrant, que de nombreux produits implémentent, dont Istio. Vous écrivez une fois selon le
standard - et cela fonctionne sur n'importe quelle implémentation compatible.

Prévenons tout de suite d'une confusion dans les noms. Il existe deux ressources différentes avec
le mot `Gateway` :

- `Gateway` de `networking.istio.io` - une ressource Istio (nous l'avons utilisée depuis le
  chapitre 5).
- `Gateway` de `gateway.networking.k8s.io` - une ressource du standard Kubernetes Gateway API.

Ce sont des API différentes avec des structures différentes. Par la suite, par « Gateway API »
nous entendrons précisément la seconde, la standard.

## 11.2. Rôles et ressources de Gateway API

Dans Gateway API, la responsabilité est répartie entre plusieurs ressources, chacune pour son
rôle :

| Ressource | Responsable de | Équivalent dans Istio |
|--------|-------------|----------------|
| `GatewayClass` | le type d'implémentation (qui traite le trafic) | défini à l'installation |
| `Gateway` | quoi écouter : ports, protocoles, TLS | Istio `Gateway` |
| `HTTPRoute` | les règles de routage HTTP | Istio `VirtualService` |

Outre `HTTPRoute`, il existe d'autres routes pour différents protocoles : `TCPRoute`, `TLSRoute`,
`GRPCRoute`. L'idée est la même que dans Istio : d'un côté « ce qu'on écoute » (Gateway), de
l'autre « où l'on dirige » (Route).

## 11.3. Installation des CRD de Gateway API

Un point pratique important, sur lequel on trébuche souvent : les ressources de Gateway API sont
des **CRD, qui par défaut peuvent ne pas être présentes dans le cluster**. Istio implémente le
standard, mais les définitions elles-mêmes (`GatewayClass`, `Gateway`, `HTTPRoute`…) doivent être
installées soit par la communauté, soit par Istio. Si les CRD ne sont pas installées, vos
manifestes ne s'appliqueront tout simplement pas.

Vérifier la présence :

```bash
kubectl get crd gateways.gateway.networking.k8s.io
```

Si les CRD ne sont pas là, installez-les depuis la release officielle du standard (le canal
`standard` contient les ressources stables, `experimental` - en plus `TCPRoute`/`TLSRoute` et
autres) :

```bash
kubectl apply -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

Istio installe automatiquement une `GatewayClass` nommée `istio` lors de l'installation (istiod
surveille les CRD et crée la classe). Vérifier que la classe est en place :

```bash
kubectl get gatewayclass istio
```

## 11.4. Gateway et HTTPRoute par l'exemple

Montons un gateway sur le port 80 et dirigeons tout le trafic vers le service `reviews`.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: istio    # cette implémentation est fournie par Istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: reviews-route
spec:
  parentRefs:
  - name: my-gateway         # à quel Gateway la route est rattachée
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: reviews          # directement le nom du Kubernetes Service
      port: 8080
```

```mermaid
flowchart LR
    C["Client"] --> GW["Gateway<br>class: istio"]
    GW --> HR["HTTPRoute<br>règles de routes"]
    HR --> S["Service reviews"]
    style C fill:#673ab7,color:#fff
    style GW fill:#326ce5,color:#fff
    style HR fill:#326ce5,color:#fff
    style S fill:#0f9d58,color:#fff
```

Champs clés :

- **`gatewayClassName: istio`** - indique que ce Gateway est implémenté par Istio. C'est
  l'équivalent de la manière dont, dans un Istio Gateway, nous nous rattachions à l'ingress
  gateway via `selector`.
- **`parentRefs`** dans HTTPRoute relie la route à un Gateway concret. Dans Istio, ce rôle était
  joué par le champ `gateways` du VirtualService.
- **`backendRefs`** pointe directement vers un Kubernetes Service et un port. Il n'y a ni subsets
  ni DestinationRule dans le Gateway API de base - les versions et les politiques se décrivent
  autrement.

Autre commodité : lorsque vous créez un `Gateway` avec `gatewayClassName: istio`, Istio peut
déployer automatiquement pour ce gateway un déploiement Envoy distinct. Pas besoin d'installer à
l'avance un ingress gateway - il apparaît pour ce Gateway concret.

## 11.5. TLS : HTTPS sur Gateway API

L'edge TLS du chapitre 9 se décrit dans Gateway API avec ses propres champs. Un listener HTTPS se
déclare avec `protocol: HTTPS` et un bloc `tls`, où figurent le mode et la référence au Secret
contenant le certificat :

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: istio-system
spec:
  gatewayClassName: istio
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    hostname: myapp.example.com
    tls:
      mode: Terminate                # le gateway termine TLS (équivalent de SIMPLE dans Istio)
      certificateRefs:
      - kind: Secret
        name: myapp-cert             # le même Secret tls qu'au chapitre 9
    allowedRoutes:
      namespaces:
        from: All                    # quels namespaces peuvent rattacher des routes (voir 11.7)
```

Correspondance des modes avec le chapitre 9 :

- **`mode: Terminate`** - le gateway déchiffre TLS (comme `SIMPLE`/`MUTUAL` dans Istio). Le
  certificat client (équivalent de `MUTUAL`) se configure via `frontendValidation`/
  `BackendTLSPolicy` et dépend de la version du standard.
- **`mode: Passthrough`** - le gateway ne déchiffre pas, le trafic passe de bout en bout par SNI
  (comme `PASSTHROUGH`) ; pour lui, on utilise `TLSRoute`, et non `HTTPRoute`.

Le certificat est stocké dans un `Secret` Kubernetes ordinaire de type `tls` - il peut de la même
manière être émis par cert-manager (chapitre 9), la route y fait simplement référence maintenant
via `certificateRefs`, et non via `credentialName`.

## 11.6. Canary et filtres dans HTTPRoute

La répartition pondérée du trafic (canary du chapitre 6) dans Gateway API est une possibilité
**standard**, et non une extension : `backendRefs` possède un champ `weight`.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: reviews-canary
spec:
  parentRefs:
  - name: my-gateway
  rules:
  - backendRefs:
    - name: reviews-v1       # 90% du trafic vers v1
      port: 8080
      weight: 90
    - name: reviews-v2       # 10% vers v2
      port: 8080
      weight: 10
```

Notez bien : dans Gateway API, il n'y a ni subsets ni DestinationRule, c'est pourquoi les
différentes versions sont des **Kubernetes Services distincts** (`reviews-v1`, `reviews-v2`), et
non un subset d'un seul service.

HTTPRoute sait modifier les requêtes via des **filtres** (`filters`) - c'est l'équivalent d'une
partie des possibilités du VirtualService :

```yaml
  rules:
  - filters:
    - type: RequestHeaderModifier      # ajouter/retirer des en-têtes
      requestHeaderModifier:
        add:
        - name: x-env
          value: prod
    - type: RequestMirror              # mirroring du trafic (chapitre 6)
      requestMirror:
        backendRef:
          name: reviews-shadow
          port: 8080
    backendRefs:
    - name: reviews
      port: 8080
```

Types de filtres utiles : `RequestHeaderModifier`/`ResponseHeaderModifier` (en-têtes),
`RequestRedirect` (redirections, y compris HTTP→HTTPS), `URLRewrite` (réécriture du chemin/de
l'hôte), `RequestMirror` (mirroring). En revanche, **fault injection** n'existe pas dans le
standard - cela reste exclusif à l'API Istio (chapitre 8).

## 11.7. Routes entre namespaces : allowedRoutes et ReferenceGrant

Un point fort de Gateway API est la séparation explicite et sûre des droits entre namespaces. Il y
a ici deux mécanismes.

**`allowedRoutes` sur un listener** - le Gateway décide lui-même depuis quels namespaces il est
autorisé à rattacher des routes (`from: Same` - uniquement le sien, `All` - n'importe lequel,
`Selector` - par labels de namespace) :

```yaml
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            team: frontend      # uniquement les routes des namespaces avec ce label
```

**`ReferenceGrant`** - lorsqu'une ressource d'un namespace fait référence à une ressource dans un
**autre** (par exemple, un HTTPRoute dans `apps` veut envoyer du trafic vers un Service dans
`data`), c'est interdit par défaut. L'autorisation est délivrée par un `ReferenceGrant` dans le
namespace **cible** :

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-apps-to-data
  namespace: data              # namespace où se trouve le Service cible
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: apps            # qui fait référence
  to:
  - group: ""
    kind: Service              # ce à quoi on autorise à faire référence
```

Cela protège contre le fait qu'une route étrangère « détourne » le trafic vers un service de
votre namespace sans votre consentement - dans l'API Istio, il n'existe pas de mécanisme intégré
de ce genre.

## 11.8. Comparaison avec l'API Istio

| | API Istio | Kubernetes Gateway API |
|---|-----------|------------------------|
| Ressources d'entrée | `Gateway` + `VirtualService` | `Gateway` + `HTTPRoute` |
| Rattachement de la route | champ `gateways` dans VirtualService | `parentRefs` dans Route |
| Choix de l'implémentation | `selector` sur l'ingress gateway | `gatewayClassName` |
| Versions/subsets | `DestinationRule` (subsets) | Services distincts + `weight` dans `backendRefs` |
| Canary par poids | `VirtualService` weight | `backendRefs.weight` (natif) |
| Mirroring | `VirtualService` mirror | filtre `RequestMirror` (natif) |
| Fault injection | oui | non (Istio uniquement) |
| Politiques vers le backend | `DestinationRule` (LB, circuit breaking) | non (Istio uniquement) |
| Séparation des droits par namespace | pas d'intégré | `allowedRoutes` + `ReferenceGrant` |
| Standard | spécifique à Istio | commun, indépendant des fournisseurs |
| Portabilité | Istio uniquement | tout ingress/maillage compatible |

Principale conclusion de ce tableau : Gateway API l'emporte en standardisation, portabilité et
séparation des droits entre équipes, tandis que l'API Istio l'emporte en complétude des
possibilités côté destinataire (`DestinationRule` : répartition de charge, circuit breaking,
subsets) et en fault injection. Le mirroring et le canary par poids existent dans les deux API.

## 11.9. Quoi utiliser et quand (bonnes pratiques)

Recommandations pratiques sur ce qu'il faut choisir dans les projets réels.

**Prenez Kubernetes Gateway API quand :**

- vous démarrez un nouveau projet et voulez être sur le standard actuel ;
- la portabilité est importante : vous ne voulez pas vous lier à Istio au niveau des manifestes ;
- vous avez besoin d'une répartition claire des responsabilités entre équipes (l'équipe
  plateforme possède le `Gateway`, les équipes produit - leurs propres `HTTPRoute`) ;
- les possibilités de routage standard suffisent (par chemin, en-têtes, poids) ;
- vous travaillez avec le **mode ambient** : les proxys waypoint (chapitre 22) se configurent
  précisément via Gateway API.

**Restez sur l'API Istio (VirtualService/DestinationRule) quand :**

- vous avez besoin de fonctionnalités absentes du standard : **fault injection** (chapitre 8),
  politiques `DestinationRule` (répartition de charge fine, circuit breaking, outlier detection,
  subsets), délégation de routes ;
- vous avez déjà de nombreux manifestes fonctionnels sur l'API Istio et aucune raison de les
  réécrire.

(Le mirroring et le canary par poids existent dans les deux API, il n'est donc pas nécessaire de
migrer ou de rester pour eux.)

### La ressource Kubernetes Ingress classique (legacy)

Il existe une troisième option d'entrée - le `Ingress` Kubernetes ordinaire
(`networking.k8s.io/v1`), celui-là même qu'on utilisait avec nginx-ingress, Traefik et les
contrôleurs cloud. Istio sait en être le contrôleur d'ingress : l'istio ingress gateway lit les
ressources `Ingress` si elles indiquent la classe `istio`.

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: istio
spec:
  controller: istio.io/ingress-controller
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: reviews-ingress
  namespace: app
spec:
  ingressClassName: istio          # servi par l'istio ingress gateway
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /reviews
        pathType: Prefix
        backend:
          service:
            name: reviews
            port:
              number: 8080
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-cert          # Secret tls, comme au chapitre 9
```

Pourquoi c'est **legacy** et pourquoi il ne faut pas le choisir pour du nouveau trafic :

- Le standard `Ingress` lui-même a un ensemble de possibilités très pauvre : hôte, chemin, TLS -
  et c'est tout. Aucun poids, mirroring, redirection, split par en-têtes.
- Tout ce qui va au-delà se réalise par des **annotations non standard** du contrôleur (comme
  chez nginx, chapitre 26). Les annotations sont incompatibles entre contrôleurs, et Istio ne
  prend en charge qu'un petit sous-ensemble - la plupart des habituelles
  `nginx.ingress.kubernetes.io/*` ne fonctionnent pas.
- L'évolution de l'industrie et d'Istio lui-même va dans le sens de Gateway API, qui est
  précisément conçu comme le « `Ingress` de nouvelle génération ».

Conclusion pratique : le `Ingress` classique dans Istio ne se conserve que pour la compatibilité
avec d'anciens manifestes lors d'une migration (chapitre 26). Pour un nouvel ingress, prenez
Kubernetes Gateway API ou, si vous avez besoin des fonctionnalités Istio, - Istio `Gateway` +
`VirtualService`.

**Règles générales :**

- Ne décrivez pas la même route à la fois via VirtualService et via HTTPRoute - c'est source de
  confusion et de conflits. Pour un même service, choisissez l'un ou l'autre.
- L'API Istio ne disparaît pas et est pleinement prise en charge, la migration peut donc être
  progressive : les nouveaux services sur Gateway API, les anciens restent tels quels.
- La direction du mouvement de l'industrie va vers Gateway API, il vaut donc la peine de le
  connaître et de le maîtriser, même si aujourd'hui l'essentiel de votre trafic est sur l'API
  Istio.

## 11.10. Résumé du chapitre

- Kubernetes Gateway API (`gateway.networking.k8s.io`) est un standard indépendant des
  fournisseurs pour la gestion du trafic entrant ; Istio l'implémente.
- Ne confondez pas l'Istio `Gateway` et le `Gateway` de Gateway API - ce sont des ressources
  différentes.
- Rôles dans Gateway API : `GatewayClass` (implémentation), `Gateway` (quoi écouter), `HTTPRoute`
  et autres Route (où diriger).
- Rattachement de la route au gateway - via `parentRefs`, choix de l'implémentation - via
  `gatewayClassName: istio`.
- Les CRD de Gateway API peuvent ne pas être présentes par défaut - on les installe séparément
  (canal `standard`), et `GatewayClass istio`, Istio la crée lui-même.
- TLS : listener HTTPS avec `tls.mode: Terminate`/`Passthrough` et référence au Secret via
  `certificateRefs` (équivalent de `credentialName`) ; les certificats sont de même émis par
  cert-manager.
- Canary par poids (`backendRefs.weight`, mais les versions sont des Services distincts) et
  mirroring (filtre `RequestMirror`) sont natifs ; fault injection et politiques `DestinationRule`
  - uniquement dans l'API Istio.
- Séparation des droits entre namespaces : `allowedRoutes` sur un listener et `ReferenceGrant`
  pour les références cross-namespace - il n'y a pas d'équivalent intégré dans l'API Istio.
- Bonne pratique : Gateway API pour le nouvel ingress, les scénarios standard et ambient ; l'API
  Istio - quand on a besoin de fault injection ou des politiques DestinationRule ; ne pas mélanger
  les deux pour une même route.
- Le `Ingress` Kubernetes classique (`ingressClassName: istio`), Istio le sert aussi, mais c'est
  du legacy : les possibilités sont pauvres, l'avancé passe par des annotations non standard
  (petit sous-ensemble). On le conserve pour la compatibilité lors d'une migration, on ne le
  choisit pas pour du nouveau trafic.

## 11.11. Questions d'auto-évaluation

1. Quel problème Kubernetes Gateway API résout-il par rapport à l'API Istio ?
2. En quoi diffèrent les deux ressources nommées `Gateway` ?
3. Quelles ressources de Gateway API correspondent à Istio Gateway et VirtualService ?
4. De quoi sont responsables `gatewayClassName` et `parentRefs` ?
5. Dans quels cas vaut-il mieux rester sur Istio VirtualService/DestinationRule ? Quelles
   fonctionnalités manquent dans Gateway API ?
6. Pourquoi ne faut-il pas décrire une même route simultanément dans les deux API ?
7. Comment configurer HTTPS et le canary par poids dans Gateway API ? En quoi le canary
   diffère-t-il d'Istio (qu'en est-il des subsets) ?
8. À quoi servent `allowedRoutes` et `ReferenceGrant` ? Quel problème de sécurité résolvent-ils ?
9. Que vérifier si les manifestes Gateway API ne s'appliquent pas dans le cluster ?
10. Istio peut-il servir un `Ingress` Kubernetes classique et pourquoi le considère-t-on comme
    legacy ? Quand l'utilise-t-on tout de même ?

## Pratique

Configurez l'ingress via Kubernetes Gateway API (Gateway + HTTPRoute) :

🧪 Lab 16 : [tasks/ica/labs/16](../../labs/16/README_FR.MD)

---
[Table des matières](../README_FR.md) · [Chapitre 10](../10/fr.md) · [Chapitre 12](../12/fr.md)
