[RU version](ru.md) · [Eng version](en.md) · [Versión en español](es.md) · [Deutsche Version](de.md)

# Chapitre 32. L'examen ICA : format et préparation

> **Chapitre final.** Tout au long du cours, nous avons préparé la théorie comme la pratique en vue
> de la certification **Istio Certified Associate (ICA)**. Ici, nous rassemblons comment l'examen est
> structuré, comment s'y préparer et où trouver des passages d'essai - nos mock-examens.

## 32.1. De quel examen s'agit-il

**ICA (Istio Certified Associate)** - une certification de la CNCF et de la Linux Foundation
(initialement développée par Tetrate), qui atteste de la capacité à travailler avec Istio. L'examen
est **en ligne, avec surveillance (proctoring)**, et de format **hybride - des tâches pratiques
(performance-based) plus des questions à choix multiple (multiple-choice)**. Dans la partie pratique,
on vous donne accès à un cluster et on vous demande de résoudre des tâches à la main - configurer le
routage, activer le mTLS, écrire une politique, trouver et réparer un problème ; dans la partie
théorique - on vérifie la compréhension des principes et de la terminologie. Durée - **2 heures**,
environnement mis à jour vers **Istio v1.26**.

Pendant l'examen, l'accès à la documentation officielle est autorisé (istio.io et ses sous-domaines ;
en règle générale, également le blog Istio et la documentation Kubernetes - consultez la liste à jour
des ressources autorisées dans le Candidate Handbook). C'est important : personne ne vous force à
retenir tous les champs YAML par cœur, mais il faut **rapidement** trouver et appliquer ce qu'il faut.

> Les détails exacts (durée, score de réussite, nombre de tâches, règles de repassage) évoluent avec
> le temps et dépendent de la version du programme. Vérifiez toujours sur la page officielle :
> [Istio Certified Associate (ICA)](https://training.linuxfoundation.org/certification/istio-certified-associate-ica).

## 32.2. Domaines et sur quoi mettre l'accent

L'examen est construit par domaines avec des poids. Répartition à jour (après la mise à jour du
programme en août 2025) :

| Domaine | Poids | Chapitres du cours |
|---------|-------|--------------------|
| Traffic Management | 35% | 5-12 |
| Securing Workloads | 25% | 9, 13-16 |
| Installation, Upgrade & Configuration | 20% | 2-4, 22 (ambient) |
| Troubleshooting | 20% | 24, 30 |

Ce qu'il est important de savoir sur le nouveau programme :

- **Il n'y a plus de domaine « Advanced Scenarios » séparé** - ses thèmes ont été redistribués :
  l'installation d'ambient est passée dans Installation, l'egress et la liaison avec des services
  externes - dans Traffic Management.
- **Installation est passé à 20%** et inclut désormais explicitement l'installation **en mode sidecar
  et en mode ambient**, la personnalisation et la mise à niveau (canary/in-place).
- **Traffic Management inclut egress, ingress, resilience** (circuit breaking, failover, outlier
  detection, timeouts, retries) **et fault injection**.
- **Securing Workloads** - autorisation, authentification (mTLS, JWT) et **protection du trafic edge
  par TLS**.
- **Troubleshooting** - configuration, control plane et data plane.

Conclusion : **entraînez surtout la gestion du trafic** (Gateway, VirtualService, DestinationRule,
routage, résilience, egress, fault injection) - c'est le plus grand domaine (35%). Ensuite, les
priorités sont presque à égalité : sécurité (25%), installation/mise à niveau et troubleshooting
(20% chacun) - ne négligez pas l'installation et le débogage, leur poids a nettement augmenté.

## 32.3. Conseils pratiques

L'expérience CKA/CKS se transpose directement :

- **Alias et autocomplétion.** Configurez `alias k=kubectl`, activez la completion pour `kubectl` et
  `istioctl` - cela fait gagner du temps sur chaque tâche.
- **Vérifiez le contexte.** Assurez-vous toujours du cluster et du namespace dans lequel vous
  travaillez (`kubectl config current-context`), surtout s'il y a beaucoup de tâches.
- **Lisez la tâche mot à mot.** Noms de ressources, namespace, ports, versions exacts - une erreur
  dans un nom de subset ou de selector et la règle ne fonctionnera pas (chapitre 5).
- **Vérifiez le résultat.** Après la configuration, lancez `curl` depuis un pod, regardez les codes
  et les en-têtes - assurez-vous que le trafic va réellement là où il faut.
- **`istioctl analyze` est votre ami.** Il attrape vite les erreurs de configuration (chapitre 24).
  En cas de problème - `proxy-status` (SYNCED ?) et `proxy-config`.
- **Gestion du temps.** Ne bloquez pas sur une seule tâche. Sautez une tâche difficile, revenez-y plus
  tard - comme à la CKA.
- **Documentation à portée de main.** Sachez à l'avance où se trouvent dans istio.io les exemples de
  Gateway, VirtualService, PeerAuthentication - à l'examen, vous les copierez de là et les
  adapterez.

## 32.4. Examens d'essai (mock)

La meilleure préparation est de passer des examens réalistes en temps limité. Ce dépôt contient
**deux mock-examens**, imitant le format ICA :

- **Mock 01** - 17 tâches sur des thèmes de base : installation, Gateway/VirtualService,
  AuthorizationPolicy, gestion de l'injection.
  [tasks/ica/mock/01](../../mock/01/README.MD)
- **Mock 02** - 16 tâches sur des patterns avancés : mise à jour canary par l'opérateur, installation
  via Helm, egress gateway, équilibrage au niveau des ports, fault injection, autorisation
  cross-namespace.
  [tasks/ica/mock/02](../../mock/02/README.MD)

Description générale de l'environnement, commandes (`check_result`, `time_left`, `hosts`) et conseils -
dans le README racine de l'infrastructure : [tasks/ica/README.MD](../../README.MD).

Comment utiliser les mocks :

1. Parcourez les chapitres et labs correspondants au thème.
2. Passez le mock **en temps limité**, comme un vrai examen, sans indices.
3. Vérifiez-vous via `check_result`, analysez les erreurs à l'aide des solutions.
4. Répétez jusqu'à tenir avec assurance dans le timing avec un résultat de **70%+**.

Les mocks entraînent la partie **pratique** de l'examen. Mais rappelez-vous que le format est
hybride : il y a aussi des questions à choix multiple sur la compréhension des principes et de la
terminologie. C'est pourquoi, en plus des mocks, révisez la **théorie** par chapitres (ce que fait
chaque ressource, comment fonctionnent le mTLS, le xDS, l'équilibrage par localité) - « je sais faire »
et « je comprends pourquoi c'est ainsi » sont tous deux évalués.

## 32.5. Comment se préparer avec ce cours

Parcours recommandé :

1. **Partie 1 (chapitres 1-24)** - les fondamentaux et tous les domaines de l'examen. Consolidez
   chaque chapitre par un lab (🧪).
2. **Mocks** (chapitre 32.4) - passez-les après la Partie 1, en temps limité.
3. **Partie 2 (chapitres 25-31)** - best practices pour le travail réel. Pas indispensables pour
   l'examen en soi, mais elles font de vous un ingénieur qui comprend Istio en production, et pas
   seulement qui réussit un test.

## 32.6. Résumé

- L'ICA est un examen en ligne surveillé, de format **hybride** : tâches pratiques dans un cluster
  plus questions à choix multiple ; l'accès à la documentation istio.io est autorisé, durée 2 heures,
  environnement v1.26.
- Domaines à jour (depuis août 2025) : **Traffic Management 35%**, Securing Workloads 25%,
  Installation/Upgrade/Config 20%, Troubleshooting 20% ; le domaine « Advanced Scenarios » n'existe
  plus.
- Entraînez surtout la gestion du trafic, mais ne négligez pas l'installation et le troubleshooting -
  leur poids est passé à 20%.
- Transposez les habitudes CKA/CKS : alias, autocomplétion, vérification du contexte, lecture mot à
  mot des tâches, vérification du résultat, gestion du temps.
- Passez **mock 01 et mock 02** en temps limité pour la pratique, et révisez la théorie par chapitres
  (pour la partie multiple-choice) ; visez des 70%+ stables.
- Vérifiez la logistique et les règles exactes (score de réussite, nombre de questions, ressources
  autorisées) sur la page officielle de l'ICA.

---

Le cours s'achève ici. Vous avez parcouru le chemin de l'idée de maillage de services jusqu'à
l'exploitation en production d'Istio : gestion du trafic, résilience, sécurité, observabilité,
scénarios avancés, troubleshooting, migrations réelles, durcissement - et la préparation à l'examen.
Revenez aux chapitres, aux labs et aux mocks au fur et à mesure de vos besoins. Bonne chance avec
l'ICA et avec Istio en situation réelle.

[Table des matières](../README_FR.md) · [Chapitre 31](../31/fr.md)
