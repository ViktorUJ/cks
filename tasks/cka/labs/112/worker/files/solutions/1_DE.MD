[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 112 — Referenzlösung (etcd: Snapshots und Wiederherstellung)

Alle Aktionen mit etcd erfolgen auf der Control-Plane-Node
(`ssh k8s1_controlPlane_1`, `sudo -i`). `etcdctl` ist bereits installiert; die Zertifikate
liegen in `/etc/kubernetes/pki/etcd/`.

Praktisch ist es, die gemeinsamen Verbindungsparameter für etcd einmal zu setzen:

```bash
# auf der Control Plane, als root
export ETCDCTL_API=3
export EP="--endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key"
```

## Aufgabe 1. Snapshot S1 erstellen (Basiszustand) und auf den worker kopieren

```bash
# auf der Control Plane
etcdctl $EP snapshot save /root/etcd-snapshot-1.db
etcdctl snapshot status /root/etcd-snapshot-1.db --write-out=table
```

Den Snapshot auf die Arbeitsmaschine kopieren (für die Prüfung):

```bash
# von worker PC
scp k8s1_controlPlane_1:/root/etcd-snapshot-1.db \
  /var/work/tests/artifacts/etcd/etcd-snapshot-1.db
```

(wenn `scp` die Datei nicht aus `/root` holen kann, kopiere sie auf der Control Plane nach
`/tmp` und setze die Rechte:
`cp /root/etcd-snapshot-1.db /tmp/ && chmod 644 /tmp/etcd-snapshot-1.db`, dann `scp` aus
`/tmp`.)

## Aufgabe 2. Änderungen im Cluster vornehmen

Wir erstellen „Marker-Ressourcen“ — an ihnen sehen wir später den Unterschied zwischen den
Snapshots. Die Befehle laufen auf der Arbeitsmaschine (dort ist `kubectl` konfiguriert).

```bash
# auf worker PC
kubectl create namespace snapshot-demo
kubectl -n snapshot-demo create configmap demo-config --from-literal=app=v1
kubectl -n snapshot-demo create deployment demo-web \
  --image=viktoruj/ping_pong --replicas=2

kubectl get ns snapshot-demo
kubectl -n snapshot-demo get cm,deploy
```

## Aufgabe 3. Snapshot S2 erstellen (nach den Änderungen)

```bash
# auf der Control Plane
etcdctl $EP snapshot save /root/etcd-snapshot-2.db
etcdctl snapshot status /root/etcd-snapshot-2.db --write-out=table
```

```bash
# von worker PC
scp k8s1_controlPlane_1:/root/etcd-snapshot-2.db \
  /var/work/tests/artifacts/etcd/etcd-snapshot-2.db
```

Der Unterschied: `etcd-snapshot-1.db` wurde **vor** dem Erstellen von `snapshot-demo`
aufgenommen, `etcd-snapshot-2.db` — **danach**. Das heißt, S2 enthält den Namespace
`snapshot-demo` und seine Ressourcen, S1 nicht.

## Aufgabe 4. S1 wiederherstellen und prüfen, dass keine überflüssigen Ressourcen da sind

Wir stellen den allerersten Snapshot wieder her — der Cluster muss in den Zustand **vor** dem
Erstellen von `snapshot-demo` zurückkehren.

Ablauf der Wiederherstellung (Methode „statische Pods stoppen → nach `/var/lib/etcd`
wiederherstellen → statische Pods hochfahren“):

```bash
# auf der Control Plane, als root
# 1. Node-Namen und Adressen aus dem aktuellen etcd-Manifest ansehen — nötig beim restore
grep -E -- '--name=|--initial-cluster=|--initial-advertise-peer-urls=' \
  /etc/kubernetes/manifests/etcd.yaml
# Beispielausgabe:
#   - --name=ip-10-10-1-17
#   - --initial-advertise-peer-urls=https://10.10.1.17:2380
#   - --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380

# 2. alle statischen Pods der Control Plane stoppen (kubelet fährt ihre Container herunter)
mkdir -p /etc/kubernetes/manifests-stopped
mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
# warten, bis die etcd-/apiserver-Container verschwinden
crictl ps

# 3. die aktuellen Daten beiseiteschieben und Snapshot S1 nach /var/lib/etcd wiederherstellen
mv /var/lib/etcd /var/lib/etcd.bak
etcdctl snapshot restore /root/etcd-snapshot-1.db \
  --data-dir=/var/lib/etcd \
  --name=ip-10-10-1-17 \
  --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380 \
  --initial-advertise-peer-urls=https://10.10.1.17:2380

# 4. die Manifeste zurücklegen — kubelet fährt die Control Plane auf den wiederhergestellten Daten hoch
mv /etc/kubernetes/manifests-stopped/*.yaml /etc/kubernetes/manifests/
```

> **Wichtig zu `--name` (etcd 3.6+).** Beim restore müssen `--name`, `--initial-cluster` und
> `--initial-advertise-peer-urls` **genau so** angegeben werden wie im etcd-Manifest. Sonst
> passt der wiederhergestellte Member nicht zu dem, mit dem der statische Pod startet, und
> etcd stürzt mit der Panik `member unknown` ab. Die Werte kommen aus Schritt 1.

Wir prüfen, dass der Cluster hochgekommen ist und `snapshot-demo` **verschwunden** ist:

```bash
# von worker PC (ca. 1 Minute warten, bis die API hochkommt)
kubectl get --raw='/healthz'          # ok
kubectl get ns snapshot-demo          # NotFound — keine überflüssigen Ressourcen
kubectl get pods -n kube-system
```

## Aufgabe 5. Cluster aus S2 wiederherstellen

Jetzt stellen wir den zweiten Snapshot wieder her — `snapshot-demo` und seine Ressourcen
müssen zurückkommen. Das Verfahren ist dasselbe, der Snapshot ist
`/root/etcd-snapshot-2.db`.

```bash
# auf der Control Plane, als root
mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
crictl ps                                    # warten, bis die Container stoppen

rm -rf /var/lib/etcd
etcdctl snapshot restore /root/etcd-snapshot-2.db \
  --data-dir=/var/lib/etcd \
  --name=ip-10-10-1-17 \
  --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380 \
  --initial-advertise-peer-urls=https://10.10.1.17:2380

mv /etc/kubernetes/manifests-stopped/*.yaml /etc/kubernetes/manifests/
```

Wir prüfen, dass der Cluster gesund ist und `snapshot-demo` **zurück** ist:

```bash
# von worker PC
kubectl get --raw='/healthz'                 # ok
kubectl get ns snapshot-demo                 # Active
kubectl -n snapshot-demo get cm,deploy       # demo-config und demo-web sind vorhanden
kubectl get pods -n kube-system
```

Fazit: ein Snapshot ist ein vollständiges Abbild des Cluster-Zustands zum Zeitpunkt der
Aufnahme. Die Wiederherstellung aus S1 setzt den Cluster auf den „leeren“ Zustand zurück, die
aus S2 bringt die erstellten Ressourcen zurück.
