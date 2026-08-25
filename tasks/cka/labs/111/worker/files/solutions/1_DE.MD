[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 111 — Referenzlösung (Upgrade eines kubeadm-Clusters)

Der Cluster startet auf `1.33.1`. Die Aufgabe: Control Plane und Worker auf `1.33.2`
aktualisieren. Reihenfolge: zuerst die Control Plane, dann der Worker; die Nodes
aktualisieren wir einzeln und geben sie über cordon/drain frei.

Die Node-Namen nehmen wir aus `kubectl get nodes` — **dieselben Namen verwenden wir sowohl
für `ssh` als auch für `drain`/`uncordon`** (in dieser Umgebung werden sie aufgelöst:
`ssh <Node-Name>` funktioniert):

```bash
kubectl get nodes
# Namen notieren, zum Beispiel:
CP=ip-10-10-1-151        # control plane (Rolle control-plane in der Ausgabe)
WORKER=ip-10-10-1-81     # worker (Rolle <none>)
```

## Schritt 1. Control Plane

```bash
# wir melden uns auf dem Control-Plane-Node an
ssh $CP

# kubeadm auf 1.33.2 aktualisieren
sudo apt-mark unhold kubeadm
sudo apt-get update && sudo apt-get install -y kubeadm=1.33.2-1.1
sudo apt-mark hold kubeadm
kubeadm version -o short          # v1.33.2

sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.33.2 -y
exit
```

```bash
# von der Arbeitsmaschine geben wir die Control Plane frei
kubectl drain $CP --ignore-daemonsets --delete-emptydir-data

# kubelet und kubectl auf dem Node selbst aktualisieren
ssh $CP '
  sudo apt-mark unhold kubelet kubectl
  sudo apt-get install -y kubelet=1.33.2-1.1 kubectl=1.33.2-1.1
  sudo apt-mark hold kubelet kubectl
  sudo systemctl daemon-reload && sudo systemctl restart kubelet
'

kubectl uncordon $CP
```

## Schritt 2. Worker-Node

```bash
# von der Arbeitsmaschine geben wir den Worker frei
kubectl drain $WORKER --ignore-daemonsets --delete-emptydir-data

# auf dem Worker-Node aktualisieren wir kubeadm und die Node-Konfiguration
ssh $WORKER '
  sudo apt-mark unhold kubeadm
  sudo apt-get update && sudo apt-get install -y kubeadm=1.33.2-1.1
  sudo apt-mark hold kubeadm
  sudo kubeadm upgrade node
  sudo apt-mark unhold kubelet kubectl
  sudo apt-get install -y kubelet=1.33.2-1.1 kubectl=1.33.2-1.1
  sudo apt-mark hold kubelet kubectl
  sudo systemctl daemon-reload && sudo systemctl restart kubelet
'

# von der Arbeitsmaschine nehmen wir den Worker wieder in Betrieb
kubectl uncordon $WORKER
```

## Prüfung

```bash
kubectl get nodes    # alle Nodes v1.33.2, Ready
```

> Hinweis: Wenn die Pakete `1.33.2-1.1` nicht vorhanden sind, sieh dir die verfügbaren an:
> `apt-cache madison kubeadm` und verwende den aktuellen 1.33.x-Patch (passe dann `TARGET` in
> der Prüfung an).
