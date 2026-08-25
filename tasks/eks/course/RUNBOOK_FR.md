[Русская версия](RUNBOOK_RU.md) · [Eng version](RUNBOOK.md) · [Versión en español](RUNBOOK_ES.md) · [Deutsche Version](RUNBOOK_DE.md) · [ქართული ვერსია](RUNBOOK_GE.md) · [繁體中文版](RUNBOOK_TW.md) · [日本語版](RUNBOOK_JP.md)

# Guide de diagnostic EKS : symptôme, cause, vérification

[Table des matières du cours](README_FR.md) · [Glossaire](GLOSSARY_FR.md)

## Comment l'utiliser

Cette synthèse rassemble dans un seul fichier les sections « Procédure et outils de diagnostic »
des chapitres 45, 46 et 47, pour l'astreinte : parcourir trois chapitres pendant un incident est
peu pratique. Procédez ainsi : identifiez d'abord la CLASSE du symptôme dans le tableau « Accès
rapide par symptôme », puis allez dans votre couche et parcourez-la de haut en bas. La
classification est plus importante que l'outil : un pod en `ContainerCreating` et une erreur 503
du répartiteur de charge se corrigent avec des commandes différentes.
Ce document ne contient que l'ordre de passage, les listes de contrôle et les commandes.
L'analyse des causes, les mécanismes et les explications restent dans les chapitres 45 à 47 ; des
liens vers eux figurent dans chaque ligne du navigateur.

## Accès rapide par symptôme

| Ce qui est visible | Classe | Où aller |
|---|---|---|
| `kubectl get nodes` est vide, aucune node | la node n'a pas rejoint le cluster | [node](#nœud-ne-rejoint-pas-le-cluster), [chapitre 45](45/fr.md) |
| `NodeCreationFailure`, `Instances failed to join the kubernetes cluster` | la node n'a pas rejoint le cluster | [node](#nœud-ne-rejoint-pas-le-cluster), [chapitre 45](45/fr.md) |
| le node group est en `CREATE_FAILED` ou `DEGRADED` | la node n'a pas rejoint le cluster | [node](#nœud-ne-rejoint-pas-le-cluster), [chapitre 45](45/fr.md) |
| le journal kubelet contient `node "" not found` | node : DNS et private DNS name | [node](#nœud-ne-rejoint-pas-le-cluster), [chapitre 45](45/fr.md) |
| la node est visible mais `NotReady` | CNI non prêt, autre couche | [node](#nœud-ne-rejoint-pas-le-cluster), [chapitre 45](45/fr.md), chapitre 8 |
| pod en `ContainerCreating`, `failed to assign an IP address to container` | réseau : IP et ENI | [réseau](#pannes-réseau-dans-un-cluster-en-fonctionnement), [chapitre 46](46/fr.md) |
| timeout pod-pod ou pod-RDS `connection timed out`, DNS résolu | réseau : security group | [réseau](#pannes-réseau-dans-un-cluster-en-fonctionnement), [chapitre 46](46/fr.md) |
| la requête part mais la connexion se bloque | réseau : NACL et ephemeral ports | [réseau](#pannes-réseau-dans-un-cluster-en-fonctionnement), [chapitre 46](46/fr.md) |
| le pod ne résout pas les noms et échoue au readiness | réseau : son propre SG sur le pod | [réseau](#pannes-réseau-dans-un-cluster-en-fonctionnement), [chapitre 46](46/fr.md) |
| DNS fonctionne de manière intermittente, timeouts variables | réseau : DNS | [réseau](#pannes-réseau-dans-un-cluster-en-fonctionnement), [chapitre 46](46/fr.md) |
| charge DNS excessive sur les noms externes | réseau : effet `ndots:5` | [réseau](#pannes-réseau-dans-un-cluster-en-fonctionnement), [chapitre 46](46/fr.md) |
| targets du target group `unhealthy`, 502 `Bad gateway` | réseau : répartiteur de charge | [réseau](#pannes-réseau-dans-un-cluster-en-fonctionnement), [chapitre 46](46/fr.md) |
| 503 `Service unavailable` d'un service derrière le LB | réseau : aucun target sain | [réseau](#pannes-réseau-dans-un-cluster-en-fonctionnement), [chapitre 46](46/fr.md) |
| `You must be logged in to the server (Unauthorized)` | accès : authentification | [accès](#refus-daccès--personne-et-pod), [chapitre 47](47/fr.md) |
| `couldn't get current server API group list: Unauthorized` | accès : kubeconfig ou région | [accès](#refus-daccès--personne-et-pod), [chapitre 47](47/fr.md) |
| `Forbidden: cannot <verb> resource` | accès : RBAC | [accès](#refus-daccès--personne-et-pod), [chapitre 47](47/fr.md) |
| le pod échoue avec `AccessDenied` lors d'un appel AWS | accès du pod : STS et rôle | [accès](#refus-daccès--personne-et-pod), [chapitre 47](47/fr.md) |
| le pod échoue avec `WebIdentityErr: failed to retrieve credentials` | accès du pod : IRSA | [accès](#refus-daccès--personne-et-pod), [chapitre 47](47/fr.md) |

## Nœud ne rejoint pas le cluster

Chapitre 45. Le symptôme est unique, `kubectl get nodes` vide et `NodeCreationFailure`, mais les
causes se trouvent dans des couches différentes. Procédure de haut en bas :

1. Couche IAM : droits du node instance role et autorisation du rôle dans le cluster (section 45.2).
2. Couche réseau : chemin vers l'endpoint du serveur API sur 443, type d'endpoint, DNS (section 45.3).
3. Couche user data et bootstrap : `bootstrap.sh` sur AL2, `nodeadm`/`NodeConfig` sur AL2023 (45.4).
4. Couche kubelet : le démon est lancé, kubeconfig et certificat sont intacts, l'enregistrement a réussi (45.5).

Logique : interrogez d'abord EKS avec `describe-nodegroup`, vérifiez ensuite l'autorisation du rôle
(peu coûteux et c'est le coupable le plus fréquent), puis le réseau jusqu'à l'endpoint, et enfin
consultez sur la node les journaux de cloud-init et kubelet. Distinguez « aucune node » et
`NotReady` : le second cas, avec un kubelet actif, est presque toujours lié au CNI ; voir le chapitre 8.

| Symptôme | Cause probable | À vérifier |
|---|---|---|
| `NodeCreationFailure`, aucune node | le rôle de la node n'est pas autorisé | `aws eks list-access-entries`, `aws-auth` |
| aucune node, IAM en ordre | aucun chemin vers l'API sur 443 | SG, route NAT/IGW, type d'endpoint |
| aucune node, cluster privé | l'endpoint ne se résout pas | DNS, DHCP options set dans le VPC |
| aucune node, AMI personnalisée | le bootstrap ne s'est pas exécuté | `/var/log/cloud-init-output.log` |
| aucune node, kubelet échoue | kubeconfig/certificat corrompu | `journalctl -u kubelet` |
| la node existe mais `NotReady` | CNI non prêt, pas d'IP pour les pods | pod `aws-node`, événements de la node (chapitre 8) |
| le journal contient `node "" not found` | pas de private DNS name | options DHCP, DNS dans le VPC |

```bash
# 1. ce qu'EKS indique lui-même sur le node group
aws eks describe-nodegroup --cluster-name prod --nodegroup-name ng-1 \
  --query 'nodegroup.health.issues'
# 2. si le cluster voit les nodes
kubectl get nodes
# 3. si le rôle de la node est autorisé
aws eks list-access-entries --cluster-name prod
# chemin obsolète : mappings dans aws-auth
kubectl -n kube-system get configmap aws-auth -o yaml
# 4. sur la node via SSM Session Manager : journal bootstrap/cloud-init
sudo cat /var/log/cloud-init-output.log
# 5. sur la node : statut et journaux kubelet
systemctl status kubelet
journalctl -u kubelet -n 200 --no-pager
```

L'accès à une node sans SSH s'effectue via SSM Session Manager : il faut le SSM agent et les
droits nécessaires. Si SSM est indisponible, il reste la sortie de console de l'instance (system log)
et `/var/log`.

## Pannes réseau dans un cluster en fonctionnement

Chapitre 46. Le cluster fonctionne, les nodes sont `Ready`, mais le réseau peut échouer de
plusieurs façons. Commencez par classifier le symptôme : pas d'IP, rupture de connectivité, DNS,
5xx du répartiteur de charge. La classe détermine la couche et la commande.
`describe pod` et `get pods -o wide` sont peu coûteux et éliminent d'abord les problèmes d'IP,
`describe-target-health` localise immédiatement une défaillance du répartiteur, et les VPC Flow Logs
sont le dernier recours pour les ruptures non expliquées ni par les IP ni par le health check.
Souvenez-vous de la différence entre les couches : le security group est stateful et opère au niveau
ENI, le NACL est stateless et opère au niveau du sous-réseau ; le trafic retour sur les ephemeral
ports doit donc être autorisé manuellement dans le NACL.

| Symptôme | Cause probable | À vérifier |
|---|---|---|
| `failed to assign an IP address` | aucune IP libre sur la node ou dans le sous-réseau | `describe pod`, `AvailableIpAddressCount` |
| timeout pod-pod ou pod-RDS | le SG n'autorise pas le trafic | Groups de `describe-network-interfaces`, SG RDS |
| rupture, mais la requête part | le NACL bloque les ephemeral ports | règles NACL in/out, VPC Flow Logs |
| DNS avec timeouts intermittents | CoreDNS, conntrack, throttling par ENI | métriques CoreDNS (chapitre 33), conntrack, PPS |
| charge DNS excessive sur les noms externes | effet `ndots:5` | search domains, FQDN avec point final |
| 502 ou 503 d'un service derrière un LB | targets `unhealthy` | `describe-target-health`, health check, SG |
| targets `unhealthy`, pod actif | chemin/port du health check ou SG | chemin et port de vérification, SG du répartiteur |
| pod sans DNS ni readiness | son propre SG sur le pod au lieu du SG de la node | `SecurityGroupPolicy` du pod, 53 TCP/UDP, entrée depuis le SG des nodes |

```bash
# 1. événements du pod : cause de ContainerCreating et attribution d'IP
kubectl describe pod <pod>
# 2. où se trouve le pod et sur quelle node
kubectl get pods -o wide
# 3. ENI, IP et SG d'une adresse donnée
aws ec2 describe-network-interfaces \
  --filters "Name=private-ip-address,Values=<ip>" --query 'NetworkInterfaces[0]'
# 4. adresses libres dans le sous-réseau
aws ec2 describe-subnets --subnet-ids <subnet> \
  --query 'Subnets[0].AvailableIpAddressCount'
# 5. santé des targets du répartiteur de charge
aws elbv2 describe-target-health --target-group-arn "$TG_ARN"
# y a-t-il des endpoints prêts derrière le service
kubectl get endpointslices -l kubernetes.io/service-name=<svc>
# 6. test de résolution depuis le pod
kubectl run dnstest --image=busybox:1.36 --rm -it --restart=Never -- nslookup <name>
# propre SG sur le pod : mode d'application et recherche d'une erreur dans l'id du SG
kubectl describe daemonset aws-node -n kube-system | grep -iE 'SECURITY_GROUP|DEMUX'
kubectl describe pod <pod> | grep -i InvalidSecurityGroupID
# 7. sur la node : collecter le dump réseau VPC CNI (journaux ipamd/plugin, ENI, eni-configs)
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids <instance-id> \
  --parameters 'commands=["/opt/cni/bin/aws-cni-support.sh"]'
```

L'état d'ipamd est également disponible directement via son endpoint local : `/v1/enis` affiche les
ENI et IP attribuées, `/v1/pods` affiche l'association des adresses aux pods.

## Refus d'accès : personne et pod

Chapitre 47. Les défaillances d'accès se divisent en deux axes indépendants ; la première question
pour l'astreinte est de savoir lequel est défaillant : une personne ou le CI ne peut pas entrer dans
le cluster, ou un pod reçoit `AccessDenied` lors d'un appel AWS. Ensuite, le code de refus achève
la classification. `Unauthorized` (401) est un échec d'authentification : pas de token, token expiré,
identity non mappée ; on corrige le kubeconfig, les credentials et le mapping (access entry ou
aws-auth). `Forbidden` (403) est un échec d'autorisation : l'identity est déjà connue, mais RBAC
ne donne pas les droits ; on corrige les Role, ClusterRole et bindings. Un `AccessDenied` depuis un
pod mène vers IRSA ou Pod Identity. Raccourci « le cluster ou moi » : si
`aws sts get-caller-identity` affiche une autre identity que celle attendue, le problème est local :
profil, région ou credentials.

| Symptôme | Cause probable | À vérifier |
|---|---|---|
| `Unauthorized`, `must be logged in` | mauvaise identity ou identity non mappée | `sts get-caller-identity`, `list-access-entries` |
| `Unauthorized` juste après `edit aws-auth` | son propre mapping a été supprimé | `get cm aws-auth`, restaurer avec une access entry |
| `Forbidden: cannot <verb>` | RBAC ne donne pas les droits | `kubectl auth can-i`, Role et bindings |
| `couldn't get server API group` | kubeconfig ou région incorrects | `update-kubeconfig`, `current-context`, profil |
| pod avec `AccessDenied` sous IRSA | trust policy, OIDC, annotation SA | OIDC provider, `sub`/`aud`, annotation `role-arn` |
| pod avec `WebIdentityErr` | token non monté, mauvais rôle | recréer le pod, vérifier la trust policy |
| pod avec `AccessDenied` sous Pod Identity | pas d'association, d'agent ou de token | `list-pod-identity-associations`, agent, token dans le pod |

```bash
# qui suis-je réellement aux yeux d'AWS
aws sts get-caller-identity
# mode d'authentification et accessConfig du cluster
aws eks describe-cluster --name <cluster> --query 'cluster.accessConfig'
# qui est mappé via les access entries
aws eks list-access-entries --cluster-name <cluster>
# contenu de aws-auth (si le mode l'utilise encore)
kubectl -n kube-system get cm aws-auth -o yaml
# authz : ce que j'ai le droit de faire
kubectl auth can-i --list
kubectl auth can-i get pods -n <ns>
# régénérer kubeconfig et vérifier le contexte
aws eks update-kubeconfig --name <cluster> --region <region> --profile <profile>
kubectl config current-context
# axe du pod : annotation de rôle sur le ServiceAccount (IRSA)
kubectl get sa <sa> -n <ns> -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
# associations Pod Identity
aws eks list-pod-identity-associations --cluster-name <cluster>
# si l'agent Pod Identity est lancé
kubectl -n kube-system get pods -l app.kubernetes.io/name=eks-pod-identity-agent
# le token Pod Identity est-il monté dans le pod même (pas de fichier : agent/association n'a pas fonctionné)
kubectl exec <pod> -n <ns> -- ls /var/run/secrets/pods.eks.amazonaws.com/serviceaccount/
```

Un cluster verrouillé se restaure par l'API EKS : `update-cluster-config` avec
`authenticationMode=API_AND_CONFIG_MAP`, puis `create-access-entry` et
`associate-access-policy` avec `AmazonEKSClusterAdminPolicy` (section 47.4). Le retour à
`CONFIG_MAP` est impossible.

## Que consulter quand rien ne correspond

- Les **VPC Flow Logs** indiquent si le paquet a reçu `ACCEPT` ou `REJECT` au niveau de l'ENI ou
  du sous-réseau. `REJECT` indique un SG ou un NACL ; l'absence de paquets de réponse alors que
  la requête est partie indique un NACL stateless et les ephemeral ports.
- Les **journaux du control plane** (api, audit, authenticator) sont activés à l'avance et non après
  coup : les journaux de l'authenticator indiquent si l'identity reçue est mappée (chapitres 21 et 34).
- **`aws-cni-support.sh` via SSM** collecte les journaux ipamd et plugin avec l'état ENI/IP et la
  configuration dans l'archive `/var/log/eks_<instance-id>_<...>.tar.gz`, sans SSH sur la node.
- Les **journaux `/var/log/aws-routed-eni`** (`ipamd.log`, `plugin.log`) se lisent sur la node quand
  un pod reste bloqué avec `failed to assign an IP address` et qu'il est impossible de savoir si les
  IP sont épuisées ou si l'ENI n'est pas montée.

## Ce qui n'est pas inclus ici

Ce document ne remplace pas les chapitres : il ne contient ni les explications des causes, ni les
mécanismes des couches, ni l'analyse expliquant pourquoi le symptôme a cette forme ; ils sont dans
les chapitres 45, 46 et 47. Il ne contient que l'ordre de passage et les commandes.
Les laboratoires de troubleshooting du cours (119, 120, 121, ainsi que 126 sur les security groups
for pods) ne sont pas reproduits dans ce fichier : ils se font selon leurs propres consignes.
