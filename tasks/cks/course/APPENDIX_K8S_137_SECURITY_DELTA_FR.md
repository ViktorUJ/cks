[Русская версия](APPENDIX_K8S_137_SECURITY_DELTA_RU.md) · [Eng version](APPENDIX_K8S_137_SECURITY_DELTA.md) · [Versión en español](APPENDIX_K8S_137_SECURITY_DELTA_ES.md) · [Deutsche Version](APPENDIX_K8S_137_SECURITY_DELTA_DE.md) · [ქართული ვერსია](APPENDIX_K8S_137_SECURITY_DELTA_GE.md) · [繁體中文版](APPENDIX_K8S_137_SECURITY_DELTA_TW.md) · [日本語版](APPENDIX_K8S_137_SECURITY_DELTA_JP.md)

# Appendice. Kubernetes v1.37 Delta de sécurité

> Marqueur : PRODUCTION / VERSION-SENSITIVE. L'inclusion dans cette annexe ne signifie pas qu'un sujet appartient au pool d'examens CKS actuel. L'instantané officiel de l'examen du cours (voir [`../metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml)) utilise Kubernetes v1.35, tandis que la référence de formation du cours est la v1.36. La dernière version stable en amont est Kubernetes v1.37. Ne faites pas la promotion d'une fonctionnalité de cette annexe dans 🎯 CKS Core sans confirmation séparée de sa pertinence pour l'examen/le programme.

Cette annexe rassemble les modifications de Kubernetes v1.37 liées à la sécurité. Les principaux chapitres et laboratoires restent liés au contexte vérifié de l'examen/de la formation ; ce document enregistre les changements actuels pour la production.

## 1. Manifest-Based Admission Control : bêta et activé par défaut

**Pertinence CKS :** Deep Dive / Production / Sensible à la version.

Dans la base de référence de formation v1.36, Manifest-Based Admission Control reste alpha et désactivé par défaut. Dans la version 1.37, il est devenu bêta, avec le feature gate `ManifestBasedAdmissionControlConfig` activée par défaut. Le serveur API charge les webhooks et les stratégies d'admission basées sur CEL à partir de fichiers statiques : ils sont actifs au démarrage du serveur API, ne s'appuient pas sur etcd pour stocker la configuration d'admission elle-même et peuvent protéger les ressources d'admission basées sur API contre toute modification.

Cela comble l'écart d'amorçage et d'autoprotection mais augmente le risque opérationnel : un manifeste non valide lors du chargement initial empêche le serveur API d'être prêt. En haute disponibilité, chaque serveur API lit ses propres fichiers, ce qui nécessite une livraison atomique cohérente.

Source : [Manifest-Based Admission Control](https://kubernetes.io/docs/reference/access-authn-authz/manifest-admission-control/).

## 2. SELinuxMount : GA et activé par défaut

**Pertinence CKS :** Deep Dive / Production / Sensible à la version.

Dans la version 1.36, `SELinuxMount` était désactivé par défaut ; dans la version 1.37, il s'agit de GA et activé par défaut. Pour les PVC CSI éligibles, Kubernetes utilise une option de montage d'étiquette SELinux au lieu d'un réétiquetage récursif plus lent uniquement lorsque `CSIDriver.spec.seLinuxMount: true` et toutes les autres conditions d'éligibilité sont remplies. Cela change le comportement : avec un volume partagé sur un nœud, un Pod avec une étiquette SELinux incompatible peut rester dans `ContainerCreating`.

Avant de mettre à niveau un cluster compatible SELinux, activez `SELinuxWarningController`, résolvez les conflits détectés et observez sa métrique. Une charge de travail partageant intentionnellement un volume entre différentes étiquettes peut conserver le comportement précédent en utilisant :

```yaml
spec:
  securityContext:
    seLinuxChangePolicy: Recursive
```

Source : [Configurer un contexte de sécurité pour un Pod ou un conteneur](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/).

## 3. Pod Certificates et ClusterTrustBundles : stables

**Pertinence CKS :** Deep Dive / Production.

Un JWT ServiceAccount reste un bearer credential : sa durée de validité, sa liaison à un objet et son audience sont limitées, mais il est présenté au pair. Pod Certificates ajoute des credentials X.509 pour les workloads, avec une clé privée et une preuve de possession. Kubelet crée un `PodCertificateRequest`, obtient une chaîne de certificats auprès du signataire et renouvelle le credential. Le certificat et le bundle de confiance sont transmis par des volumes projetés ; `ClusterTrustBundle` fournit les ancres de confiance.

Le composant de signature reste interchangeable. Kubernetes v1.37 ne fournit pas de signataire principal universel et prêt à l'emploi pour SPIFFE ou toutes les charges de travail. Pod Certificates ne remplace donc pas automatiquement les JWT ServiceAccount et ne rend pas inutiles les mécanismes d'identité Istio/SPIFFE existants.

Source : [Kubernetes v1.37 : Pod Certificates et bundles de confiance de cluster](https://kubernetes.io/blog/2026/08/28/kubernetes-v1-37-pod-certificates-and-cluster-trust-bundles/).

## 4. KubeletInUserNamespace : chemin du nœud bêta sans racine

**Pertinence CKS :** Deep Dive / Production.

`KubeletInUserNamespace` est en version bêta dans la version 1.37. Lorsqu'ils sont activés, kubelet, le runtime CRI/OCI, CNI et kube-proxy peuvent s'exécuter en tant qu'utilisateur hôte non root dans un espace de noms utilisateur Linux. Cette architecture de nœud sans racine réduit l'impact des composants de nœud compromis et peut nécessiter des vérifications de compatibilité CNI et CSI.

Ne confondez pas cela avec `spec.hostUsers: false`, qui crée un espace de noms utilisateur pour un Pod alors que les composants de nœud peuvent toujours s'exécuter en tant que racine hôte. Ce sont des limites de sécurité différentes et compatibles. L'activation de le feature gate ne convertit pas automatiquement les nœuds root existants en mode sans racine.

Source : [Kubernetes v1.37 : KubeletInUserNamespace passe en version bêta](https://kubernetes.io/blog/2026/09/04/kubernetes-v1-37-rootless-beta/).

## 5. Suppression de ressources illisibles/corrompues : chemin de récupération dangereux

**Pertinence CKS :** Production / Récupération / Opération dangereuse.

Dans la version 1.37, le feature gate bêta, activée par défaut, `AllowUnsafeMalformedObjectDeletion`, permet la suppression non sécurisée d'un objet qui ne peut pas être lu à partir du stockage en raison d'un échec de décryptage ou d'une corruption du décodage. La demande de suppression utilise `ignoreStoreReadErrorWithClusterBreakingPotential` ; les autorisations `delete` et `unsafe-delete-ignore-read-errors` sont requises.

> ⚠️ Il s'agit d'un mécanisme de récupération de dernier recours avec un potentiel de rupture de cluster. Il contourne les vérifications du finaliseur et des conditions préalables, ne remplace pas la conservation des anciennes clés de chiffrement ni la sauvegarde/restauration, et ne constitue pas un moyen normal de corriger une erreur EncryptionConfiguration.

Source : [Concepts Kubernetes API : Forcer la suppression](https://kubernetes.io/docs/reference/using-api/api-concepts/#force-deletion).

## 6. StorageVersionMigration : GA et activé par défaut

**Pertinence CKS :** Production / Deep Dive.

Dans la version 1.37, le `storagemigration.k8s.io/v1` API et le contrôleur intégrés sont devenus GA et activés par défaut. Storage Version Migration réécrit de manière déclarative les objets API persistants dans la version de stockage actuelle. Ceci est utile pour la migration de la version de stockage API et peut faire partie d'un rechiffrement contrôlé après un fournisseur de chiffrement ou un changement de clé.

SVM n'est pas la même chose que la rotation des fournisseurs de chiffrement : l'ordre des fournisseurs, le déchiffrement des anciennes données, les sauvegardes et la stratégie de restauration restent des responsabilités distinctes de l'opérateur.

Source : [Kubernetes v1.37 : Storage Version Migration activé par défaut](https://kubernetes.io/blog/2026/08/31/kubernetes-v1-37-storage-version-migration-ga/).

---
[Contenu](README_FR.md)
