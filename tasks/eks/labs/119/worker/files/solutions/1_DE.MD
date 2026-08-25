[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 119 - Referenzlösung (Troubleshooting: Node erreicht Ready nicht)

Alle Befehle laufen auf der Worker-Maschine per SSH. kubectl ist bereits für den
Cluster konfiguriert, die `aws` CLI ist für denselben Account und dieselbe Region
konfiguriert.

Zuerst speichern wir den Cluster-Namen in eine Variable - fast jeder Befehl braucht sie:

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
echo "$CLUSTER"
```

## Aufgabe 1. Namespace `eks-119`

```bash
kubectl create namespace eks-119
```

## Aufgabe 2. Inventar: eine gesunde managed node group als Norm

In der Lab läuft bereits eine managed node group (getrennt von Karpenter) - das ist das
gesunde Muster, mit dem die kaputte self-managed Instance aus den folgenden Aufgaben
verglichen wird.

```bash
mkdir -p /var/work/tests/artifacts/2
NODEGROUP=$(aws eks list-nodegroups --cluster-name "$CLUSTER" --query 'nodegroups[0]' --output text)
{
  echo "=== aws eks describe-nodegroup health.issues (Norm - leere Liste) ==="
  aws eks describe-nodegroup --cluster-name "$CLUSTER" --nodegroup-name "$NODEGROUP" \
    --query 'nodegroup.health.issues'
  echo "=== kubectl get nodes -o wide ==="
  kubectl get nodes -o wide
} > /var/work/tests/artifacts/2/nodegroup_health.txt
cat /var/work/tests/artifacts/2/nodegroup_health.txt
```

Wenn `health.issues` keine leere Liste ist - das ist genau der `NodeCreationFailure` aus
Kapitel 45, und es wäre dann kein gesundes Muster mehr für den Vergleich. Normalerweise
ist eine Node aus der managed node group in `kubectl get nodes` mit Status `Ready`
sichtbar.

## Aufgabe 3. Test-IAM-Rolle für die self-managed Instance

Die Node-Rolle muss `AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryReadOnly`
und `AmazonEKS_CNI_Policy` (Kapitel 45.2) bekommen - dasselbe Set wie die Rolle der
gesunden managed node group. Die dritte Policy ist hier keine Formalität: das Addon
`vpc-cni` läuft ohne eigene IRSA-Rolle, deshalb nimmt `aws-node` die Credentials aus der
Rolle der Node, und ohne `AmazonEKS_CNI_Policy` bleibt die Node für immer `NotReady` mit
`cni plugin not initialized`. In dieser Lab muss genau eine Sache kaputt sein - der
fehlende access entry. Der Rollenname muss `-test-` enthalten, sonst kann der Worker sie
nicht verwalten.

```bash
ROLE_NAME="eks-task119-test-node"
aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}'

aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

aws iam create-instance-profile --instance-profile-name "$ROLE_NAME"
aws iam add-role-to-instance-profile --instance-profile-name "$ROLE_NAME" --role-name "$ROLE_NAME"

ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
mkdir -p /var/work/tests/artifacts/3
echo "$ROLE_ARN" > /var/work/tests/artifacts/3/test_role_arn.txt
cat /var/work/tests/artifacts/3/test_role_arn.txt
```

Das Instance Profile wird sofort erstellt: die Instance braucht genau dieses, nicht die
Rolle direkt. Geben Sie dem Profil 10-15 Sekunden zur Propagierung, bevor Sie die
Instance starten.

## Aufgabe 4. Self-managed EC2-Instance auf AL2023 ohne access entry

Wir nehmen dieselbe AMI, dasselbe private Subnet und dieselbe security group der Nodes
wie bei den regulären Nodes des Clusters, erstellen aber KEINEN access entry - das ist
das absichtlich unvollständige Setup.

```bash
AMI_ID=$(aws ssm get-parameter \
  --name /aws/service/eks/optimized-ami/1.36/amazon-linux-2023/x86_64/standard/recommended/image_id \
  --query 'Parameter.Value' --output text)

VPC_ID=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.resourcesVpcConfig.vpcId' --output text)
SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
  "Name=tag:kubernetes.io/cluster/$CLUSTER,Values=owned" "Name=tag:kubernetes.io/role/internal-elb,Values=1" \
  --query 'Subnets[0].SubnetId' --output text)
SG_ID=$(aws ec2 describe-security-groups --filters "Name=tag:karpenter.sh/discovery,Values=$CLUSTER" \
  --query 'SecurityGroups[0].GroupId' --output text)

API_ENDPOINT=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.endpoint' --output text)
CA_DATA=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.certificateAuthority.data' --output text)
SERVICE_CIDR=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.kubernetesNetworkConfig.serviceIpv4Cidr' --output text)
```

Wir bauen die user data: ein MIME-Dokument mit einer `NodeConfig` für `nodeadm`
(Kapitel 10.5 und Kapitel 45.4).

```bash
cat > /tmp/user-data.yaml <<EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="BOUNDARY"

--BOUNDARY
Content-Type: application/node.eks.aws

apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: ${CLUSTER}
    apiServerEndpoint: ${API_ENDPOINT}
    certificateAuthority: ${CA_DATA}
    cidr: ${SERVICE_CIDR}

--BOUNDARY--
EOF
```

Wir starten die Instance mit dem Test-Instance-Profile und derselben AMI/Subnet/SG wie
die Produktions-Nodes. Der `Name`-Tag mit `-test-` wird für die Berechtigungen des
Workers benötigt und muss gleichzeitig in beiden `--tag-specifications`-Abschnitten
angegeben werden - sowohl für `instance` als auch für `volume`. Die Policy des Workers
erlaubt `RunInstances` auf `instance/*` und `volume/*` nur unter der Bedingung
`aws:RequestTag/Name = *-test-*`, und `RunInstances` erstellt zusammen mit der Instance
auch ein Root-Volume. Ohne Tag auf dem Volume antwortet AWS mit `UnauthorizedOperation
... on resource: .../volume/*`, obwohl die Instance selbst korrekt getaggt ist:

```bash
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t3.medium \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$SG_ID" \
  --iam-instance-profile "Name=eks-task119-test-node" \
  --user-data file:///tmp/user-data.yaml \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=eks-task119-test-node}]' \
    'ResourceType=volume,Tags=[{Key=Name,Value=eks-task119-test-node}]' \
  --query 'Instances[0].InstanceId' --output text)

mkdir -p /var/work/tests/artifacts/4
echo "$INSTANCE_ID" > /var/work/tests/artifacts/4/instance_id.txt
cat /var/work/tests/artifacts/4/instance_id.txt
```

## Aufgabe 5. Symptom: `running` in EC2, aber nicht in `kubectl get nodes`

Geben Sie der Instance 3-5 Minuten zum Booten und Bootstrapping, dann vergleichen Sie
die beiden Quellen der Wahrheit.

```bash
sleep 240
STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].State.Name' --output text)
NODES=$(kubectl get nodes -o wide)

mkdir -p /var/work/tests/artifacts/5
{
  echo "instance $INSTANCE_ID state: $STATE"
  echo "=== kubectl get nodes ==="
  echo "$NODES"
} > /var/work/tests/artifacts/5/no_join_symptom.txt
cat /var/work/tests/artifacts/5/no_join_symptom.txt
```

Die Instance ist `running`, fehlt aber in der Node-Liste - genau das Symptom, mit dem
Kapitel 45 beginnt.

## Aufgabe 6. Diagnose: was der Rolle fehlt

```bash
aws eks list-access-entries --cluster-name "$CLUSTER"
```

Der ARN der Rolle `eks-task119-test-node` fehlt in der Liste. Die Rolle hat managed
policies (`AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryReadOnly`), aber keine
Autorisierung innerhalb des Clusters - ohne einen access entry vom Typ `EC2_LINUX`
kommt kubelet nicht durch die Autorisierung.

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/why_no_access_entry.txt <<EOF
Instance $INSTANCE_ID läuft in EC2, ist aber nicht in kubectl get nodes erschienen. Der
Grund ist, dass die Rolle $ROLE_ARN managed policies hat (AmazonEKSWorkerNodePolicy,
AmazonEC2ContainerRegistryReadOnly), aber keinen access entry im Cluster. Die
IAM-Berechtigungen der Rolle und die Autorisierung der Rolle im Cluster sind zwei
verschiedene Dinge (Kapitel 45.2). aws eks list-access-entries für $CLUSTER zeigt diese
Rolle nicht an. Eine managed node group erstellt einen solchen Eintrag automatisch,
während für self-managed Nodes ein access entry vom Typ EC2_LINUX manuell mit aws eks
create-access-entry erstellt werden muss.
EOF
cat /var/work/tests/artifacts/6/why_no_access_entry.txt
```

## Aufgabe 7. Fix: ein access entry vom Typ `EC2_LINUX`

```bash
aws eks create-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$ROLE_ARN" --type EC2_LINUX
```

Geben Sie der Node Zeit, sich zu registrieren und in `Ready` zu wechseln
(normalerweise 1-2 Minuten nach dem Erstellen des access entry, da kubelet bereits
lief und auf Autorisierung wartete):

```bash
for i in $(seq 1 20); do
  kubectl get nodes -o wide | grep -q "$INSTANCE_ID" && break
  sleep 15
done
kubectl get nodes -o wide
```

Der Identifikator der Node im Cluster ist der private DNS-Name der Instance, nicht die
`INSTANCE_ID` selbst; um die Zeile für die konkrete Instance zu finden, vergleichen Sie
sie mit `PrivateDnsName`:

```bash
NODE_NAME=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PrivateDnsName' --output text)
kubectl get node "$NODE_NAME"
```

Warten Sie auf das tatsächliche `Ready`, nicht nur auf das Erscheinen der Node in der
Liste: direkt nach der Registrierung bleibt sie noch ein paar Dutzend Sekunden
`NotReady`, während `aws-node` hochkommt. Dann halten wir den Beweis fest - nach
Aufgabe 9 wird weder die Node noch ihr privater DNS-Name mehr existieren:

```bash
for i in $(seq 1 20); do
  STATUS=$(kubectl get node "$NODE_NAME" --no-headers | awk '{print $2}')
  echo "node status=$STATUS"
  [[ "$STATUS" == "Ready" ]] && break
  sleep 15
done

mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/node_ready.txt <<EOF
node_name=$NODE_NAME
node_status=$STATUS
EOF
cat /var/work/tests/artifacts/7/node_ready.txt
```

## Aufgabe 8. Verifikation: die Node akzeptiert tatsächlich Pods

`Ready` ist noch kein Beweis, dass die Node funktioniert. Wir planen einen Pod gezielt
auf sie:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: probe
  namespace: eks-119
spec:
  nodeSelector:
    kubernetes.io/hostname: ${NODE_NAME}
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

kubectl wait --for=condition=Ready pod/probe -n eks-119 --timeout=240s
kubectl get pod probe -n eks-119 -o wide
```

Wir halten den Beweis genauso fest wie in Aufgabe 7: der Pod lebt auf dieser Node und
verschwindet zusammen mit ihr, sobald die Instance in Aufgabe 9 terminiert wird.

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/probe.txt <<EOF
pod_phase=$(kubectl get pod probe -n eks-119 -o jsonpath='{.status.phase}')
pod_node=$(kubectl get pod probe -n eks-119 -o jsonpath='{.spec.nodeName}')
EOF
cat /var/work/tests/artifacts/8/probe.txt
```

## Aufgabe 9. Aufräumen: die self-managed Instance terminieren

Diese EC2-Instance ist nicht Teil des terraform-Zustands der Lab: `make delete_eks_task`
rührt sie nicht an. Terminieren Sie sie selbst, bevor Sie die Lab abschließen:

```bash
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"

mkdir -p /var/work/tests/artifacts/9
echo "terminated $INSTANCE_ID at $(date -u +%FT%TZ)" > /var/work/tests/artifacts/9/terminated.txt
```

Den access entry, die Test-Rolle und das Instance Profile lohnt es sich ebenfalls zu
entfernen: sie kosten kein Geld, aber ihre Namen sind statisch, deshalb bleiben sie im
Account auch nach `make delete_eks_task` bestehen. Die Reihenfolge ist wichtig - zuerst
der access entry, dann die Rolle:

```bash
aws eks delete-access-entry --cluster-name "$CLUSTER" --principal-arn "$ROLE_ARN"
aws iam remove-role-from-instance-profile --instance-profile-name eks-task119-test-node \
  --role-name eks-task119-test-node
aws iam delete-instance-profile --instance-profile-name eks-task119-test-node
for p in AmazonEKSWorkerNodePolicy AmazonEC2ContainerRegistryReadOnly AmazonEKS_CNI_Policy; do
  aws iam detach-role-policy --role-name eks-task119-test-node \
    --policy-arn arn:aws:iam::aws:policy/$p
done
aws iam delete-role --role-name eks-task119-test-node
```

## Schnellprüfung

```bash
check_result
```
