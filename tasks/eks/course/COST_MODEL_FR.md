[Русская версия](COST_MODEL_RU.md) · [Eng version](COST_MODEL.md) · [Versión en español](COST_MODEL_ES.md) · [Deutsche Version](COST_MODEL_DE.md) · [ქართული ვერსია](COST_MODEL_GE.md) · [繁體中文版](COST_MODEL_TW.md) · [日本語版](COST_MODEL_JP.md)

# Modèle de coûts d'un cluster EKS : modèle d'estimation

[Table des matières du cours](README_FR.md) · [Chapitre 43](43/fr.md) · [Glossaire](GLOSSARY_FR.md)

Ce document de travail accompagne le chapitre 43 : il reprend la même structure de coûts,
mais sous forme de tableau et de formules avec lesquels l'ingénieur établit l'estimation de
son cluster. Il n'apporte aucun nouveau contenu.

## Comment l'utiliser

- Le modèle ne contient PAS de prix. Les tarifs dépendent de la région, évoluent et deviennent
  obsolètes plus rapidement que le cours ; la colonne « Tarif (à renseigner) » est donc laissée
  vide intentionnellement.
- Relevez les tarifs dans AWS Pricing Calculator pour votre région et reportez-les dans la
  colonne vide ; pour le réel d'un cluster déjà en fonctionnement, utilisez Cost and Usage
  Report (chapitre 43).
- La valeur du modèle ne réside pas dans la précision du chiffre, mais dans l'exhaustivité de
  la liste : il évite d'oublier un poste qui apparaîtra sur la facture sans avoir figuré dans
  l'estimation.
- Faites l'estimation deux fois : AVANT le right-sizing et APRÈS. La différence entre les deux
  passages est l'effet mesuré de la décision d'ingénierie, et non une promesse d'économies.
- Conservez les mêmes unités dans tout le modèle (heures par mois, GB ou GiB), sinon les lignes
  ne peuvent pas être additionnées.
- Reprenez le modèle après un changement de mode d'achat des nœuds, l'ajout d'une AZ,
  l'activation de nouveaux types de logs ou toute modification de la topologie d'egress.

## Postes de coûts

| Poste | Dépend de | Unité | Tarif (à renseigner) | Chapitre |
|---|---|---|---|---|
| Control plane du cluster | nombre de clusters, durée de fonctionnement | cluster-heure |  | [02](02/fr.md) |
| Supplément pour extended support | version hors standard support | cluster-heure |  | [38](38/fr.md) |
| Nœuds EC2 | type d'instance, nombre de nœuds, mode d'achat | instance-heure |  | [09](09/fr.md) |
| Supplément de gestion Auto Mode | managed instances sous Auto Mode | instance-heure |  | [09](09/fr.md) |
| Fargate : vCPU | CapacityProvisioned du pod, durée de vie | vCPU-heure |  | [15](15/fr.md) |
| Fargate : mémoire | CapacityProvisioned du pod, durée de vie | GB-heure |  | [15](15/fr.md) |
| Volumes EBS | type de volume, taille, IOPS et throughput provisionnés | GiB-mois |  | [23](23/fr.md) |
| Snapshots EBS | volume de données sauvegardées, durée de conservation | GiB-mois |  | [23](23/fr.md) |
| NAT Gateway : fonctionnement | nombre de NAT (un par AZ), durée d'existence | NAT-heure |  | [31](31/fr.md) |
| NAT Gateway : traitement | egress des pods, pull d'images, appels AWS API | GB |  | [31](31/fr.md) |
| Trafic cross-AZ | trafic east-west entre zones, accès à une base dans une autre AZ | GB |  | [31](31/fr.md) |
| Trafic sortant vers Internet | réponses aux clients, export vers l'extérieur | GB |  | [31](31/fr.md) |
| Interface endpoints (PrivateLink) | nombre d'endpoints, volume traité | endpoint-heure et GB |  | [31](31/fr.md) |
| Logs : ingestion | volume de logs de pods et de control plane ingéré | GB |  | [34](34/fr.md) |
| Logs : stockage | volume selon la rétention définie | GB-mois |  | [34](34/fr.md) |
| Load balancers (NLB, ALB) | nombre de load balancers, volume traité | heure et volume |  | [26](26/fr.md) |

Les gateway endpoints pour S3 et DynamoDB ne nécessitent pas de ligne dans ce tableau : ils
sont gratuits, mais détournent du volume du NAT payant et influent donc sur la ligne « NAT
Gateway : traitement » (chapitre 31).

## Formules générales

```text
Notations : HOURS - heures dans le mois calculé, RATE_* - tarif issu du tableau ci-dessus,
toutes les valeurs de consommation proviennent des métriques et de la facturation, non des plans de conception.

control_plane = CLUSTERS * HOURS * RATE_CP
              + CLUSTERS_EXT * HOURS * RATE_CP_EXT_DELTA
# CLUSTERS_EXT - clusters sur une version en extended support : c'est le SUPPLÉMENT au tarif
# horaire normal du cluster, et non le même tarif (chapitre 38).

nodes = somme sur les pools P : NODES[P] * HOURS[P] * RATE_INSTANCE[P, mode d'achat]
# modes d'achat : On-Demand, Spot, couverture Reserved ou Savings Plans (chapitre 43).

auto_mode = nodes(pools Auto Mode)                         # partie EC2
          + MANAGED_INSTANCES * HOURS * RATE_AM_MGMT       # supplément de gestion
# IMPÉRATIF : Reserved Instances et Savings Plans réduisent UNIQUEMENT la partie EC2.
# Le supplément de gestion Auto Mode ne bénéficie PAS de ces remises et apparaît sur la facture
# comme une ligne distincte (chapitre 09). Le tarif horaire du control plane EKS ne relève pas
# non plus de Compute Savings Plans (chapitre 43).

fargate = somme sur les pods : VCPU_PROV * LIFETIME_H * RATE_VCPU
        + MEM_PROV_GB * LIFETIME_H * RATE_MEM
# VCPU_PROV et MEM_PROV_GB sont la combinaison allouée par l'annotation CapacityProvisioned,
# c'est-à-dire les requests arrondies vers le haut, et non les requests elles-mêmes (chapitre 15).

commit_base = BASELINE_COMPUTE - SPOT_SUSTAINED
# BASELINE_COMPUTE se calcule APRÈS le right-sizing, sinon on s'engage sur du vide.
# SPOT_SUSTAINED est la part Spot atteignable de manière durable, et non celle prévue : Savings Plans
# ne couvrent pas Spot, l'engagement horaire ne se reporte pas d'une heure à l'autre et le reliquat non utilisé
# est perdu chaque heure, tandis qu'un fallback sur On-Demand replace une partie de la consommation sous engagement
# (chapitres 43 et 13). Réévaluez l'engagement sur la base de l'utilisation et de la couverture réelles.

nat = NAT_COUNT * HOURS * RATE_NAT_HOUR
    + PROCESSED_GB * RATE_NAT_GB
# Deux composantes indépendantes : l'existence du NAT et chaque gigaoctet traité.

cross_az = CROSS_AZ_GB * RATE_CROSS_AZ
# Facturé dans les deux sens : CROSS_AZ_GB inclut la requête comme la réponse (chapitre 31).

storage = somme sur les volumes : SIZE_GIB * RATE_VOLUME[type]
        + SNAPSHOT_GIB * RATE_SNAPSHOT
# La taille provisionnée du volume est facturée, pas l'espace occupé à l'intérieur du système de fichiers.

logs = INGEST_GB * RATE_INGEST + STORED_GB * RATE_STORAGE
# INGEST_GB est le volume ingéré : c'est généralement le poste principal (chapitre 34).

total_month = control_plane + nodes + auto_mode + fargate
            + nat + cross_az + egress_internet + storage + logs
            + endpoints + load_balancers
```

## Ce qui est généralement oublié

- **Supplément Auto Mode.** C'est une ligne distincte de la facture, en plus du tarif EC2, et
  les modèles de remise ne s'y appliquent pas ; pour comparer Auto Mode à votre propre stack,
  calculez-le explicitement (chapitre 09).
- **Extended support comme supplément.** Un cluster sur une version obsolète coûte davantage
  par heure de fonctionnement, et non le même montant ; c'est un terme distinct dans
  l'estimation (chapitre 38).
- **Cross-AZ dans les deux sens.** Un service dans une zone qui appelle une base dans une
  autre paie l'échange, et non uniquement la requête ; comptez les deux directions (chapitre 31).
- **NAT facture deux fois.** Le tarif horaire s'applique tant que le NAT existe et chaque
  gigaoctet traité est facturé indépendamment ; c'est généralement la seconde partie qui est
  oubliée (chapitre 31).
- **Les logs coûtent principalement à l'ingestion.** Réduire la rétention ne touche que le
  stockage et apporte peu d'économies ; agissez sur l'intervalle de collecte, les niveaux de
  journalisation et le filtrage des séries (chapitre 34).
- **Volumes et snapshots oubliés.** Le PVC a été supprimé, mais le volume est resté ; les
  snapshots s'accumulent durant des années. C'est une fuite silencieuse visible uniquement dans
  la facturation (chapitre 23).
- **Load balancer après la suppression du service.** Le Service a été supprimé autrement que
  via Kubernetes, mais le NLB ou l'ALB continue d'exister et d'être facturé (chapitre 26).
- **Capacité inactive.** Vous payez les requests réservées, pas l'utilisation réelle : l'écart
  entre requested et used est du vide payé, multiplié par les répliques (chapitre 43).

## Ordre d'optimisation

1. **Right-size et bin-pack** - alignez les requests sur la consommation réelle et laissez la
   consolidation densifier les nœuds (chapitres 43, 14, 12).
2. **Engagement sur le baseline stabilisé** - appliquez les Savings Plans au volume qui reste
   stable pendant des mois, après la réduction (chapitre 43).
3. **Spot pour les charges flexibles** - déplacez les charges interruptibles vers Spot, avec
   diversification par types et par zones (chapitre 13).
4. **Trafic, logs et stockage** - gateway endpoint pour S3, NAT par zone, volume des logs à la
   source, volumes et snapshots (chapitres 31, 34, 23).

Cet ordre est important, car chaque étape suivante s'applique à une base réduite par la
précédente : s'engager ou passer en Spot sur un volume gonflé revient à figer le paiement du vide.

## Limites du modèle

- Le modèle ne remplace pas AWS Pricing Calculator pour la prévision ni Cost and Usage Report
  pour le réel : il fournit la liste des postes et les formules, les chiffres viennent de ces outils.
- Les services applicatifs hors du cluster (bases de données, files, caches, S3 pour les données
  applicatives) ne sont pas comptés ici, bien qu'ils figurent dans la facture du produit.
- L'allocation par équipe et namespace se fait avec l'outil d'allocation du chapitre 43, et non
  avec ce tableau : il concerne le cluster entier, pas la part dépensée par chacun à l'intérieur.
- Le modèle affiche les coûts partagés (control plane, namespaces système, idle) comme lignes du
  cluster ; la règle de leur répartition entre équipes est choisie séparément (chapitre 43).
- Le modèle ne représente pas les remises négociées avec AWS ni l'ordre d'application des
  engagements : ils ne sont visibles que dans la facturation réelle.
