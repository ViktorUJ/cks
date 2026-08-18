[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 111 - Referenzlösung (Spot-Nodes: Diversifizierung, Interruptions, graceful drain)

Alle Befehle laufen auf der Worker-Maschine über SSH. kubectl ist bereits für den Cluster
konfiguriert (kubeconfig wurde über `aws eks update-kubeconfig` beim Hochfahren der
Maschine erstellt).

## Aufgabe 1. Namespace `eks-111`

```bash
kubectl create namespace eks-111
```

## Aufgabe 2. Deployment `spotapp` auf dem Spot-Pool mit toleration und graceful shutdown

Der Pool `spot-lab` ist mit dem taint `dedicated=spot-lab:NoSchedule` abgeschottet, daher
muss der Pod die passende toleration tragen, sonst kann Karpenter ihn nicht auf diesem
NodePool platzieren. `terminationGracePeriodSeconds: 60` passt in das zweiminütige Fenster
einer Spot-Interruption, und `preStop` mit `sleep 5` gibt dem Load Balancer Zeit, den
Traffic vor dem Stoppen des Containers abzuziehen.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spotapp
  namespace: eks-111
spec:
  replicas: 4
  selector:
    matchLabels:
      app: spotapp
  template:
    metadata:
      labels:
        app: spotapp
    spec:
      terminationGracePeriodSeconds: 60
      tolerations:
        - key: "dedicated"
          value: "spot-lab"
          effect: "NoSchedule"
      containers:
        - name: app
          image: viktoruj/ping_pong:latest
          lifecycle:
            preStop:
              exec:
                command: ["sh", "-c", "sleep 5"]
EOF

kubectl rollout status deployment/spotapp -n eks-111
```

Prüfung, dass alle 4 Replicas auf Spot-Nodes gelandet sind:

```bash
kubectl get po -n eks-111 -l app=spotapp -o wide
NODES=$(kubectl get po -n eks-111 -l app=spotapp -o jsonpath='{.items[*].spec.nodeName}')
for n in $NODES; do
  kubectl get node "$n" -L karpenter.sh/capacity-type --no-headers
done
```

Karpenter startet eine neue EC2-Node in etwa 60-90 Sekunden, daher können die Pods zunächst
in `Pending` hängen. Wir warten auf `rollout status`, bevor wir weitermachen.

## Aufgabe 3. Artefakt: Spot-Nodes und NodePool-Diversifizierung

Wir speichern einen Snapshot der Nodes mit dem Label des Kapazitätstyps und der
Instance-Kategorie, sowie die requirements des NodePool `spot-lab`, um den breiten Satz
von Familien (die Diversifizierung) zu bestätigen.

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl get nodes -L karpenter.sh/capacity-type -L karpenter.k8s.aws/instance-category \
  > /var/work/tests/artifacts/3/nodes.txt
cat /var/work/tests/artifacts/3/nodes.txt

kubectl get nodepool spot-lab -o yaml \
  | grep -A5 'instance-category' > /var/work/tests/artifacts/3/nodepool.txt
cat /var/work/tests/artifacts/3/nodepool.txt
```

In `nodes.txt` sollte mindestens eine Node mit `capacity-type=spot` vorhanden sein. In
`nodepool.txt` sollten die drei Instance-Kategorien `c`, `m`, `r` vorhanden sein - genau das
ist die Anforderung der Diversifizierung: der Pool spot-lab ist nicht auf eine einzige
Instance-Familie eingeengt.

## Aufgabe 4. PodDisruptionBudget für `spotapp`

`minAvailable: 3` von 4 Replicas schützt vor übermäßiger voluntärer Eviction:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: spotapp-pdb
  namespace: eks-111
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: spotapp
EOF

kubectl get pdb spotapp-pdb -n eks-111 -o yaml
```

## Aufgabe 5. Symptom: drain wird durch PDB blockiert, aber das rettet nicht vor Spot-AWS

Wir nehmen eine Node, auf der mindestens ein `spotapp`-Pod läuft, cordonen sie und
versuchen einen drain. Bei 4 Replicas und `minAvailable: 3` erlaubt das PDB, nicht mehr
als eine Replica gleichzeitig zu evicten (`disruptionsAllowed` überschreitet nicht 1) -
der drain kommt über eine Replica hinaus nicht weiter.

```bash
NODE=$(kubectl get po -n eks-111 -l app=spotapp -o jsonpath='{.items[0].spec.nodeName}')
kubectl cordon "$NODE"
kubectl get pdb spotapp-pdb -n eks-111 -o jsonpath='{.status.disruptionsAllowed}'
echo

# was zu evicten versucht wird, ohne die ganze Node wirklich zu drainen
kubectl drain "$NODE" --ignore-daemonsets --dry-run=client
```

Wir halten das Symptom und die Erklärung der Verantwortungsgrenze des PDB im Artefakt
fest:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/drain.txt <<'EOF'
Die Node ist gecordont, drain versucht, die spotapp-Pods über die Eviction-API zu
evicten. Das PDB spotapp-pdb mit minAvailable: 3 erlaubt nicht, mehr als eine Replica
gleichzeitig zu evicten (disruptionsAllowed <= 1 bei 4 Replicas): beim Versuch, das
budget zu verletzen, verweigert die Eviction, und der drain kommt über eine Replica
hinaus nicht weiter.

Wichtige Grenze: PDB schützt nur eine freiwillige (добровольн/voluntary) Eviction -
kubectl drain, Node-Upgrades, Karpenter-Konsolidierung. Es rettet nicht vor einem
forcierten Reclaim einer Spot-Instance durch AWS: wenn AWS die Instance nach Ablauf der
zweiminütigen Benachrichtigung tatsächlich zurückholt, werden die Pods darauf unabhängig
vom PDB beendet, weil das keine freiwillige Aktion von Kubernetes ist, sondern das
Stoppen der Instance selbst.
EOF
cat /var/work/tests/artifacts/5/drain.txt

kubectl uncordon "$NODE"
```

## Aufgabe 6. Prüfung des Interruption-Handlings von Karpenter

Karpenter behandelt Spot-Interruptions selbst über eine Interruption-Queue
(`interruptionQueue`, konfiguriert im Modul `eks_v2_karpenter` unabhängig von diesem Lab).
Wir bestätigen den Mechanismus über die Controller-Logs - die Berechtigung für
`aws sqs list-queues` fehlt der Worker-Maschine möglicherweise, daher verwenden wir
`kubectl logs`:

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=500 \
  | grep -i interrupt > /var/work/tests/artifacts/6/interruption.txt

# wenn bisher noch keine Interruption-Events aufgetreten sind, halten wir zumindest fest,
# dass der Mechanismus vorhanden ist:
if [[ ! -s /var/work/tests/artifacts/6/interruption.txt ]]; then
  echo "no interruption events yet, but Karpenter interruption handling is configured via interruptionQueue" \
    > /var/work/tests/artifacts/6/interruption.txt
fi
cat /var/work/tests/artifacts/6/interruption.txt
```

## Schnelle Prüfung

```bash
check_result
```
