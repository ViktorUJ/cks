[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# KCSA : guide pratique d'autoformation à la sécurité cloud native et Kubernetes

KCSA (Kubernetes and Cloud Native Security Associate) est une certification CNCF et Linux Foundation de niveau associate, pré-professionnelle et conceptuelle, consacrée à la sécurité cloud native et Kubernetes. Le cours s'inscrit dans le parcours KCNA (optional) → KCSA → CKA → CKS : KCSA explique les fondamentaux et les modèles de menaces, CKA apporte la base pratique obligatoire pour CKS, et CKS développe les security skills hands-on. Il n'y a pas de prérequis formels ; il suffit de comprendre les notions de base de `Pod`, `Deployment`, `Service` et `kubectl`.

> **À propos des liens vers CKA et CKS.** L'archive KCSA autonome n'inclut pas les répertoires CKA et CKS. Ainsi, dans la standalone-distribution, les liens internes à KCSA restent cliquables, tandis que les cross-course references vers CKA/CKS sont publiées comme texte ordinaire sans URL relative. Dans un monorepo-build, ils peuvent être générés comme liens fonctionnels vers les cours voisins ou comme stable absolute URLs.

> **Format de l'examen et version des exemples.** KCSA est un examen à choix multiples. Selon les règles de la Linux Foundation vérifiées le 1er septembre 2026, l'examen MCQ standard (multiple choice question, question à choix multiple) comprend 60 questions, dure 90 minutes et exige 75 % pour réussir ; il ne comporte aucune tâche hands-on. Avant votre inscription, vérifiez impérativement à nouveau les exigences actuelles de LF, car ces paramètres peuvent évoluer. Les exemples du cours sont basés sur Kubernetes `v1.36`. Les pondérations actuelles, les sources et l'évolution du programme sont consignées dans la [politique de versions](../VERSION_POLICY.md).

## Organisation du cours

Chaque thème est un répertoire avec un numéro et la source russe canonique `ru.md`. Pour chaque chapitre, les traductions suivantes sont également publiées : English `README.md`, Español `es.md`, Français `fr.md`, Deutsch `de.md`, ქართული `ge.md`, 繁體中文 `tw.md` et 日本語 `jp.md`. Les chapitres sont regroupés par domaines KCSA et identifiés par couleur :

- 🟦 Overview of Cloud Native Security - 14%
- 🟥 Kubernetes Cluster Component Security - 22%
- 🟩 Kubernetes Security Fundamentals - 22%
- 🟪 Kubernetes Threat Model - 16%
- 🟨 Platform Security - 16%
- 🟫 Compliance and Security Frameworks - 10%
- ⬜ introduction, fondamentaux et préparation à l'examen

La pratique KCSA consiste en questions à choix multiple et en mock exams, et non en travaux pratiques. Ce fichier fournit un parcours de préparation unifié et la navigation de l'examen. Les termes sont regroupés dans le [glossaire](GLOSSARY_FR.md).

## Programme officiel de l'examen

| Domaine | Poids |
|---|---:|
| Overview of Cloud Native Security | 14% |
| Kubernetes Cluster Component Security | 22% |
| Kubernetes Security Fundamentals | 22% |
| Kubernetes Threat Model | 16% |
| Platform Security | 16% |
| Compliance and Security Frameworks | 10% |

## Sommaire

### Partie 0. Introduction et fondamentaux ⬜

1. [Introduction : examen KCSA, format, place dans le parcours de certifications, versions](01/fr.md)
2. [Cloud native et pourquoi la sécurité](02/fr.md)

### Partie 1. Overview of Cloud Native Security - 14% 🟦

3. [Les 4C de la sécurité cloud : Cloud, Cluster, Container, Code](03/fr.md)
4. [Sécurité du fournisseur cloud et de l'infrastructure](04/fr.md)
5. [Contrôles, frameworks et techniques d'isolation](05/fr.md)
6. [Sécurité des artefacts, des images et du code](06/fr.md)

### Partie 2. Kubernetes Cluster Component Security - 22% 🟥

7. [Sécurité du control plane : API Server, Controller Manager, Scheduler, Etcd](07/fr.md)
8. [Sécurité du nœud : Kubelet, Container Runtime, KubeProxy](08/fr.md)
9. [Pod, réseau de conteneurs, storage et sécurité côté client](09/fr.md)

### Partie 3. Kubernetes Security Fundamentals - 22% 🟩

10. [Authentification et autorisation](10/fr.md)
11. [Pod Security Standards et Pod Security Admission](11/fr.md)
12. [Secrets](12/fr.md)
13. [Network Policy, isolation et segmentation](13/fr.md)
14. [Audit Logging](14/fr.md)

### Partie 4. Kubernetes Threat Model - 16% 🟪

15. [Frontières de confiance, flux de données et modèle de menaces](15/fr.md)
16. [Catégories de menaces Kubernetes](16/fr.md)

### Partie 5. Platform Security - 16% 🟨

17. [Supply chain, registres d'images et admission control](17/fr.md)
18. [Observability, PKI, connectivity et service mesh](18/fr.md)

### Partie 6. Compliance and Security Frameworks - 10% 🟫

19. [Conformité et frameworks de sécurité](19/fr.md)

### Partie 7. Préparation à l'examen ⬜

20. [Examen KCSA : stratégie, gestion du temps, checklist](20/fr.md)

## Pratique

- 📝 [Mock exams KCSA](../mock) - les Mock 01 et Mock 02 en anglais au format MCQ sont disponibles pour des entraînements autonomes. Les questions sont réparties selon les pondérations des domaines ; aucun lab terragrunt/bats n'est créé pour KCSA.

Commencez par les chapitres 01-02, puis parcourez les domaines dans l'ordre. La tactique finale et la checklist sont regroupées dans le [chapitre 20](20/fr.md).

## Lectures complémentaires

- [Documentation officielle Kubernetes : Security](https://kubernetes.io/docs/concepts/security/)
- [CNCF Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/v2/cloud-native-security-whitepaper.md)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- Le cours CKS est la prochaine étape pour approfondir le hardening pratique et l'investigation.