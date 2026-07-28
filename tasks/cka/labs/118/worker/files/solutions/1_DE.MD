[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 118 — Referenzlösung (Zertifikate, CoreDNS, Cluster-Netzwerk)

Die Berichte speichern wir auf der Arbeitsmaschine im Verzeichnis `/home/ubuntu/answers/`.
Mit der Control Plane verbinden wir uns per SSH: `ssh k8s1_controlPlane_1`.

## Aufgabe 1. Health-Check der Zertifikate → `certs.txt`

Die Zertifikate des Clusters liegen auf der Control Plane in `/etc/kubernetes/pki/`. Wir
lesen sie mit `openssl` ([offizielle Dokumentation: Certificate Management with kubeadm](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)).

```bash
ssh k8s1_controlPlane_1

# Gültigkeit des API-Server-Zertifikats
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -enddate
# notAfter=Jul 20 10:00:00 2026 GMT   <- der Wert nach "notAfter="

# CN der Zertifizierungsstelle des Clusters
sudo openssl x509 -in /etc/kubernetes/pki/ca.crt -noout -subject
# subject=CN = kubernetes   <- CN = kubernetes

# praktischer Gesamtüberblick über die Gültigkeitsdaten:
sudo kubeadm certs check-expiration
```

Schreiben Sie auf der Arbeitsmaschine den Bericht (der Wert `notAfter` — genau die
Zeichenkette nach dem Zeichen `=`):

```bash
mkdir -p /home/ubuntu/answers
cat > /home/ubuntu/answers/certs.txt <<EOF
apiserver_notafter=Jul 20 10:00:00 2026 GMT
ca_cn=kubernetes
EOF
```

> Setzen Sie Ihren eigenen `notAfter`-Wert aus der Ausgabe von `openssl` ein.

## Aufgabe 2. CoreDNS reparieren

CoreDNS ist ein Deployment in `kube-system`
([offizielle Dokumentation: DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/),
[Debugging DNS Resolution](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)).

```bash
kubectl -n kube-system get deploy coredns          # READY 0/0 — Repliken auf null gesetzt
kubectl -n kube-system scale deployment coredns --replicas=2
kubectl -n kube-system rollout status deploy coredns

# Prüfung der Namensauflösung:
kubectl run dnstest --image=busybox:1.36 --restart=Never -it --rm -- \
  nslookup kubernetes.default
```

## Aufgabe 3. Fakten zum Cluster-Netzwerk → `net.txt`

```bash
# Pod CIDR des Clusters (--cluster-cidr des kube-controller-manager)
ssh k8s1_controlPlane_1 \
  "sudo grep -o 'cluster-cidr=[^ ]*' /etc/kubernetes/manifests/kube-controller-manager.yaml"
# cluster-cidr=10.0.0.0/16

# CNI: DaemonSet des Netzwerk-Agents in kube-system
kubectl -n kube-system get ds | grep calico
# calico-node ...
```

Dokumentation: [Cluster Networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/),
[kubeadm: pod-network-cidr](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/).

Schreiben Sie auf der Arbeitsmaschine den Bericht:

```bash
cat > /home/ubuntu/answers/net.txt <<EOF
pod_cidr=10.0.0.0/16
cni_daemonset=calico-node
EOF
```

## Aufgabe 4. ndots für einen Pod senken (dnsConfig)

kubelet schreibt in Pods eine `/etc/resolv.conf` mit `options ndots:5`: Namen mit weniger als
5 Punkten werden zuerst mit den Search-Suffixen durchprobiert. Für externe Namen
(`api.github.com` — 2 Punkte) sind das unnötige NXDOMAIN-Anfragen. Die Schwelle lässt sich
für einen Pod über `dnsConfig` senken
([offizielle Dokumentation: DNS for Services and Pods — Pod DNS Config](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-dns-config)).

Zuerst ein Pod mit Standard-DNS:

```bash
kubectl run dns-default --image=viktoruj/ping_pong:alpine --restart=Never

# seine resolv.conf ansehen: dort steht "options ndots:5"
kubectl exec dns-default -- cat /etc/resolv.conf
```

Dann ein Pod mit gesenktem `ndots` (deklarativ, da `--dry-run` dnsConfig nicht kann):

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

> Kompromiss: `ndots:2` beschleunigt externe Namen, aber der Zugriff auf einen Service in
> einem **anderen** Namespace über den kurzen Namen `backend.prod` (2 Punkte → schon
> absolut) wird nicht mehr über die Search-Suffixe vervollständigt. Für externe Namen ist
> ein FQDN mit Punkt am Ende zuverlässiger: `api.github.com.`.

## Aufgabe 5. Bericht zu ndots → `dns.txt`

```bash
# ndots-Wert aus dem Standard-Pod
kubectl exec dns-default -- cat /etc/resolv.conf | grep -oE 'ndots:[0-9]+'
# ndots:5

cat > /home/ubuntu/answers/dns.txt <<EOF
default_ndots=5
tuned_ndots=2
EOF
```

## Prüfung

```bash
check_result
```

## Aufgabe 6. Den DNS-Namen des Pods finden

Jeder Pod erhält einen A-Record nach der Formel:
`<pod-ip-mit-bindestrichen>.<namespace>.pod.cluster.local`
([offizielle Dokumentation: DNS for Services and Pods — Pod's A/AAAA record](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pods)).

```bash
# die IP des Pods dns-test ermitteln
kubectl get pod dns-test -n dns-lab -o wide
# NAME       READY   STATUS    IP           ...
# dns-test   1/1     Running   10.0.1.23    ...

# den DNS-Namen bilden: die Punkte in der IP durch Bindestriche ersetzen
# 10.0.1.23 → 10-0-1-23.dns-lab.pod.cluster.local

# die Auflösung prüfen (aus einem beliebigen Pod mit nslookup/dig)
kubectl exec dns-default -- nslookup 10-0-1-23.dns-lab.pod.cluster.local

# die Antwort schreiben
echo "10-0-1-23.dns-lab.pod.cluster.local" > /home/ubuntu/answers/pod-dns-name.txt
```

> Setzen Sie die echte IP Ihres Pods ein.
