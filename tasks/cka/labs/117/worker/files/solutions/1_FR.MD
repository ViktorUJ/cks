[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 117 — solution de référence (troubleshooting du control plane et des nœuds)

Connexion aux nœuds depuis la machine de travail :

```bash
ssh k8s1_controlPlane_1     # control plane
ssh k8s1_node_node_1        # worker (nom indiqué dans /etc/hosts)
```

## Tâche 1. Réparer kube-apiserver (débogage via crictl)

`kubectl` ne fonctionne pas (`connection refused`) — le serveur d'API est tombé. Le seul
moyen de comprendre est le débogage au niveau du runtime de conteneurs avec `crictl`.

```bash
ssh k8s1_controlPlane_1
sudo -i

# lister les conteneurs — on cherche kube-apiserver à l'état Exited
crictl ps -a | grep kube-apiserver
# CONTAINER   IMAGE   CREATED   STATE    NAME                ATTEMPT
# abc123...   ...     ...       Exited   kube-apiserver      5

# on lit les logs du conteneur tombé
crictl logs <container-id>
# Error: unknown flag: --invalid-nonexistent-flag

# on corrige le manifeste — on supprime la ligne contenant le flag cassé
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# supprimer la ligne :    - --invalid-nonexistent-flag=true
```

> **Alternative :** `grep -n "invalid" /etc/kubernetes/manifests/kube-apiserver.yaml`
> pour trouver la ligne, puis `sed -i '/--invalid-nonexistent-flag/d' /etc/kubernetes/manifests/kube-apiserver.yaml`.

kubelet recrée le static pod après la modification du manifeste. On attend ~30 s :

```bash
# sur le control plane
crictl ps | grep kube-apiserver    # doit être Running
exit
```

```bash
# sur le worker PC — on vérifie
kubectl get --raw='/healthz'       # ok
```

## Tâche 2. Réparer kube-scheduler

```bash
# symptôme : les nouveaux pods ne sont pas planifiés
kubectl get pod sched-check -n default            # Pending
kubectl -n kube-system get pods -l component=kube-scheduler   # ImagePullBackOff

# on regarde la cause
kubectl -n kube-system describe pod -l component=kube-scheduler   # bad image tag v0.0.0-broken

# on corrige le static pod sur le nœud control plane
ssh k8s1_controlPlane_1
sudo vi /etc/kubernetes/manifests/kube-scheduler.yaml
#   image: registry.k8s.io/kube-scheduler:v0.0.0-broken
# ->image: registry.k8s.io/kube-scheduler:v1.35.2   (version = version du cluster)
```

kubelet recrée lui-même le static pod après la modification du manifeste.
Au bout de ~30-60 s, le planificateur démarre et `sched-check` passe en Running.

> La version exacte de l'image peut être reprise d'un composant fonctionnel :
> `kubectl -n kube-system get pod -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].image}'`

## Tâche 3. Réparer le nœud worker (NotReady)

```bash
kubectl get nodes                     # le worker est NotReady
kubectl describe node <worker>        # kubelet ne remonte pas son statut

ssh k8s1_node_node_1
sudo systemctl status kubelet         # activating/failed
sudo journalctl -u kubelet -n 10      # failed to load kubelet config file ... NONEXISTENT-config.yaml

# on retire le drop-in cassé (il remplaçait le chemin du config)
sudo rm /etc/systemd/system/kubelet.service.d/99-broken.conf
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl status kubelet         # active (running)
```

Au bout de ~30 s, le nœud revient en Ready.

## Tâche 4. Réparer le static pod cassé sur le control plane

```bash
kubectl get pods -n default           # staticweb-<cp> en ImagePullBackOff
kubectl describe pod staticweb-<cp> -n default   # image viktoruj/ping_pong:doesnotexist999

ssh k8s1_controlPlane_1
sudo vi /etc/kubernetes/manifests/staticweb.yaml
#   image: viktoruj/ping_pong:doesnotexist999  ->  image: viktoruj/ping_pong:latest
```

kubelet recréera le static pod et le mirror pod `staticweb-<cp>` passera en Running.

## Vérification

```bash
check_result
```
