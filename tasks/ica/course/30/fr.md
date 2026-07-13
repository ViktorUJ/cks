[RU version](ru.md) · [Eng version](en.md) · [Versión en español](es.md) · [Deutsche Version](de.md)

# Chapitre 30. Performance du control plane et exploitation

> **La suite.** Nous avons parcouru le chemin des fondamentaux jusqu'au multicluster et aux VM. Ce
> chapitre clôt le bloc exploitation : comment fonctionne le control plane, de quoi dépend sa
> performance, quoi monitorer, comment tuner et comment garder le maillage sain en production. Il
> reste encore deux chapitres - le durcissement et le modèle de menaces (chapitre 31) et la
> préparation à l'examen ICA (chapitre 32).

## 30.1. Fonctionnement du control plane et ce qui influe sur la performance

Rappelons le chapitre 4 : istiod (control plane) ne traite pas le trafic lui-même. Sa tâche est de
surveiller l'état du cluster (services, pods, vos configs) et de **diffuser la configuration à jour**
à tous les Envoy via xDS. C'est précisément ce travail qui charge le control plane.

```mermaid
flowchart LR
    E["changement<br>(pod / config)"] --> D["debounce / batching"]
    D --> C["istiod recalcule"]
    C --> P["push via xDS à tous les proxys"]
    style E fill:#673ab7,color:#fff
    style D fill:#f4b400,color:#000
    style C fill:#326ce5,color:#fff
    style P fill:#0f9d58,color:#fff
```

Sur la performance d'istiod influent :

- **Le nombre de services et de pods** - plus il y en a, plus il faut calculer et envoyer de
  configuration.
- **La fréquence des changements (churn)** - chaque nouveau pod, chaque modification de service ou de
  règle déclenche un recalcul et une diffusion.
- **Le nombre de proxys connectés** - il faut livrer la config à chacun.
- **La taille de la configuration par proxy** - si chaque sidecar connaît tout le maillage (chapitre
  19), le volume croît de façon quadratique.

## 30.2. Monitoring du control plane

istiod doit être monitoré séparément des applications. Repérez-vous à ses « signaux dorés » :

- **Latence de propagation de la config** - `pilot_proxy_convergence_time`. Le signal principal :
  combien de temps un changement met à parvenir aux proxys. Une hausse est le premier signe que le
  control plane ne suit pas.
- **Pushes et erreurs** - `pilot_xds_pushes` (nombre de diffusions) et les compteurs de
  configurations rejetées / erreurs xDS. Une flambée d'erreurs signale des problèmes de configuration
  ou de connexion.
- **Proxys connectés** - combien d'Envoy sont connectés à istiod.
- **Saturation** - CPU et mémoire d'istiod. S'il bute sur ses limites, toute la propagation de la
  config en souffre.

Ces métriques sont la base des alertes sur le control plane (chapitre 17). Les proxys en
fonctionnement continuent de fonctionner même quand istiod est indisponible (sur la dernière config
reçue), mais les nouveaux changements n'arriveront pas - c'est pourquoi la santé d'istiod est
critique.

**Vérifie ton travail.** Requêtes PromQL de base sur les signaux dorés d'istiod :

```promql
# p99 du temps de convergence de la config (sec) - le signal principal
histogram_quantile(0.99, sum(rate(pilot_proxy_convergence_time_bucket[5m])) by (le))

# fréquence des pushes xDS par type (cds/eds/lds/rds)
sum(rate(pilot_xds_pushes[5m])) by (type)

# configurations rejetées - doit être à 0
sum(rate(pilot_total_xds_rejects[5m]))

# combien de proxys sont connectés à istiod
pilot_xds
```

Une hausse du p99 de convergence ou un `pilot_total_xds_rejects` non nul est un signal à
investiguer : surcharge d'istiod, config corrompue ou problèmes de connexion.

## 30.3. Tuning de la performance

Les principaux leviers (nous en avons déjà mentionné beaucoup) :

- **discovery selectors** (chapitre 19) - istiod ne suit que les namespace nécessaires, en ignorant
  les autres. Le gain le plus important si une partie du cluster n'est pas dans le maillage.
- **Sidecar scope** (chapitre 19) - chaque proxy ne reçoit la config que des services dont il a
  besoin, et non de tout le maillage. Réduit fortement le volume de configuration et la charge sur
  istiod.
- **Batching et debounce des événements** - istiod ne diffuse pas la config au moindre soubresaut,
  mais groupe les changements sur un court intervalle (debounce) et throttle la fréquence des pushes.
  Ces paramètres (par exemple `PILOT_DEBOUNCE_AFTER`, `PILOT_PUSH_THROTTLE`) se règlent selon la
  charge : plus de batching - moins de pushes, mais une latence de propagation un peu plus élevée.
- **Ressources et HA d'istiod** (chapitre 27) - plusieurs répliques + HPA, assez de CPU/mémoire.
- **Réduction du churn** - moins de changements superflus (par exemple, ne pas toucher aux configs
  sans nécessité) = moins de recalculs.

Les paramètres de batching se définissent comme des variables d'environnement d'istiod - dans
`IstioOperator` via `components.pilot.k8s.env` :

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  components:
    pilot:
      k8s:
        env:
        - name: PILOT_DEBOUNCE_AFTER      # attendre le silence avant de recalculer
          value: "100ms"
        - name: PILOT_DEBOUNCE_MAX        # mais pas plus longtemps que cela
          value: "10s"
        - name: PILOT_PUSH_THROTTLE       # nb max de pushes simultanés
          value: "100"
```

Plus de debounce - moins de recalculs et de pushes lors d'une flambée de changements, mais une
latence de propagation un peu plus élevée (surveillez `pilot_proxy_convergence_time`, section 30.2).
Les valeurs par défaut conviennent à la plupart ; ne les touchez que sciemment, pour un problème
concret.

## 30.4. Politiques de déploiement : OPA Gatekeeper

Dans un grand maillage, il est important que les équipes ne déploient pas de configurations
dangereuses ou cassantes. C'est là qu'aide **OPA Gatekeeper** - un contrôleur d'admission qui vérifie
les ressources à la création (comme le webhook du chapitre 4) et rejette celles qui ne respectent pas
les règles.

Politiques typiques pour Istio :

- exiger le label d'injection (ou `istio.io/rev`) sur les namespace applicatifs ;
- interdire `PeerAuthentication` avec `mode: DISABLE` (pour que personne ne coupe accidentellement le
  mTLS) ;
- exiger que les ports des Service soient correctement nommés (chapitre 10) ;
- interdire des `AuthorizationPolicy` ou `EnvoyFilter` trop larges sans revue.

Gatekeeper transforme les best practices de ce cours en **règles appliquées automatiquement** : non
pas « on a convenu de faire ainsi », mais « sinon ça ne se déploie tout simplement pas ».

Exemple : interdire `PeerAuthentication` avec `mode: DISABLE`. La politique se décrit par deux
ressources - `ConstraintTemplate` (quoi vérifier, en Rego) et `Constraint` (à quoi l'appliquer) :

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: denymtlsdisable
spec:
  crd:
    spec:
      names:
        kind: DenyMtlsDisable
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package denymtlsdisable
      violation[{"msg": msg}] {
        input.review.object.spec.mtls.mode == "DISABLE"
        msg := "PeerAuthentication mode DISABLE interdit par la politique"
      }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: DenyMtlsDisable
metadata:
  name: no-mtls-disable
spec:
  match:
    kinds:
    - apiGroups: ["security.istio.io"]
      kinds: ["PeerAuthentication"]
```

Désormais, tout `PeerAuthentication` avec le mTLS désactivé sera rejeté à l'admission - personne ne
« troue » accidentellement le maillage. Une alternative à Gatekeeper avec une syntaxe YAML plus simple
(sans Rego) est **Kyverno** ; le choix entre les deux revient généralement à l'outil adopté par
l'équipe.

## 30.5. Exploitation sur EKS/AWS

Quelques points spécifiques à EKS qui influent sur le control plane.

- **Monitoring d'istiod via des services managés.** Les signaux dorés d'istiod se stockent
  commodément dans **Amazon Managed Prometheus (AMP)** et se consultent dans **Grafana (AMG)**, les
  métriques étant collectées par l'agent **ADOT** (chapitre 17). istiod peut alors vivre sur
  **Fargate** (chapitre 27) - il est stateless.
- **Karpenter et les nœuds spot augmentent le churn.** L'autoscaling des nœuds (Karpenter) et les
  spot avec leurs interruptions signifient une apparition/disparition fréquente de nœuds et de pods.
  Pour le control plane, c'est une **hausse du churn** : chaque pod recréé engendre des événements
  d'endpoints et de nouveaux pushes xDS. Ce qui aide : une **consolidation** pas trop agressive chez
  Karpenter, un `disruption budget` sur le pool de nœuds, des PDB sur les applications - pour que les
  nœuds ne se « recomposent » pas en permanence. Plus le même scope (chapitre 19), pour qu'une
  flambée de changements dans une partie du cluster ne soit pas diffusée à tous les proxys.
- **Coût de l'observabilité.** Les métriques d'Istio sont à haute cardinalité ; sur un grand cluster
  EKS, la facture d'AMP/du stockage grimpe vite - maîtrisez cela via le Telemetry API (chapitre 18) :
  désactivez les dimensions inutiles, échantillonnez raisonnablement les traces.

## 30.6. Exploitation à l'échelle : checklist

Réunissons les pratiques opérationnelles disséminées dans le cours :

- **Monitorez le control plane** séparément (signaux dorés d'istiod), et pas seulement les
  applications.
- **Optimisez le scope** (discovery selectors + Sidecar) sur les grands clusters - le principal
  levier de performance.
- **Mettez à jour via les révisions/canary** (chapitre 3), et non in-place sur une production vivante.
- **Anticipez la PKI et le CA commun** (chapitres 16, 28), planifiez la rotation de la racine.
- **Gardez des versions unifiées** d'Istio sur les clusters du multicluster (chapitre 28).
- **Automatisez les politiques** via Gatekeeper - les best practices comme règles obligatoires.
- **Observabilité sur tout le maillage** avec des alertes (chapitres 17-18), un échantillonnage
  raisonnable.
- **Répétez les mises à jour et les rollbacks** avant d'en avoir besoin en situation réelle.
- **Ne complexifiez pas prématurément** - ambient, multicluster, VM s'introduisent pour un besoin
  concret, et non « parce qu'on peut ».

## 30.7. Résumé du chapitre

- Le control plane (istiod) ne porte pas le trafic, mais calcule et diffuse la configuration à tous
  les proxys ; c'est bien là sa charge.
- La performance dépend du nombre de services/pods, de la fréquence des changements, du nombre de
  proxys et de la taille de la configuration par proxy.
- Monitorez les signaux dorés d'istiod : temps de propagation de la config
  (`pilot_proxy_convergence_time`), pushes et erreurs, nombre de proxys, CPU/mémoire.
- Tuning : **discovery selectors** et **Sidecar scope** (chapitre 19), batching/throttle des pushes
  (`PILOT_DEBOUNCE_AFTER`/`PILOT_PUSH_THROTTLE` via `IstioOperator`), ressources et HA d'istiod,
  réduction du churn.
- **OPA Gatekeeper** (ou Kyverno) transforme les best practices en règles d'admission obligatoires
  (`ConstraintTemplate` + `Constraint`), par exemple l'interdiction du mTLS `DISABLE`.
- Sur EKS : monitoring d'istiod via AMP/AMG/ADOT, istiod sur Fargate ; **Karpenter/spot** augmentent
  le churn - freinez la consolidation et gardez le scope étroit ; surveillez le coût des métriques à
  haute cardinalité.
- Exploitation à l'échelle : monitoring du control plane, optimisation du scope, mises à jour via les
  révisions, PKI à l'avance, versions unifiées, automatisation des politiques, observabilité de bout
  en bout, répétition des rollbacks, refus de la complexité superflue.

## 30.8. Questions d'auto-évaluation

1. Qu'est-ce qui charge le control plane, s'il ne traite pas le trafic utilisateur ?
2. Quels facteurs influent sur la performance d'istiod ?
3. Nommez les signaux dorés du control plane et ce que signifie une hausse de
   `pilot_proxy_convergence_time`.
4. Quels leviers de tuning de la performance connaissez-vous ? Comment définir les paramètres de
   batching d'istiod ?
5. Qu'apporte OPA Gatekeeper dans le contexte de l'exploitation d'Istio ? De quelles ressources se
   compose une politique et par quoi peut-on la remplacer ?
6. Avec quelles requêtes PromQL vérifieriez-vous la santé du control plane ?
7. Comment Karpenter et les nœuds spot influent-ils sur la charge d'istiod et que faire à ce sujet ?

## Pratique

Exercez-vous à l'exploitation et à la performance : discovery selectors et Sidecar scope, monitoring
des signaux dorés d'istiod, politiques de déploiement via OPA Gatekeeper.

🧪 Lab 33 : [tasks/ica/labs/33](../../labs/33/README_FR.MD)

---
[Table des matières](../README_FR.md) · [Chapitre 29](../29/fr.md) · [Chapitre 31](../31/fr.md)
