[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 124 — Referenzlösung (HA Control Plane aus 3 Nodes)

Gegeben ist ein Cluster mit einer Control Plane `cp1`, initialisiert über
`--control-plane-endpoint` und `--upload-certs`, mit installiertem CNI. Es sind **zwei**
Control-Plane-Nodes `cp2` und `cp3` anzuhängen (Prerequisites und Pakete sind dort bereits
vorhanden), um ein ungerades etcd-Quorum (3 Nodes) zu erhalten.

Offizielle Dokumentation:
[Creating Highly Available clusters with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/),
[kubeadm join](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/).

## Schritt 1. certificate-key und Join-Befehl holen (auf `cp1`)

```bash
# 1. Die Control-Plane-Zertifikate in ein Secret laden und den certificate-key erhalten
sudo kubeadm init phase upload-certs --upload-certs
# ... gibt aus: <certificate-key>

# 2. Den Basis-Join-Befehl holen (Token + Discovery-Hash)
sudo kubeadm token create --print-join-command
# kubeadm join <endpoint>:6443 --token ... --discovery-token-ca-cert-hash sha256:...
```

Setze den Befehl für einen Control-Plane-Node zusammen, indem du `--control-plane` und
`--certificate-key` ergänzt.

## Schritt 2. cp2 anhängen (Aufgabe 1)

```bash
ssh cp2
sudo kubeadm join <endpoint>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <certificate-key>
exit
```

## Schritt 3. cp3 anhängen (Aufgabe 2)

Auf die gleiche Weise. Sind seit Schritt 1 mehr als ~2 Stunden vergangen, ist der
`certificate-key` abgelaufen — wiederhole `upload-certs`; ist das Token abgelaufen (~24 h) —
führe `kubeadm token create` erneut aus.

```bash
ssh cp3
sudo kubeadm join <endpoint>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <certificate-key>
exit
```

Prüfung auf `cp1`:

```bash
kubectl get nodes -l node-role.kubernetes.io/control-plane   # 3 Nodes
kubectl get nodes                                            # alle Ready
```

## Schritt 4. etcd-Quorum prüfen (Aufgabe 3)

Bei der Stacked-Topologie kommt auf jedem Control-Plane-Node ein eigener Static Pod `etcd-*`
hoch:

```bash
kubectl -n kube-system get pods -l component=etcd -o wide
# etcd-cp1   Running
# etcd-cp2   Running
# etcd-cp3   Running

# die Anzahl der etcd-Mitglieder direkt (mit den Zertifikaten, Kapitel 37):
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
# 3 Zeilen — drei Mitglieder des etcd-Clusters
```

## Warum genau 3

3 etcd-Mitglieder haben ein Quorum von 2 und überstehen den Ausfall **eines** Nodes.
2 Mitglieder überstehen **null** Ausfälle (Quorum 2 von 2) — das ist schlechter als ein
einzelner Node. Deshalb wird HA auf einer ungeraden Zahl gebaut: 3 (Standard) oder 5
(übersteht zwei Ausfälle). Eine gerade Zahl ist nicht vorteilhaft (Kapitel 35A).

## Prüfung

```bash
check_result
```
