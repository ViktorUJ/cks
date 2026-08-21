[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 101 - Referenzlösung (Cluster als Code: Zugriff, Compute, Netzwerk, AMI)

Alle Befehle werden auf der Worker-Maschine per SSH ausgeführt. kubectl ist bereits für den
Cluster konfiguriert (kubeconfig wird beim Hochfahren der Maschine über
`aws eks update-kubeconfig` zusammengesetzt).

## Aufgabe 1. Namespace `eks-101`

```bash
kubectl create namespace eks-101
```

## Aufgabe 2. Deployment `web` (viktoruj/ping_pong, 3 Replicas) auf EC2-Nodes

System-Pods (kube-system, karpenter) laufen auf Fargate, während jeder Pod in einem normalen
Namespace auf einen EC2-Node geplant wird, den Karpenter hochfährt. Deshalb landet das
Deployment in `eks-101` automatisch auf EC2:

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=3 -n eks-101
kubectl rollout status deployment/web -n eks-101
```

Prüfen, dass die Pods nicht auf Fargate laufen (der Node-Name beginnt mit `ip-`, nicht mit
`fargate-`):

```bash
kubectl get po -n eks-101 -l app=web -o wide
```

Warum das so ist: Fargate startet einen Pod nur, wenn der Namespace des Pods zu einem
Fargate-Profile passt. In diesem Lab ist das Profile für `kube-system` und `karpenter`
eingerichtet, für `eks-101` gibt es keines, deshalb übernimmt Karpenter (EC2) die
`eks-101`-Workload. Diese Erklärung halten Sie in Aufgabe 7 fest.

## Aufgabe 3. Artefakt: Trennung von System- und Worker-Nodes

Wir speichern die Node-Liste mit der Angabe, welche Fargate und welche EC2 sind:

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl get nodes -o wide > /var/work/tests/artifacts/3/nodes.txt
cat /var/work/tests/artifacts/3/nodes.txt
```

Die Datei sollte sowohl `fargate-...`-Nodes (System-Pods) als auch `ip-...`-Nodes
(Karpenter-Worker-Nodes) enthalten. Das ist genau die Compute-Trennung aus Kapitel 9.

## Aufgabe 4. Artefakt: Pod-IP aus dem VPC-CIDR

VPC CNI vergibt Pods routbare Adressen aus dem Subnetz des Nodes (`10.10.15.0/24` oder
`10.10.16.0/24`), also aus der VPC `10.10.0.0/16`:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl get po -n eks-101 -l app=web -o jsonpath='{.items[0].status.podIP}' \
  > /var/work/tests/artifacts/4/podip.txt
echo >> /var/work/tests/artifacts/4/podip.txt
cat /var/work/tests/artifacts/4/podip.txt
```

Um ein Gefühl für VPC CNI zu bekommen, vergleichen Sie die Pod-Adresse mit den CIDRs der
privaten Subnetze (der Pod hat eine IP aus dem Subnetz seines eigenen Nodes erhalten):

```bash
VPC=$(aws eks describe-cluster --name "$(kubectl config current-context | sed 's|.*/||')" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null)
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'Subnets[].[CidrBlock,AvailabilityZone]' --output table
```

## Aufgabe 5. Artefakt: AMI des Worker-Nodes (AL2023)

Wir schauen uns das OS-Image eines beliebigen Worker-(EC2-)Nodes an. Das Standard-NodePool
ist auf `al2023@latest` aufgebaut, also ist es Amazon Linux 2023:

```bash
mkdir -p /var/work/tests/artifacts/5
NODE=$(kubectl get po -n eks-101 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
kubectl get node "$NODE" -o jsonpath='{.status.nodeInfo.osImage}' \
  > /var/work/tests/artifacts/5/ami.txt
echo >> /var/work/tests/artifacts/5/ami.txt
cat /var/work/tests/artifacts/5/ami.txt
```

## Aufgabe 6. Deployment `batch` (6 Replicas mit CPU-Request) - Skalierung über Karpenter

Eine Workload mit expliziten Requests bringt Karpenter dazu, Compute-Ressourcen
hinzuzufügen. Wir erstellen das Deployment mit einem CPU-Request und warten, bis alle
Replicas bereit sind:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch
  namespace: eks-101
spec:
  replicas: 6
  selector:
    matchLabels:
      app: batch
  template:
    metadata:
      labels:
        app: batch
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "128Mi"
EOF

kubectl rollout status deployment/batch -n eks-101
```

So können Sie beobachten, wie Karpenter Nodes hochfährt:

```bash
kubectl get nodeclaims.karpenter.sh
kubectl get nodes -l work_type=default -o wide
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | tail -n 20
```

## Aufgabe 7. Verantwortungsgrenze: Symptom und Erklärung

Wir fordern absichtlich Fargate an, wo es das nicht gibt. Der Pod sollte in `Pending`
hängen bleiben:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: fg-probe
  namespace: eks-101
spec:
  nodeSelector:
    eks.amazonaws.com/compute-type: fargate
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

kubectl get po fg-probe -n eks-101 -o wide
kubectl describe po fg-probe -n eks-101 | sed -n '/Events/,$p'
# Events des gesamten Namespace nach Zeit sortiert - eine SRE-Diagnosefähigkeit für Scheduling-Fehler
kubectl get events -n eks-101 --sort-by='.metadata.creationTimestamp'
```

Der Pod bleibt `Pending`: Für `eks-101` gibt es kein Fargate-Profile, deshalb plant EKS den
Pod nicht auf Fargate, und Karpenter erstellt auch keinen EC2-Node, weil seine Nodes das
Label `eks.amazonaws.com/compute-type: fargate` nicht tragen. Niemand kann diese
Anforderung erfüllen.

Wir speichern die Erklärung als Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/whyfargate.txt <<'EOF'
Die Pods web und batch liefen auf Karpenter-EC2-Nodes, nicht auf Fargate: Fargate startet
einen Pod nur, wenn der Namespace des Pods zu einem profile passt. Im Cluster gibt es ein
profile fuer kube-system und karpenter, aber keines fuer eks-101.

fg-probe blieb in Pending haengen, weil er explizit Fargate anfordert (nodeSelector
eks.amazonaws.com/compute-type: fargate), aber es kein profile fuer eks-101 gibt und die
EC2-Nodes von Karpenter dieses Label nicht tragen. Weder Fargate noch Karpenter koennen
diese Anforderung erfuellen.
EOF
cat /var/work/tests/artifacts/7/whyfargate.txt
```

Die Verantwortungsgrenze wird anschaulich sichtbar: Welche Namespaces auf Fargate laufen,
entscheiden Sie selbst (über Fargate-Profile, Kapitel 9), nicht EKS "von sich aus".

## Schnellprüfung

```bash
check_result
```
