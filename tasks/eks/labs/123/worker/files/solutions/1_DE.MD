[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 123 - Referenzlösung (Karpenter: NodePool, consolidation, StatefulSet)

Alle Befehle laufen auf der Worker-Maschine über SSH. kubectl ist bereits für den Cluster
konfiguriert (der kubeconfig wurde über `aws eks update-kubeconfig` beim Booten der
Maschine zusammengestellt).

## Aufgabe 1. Namespace `eks-123`

```bash
kubectl create namespace eks-123
```

## Aufgabe 2. Inventar von NodePool, EC2NodeClass, NodeClaim

Wir schauen, welche Pools im Cluster bereits konfiguriert sind: der Standard `default`
(spot und on-demand) und der neue `stateful` (nur on-demand, Taint `dedicated=stateful`):

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "=== nodepools ==="
  kubectl get nodepools -o wide
  echo "=== ec2nodeclasses ==="
  kubectl get ec2nodeclasses
  echo "=== nodeclaims ==="
  kubectl get nodeclaims
} > /var/work/tests/artifacts/2/inventory.txt

cat /var/work/tests/artifacts/2/inventory.txt
```

Die Ausgabe sollte Zeilen mit den Namen `default` und `stateful` enthalten - das sind zwei
unabhängige NodePools, jeder mit eigenem `EC2NodeClass` (Kapitel 12.2-12.3).

## Aufgabe 3. StatefulSet `db` auf dem Pool `stateful`

Der Pool `stateful` ist durch den Taint `dedicated=stateful:NoSchedule` verschlossen,
deshalb braucht der Pod eine Toleration. Volumes sind für die Zwecke dieser Lab nicht
erforderlich - der Fokus liegt auf disruption, nicht auf EBS (das Volume eines
StatefulSets mit eigenem PVC wird in Kapitel 23 behandelt):

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
  namespace: eks-123
spec:
  serviceName: db
  replicas: 3
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      tolerations:
        - key: dedicated
          operator: Equal
          value: stateful
          effect: NoSchedule
      containers:
        - name: app
          image: viktoruj/ping_pong:latest
          resources:
            requests:
              cpu: "250m"
              memory: "128Mi"
EOF

kubectl rollout status statefulset/db -n eks-123
```

Wir prüfen, dass alle Replicas auf dem Pool `stateful` gelandet sind (Node-Label
`work_type=stateful`):

```bash
kubectl get po -n eks-123 -l app=db -o wide
kubectl get nodes -L work_type
```

## Aufgabe 4. PodDisruptionBudget `db-pdb`

`maxUnavailable: 1` ist die wichtigste Bremse für die freiwillige Eviction. Karpenter
draint über die Eviction API, deshalb lässt das PDB nicht mehr als eine Replica gleichzeitig
evicten:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: db-pdb
  namespace: eks-123
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: db
EOF

kubectl get pdb db-pdb -n eks-123
```

## Aufgabe 5. Symptom: ein PDB ohne Eviction-Recht blockiert die Consolidation

Die Nodes des Pools `stateful` sind bereits unterausgelastet: drei Replicas mit je `250m`
verteilten sich auf zwei `m6g.medium`-Nodes, und Karpenter mit `consolidateAfter: 30s`
versucht ständig, sie zu konsolidieren. Es ist keine Last-Erzeugung nötig - man muss nur
sehen, was die Consolidation blockiert.

Wichtig: bei `maxUnavailable: 1` blockiert das PDB die Consolidation NICHT. Es erlaubt eine
Eviction pro Mal (`ALLOWED DISRUPTIONS=1`), Karpenter draint den Node Replica für Replica
und löscht ihn ruhig. Eine Blockierung entsteht nur, wenn das PDB keine einzige Eviction
erlaubt. Wir verschärfen den Schutz zu einer vollständigen Sperre - `minAvailable: 3` bei
drei Replicas:

```bash
kubectl patch pdb db-pdb -n eks-123 --type=merge \
  -p '{"spec":{"maxUnavailable":null,"minAvailable":3}}'

kubectl get pdb db-pdb -n eks-123
```

Die Spalte `ALLOWED DISRUPTIONS` zeigt jetzt `0`. Nach 1-2 Minuten erscheint auf den Nodes
des Pools ein Blockierungs-Event. Beachten Sie: das ist NICHT `Unconsolidatable`, sondern
ein separates `DisruptionBlocked`:

```bash
for n in $(kubectl get nodes -l work_type=stateful -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== $n ==="
  kubectl describe node "$n" | grep -A2 DisruptionBlocked
done
```

Erwartete Zeile: `Pdb prevents pod evictions (PodDisruptionBudget=[eks-123/db-pdb])`. Die
Logs des Controllers selbst liegen im Namespace `karpenter` (nicht in `kube-system` - dort
sind nur Addons, Karpenter ist als separater Release auf dem Fargate-Profil deployt):

```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=500 \
  | grep -i "disrupting node"
```

Wir speichern die Beobachtung in einem Artefakt - die `get pdb`-Ausgabe plus das reale
Node-Event:

```bash
mkdir -p /var/work/tests/artifacts/5
{
  echo "Symptom: ein PDB, das keine einzige Eviction erlaubt, blockiert die Consolidation."
  echo "db-pdb verschaerft zu minAvailable=3 bei 3 Replicas -> ALLOWED DISRUPTIONS=0."
  kubectl get pdb db-pdb -n eks-123
  echo
  echo "=== Events der Nodes des Pools stateful ==="
  for n in $(kubectl get nodes -l work_type=stateful -o jsonpath='{.items[*].metadata.name}'); do
    kubectl describe node "$n" | grep -E "DisruptionBlocked|Unconsolidatable" | sed "s|^|$n |"
  done
} > /var/work/tests/artifacts/5/consolidation.txt

cat /var/work/tests/artifacts/5/consolidation.txt
```

Wir setzen das PDB zurück in einen funktionierenden Zustand, sonst wird Aufgabe 4 nicht
bestehen, und der Node des Pools kann nie weggehen:

```bash
kubectl patch pdb db-pdb -n eks-123 --type=merge \
  -p '{"spec":{"minAvailable":null,"maxUnavailable":1}}'

kubectl get pdb db-pdb -n eks-123
```

`ALLOWED DISRUPTIONS` ist wieder `1`. Fazit für den Betrieb: `minAvailable` gleich der
Anzahl der Replicas (oder `maxUnavailable: 0`) stoppt nicht nur die Consolidation, sondern
jedes Drain - also auch Node-Updates und das Cluster-Upgrade (Kapitel 12.6, Kapitel 40).

## Aufgabe 6. Fix: ein gezieltes `do-not-disrupt`

Der richtige Schutz eines StatefulSets ist die Kombination aus drei Teilen (Kapitel 12.7),
nicht eine einzige Annotation auf alles. Das PDB (Aufgabe 4) gibt bereits eine Eviction pro
Replica. Das disruption budget des Pools `stateful` (`nodes: 50%` in
`eks_karpenter_stateful_vng/terragrunt.hcl`) begrenzt das Tempo, damit Karpenter nicht alle
Nodes des Pools gleichzeitig anfasst. Der dritte Teil ist `do-not-disrupt`, gezielt nur auf
die Replica, bei der eine Disruption aktuell nicht akzeptabel ist (zum Beispiel hält
`db-0` eine Leadership oder eine lange Operation), nicht auf das ganze StatefulSet:

```bash
kubectl annotate pod db-0 -n eks-123 karpenter.sh/do-not-disrupt=true
kubectl get po db-0 db-1 db-2 -n eks-123 \
  -o custom-columns=NAME:.metadata.name,DO_NOT_DISRUPT:'.metadata.annotations.karpenter\.sh/do-not-disrupt'
```

`db-1` und `db-2` bekommen die Annotation nicht - sonst würde der Schutz vollständig und
würde nicht nur die Consolidation blockieren, sondern auch den Drift (AMI-Updates), wie in
Kapitel 12.8 beschrieben.

Dass die Annotation tatsächlich funktioniert, sieht man über denselben Mechanismus wie das
PDB in Aufgabe 5 - Karpenter schreibt ein separates Event auf den Node, der `db-0` trägt:

```bash
NODE=$(kubectl get po db-0 -n eks-123 -o jsonpath='{.spec.nodeName}')
kubectl describe node "$NODE" | grep -A1 'do-not-disrupt'
```

Erwartete Zeile: `DisruptionBlocked ... Pod has "karpenter.sh/do-not-disrupt" annotation
(Pod=eks-123/db-0)`. Das heißt, die gezielte Annotation stoppt nur die Consolidation des
Nodes, der die geschützte Replica trägt, während Karpenter die übrigen Nodes des Pools
weiterhin anfassen kann.

Wir speichern die Erklärung in einem Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/fix.txt <<'EOF'
Der richtige Schutz von StatefulSet db bei der Consolidation sind drei unabhaengige Teile,
nicht eine einzige pauschale Annotation:

1. PDB db-pdb (maxUnavailable: 1) - Eviction pro Replica, das Quorum geht nie verloren.
   Genau dieser Wert laesst ALLOWED DISRUPTIONS=1. Eine vollstaendige Sperre
   (minAvailable=3 bei drei Replicas) ergibt ALLOWED DISRUPTIONS=0 und ein Event
   DisruptionBlocked "Pdb prevents pod evictions" - fuer immer, bis das PDB selbst
   korrigiert wird (Aufgabe 5).
2. Das disruption budget des Pools stateful (nodes: 50%) - begrenzt, wie viele Nodes des
   Pools Karpenter gleichzeitig anfassen kann, und verhindert, den ganzen Pool auf einmal
   zu konsolidieren.
3. karpenter.sh/do-not-disrupt=true gezielt auf db-0 - schuetzt die konkrete Replica, bei
   der eine Unterbrechung aktuell nicht akzeptabel ist, nicht das ganze StatefulSet.

Waere do-not-disrupt gleichzeitig auf db-0, db-1 und db-2 gesetzt, wuerde das nicht nur die
Consolidation blockieren, sondern auch den Drift: wenn eine neue AMI erscheint, koennten
sich die Nodes des Pools stateful nicht aktualisieren, und es wuerde sich ein CVE-Rueckstand
aufbauen (Kapitel 12.8). Deshalb wird die Annotation nur auf eine Replica gesetzt und
entfernt, sobald die kritische Operation abgeschlossen ist.
EOF

cat /var/work/tests/artifacts/6/fix.txt
```

## Schnelle Prüfung

```bash
check_result
```
