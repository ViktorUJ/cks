[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 115 - Cilium bootstrap, kube-proxy replacement et Mutual Authentication

> **Advanced / production track. Ne fait pas partie de l'exigence formelle de l'examen CKS Core.**
> Ce lab dépasse le cadre de l'examen CKS et est utile comme compétence de production : installer
> Cilium de zéro en tant que remplacement complet de kube-proxy, et Cilium Mutual Authentication basée
> sur SPIRE. Si vous ne vous préparez qu'à l'examen, la priorité va aux labs 101-114.

## Description

Le control-plane de ce lab est monté via `kubeadm init --skip-phases=addon/kube-proxy` - sans
DaemonSet `kube-proxy` et **sans CNI installé**. Le node reste `NotReady` tant que vous n'avez pas
installé Cilium vous-même. C'est voulu : le lab porte entièrement sur l'installation manuelle de Cilium en tant que
remplacement complet de kube-proxy (`kubeProxyReplacement`), l'activation incrémentale de WireGuard
transparent encryption et de Cilium Mutual Authentication basée sur SPIRE - chaque étape
s'installe et se vérifie séparément, et n'est pas fournie toute faite.

Les CLI `cilium`/`hubble` sont déjà installées sur le worker et pointent vers le vrai cluster
(`~/.kube/config`), mais l'installation de Cilium dans le cluster, vous la réalisez vous-même.

## Déploiement

```bash
TASK=115 make run_cks_task
```

Après le déploiement, connectez-vous en SSH avec la commande issue de la sortie de Terraform (`worker_pc_ssh`).
Le node sera `NotReady` dès la connexion - c'est le baseline attendu, et non une erreur.

## Objectif

Installer Cilium comme remplacement complet de kube-proxy sur un cluster kubeadm déjà monté et sans kube-proxy,
activer le WireGuard encryption, activer Cilium Mutual Authentication
(SPIRE), et écrire une `CiliumNetworkPolicy` exigeant une mutual authentication réussie entre
deux namespaces.

## Infrastructure

| Composant | Rôle |
| --- | --- |
| control-plane EC2 | cluster kubeadm sans kube-proxy et sans CNI au moment de la remise du lab |
| `ingress-115` | namespace du client, qui doit réussir la mutual authentication |
| `app-115` | namespace du backend, protégé par une CiliumNetworkPolicy avec `authentication.mode: required` |
| worker EC2 | CLI `cilium`/`hubble`, kubeconfig configuré |

## Tâches

---

|           **1**           | **Baseline : kube-proxy-free, sans CNI**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Ce qu'on fait       | • Confirmez l'état actuel du cluster avant d'installer quoi que ce soit |
| Critères d'acceptation | • Le DaemonSet `kube-proxy` est absent<br/>• Le `NotReady` initial est observé avant l'installation de Cilium<br/>• Une fois toutes les tâches exécutées, le checker confirme l'absence de kube-proxy et la disponibilité de l'API, et non le `NotReady` historique |
|        Vérification        | `kubectl -n kube-system get ds kube-proxy` -> `NotFound`. `kubectl get nodes` -> `NotReady` (pas de CNI). |

---

|           **2**           | **Installation de Cilium comme remplacement de kube-proxy**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Ce qu'on fait       | • Installez l'agent/chart Cilium de version `1.20.1` via la CLI `cilium` de version `v0.19.7` installée sur le worker, avec `kubeProxyReplacement=true` et des `k8sServiceHost`/`k8sServicePort` explicitement définis, pointant vers le véritable API server (pas le Service ClusterIP - sans kube-proxy, le trafic vers le ClusterIP `kubernetes.default` n'atteint pas l'API server tant que Cilium lui-même n'a pas démarré) |
| Critères d'acceptation | • `KubeProxyReplacement: True/Strict` (dans le `cilium-dbg status` de l'agent)<br/>• Le node passe à `Ready`<br/>• Le Service ClusterIP est accessible sans kube-proxy |
|        Vérification        | `cilium status --wait`, `kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status \| grep KubeProxyReplacement`, puis `kubectl get nodes` -> `Ready`. Depuis un Pod de test : `curl https://kubernetes.default.svc.cluster.local/` doit recevoir une HTTP response (pas une connection error). |

---

|           **3**           | **WireGuard transparent encryption**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Ce qu'on fait       | • Activez `encryption.enabled=true`, `encryption.type=wireguard` par-dessus le Cilium déjà installé (`cilium upgrade`, et non une réinstallation de zéro) |
| Critères d'acceptation | • `Encryption: Wireguard` dans `cilium-dbg status` et `enable-wireguard: "true"` dans le ConfigMap de Cilium<br/>• Le chemin de la tâche 2 n'a pas régressé<br/>• Le banc mono-nœud confirme la configuration WireGuard activée, mais ne démontre pas un trafic inter-nœuds chiffré (Peers: 0) |
|        Vérification        | `kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status \| grep Encryption`. Répétez le curl de la tâche 2 - il doit de nouveau recevoir une HTTP response. |

---

|           **4**           | **Cilium Mutual Authentication (SPIRE)**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Ce qu'on fait       | • Activez l'installation SPIRE intégrée via le helm chart de Cilium lui-même : `authentication.mutual.spire.enabled=true`, `authentication.mutual.spire.install.enabled=true` |
| Critères d'acceptation | • Le StatefulSet `spire-server` et le DaemonSet `spire-agent` ont toutes les répliques Ready demandées dans le namespace `cilium-spire` |
|        Vérification        | `kubectl get pods -A \| grep spire` - les deux types de Pod sont à l'état `Running` et Ready. |

> **Particularités du banc.** Dans le cluster, il n'y a pas de StorageClass, donc le serveur SPIRE a besoin d'un stockage
> éphémère (`authentication.mutual.spire.install.server.dataStorage.enabled=false`). L'image
> `spire-server` fonctionne sous l'uid 1000 et ne peut pas créer de socket dans un répertoire hostPath `root:755` -
> lancez-la en root (`authentication.mutual.spire.install.server.securityContext.runAsUser=0`).
> De plus, le chart exige `authentication.enabled=true`. Pour les détails, voir la solution de référence.

---

|           **5**           | **CiliumNetworkPolicy avec mutual authentication obligatoire**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       Ce qu'on fait       | • Créez `ingress-115` (client) et `app-115` (backend, label `app=backend`, Service `backend`)<br/>• Créez la `CiliumNetworkPolicy backend-auth-required` dans `app-115` : `endpointSelector` sur `app=backend`, ingress uniquement depuis le namespace `ingress-115`, et `authentication.mode: required` sur cette règle ingress |
| Critères d'acceptation | • La policy sélectionne exactement le backend, contient une seule règle ingress depuis `ingress-115` sur TCP/80 avec `authentication.mode: required`<br/>• Il n'y a ni règles ingress supplémentaires ni chemins de contournement<br/>• Dans le banc isolé du Lab 115, il n'y a pas d'autres network policies namespaced/globales affectant le backend<br/>• Le Service `backend` pointe vers le Pod `backend` Ready |
|        Vérification        | `kubectl -n app-115 get ciliumnetworkpolicy backend-auth-required -o yaml` - vérifiez `authentication.mode: required` à l'intérieur de `ingress[0]`. |

---

|           **6**           | **Positive/negative control : l'authenticated identity est autorisée, une identité tierce - non**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Ce qu'on fait       | • Vérifiez l'effet de la policy avec du trafic réel : le client de `ingress-115` doit atteindre `backend` (après un SPIRE-based mutual auth handshake réussi)<br/>• Un Pod distinct d'un namespace « incorrect » (`app-115`, et non `ingress-115` ; le trafic du backend vers lui-même, Cilium le laisse toujours passer) doit être bloqué |
| Critères d'acceptation | • Dans un backend miroir isolé, le baseline autorise les deux clients, et après application d'une copie de la policy, seul `ingress-115` est autorisé<br/>• Le backend réel répond au client autorisé, rejette les clients de `app-115` et d'un nouveau namespace indépendant<br/>• Le Cilium BPF auth map contient `spire` pour la paire exacte d'identities client/backend |
|        Vérification        | `curl` depuis le Pod client dans `ingress-115` vers `http://backend.app-115.svc.cluster.local/` -> HTTP response. Le même curl depuis un Pod dans `app-115` sans le label du client -> connection error. |

## Vérification

```bash
check_result
```

Le checker **ne retire jamais la policy** `app-115/backend-auth-required` **en vigueur**. Pour vérifier le baseline, il crée un backend miroir temporaire et un Service dans un namespace jetable `cks-115-*`, vérifie d'abord le trafic autorisé sans policy, puis applique une copie de la CiliumNetworkPolicy vérifiée uniquement au backend miroir. Séparément, sont vérifiés le backend réel, l'EndpointSlice, les paires exactes de SPIRE identities dans le BPF auth map et l'interdiction pour les clients de namespaces tiers. Tous les Pods, Services, policies et le namespace temporaire créés sont supprimés, avec vérification du cleanup.

Solution de référence : [worker/files/solutions/1_FR.MD](worker/files/solutions/1_FR.MD).

## Suppression

```bash
TASK=115 make delete_cks_task
```
