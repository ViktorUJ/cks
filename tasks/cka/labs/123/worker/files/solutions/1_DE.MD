[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 123 — Referenzlösung (CNI von Null installieren + Netzwerk auf niedriger Ebene)

Der Cluster ist **ohne CNI** gestartet: `kubectl get nodes` → alle Nodes `NotReady`, die Pods in
`netlab` hängen in `Pending`/`ContainerCreating`, CoreDNS kommt nicht hoch. Solange es kein
Netzwerk-Plugin gibt — gibt es kein Pod-Netzwerk.

Verbindung zu den Nodes: `ssh k8s1_controlPlane_1`, `ssh k8s1_node_node_1`.

## Aufgabe 1. Das CNI von Hand installieren

Der offizielle kubeadm-Schritt heißt „Installing a Pod network add-on“
([kubeadm-Dokumentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network),
[Liste der Addons](https://kubernetes.io/docs/concepts/cluster-administration/addons/)).
Wir installieren Calico ([Calico quickstart](https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart)):

```bash
# nimm eine Manifest-Version, die mit k8s 1.35 kompatibel ist (siehe docs.tigera.io)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml

# wir beobachten, wie das Netzwerk hochkommt
kubectl -n kube-system get pods -l k8s-app=calico-node -w
kubectl get nodes -w        # die Nodes wechseln nach Ready
```

Nach der CNI-Installation:
- die Nodes werden `Ready`;
- CoreDNS kommt hoch (`kubectl -n kube-system get deploy coredns`);
- die `netprobe`-Pods in `netlab` verteilen sich auf die zwei Nodes und wechseln nach `Running`.

> Wenn der Adresspool von Calico mit `--pod-network-cidr=10.0.0.0/16` übereinstimmen soll,
> setze `CALICO_IPV4POOL_CIDR=10.0.0.0/16` im Manifest vor dem `apply` (auf das Bestehen des
> Labs hat das keinen Einfluss).

## Aufgaben 2-3 (werden automatisch geprüft)

Sobald das CNI funktioniert, kommen CoreDNS und `netprobe` (2 Pods auf verschiedenen Nodes) von
selbst hoch — genau das ist die Bestätigung für ein funktionierendes Pod-Netzwerk, auch
**node-übergreifend**.

## Aufgabe 4. Report zum Netzwerk auf niedriger Ebene → `net-lowlevel.txt`

Wir sammeln die Fakten auf der Control-Plane-Node:

```bash
ssh k8s1_controlPlane_1

# die CNI-Konfiguration, die das Plugin abgelegt hat
sudo ls /etc/cni/net.d
# z. B.: 10-calico.conflist

# das Gerät der Default-Route
ip route show default
# default via 10.10.1.1 dev ens5 ...   -> dev = ens5
```

Auf der Arbeitsmaschine:

```bash
mkdir -p /home/ubuntu/answers
cat > /home/ubuntu/answers/net-lowlevel.txt <<EOF
cni_conf=10-calico.conflist
default_route_dev=ens5
EOF
```

> Setze deine eigenen Werte aus den Ausgaben oben ein.

## Analyse von Network Namespaces und Routen (niedrige Ebene)

Es ist nützlich zu verstehen, wie das CNI einen Pod mit dem Netzwerk der Node verbindet. Auf einer
Node, auf der ein Pod läuft:

```bash
# die Container und ihre Network Namespaces finden
sudo crictl ps
sudo crictl inspectp <pod-id> | grep -i netns    # Pfad zum Network Namespace des Pods

# Liste der Network Namespaces
ip netns list
# in den netns des Pod-Prozesses wechseln und sein Netzwerk ansehen
PID=$(sudo crictl inspect <container-id> | jq '.info.pid')
sudo nsenter -t $PID -n ip addr        # das eth0-Interface des Pods und seine IP
sudo nsenter -t $PID -n ip route       # die Default-Route des Pods

# veth-Paare auf dem Host (ein Ende im Pod, das andere auf der Node)
ip -o link | grep -E 'cali|veth'
# Routen zu den Pod-Netzwerken (Calico fügt Routen zu den anderen Nodes hinzu)
ip route | grep -E '10\.|192\.168'
```

Die Idee: das CNI erstellt für den Pod einen eigenen **Network Namespace**, verbindet ihn per
veth-Paar mit dem Host, vergibt eine IP aus dem Pool und schreibt **Routen** zu den Pod-Netzwerken
auf den anderen Nodes — so funktioniert das „flache Netzwerk“ von Kubernetes.

Dokumentation: [Cluster Networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/),
[Network Plugins (CNI)](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/).

## Prüfung

```bash
check_result
```
