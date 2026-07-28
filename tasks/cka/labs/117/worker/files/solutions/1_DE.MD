[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 117 — Referenzlösung (Troubleshooting von Control Plane und Nodes)

Verbindung zu den Nodes von der Arbeitsmaschine:

```bash
ssh k8s1_controlPlane_1     # control plane
ssh k8s1_node_node_1        # worker (Name siehe /etc/hosts)
```

## Aufgabe 1. kube-apiserver reparieren (Debugging über crictl)

`kubectl` funktioniert nicht (`connection refused`) — der API-Server ist abgestürzt. Die
einzige Möglichkeit zur Analyse ist Debugging auf Ebene der Container-Runtime mit `crictl`.

```bash
ssh k8s1_controlPlane_1
sudo -i

# Container ansehen — wir suchen kube-apiserver im Zustand Exited
crictl ps -a | grep kube-apiserver
# CONTAINER   IMAGE   CREATED   STATE    NAME                ATTEMPT
# abc123...   ...     ...       Exited   kube-apiserver      5

# wir lesen die Logs des abgestürzten Containers
crictl logs <container-id>
# Error: unknown flag: --invalid-nonexistent-flag

# wir korrigieren das Manifest — die Zeile mit dem kaputten Flag löschen
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# Zeile löschen:    - --invalid-nonexistent-flag=true
```

> **Alternative:** `grep -n "invalid" /etc/kubernetes/manifests/kube-apiserver.yaml`
> um die Zeile zu finden, dann `sed -i '/--invalid-nonexistent-flag/d' /etc/kubernetes/manifests/kube-apiserver.yaml`.

kubelet erstellt den Static Pod nach der Änderung des Manifests neu. Wir warten ~30 s:

```bash
# auf dem control plane
crictl ps | grep kube-apiserver    # sollte Running sein
exit
```

```bash
# auf dem worker PC — wir prüfen
kubectl get --raw='/healthz'       # ok
```

## Aufgabe 2. kube-scheduler reparieren

```bash
# Symptom: neue Pods werden nicht geplant
kubectl get pod sched-check -n default            # Pending
kubectl -n kube-system get pods -l component=kube-scheduler   # ImagePullBackOff

# wir sehen uns die Ursache an
kubectl -n kube-system describe pod -l component=kube-scheduler   # bad image tag v0.0.0-broken

# wir korrigieren den Static Pod auf der control plane Node
ssh k8s1_controlPlane_1
sudo vi /etc/kubernetes/manifests/kube-scheduler.yaml
#   image: registry.k8s.io/kube-scheduler:v0.0.0-broken
# ->image: registry.k8s.io/kube-scheduler:v1.35.2   (Version = Cluster-Version)
```

kubelet erstellt den Static Pod nach der Änderung des Manifests selbst neu.
Nach ~30-60 s startet der Scheduler und `sched-check` geht in Running über.

> Die genaue Image-Version kann man von einer funktionierenden Komponente übernehmen:
> `kubectl -n kube-system get pod -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].image}'`

## Aufgabe 3. Worker-Node reparieren (NotReady)

```bash
kubectl get nodes                     # Worker ist NotReady
kubectl describe node <worker>        # kubelet meldet keinen Status

ssh k8s1_node_node_1
sudo systemctl status kubelet         # activating/failed
sudo journalctl -u kubelet -n 10      # failed to load kubelet config file ... NONEXISTENT-config.yaml

# wir entfernen das kaputte Drop-in (es ersetzte den Pfad zur Konfiguration)
sudo rm /etc/systemd/system/kubelet.service.d/99-broken.conf
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl status kubelet         # active (running)
```

Nach ~30 s kehrt die Node in Ready zurück.

## Aufgabe 4. Kaputten Static Pod auf dem Control Plane reparieren

```bash
kubectl get pods -n default           # staticweb-<cp> in ImagePullBackOff
kubectl describe pod staticweb-<cp> -n default   # Image viktoruj/ping_pong:doesnotexist999

ssh k8s1_controlPlane_1
sudo vi /etc/kubernetes/manifests/staticweb.yaml
#   image: viktoruj/ping_pong:doesnotexist999  ->  image: viktoruj/ping_pong:latest
```

kubelet erstellt den Static Pod neu, der Mirror-Pod `staticweb-<cp>` geht in Running über.

## Prüfung

```bash
check_result
```
