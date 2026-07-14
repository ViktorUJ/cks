[RU version](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD)

# Istio Certified Associate (ICA) - Supports de formation

<img src="../../docs/images/ICA.png" alt="Istio Certified Associate" width="200">

Préparation complète pour la certification **Istio Certified Associate (ICA)** : un cours
en autoformation, des travaux pratiques et des examens blancs complets, tout en un seul
endroit.

## Ce qu'il y a dedans

| Partie | Chemin | Ce que c'est |
|------|------|-----------|
| **Cours** | [`course/`](course/README_FR.md) | Cours en autoformation de 32 chapitres : de l'idée du service mesh aux opérations en production |
| **TP** | [`labs/`](labs/) | 35 travaux pratiques sur de vrais clusters AWS, chacun lié à un chapitre du cours |
| **Examens blancs** | [`mock/`](mock/) | 2 examens blancs complets qui simulent la véritable expérience ICA |

Parcours recommandé : étudier un chapitre du cours, le renforcer avec son TP, puis
enchaîner les examens blancs contre le chrono.

## Le cours

Le cours ([`course/README_FR.md`](course/README_FR.md)) compte 32 chapitres, écrits pour
des ingénieurs connaissant déjà Kubernetes (niveau CKA) :

- **Partie 1 (chapitres 1-24)** - fondamentaux et couverture complète des domaines de
  l'examen ICA (gestion du trafic, sécurité, observabilité, scénarios avancés,
  troubleshooting, installation).
- **Partie 2 (chapitres 25-31)** - bonnes pratiques du monde réel : livraison progressive,
  migration sans interruption, Istio sur EKS, multi-cluster, charges de travail VM,
  performance du control plane, durcissement.
- **Préparation à l'examen (chapitre 32)** - format de l'ICA, conseils et liens vers les
  examens blancs.

Chaque chapitre se termine par une section **Pratique** qui renvoie vers le TP
correspondant.

## Les travaux pratiques

35 travaux pratiques (`labs/01` .. `labs/35`), chacun entièrement localisé : anglais
(`README.MD`), russe (`README_RU.MD`), espagnol (`README_ES.MD`), français
(`README_FR.MD`) et allemand (`README_DE.MD`). Ils déploient de vrais clusters sur AWS
via Terragrunt :

```bash
TASK=01 make run_ica_task      # déployer le TP 01
TASK=01 make delete_ica_task   # le détruire
```

Sujets des TP (et le chapitre du cours qui couvre la théorie) :

| TP | Sujet | Chapitre |
|-----|-------|---------|
| 01 | Installation d'Istio, Bookinfo, injection de sidecar | 2 |
| 02 | Dark launch, routage par en-têtes, canary | 5, 6 |
| 03 | Fault injection et retries | 8 |
| 04 | mTLS (PeerAuthentication) + AuthorizationPolicy | 13, 14 |
| 05 | Egress : ServiceEntry, egress gateway, REGISTRY_ONLY | 12 |
| 06 | Répartition de charge + mirroring du trafic | 6, 7 |
| 07 | Installation via Helm + mise à niveau canary (révisions) | 3 |
| 08 | Observabilité : Prometheus/Jaeger/Kiali | 17 |
| 09 | Ambient mode (sans sidecar) | 22 |
| 10 | Résilience : timeout + circuit breaker | 8 |
| 11 | Authentification de l'utilisateur final : RequestAuthentication + JWT | 15 |
| 12 | Troubleshooting avec istioctl | 24 |
| 13 | TLS en périphérie (SIMPLE) | 9 |
| 14 | Failover selon la localité | 7 |
| 15 | Installation et configuration (IstioOperator + MeshConfig) | 2 |
| 16 | Kubernetes Gateway API (Gateway + HTTPRoute) | 11 |
| 17 | Rate limiting local (EnvoyFilter) | 20 |
| 18 | Telemetry API : logs d'accès + traçage | 18 |
| 19 | CA personnalisée dans istiod | 16 |
| 20 | Migration mTLS PERMISSIVE vers STRICT | 13 |
| 21 | Sidecar scoping | 19 |
| 22 | TLS origination | 12 |
| 23 | WasmPlugin (WebAssembly) | 21 |
| 24 | Ambient : waypoint proxy + autorisation L7 | 22 |
| 25 | Livraison progressive avec Flagger | 25 |
| 26 | CA dynamique : cert-manager + istio-csr | 16 |
| 27 | EnvoyFilter + Lua | 21 |
| 28 | Routage TCP | 10 |
| 29 | Ingress TLS : MUTUAL et PASSTHROUGH | 9 |
| 30 | StatefulSet et services headless | 23 |
| 31 | Migration sans interruption : ingress-nginx vers Istio | 26 |
| 32 | gRPC : équilibrage per-request, nommage des ports, retries | 10 |
| 33 | Control plane : performance et exploitation | 30 |
| 34 | Durcissement et modèle de menaces | 31 |
| 35 | Mesh multi-cluster (multi-primary, multi-network) | 28 |

## Examens blancs

Deux examens blancs complets qui reproduisent le format de l'ICA :

- **Mock 01** ([`mock/01`](mock/01/README.MD)) - 17 tâches sur les concepts de base d'Istio.
- **Mock 02** ([`mock/02`](mock/02/README.MD)) - 16 tâches sur des patterns avancés de service mesh.

Enchaînez-les contre le chrono, sans indices, en visant **70%+**.

## Environnement de terminal personnalisé

![Terminal Interface](../../docs/images/cockpit.png)

L'infrastructure fournit un terminal préconfiguré avec des outils et des aides conçus
pour la pratique de l'ICA.

### Commandes disponibles
- **`time_left`** - consulter le temps restant du TP
- **`check_result`** - vérifier l'achèvement de la tâche (`check_result <task>` pour une tâche précise)
- **`hosts`** - afficher les infos de l'ingress gateway (mappings NodePort et IPs)

### Outils préconfigurés (avec autocomplétion bash)
- **`kubectl | k`**, **`istioctl`**, **`helm`**, **`yq`**, **`curl`/`wget`**,
  **`podman`**, **`aws`**

### Accès SSH
```bash
ssh <kubernetes_nodename>
```

## Démarrage rapide

```bash
# vérifier votre score (toutes les tâches ou une en particulier)
check_result
check_result <task_number>

# infos cluster/ingress pour tester l'accès externe
hosts

# temps restant lors d'une session chronométrée
time_left
```

## Ressources autorisées pendant l'examen

Vous pouvez consulter la documentation officielle d'Istio :
**https://istio.io/latest/docs/** et tous ses sous-domaines. Les examens blancs
reproduisent cela.

## Conseils pour réussir

1. **Lisez attentivement les exigences de la tâche** - les noms exacts, les namespaces et
   les specs comptent.
2. **Vérifiez votre contexte** avec `kubectl config current-context`.
3. **Testez votre travail** - utilisez `curl` depuis des pods sleep pour vérifier le
   routage et les politiques.
4. **Utilisez `istioctl analyze`, `proxy-status`, `proxy-config`** pour repérer les
   erreurs de configuration.
5. **Relisez les solutions de référence** après avoir tenté les tâches.

## Pièges courants

- **Hosts dans VirtualService** : pour le trafic entre namespaces, incluez le nom court
  et le FQDN.
- **Sélecteurs de Gateway** : ils doivent correspondre aux labels réels de l'ingress
  gateway.
- **Injection de sidecar** : les pods doivent afficher `2/2` conteneurs.
- **Changement de contexte** : vérifiez le cluster avant d'appliquer des ressources.

---

**Bonne chance pour votre certification ICA !** C'est la pratique qui compte : parcourez
le cours, les TP et les deux examens blancs jusqu'à pouvoir réaliser les tâches en
confiance dans les délais impartis.
