[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 118 — solution de référence (certificats, CoreDNS, réseau du cluster)

Les rapports sont enregistrés sur la machine de travail dans le répertoire
`/home/ubuntu/answers/`. Au control plane, on se connecte en SSH :
`ssh k8s1_controlPlane_1`.

## Tâche 1. Health-check des certificats → `certs.txt`

Les certificats du cluster se trouvent sur le control plane dans `/etc/kubernetes/pki/`. On
les lit avec `openssl` ([documentation officielle : Certificate Management with kubeadm](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)).

```bash
ssh k8s1_controlPlane_1

# validité du certificat de l'API server
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -enddate
# notAfter=Jul 20 10:00:00 2026 GMT   <- la valeur après "notAfter="

# CN de l'autorité de certification du cluster
sudo openssl x509 -in /etc/kubernetes/pki/ca.crt -noout -subject
# subject=CN = kubernetes   <- CN = kubernetes

# aperçu global pratique des dates d'expiration :
sudo kubeadm certs check-expiration
```

Sur la machine de travail, écrivez le rapport (la valeur de `notAfter` est exactement la
chaîne qui suit le signe `=`) :

```bash
mkdir -p /home/ubuntu/answers
cat > /home/ubuntu/answers/certs.txt <<EOF
apiserver_notafter=Jul 20 10:00:00 2026 GMT
ca_cn=kubernetes
EOF
```

> Remplacez par votre propre valeur de `notAfter` issue de la sortie d'`openssl`.

## Tâche 2. Réparer CoreDNS

CoreDNS est un Deployment dans `kube-system`
([documentation officielle : DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/),
[Debugging DNS Resolution](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)).

```bash
kubectl -n kube-system get deploy coredns          # READY 0/0 — répliques mises à zéro
kubectl -n kube-system scale deployment coredns --replicas=2
kubectl -n kube-system rollout status deploy coredns

# vérification de la résolution :
kubectl run dnstest --image=busybox:1.36 --restart=Never -it --rm -- \
  nslookup kubernetes.default
```

## Tâche 3. Informations sur le réseau du cluster → `net.txt`

```bash
# Pod CIDR du cluster (--cluster-cidr de kube-controller-manager)
ssh k8s1_controlPlane_1 \
  "sudo grep -o 'cluster-cidr=[^ ]*' /etc/kubernetes/manifests/kube-controller-manager.yaml"
# cluster-cidr=10.0.0.0/16

# CNI : DaemonSet de l'agent réseau dans kube-system
kubectl -n kube-system get ds | grep calico
# calico-node ...
```

Documentation : [Cluster Networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/),
[kubeadm: pod-network-cidr](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/).

Sur la machine de travail, écrivez le rapport :

```bash
cat > /home/ubuntu/answers/net.txt <<EOF
pod_cidr=10.0.0.0/16
cni_daemonset=calico-node
EOF
```

## Tâche 4. Abaisser ndots pour un pod (dnsConfig)

kubelet écrit dans les pods un `/etc/resolv.conf` avec `options ndots:5` : les noms
comportant moins de 5 points sont d'abord essayés avec les suffixes de search. Pour les noms
externes (`api.github.com` — 2 points), ce sont des requêtes NXDOMAIN inutiles. Le seuil
peut être abaissé pour un pod via `dnsConfig`
([documentation officielle : DNS for Services and Pods — Pod DNS Config](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-dns-config)).

D'abord un pod avec le DNS par défaut :

```bash
kubectl run dns-default --image=viktoruj/ping_pong:alpine --restart=Never

# regarder son resolv.conf : on y trouvera "options ndots:5"
kubectl exec dns-default -- cat /etc/resolv.conf
```

Puis un pod avec un `ndots` abaissé (de façon déclarative, car `--dry-run` ne gère pas
dnsConfig) :

```yaml
# dns-tuned.yaml
apiVersion: v1
kind: Pod
metadata:
  name: dns-tuned
spec:
  dnsConfig:
    options:
    - name: ndots
      value: "2"
  containers:
  - name: c
    image: viktoruj/ping_pong:alpine
```

```bash
kubectl apply -f dns-tuned.yaml
kubectl get po dns-tuned -o jsonpath='{.spec.dnsConfig.options}'; echo
```

> Compromis : `ndots:2` accélère les noms externes, mais l'accès à un service d'un **autre**
> namespace par le nom court `backend.prod` (2 points → déjà absolu) ne sera plus complété
> par les suffixes de search. Pour les noms externes, un FQDN avec un point final est plus
> fiable : `api.github.com.`.

## Tâche 5. Rapport sur ndots → `dns.txt`

```bash
# valeur de ndots dans le pod par défaut
kubectl exec dns-default -- cat /etc/resolv.conf | grep -oE 'ndots:[0-9]+'
# ndots:5

cat > /home/ubuntu/answers/dns.txt <<EOF
default_ndots=5
tuned_ndots=2
EOF
```

## Vérification

```bash
check_result
```

## Tâche 6. Trouver le nom DNS du pod

Chaque Pod reçoit un enregistrement A selon la formule :
`<ip-du-pod-avec-tirets>.<namespace>.pod.cluster.local`
([documentation officielle : DNS for Services and Pods — Pod's A/AAAA record](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pods)).

```bash
# connaître l'IP du pod dns-test
kubectl get pod dns-test -n dns-lab -o wide
# NAME       READY   STATUS    IP           ...
# dns-test   1/1     Running   10.0.1.23    ...

# composer le nom DNS : les points de l'IP sont remplacés par des tirets
# 10.0.1.23 → 10-0-1-23.dns-lab.pod.cluster.local

# vérifier la résolution (depuis n'importe quel pod avec nslookup/dig)
kubectl exec dns-default -- nslookup 10-0-1-23.dns-lab.pod.cluster.local

# écrire la réponse
echo "10-0-1-23.dns-lab.pod.cluster.local" > /home/ubuntu/answers/pod-dns-name.txt
```

> Remplacez par l'IP réelle de votre pod.
