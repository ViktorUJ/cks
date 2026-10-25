[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 113 - Referenzlösung: kubeadm minor upgrade

> Wir arbeiten wie in der Prüfung: `kubectl` - auf der Arbeitsmaschine, und Operationen am Node (apt, kubeadm,
> kubelet) - auf dem Node selbst: Melde dich per `ssh <Node>` darauf an, wechsle zu root (`sudo -i`),
> führe die Befehle aus und verlasse ihn wieder (`exit`, `exit`). Die Startversion des Clusters ist `1.35.x`, die Zielversion ist
> `1.36.x`. Die Namen der Nodes (`<cp-name>`, `<worker-name>`) nehmen wir aus `kubectl get no`; in der Prüfung sind sie anders, in diesem Lab sind die ssh-Aliase: `k8s113_controlPlane_1` und `k8s113_node_worker1`.

## Wo du Befehle in der Dokumentation findest

| Was du brauchst | Seite und Abschnitt |
| :--- | :--- |
| Das apt-Repository auf das nächste minor umschalten (geändert wird nur die Version in der URL der Datei `/etc/apt/sources.list.d/kubernetes.list`, der keyring bleibt derselbe) | [Changing the Kubernetes package repository - Switching to another Kubernetes package repository](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/change-package-repository/#switching-to-another-kubernetes-package-repository) |
| Die Version auswählen (`apt-cache madison kubeadm`) | [Upgrading kubeadm clusters - Determine which version to upgrade to](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#determine-which-version-to-upgrade-to) |
| `kubeadm` aktualisieren, `kubeadm upgrade plan`, `kubeadm upgrade apply v1.xx.x` auf der ersten control-plane | [Upgrading kubeadm clusters - Upgrading control plane nodes](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#upgrading-control-plane-nodes) |
| `kubectl drain <node> --ignore-daemonsets` | [Upgrading kubeadm clusters - Drain the node](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#drain-the-node) |
| `kubelet` und `kubectl` aktualisieren, `systemctl daemon-reload`, `restart kubelet` | [Upgrading kubeadm clusters - Upgrade kubelet and kubectl](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#upgrade-kubelet-and-kubectl) |
| `kubectl uncordon <node>` | [Upgrading kubeadm clusters - Uncordon the node](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#uncordon-the-node) |
| Worker-Node: `kubeadm upgrade node` | [Upgrading Linux nodes](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/upgrading-linux-nodes/) |

Auf den Ubuntu-Nodes ist `needrestart` im Modus „nur Liste“ konfiguriert (ohne OK/Cancel-Dialog), daher
bleibt `apt-get install` nicht bei Fragen stehen.

Setze anstelle von `1.36.x` in den Befehlen den tatsächlichen patch aus `apt-cache madison kubeadm` und aus der
Ausgabe von `kubeadm upgrade plan` ein.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
mkdir -p /var/work/tests/artifacts/{1,2,4}
kubectl get no
```

Merke dir aus `kubectl get no` die Namen der Nodes (`ip-10-...`): Du brauchst sie für `drain` und `uncordon`. Im Folgenden ist
`<cp-name>` der Name der control-plane, `<worker-name>` der Name des worker-Nodes.

## Schritt 0. Starte parallel das availability-Polling (Aufgabe 4)

Öffne vor dem upgrade eine separate Sitzung (`tmux`) auf der Arbeitsmaschine und lass die Abfrageschleife für das
Deployment `canary` für die gesamte Dauer der folgenden Schritte laufen:

```bash
while true; do
  if available=$(kubectl get deployment canary -n upgrade-113 -o jsonpath='{.status.availableReplicas}' 2>/dev/null); then
    echo "$(date +%s) available=${available:-0}"
  else
    echo "$(date +%s) available=api-unreachable"
  fi >> /var/work/tests/artifacts/4/canary-availability.log
  sleep 5
done
```

## 1. Upgrade der control-plane

```bash
ssh <cp-name>
sudo -i
```

```bash
# auf der control-plane (root): aktuelle Versionen
kubeadm version -o short; kubelet --version

# das Repository auf das nächste minor umschalten: in der Datei v1.35 durch v1.36 ersetzen
vim /etc/apt/sources.list.d/kubernetes.list
# deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /

apt update
apt-cache madison kubeadm | head -3
```

Aktualisiere kubeadm (den tatsächlichen patch anstelle von `x`). **Führe diesen Befehl separat aus:** `apt-get`
leert den Eingabepuffer des Terminals, daher gehen Zeilen, die direkt danach eingefügt werden, verloren.

```bash
# auf der control-plane (root)
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm='1.36.x-*' && apt-mark hold kubeadm
```

```bash
# auf der control-plane (root)
kubeadm version -o short
kubeadm upgrade plan
```

Nimm die konkrete Version aus der Ausgabe von `plan` und führe das upgrade aus, wobei du die **vollständige** Ausgabe speicherst:

```bash
# auf der control-plane (root)
kubeadm upgrade apply v1.36.x -y > /tmp/kubeadm-upgrade-apply.txt 2>&1
tail -3 /tmp/kubeadm-upgrade-apply.txt
# [upgrade] SUCCESS! A control plane node of your cluster was upgraded to "v1.36.x".
exit   # aus root
exit   # von der control-plane
```

```bash
# auf der Arbeitsmaschine: die Ausgabe für die Prüfung abholen
scp <cp-name>:/tmp/kubeadm-upgrade-apply.txt /var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt
```

Erst jetzt, NACH dem erfolgreichen `kubeadm upgrade apply`, folgen der drain des Nodes und das Aktualisieren von kubelet/kubectl:

```bash
# auf der Arbeitsmaschine
kubectl drain <cp-name> --ignore-daemonsets --delete-emptydir-data
```

```bash
ssh <cp-name>
sudo -i
```

```bash
# auf der control-plane (root)
apt-mark unhold kubelet kubectl && apt-get update && apt-get install -y kubelet='1.36.x-*' kubectl='1.36.x-*' && apt-mark hold kubelet kubectl
```

```bash
# auf der control-plane (root)
systemctl daemon-reload
systemctl restart kubelet
kubelet --version
exit   # aus root
exit   # von der control-plane
```

```bash
# auf der Arbeitsmaschine
kubectl uncordon <cp-name>
kubectl get nodes
```

## 2. Upgrade des worker-Nodes

Beginne erst, nachdem die control-plane `Ready` auf `1.36.x` ist (version skew policy:
das kubelet des worker-Nodes darf nicht neuer sein als die control-plane). Warte, bis `canary` wieder `2/2` ist:

```bash
# auf der Arbeitsmaschine: wiederhole, bis AVAILABLE 2 wird
kubectl get deployment canary -n upgrade-113
```

```bash
ssh <worker-name>
sudo -i
```

```bash
# auf dem worker (root): dasselbe Repository wie auf der control-plane
vim /etc/apt/sources.list.d/kubernetes.list     # v1.35 -> v1.36
apt update
```

```bash
# auf dem worker (root)
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm='1.36.x-*' && apt-mark hold kubeadm
```

```bash
# auf dem worker (root)
# auf dem worker-Node (und zusätzlichen control-plane-Nodes) wird statt apply upgrade node ausgeführt
kubeadm upgrade node > /tmp/kubeadm-upgrade-node.txt 2>&1
tail -3 /tmp/kubeadm-upgrade-node.txt
exit   # aus root
exit   # vom worker
```

```bash
# auf der Arbeitsmaschine
scp <worker-name>:/tmp/kubeadm-upgrade-node.txt /var/work/tests/artifacts/2/kubeadm-upgrade-node.txt
kubectl drain <worker-name> --ignore-daemonsets --delete-emptydir-data
```

```bash
ssh <worker-name>
sudo -i
```

```bash
# auf dem worker (root)
apt-mark unhold kubelet kubectl && apt-get update && apt-get install -y kubelet='1.36.x-*' kubectl='1.36.x-*' && apt-mark hold kubelet kubectl
```

```bash
# auf dem worker (root)
systemctl daemon-reload
systemctl restart kubelet
kubelet --version
exit   # aus root
exit   # vom worker
```

```bash
# auf der Arbeitsmaschine
kubectl uncordon <worker-name>
kubectl get nodes
```

## 3. Prüfung der Reihenfolge des upgrades

Aufgabe 3 erfordert keine gesonderten Befehle: Die Reihenfolge belegt der checker-owned Monitor
(`/var/lib/cks-lab113-checker/upgrade-monitor.log` auf der Arbeitsmaschine), der seit dem bootstrap ununterbrochen protokolliert. Wenn du die Schritte der Reihe nach befolgt hast (zuerst vollständig Abschnitt 1, dann Abschnitt 2), gibt es im
Log eine Zeile, in der die control-plane bereits auf `v1.36.x`, `Ready` und schedulable ist und der worker noch auf
`v1.35.x`.

## 4. Prüfung des Fehlens von downtime

> Während des Laufs von `kubeadm upgrade apply` auf der einzigen control-plane startet der API server für einige Sekunden
> neu, und `kubectl` in der Abfrageschleife antwortet nicht. Solche Zeilen sind als
> `available=api-unreachable` geschrieben und gehen nicht in die Minimumberechnung ein: Die Nichtverfügbarkeit der API ist kein Ausfall von
> `canary`. Ob downtime vorliegt, hält der unabhängige Monitor des Checkers fest (Pod Ready und Container über `crictl`).

Stoppe die Abfrageschleife aus Schritt 0 (`Ctrl+C` in ihrer Sitzung) und prüfe, dass das Minimum von `available`
während des Durchlaufs nie auf 0 gefallen ist:

```bash
grep -oE 'available=[0-9]+' /var/work/tests/artifacts/4/canary-availability.log | sort -u
kubectl get deployment canary -n upgrade-113
```

Beide Replicas von `canary` sind auf verschiedene Nodes verteilt (required `podAntiAffinity`) und durch ein
`PodDisruptionBudget` mit `minAvailable: 1` geschützt, daher senkt ein korrekter sequenzieller drain (zuerst
ein Node, dann der andere, nach uncordon) `available` nicht unter `1`.

## Abschlussprüfung

```bash
kubectl get nodes
check_result
```

Beide Nodes müssen `Ready` auf `v1.36.x` sein, keiner `SchedulingDisabled`.
