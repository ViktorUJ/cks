[Русская версия](APPENDIX_K8S_136_SECURITY_DELTA_RU.md) · [Eng version](APPENDIX_K8S_136_SECURITY_DELTA.md) · [Versión en español](APPENDIX_K8S_136_SECURITY_DELTA_ES.md) · [Deutsche Version](APPENDIX_K8S_136_SECURITY_DELTA_DE.md) · [ქართული ვერსია](APPENDIX_K8S_136_SECURITY_DELTA_GE.md) · [繁體中文版](APPENDIX_K8S_136_SECURITY_DELTA_TW.md) · [日本語版](APPENDIX_K8S_136_SECURITY_DELTA_JP.md)

# Appendice. Kubernetes v1.36 Delta de sécurité

> Marqueur : PRODUCTION / VERSION-SENSITIVE. L'inclusion dans cette annexe ne signifie pas qu'un sujet appartient au pool d'examens CKS actuel. L'instantané officiel de l'examen du cours (voir [`../metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml)) utilise Kubernetes v1.35, tandis que la référence de formation du cours est la v1.36. Vérifiez chaque élément avant de le traiter comme un fait d'examen : certains changements sont importants en production, mais le programme peut être en retard par rapport à une version mineure.

Cette annexe complète les principaux chapitres du cours. Elle rassemble les modifications Kubernetes v1.36 liées à la sécurité en un seul endroit, plutôt que de les répartir dans les 33 chapitres ou de confondre l'actualité de la production avec la fidélité des examens.

## 1. User Namespaces GA

**Pertinence CKS :** Deep Dive / Production.

- `spec.hostUsers: false` place un Pod dans un espace de noms utilisateur : l’utilisateur root à l’intérieur du conteneur est mappée à un UID non privilégié sur l'hôte.
- Il s'agit d'une limite de défense en profondeur supplémentaire, et non d'un remplacement des contrôles existants (capacités, seccomp, AppArmor, RBAC). Voir [chapitre 03](03/fr.md).
- Linux uniquement ; voir le chapitre 03 pour les limitations spécifiques (volumes de blocs bruts, NFS).

## 2. Fine-Grained Kubelet API Authorization GA

**Pertinence CKS :** Core (utilisé dans le [chapitre 05](05/fr.md)).

- Auparavant, `nodes/proxy` était la seule sous-ressource pour presque tous les chemins kubelet API, y compris `/metrics` apparemment sûr et dangereux `/exec`.
- GA introduit des sous-ressources distinctes : `nodes/stats`, `nodes/metrics`, `nodes/log`, `nodes/pods`, `nodes/healthz`, `nodes/configz`, `nodes/spec`, `nodes/checkpoint`.
- Pour `/pods`, `/runningPods/`, `/healthz` et `/configz`, kubelet vérifie d'abord la sous-ressource à granularité fine et revient à `nodes/proxy` en cas de refus pour des raisons de compatibilité descendante.
- **Pourquoi est-ce important pour l'examen de sécurité :** un agent de surveillance avec `nodes/proxy GET` peut être utilisé de manière abusive via la sémantique WebSocket kubelet API pour RCE dans n'importe quel conteneur du nœud. `GET` correspond à RBAC `get`, mais `kubelet` ne vérifie pas séparément `create` pour l'opération d'écriture suivante. Voir le chapitre 05 et son bloc « Perspective de l'attaquant ».
- Source : [Blog Kubernetes v1.36 - Diplômés Fine-Grained Kubelet API Authorization en GA](https://kubernetes.io/blog/2026/04/24/kubernetes-v1-36-fine-grained-kubelet-authorization-ga/).

## 3. Politique d'admission de mutation/validation GA et Manifest-Based Admission Control (alpha)

**Pertinence CKS :** Core pour VAP (utilisé dans le [chapitre 20](20/fr.md)) ; Manifest-Based Admission Control est Deep Dive (alpha, désactivé par défaut).

- La couche de stratégie native basée sur CEL réduit le besoin d’un webhook d’admission supplémentaire pour de nombreuses règles courantes. Elle ne remplace pas Kyverno/Gatekeeper pour la génération, la mutation d'objets complexes ou la vérification d'image de la chaîne d'approvisionnement (voir chapitres 20 et 26).
- Manifest-Based Admission Control (v1.36, alpha) prend en charge les objets d'admission statiques : tous les objets nécessitent un suffixe de nom `.static.k8s.io` ; `paramRef` dans les bindings est interdit ; les webhooks statiques autorisent uniquement `clientConfig.url`, et non `clientConfig.service`. Un manifeste statique non valide peut empêcher le serveur API d'être prêt.

## 4. Service.spec.externalIPs formellement obsolète

**Pertinence CKS :** Production/Deep Dive.

- `externalIPs` est formellement obsolète dans Kubernetes v1.36. Une future version mineure devrait supprimer le comportement de kube-proxy et son exigence de prise en charge des critères de conformité.
- **Raison de sécurité :** ce champ représente depuis longtemps un risque : un utilisateur non privilégié capable de créer/modifier Services peut revendiquer une adresse IP arbitraire sans validation de propriété. Cela crée un risque MITM dans les clusters mutualisés et est directement lié à **CVE-2020-8554** (Homme du milieu utilisant LoadBalancer ou ExternalIPs).
- **Alternative actuelle :** un LoadBalancer Service via un contrôleur cloud/sur site, ou Gateway API au lieu d'une utilisation directe du `externalIPs`.
- Sources : [blog Kubernetes v1.36 - Dépréciation et suppression des adresses IP externes Service](https://v1-36.docs.kubernetes.io/blog/2026/05/14/kubernetes-v1-36-deprecation-and-removal-of-service-externalips/), [avis CVE-2020-8554](https://discuss.kubernetes.io/t/security-advisory-cve-2020-8554-man-in-the-middle-using-loadbalancer-or-externalips/14003).

## 5. Volume gitRepo définitivement désactivé

**Pertinence CKS :** Production/Deep Dive (leçon sur la chaîne d'approvisionnement/les sources mutables).

- Le type de volume `gitRepo` est **définitivement désactivé** dans Kubernetes v1.36 et ne peut pas être réactivé par un feature gate. L’API Kubernetes accepte toujours un Pod avec un volume `gitRepo`, mais kubelet refuse de le démarrer et renvoie une erreur.
- **Raison de sécurité :** le pilote de volume `gitRepo` a exécuté `git clone` dans un processus géré par kubelet sur le nœud sans isolation suffisante. Un référentiel Git spécialement conçu pourrait donc provoquer un RCE via un hook d'écriture pendant `git clone`.
- **Leçon sur la chaîne d'approvisionnement :** un type de volume exécutant du code externe arbitraire lors du provisionnement (même « juste » `git clone`) présente la même classe de risque qu'une balise d'image mutable sans fixation par digest. La confiance est transférée lors de l'exécution à une source externe incomplètement contrôlée au lieu d'être vérifiée au préalable.
- Sources : [Notes de publication d'AWS EKS - Suppression du volume gitRepo](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html), [kubernetes/kubernetes#125983 - Supprimer le type de volume gitRepo](https://github.com/kubernetes/kubernetes/issues/125983).

## 6. Modifications des étiquettes de volume SELinux (réétiquetage au moment du montage)

**Pertinence CKS :** Deep Dive (utilisé dans le [chapitre 18](18/fr.md)).

- Le runtime du conteneur, plutôt que kubelet, effectue un réétiquetage récursif SELinux.
- Pour les PVC avec un mode d'accès autre que `ReadWriteOncePod`, le réétiquetage basé sur le montage (`-o context=`) nécessite le feature gate `SELinuxMount` (désactivée par défaut dans la version 1.36) et `CSIDriver.spec.seLinuxMount: true` sur le pilote CSI particulier. Sinon, un réétiquetage récursif plus lent est utilisé.
- Voir le chapitre 18 pour la distinction entre le réétiquetage récursif et `MountOption`.

## Comment utiliser cette annexe

Avant de citer un élément comme un « fait d’actualité » lors d’un cours ou d’une préparation à un examen :

1. Vérifiez `checked_at` dans [`metadata/tool-compatibility.yaml`](../metadata/tool-compatibility.yaml) et [`metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml).
2. Vérifiez si la fonctionnalité spécifique figure dans le programme actuel (`CKS_Curriculum` PDF). Ne présumez pas que la production actuelle signifie automatiquement pertinente pour l'examen.
3. Si un élément est utilisé comme matériel *de base* dans un laboratoire ou un chapitre (voir [`metadata/curriculum-map.yaml`](../metadata/curriculum-map.yaml)), gardez sa formulation ici et dans ce chapitre synchronisée.

---
[Contenu](README_FR.md)
