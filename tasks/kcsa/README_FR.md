[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# KCSA : Kubernetes and Cloud Native Security Associate - supports de formation

Préparation complète à la certification **Kubernetes and Cloud Native Security Associate (KCSA)** : un cours d'autoformation et des mock exams complets, réunis en un seul endroit.

KCSA est une certification CNCF et Linux Foundation de niveau associate, pré-professionnelle et conceptuelle, consacrée à la sécurité cloud native et Kubernetes. Le cours s'inscrit dans le parcours KCNA (optional) → KCSA → CKA → CKS : KCSA explique les fondamentaux et les modèles de menaces, CKA apporte la base pratique obligatoire pour CKS, et CKS développe les security skills hands-on. Il n'y a pas de prérequis formels ; il suffit de comprendre les notions de base de `Pod`, `Deployment`, `Service` et `kubectl`.

## Contenu du répertoire

| Partie | Chemin | Description |
|------|------|-----------|
| **Cours** | [`course/`](course/README_FR.md) | 20 chapitres d'autoformation couvrant les 6 domaines officiels de KCSA |
| **Mock exams** | [`mock/`](mock/README.md) | 2 mock exams complets de 60 questions au format MCQ |

La pratique KCSA consiste en questions à choix multiple et en mock exams, et non en travaux pratiques. Parcours recommandé : lire les chapitres du cours dans l'ordre, puis passer les deux mock exams dans des conditions de temps proches de l'examen réel.

## Le cours

Le cours ([`course/README_FR.md`](course/README_FR.md)) comprend 20 chapitres, chacun publié en 8 langues : English (`README.md`), Русский (`ru.md`, source canonique), Español (`es.md`), Français (`fr.md`), Deutsch (`de.md`), ქართული (`ge.md`), 繁體中文 (`tw.md`) et 日本語 (`jp.md`). Les chapitres sont regroupés par domaines officiels KCSA :

| Domaine | Poids |
|---|---:|
| Overview of Cloud Native Security | 14% |
| Kubernetes Cluster Component Security | 22% |
| Kubernetes Security Fundamentals | 22% |
| Kubernetes Threat Model | 16% |
| Platform Security | 16% |
| Compliance and Security Frameworks | 10% |

Les termes sont regroupés dans le [glossaire](course/GLOSSARY_FR.md). Les chapitres 1-2 introduisent l'examen et la sécurité cloud native ; le chapitre 20 rassemble la stratégie finale, la gestion du temps et une checklist.

## Mock exams

Deux mock exams complets ([`mock/`](mock/README.md)) simulent l'expérience réelle de KCSA :

- **Mock 01** ([`mock/01`](mock/01/README.md)) - 60 questions réparties selon les domaines.
- **Mock 02** ([`mock/02`](mock/02/README.md)) - un ensemble indépendant de 60 questions, avec la même répartition.

Passez chaque mock en closed-book, en 90 minutes : sans documentation, recherche, notes, outils ni sites externes. Lors de la dernière vérification, la LF Multiple Choice FAQ indiquait un score de réussite de 75 % ou plus ; confirmez les exigences d'inscription actuelles de KCSA auprès de la Linux Foundation avant de vous inscrire.

## Format de l'examen et version du cours

KCSA est un examen à choix multiples : 60 questions, 90 minutes, 75 % pour réussir, aucune tâche hands-on (vérifiez les paramètres actuels auprès de la Linux Foundation avant votre inscription, car ils peuvent évoluer). Les exemples du cours sont basés sur Kubernetes `v1.36`. Les pondérations actuelles, les sources et l'évolution du programme sont consignées dans la [politique de versions](VERSION_POLICY.md).

## Lectures complémentaires

- [Documentation officielle Kubernetes : Security](https://kubernetes.io/docs/concepts/security/)
- [CNCF Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/v2/cloud-native-security-whitepaper.md)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- Le cours CKS est la prochaine étape pour approfondir le hardening pratique et l'investigation.
