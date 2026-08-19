[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 125 - Referenzlösung (EKS Auto Mode gegen den eigenen Stack)

Alle Befehle werden auf der Worker-Maschine per SSH ausgeführt. kubectl ist bereits für den
Cluster konfiguriert. Der Cluster wurde mit aktiviertem Auto Mode und einem integrierten
NodePool `general-purpose` erstellt - in diesem Lab gibt es kein Fargate-Profil, keine
managed Addons und keinen Karpenter.

Wir nehmen den Clusternamen aus der kubeconfig: `list-clusters[0]` würde den ersten Cluster
des Kontos zurückgeben, und das ist nicht unbedingt unserer.

```bash
export CLUSTER=$(kubectl config current-context | awk -F/ '{print $NF}')
echo "$CLUSTER"
```

## Aufgabe 1. Bestätigung des Modus: Auto Mode ist aktiviert

```bash
mkdir -p /var/work/tests/artifacts/1
{
  echo "=== aws eks describe-cluster computeConfig ==="
  aws eks describe-cluster --name "$CLUSTER" --query 'cluster.computeConfig'
  echo
  echo "=== kubectl get nodepools ==="
  kubectl get nodepools
} > /var/work/tests/artifacts/1/automode.txt
cat /var/work/tests/artifacts/1/automode.txt
```

`computeConfig.enabled` muss `true` sein, und `nodePools` muss `general-purpose`
enthalten. `kubectl get nodepools` zeigt denselben NodePool als normale
Kubernetes-Ressource - Auto Mode materialisiert aktivierte integrierte Pools über die
Kubernetes-API (Kapitel 9).

## Aufgabe 2. Der zweite integrierte NodePool ist deaktiviert

```bash
kubectl get nodepools
```

`system` steht nicht in der Liste - ein integrierter NodePool erscheint als
Cluster-Ressource erst, wenn sein Name in `computeConfig.nodePools` vorhanden ist; in
diesem Lab steht dort nur `general-purpose`.

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/twopools.txt <<'EOF'
EKS Auto Mode hat zwei integrierte NodePools: general-purpose und system. Der NodePool
system trägt den Taint CriticalAddonsOnly, den für den Cluster kritische Komponenten (zum
Beispiel CoreDNS) tolerieren - so lassen sie sich von normaler Workload trennen, damit sie
nicht mit Anwendungen um Ressourcen konkurrieren und bei der Konsolidierung von
general-purpose-Nodes nicht verdrängt werden.

In diesem Lab enthält node_pools nur general-purpose, daher wird system nicht als
Cluster-Ressource erstellt: kubectl get nodepools zeigt es nicht. Es zu aktivieren bedeutet,
computeConfig.nodePools auf der Control Plane zu bearbeiten, nicht ein kubectl-Objekt zu
erstellen.
EOF
cat /var/work/tests/artifacts/2/twopools.txt
```

## Aufgabe 3. Workload auf general-purpose, Versuch den integrierten NodePool zu ändern

```bash
kubectl create namespace eks-125
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=2 -n eks-125
kubectl rollout status deployment/web -n eks-125

kubectl get pods -n eks-125 -o wide
```

Beide Replicas erreichen `Running` auf einem Node, den Auto Mode selbst unter
`general-purpose` hochgefahren hat - ohne Fargate-Profil und ohne externen Karpenter, die
in der Basis von Lab 101 nötig sind.

Wir versuchen, den integrierten NodePool zu bearbeiten. AWS dokumentiert integrierte
NodePools als "enabled or disabled but not modified", aber das muss man von Hand prüfen -
es gibt kein Verbot auf Admission-Ebene:

```bash
mkdir -p /var/work/tests/artifacts/3
{
  echo "=== kubectl patch des integrierten Pools ==="
  kubectl patch nodepool general-purpose --type merge -p '{"spec":{"limits":{"cpu":"100"}}}'
  echo "limits nach der Änderung: $(kubectl get nodepool general-purpose -o jsonpath='{.spec.limits}')"
  echo
  echo "=== wem das Objekt gehört ==="
  kubectl get nodepool general-purpose -o jsonpath='labels={.metadata.labels}{"\n"}'
  kubectl get nodepool general-purpose \
    -o jsonpath='managedFields managers={range .metadata.managedFields[*]}{.manager}{","}{end}{"\n"}'
  echo
  echo "=== Schlussfolgerung ==="
  echo "Die Änderung wird angenommen: der Befehl lieferte patched, der Wert blieb im"
  echo "Objekt. Aber das Objekt gehört dem Dienst: Label"
  echo "app.kubernetes.io/managed-by=eks, Felder gehören dem Manager eks-auto-mode. Es"
  echo "gibt nur eine unterstützte Verwaltungsmethode - das Aktivieren und Deaktivieren"
  echo "des Poolnamens in computeConfig.nodePools. Ändert sich diese Liste, wird die"
  echo "Ressource zusammen mit ihren Nodes gelöscht und von Grund auf neu erstellt, ohne"
  echo "unsere Änderungen."
} > /var/work/tests/artifacts/3/builtin.txt
cat /var/work/tests/artifacts/3/builtin.txt
```

Wir setzen den Pool in den ursprünglichen Zustand zurück - wir brauchen kein überflüssiges
`limits` auf einem Objekt, das nicht uns gehört:

```bash
kubectl patch nodepool general-purpose --type merge -p '{"spec":{"limits":null}}'
kubectl get nodepool general-purpose -o jsonpath='{.spec.limits}{"\n"}'
```

Achtung: `kubectl delete nodepool general-purpose` geht ebenfalls durch, aber EKS erstellt
das Objekt NICHT neu, während die Nodes des Pools gedraint werden - der Cluster bleibt
ohne Compute. Die Wiederherstellung erfolgt nur über `computeConfig` (Rezept im Abschnitt
"Löschen" der README).

## Aufgabe 4. Kein Zugriff auf den Node: SSH und SSM sind by design geschlossen

Im Auto Mode ist der Node-Name die Instance-ID selbst, `providerID` muss nicht separat
zerlegt werden:

```bash
NODE=$(kubectl get pods -n eks-125 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
echo "node=$NODE"
```

Wir sammeln drei Belege. Erstens - die Instanz hat kein Schlüsselpaar (`KeyName`), daher
ist SSH per Schlüssel unmöglich, unabhängig davon, ob etwas auf Port 22 lauscht:

```bash
mkdir -p /var/work/tests/artifacts/4
{
  echo "=== Schlüsselpaar und Node-Image ==="
  aws ec2 describe-instances --instance-ids "$NODE" \
    --query 'Reservations[0].Instances[0].[KeyName,ImageId,PlatformDetails]' --output text
  echo "KeyName ist leer (None) - der Node hat kein Schlüsselpaar"
  echo
  echo "=== SSM: keine Verbindung ==="
  aws ssm get-connection-status --target "$NODE" --output json
  echo "SSM-Inventar (der Node sollte dort nicht auftauchen):"
  aws ssm describe-instance-information \
    --query 'InstanceInformationList[].[InstanceId,PingStatus]' --output text
} > /var/work/tests/artifacts/4/nossh.txt
```

Verwenden Sie hier nicht `aws ssm start-session`: die Worker-Maschine hat keine
Berechtigung `ssm:StartSession`, daher liefert der Befehl `AccessDeniedException` - das ist
eine Tatsache über die Policy des Workers, nicht über den Node. Die Antwort auf die Frage
der Aufgabe liefert `get-connection-status` mit dem Status `notconnected`.

Der dritte Beleg geht in die andere Richtung: der Host ist nicht vom Cluster isoliert. Ein
privilegierter Pod mit einem `hostPath` auf `/` liest das Dateisystem des Nodes:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: hostprobe
  namespace: eks-125
spec:
  nodeName: $NODE
  restartPolicy: Never
  containers:
  - name: p
    image: busybox
    command: ["sh","-c","cat /host/etc/os-release; echo ---; ls /host/bin | head -5"]
    securityContext:
      privileged: true
    volumeMounts:
    - name: h
      mountPath: /host
  volumes:
  - name: h
    hostPath:
      path: /
EOF

kubectl wait --for=condition=Ready pod/hostprobe -n eks-125 --timeout=90s 2>/dev/null
sleep 5
{
  echo
  echo "=== der Host, gesehen aus einem privilegierten Pod ==="
  kubectl logs hostprobe -n eks-125
  echo
  echo "=== Schlussfolgerung ==="
  echo "SSH ist unmöglich (kein KeyName-Schlüsselpaar), SSM ist nicht verbunden"
  echo "(notconnected) - es gibt keinen Operator-Zugriff auf den Node. Aber das"
  echo "Bottlerocket-Image lässt sich aus einem privilegierten Pod lesen: Auto Mode"
  echo "schließt die Tür des Operators, nicht die Tür des Cluster-Admins. Für letztere"
  echo "sind Pod Security Admission und Admission-Policies zuständig (Kapitel 19 und 22)."
} >> /var/work/tests/artifacts/4/nossh.txt

kubectl delete pod hostprobe -n eks-125
cat /var/work/tests/artifacts/4/nossh.txt
```

Auto-Mode-Nodes sind Bottlerocket mit einem Read-Only-Root und SELinux im
Enforcing-Modus, ohne Shell und ohne Paketmanager, mit einer maximalen Lebensdauer von
21 Tagen und automatischem Austausch (Kapitel 9). Sie mit den gewohnten SSH- und
SSM-Mitteln zu debuggen ist grundsätzlich unmöglich - das ist der Preis minimalen
Betriebsaufwands.

## Aufgabe 5. Eigener NodePool mit expliziten limits

Integrierte Pools haben keine `limits` - bei unbegrenzter Nachfrage würden sie ohne
Obergrenze wachsen (Kapitel 9, Abschnitt 9.7). Ihr eigener NodePool referenziert die
integrierte `NodeClass` `default` und setzt die Grenzen selbst:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: custom-limited
spec:
  template:
    spec:
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: default
      requirements:
        - key: "eks.amazonaws.com/instance-category"
          operator: In
          values: ["c", "m", "r"]
        - key: "kubernetes.io/arch"
          operator: In
          values: ["amd64"]
  limits:
    cpu: "10"
    memory: 10Gi
EOF

kubectl get nodepool custom-limited
```

Eigene NodePools erben nicht die Einschränkungen der integrierten Pools (nur C/M/R, nur
on-demand, generation 5+) - man setzt sie selbst von Hand, einschließlich `limits`, sonst
wächst der Pool ohne Obergrenze (Kapitel 9, Abschnitt 9.7).

## Schnelle Prüfung

```bash
check_result
```
