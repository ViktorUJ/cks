[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 103 - Musterlösung (Adressplan: ENI, prefix delegation, secondary CIDR)

Alle Befehle werden auf der Worker-Maschine per SSH ausgeführt. kubectl ist bereits für
den Cluster konfiguriert (die kubeconfig wird beim Hochfahren der Maschine über
`aws eks update-kubeconfig` erstellt).

```bash
export CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
kubectl create namespace eks-103
```

## Aufgabe 1. Berechnung von max-pods per Formel und Abgleich mit dem Ist-Wert

Wir erstellen die Basislast und warten, bis Karpenter dafür einen EC2-Node im normalen
(adressbasierten) Modus von VPC CNI startet - das Addon ist noch nicht auf prefix
delegation umgestellt:

```bash
kubectl create deployment baseline --image=viktoruj/ping_pong:latest --replicas=2 -n eks-103
kubectl rollout status deployment/baseline -n eks-103

NODE=$(kubectl get po -n eks-103 -l app=baseline -o jsonpath='{.items[0].spec.nodeName}')
TYPE=$(kubectl get node "$NODE" \
  -o jsonpath='{.metadata.labels.node\.kubernetes\.io/instance-type}')
echo "node=$NODE type=$TYPE"
```

Wir ermitteln ENI-Anzahl, IPs pro ENI und vCPU für diesen Instanztyp:

```bash
ENI=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].NetworkInfo.MaximumNetworkInterfaces' --output text)
IPS=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].NetworkInfo.Ipv4AddressesPerInterface' --output text)
VCPU=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].VCpuInfo.DefaultVCpus' --output text)
echo "eni=$ENI ips_per_eni=$IPS vcpu=$VCPU"
```

Wir berechnen mit der Formel `max-pods = ENI * (IPs pro ENI - 1) + 2` und wenden den Cap
der managed node group an (`110` bei `vCPU < 30`, sonst `250`):

```bash
FORMULA=$((ENI * (IPS - 1) + 2))
if [ "$VCPU" -lt 30 ]; then CAP=110; else CAP=250; fi
if [ "$FORMULA" -lt "$CAP" ]; then EXPECTED=$FORMULA; else EXPECTED=$CAP; fi
echo "formula=$FORMULA cap=$CAP expected_max_pods=$EXPECTED"

ACTUAL=$(kubectl get node "$NODE" -o jsonpath='{.status.allocatable.pods}')
echo "actual_allocatable_pods=$ACTUAL"
```

Beispiel für `m5.large`: `ENI=3`, `IPs pro ENI=10` ergeben `formula = 3*(10-1)+2 = 29`, der
Cap `110` greift nicht (`29 < 110`), also `expected_max_pods = 29` - und genau das sollte
`kubectl get node` anzeigen.

Wir speichern Berechnung und Ist-Wert im Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/1
cat > /var/work/tests/artifacts/1/maxpods.txt <<EOF
node=$NODE
instance_type=$TYPE
eni=$ENI
ips_per_eni=$IPS
vcpu=$VCPU
formula=$FORMULA
cap=$CAP
expected_max_pods=$EXPECTED
actual_allocatable_pods=$ACTUAL
EOF
cat /var/work/tests/artifacts/1/maxpods.txt
```

Wenn `expected_max_pods` und `actual_allocatable_pods` nicht übereinstimmen - kubelet
erfährt max-pods nur beim Start des Nodes, der Abgleich muss also auf einem Node erfolgen,
der bereits vollständig Ready ist.

## Aufgabe 2. Prefix delegation: neuer Node gegen alten Node

Wir halten den Zustand des alten Nodes (adressbasierter Modus) fest, bevor prefix
delegation aktiviert wird:

```bash
OLD_NODE="$NODE"
OLD_PODS=$(kubectl get node "$OLD_NODE" -o jsonpath='{.status.allocatable.pods}')
echo "old_node=$OLD_NODE old_node_allocatable_pods=$OLD_PODS"
```

Wir aktivieren prefix delegation auf dem managed Addon `vpc-cni` (funktioniert nur auf
Nitro-basierten Instanzen, deshalb ist wichtig, dass der NodePool solche Typen verwendet):

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
  --configuration-values '{"env":{"ENABLE_PREFIX_DELEGATION":"true","WARM_PREFIX_TARGET":"1"}}' \
  --resolve-conflicts PRESERVE

aws eks describe-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
  --query 'addon.configurationValues'
```

Prefix delegation betrifft nur neue Nodes: der alte Node `baseline` hat sein Limit
`allocatable.pods` bereits beim Start von kubelet erhalten und berechnet es nicht neu,
bis er neu erstellt wird. Wir provozieren die Erstellung eines neuen Nodes mit einer
Last, die nicht auf den alten passt:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scale
  namespace: eks-103
spec:
  replicas: 6
  selector:
    matchLabels:
      app: scale
  template:
    metadata:
      labels:
        app: scale
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "1"
            memory: "128Mi"
EOF

kubectl rollout status deployment/scale -n eks-103
```

Wir bestimmen den neuen Node und vergleichen die Limits:

```bash
NEW_NODE=$(kubectl get po -n eks-103 -l app=scale -o jsonpath='{.items[*].spec.nodeName}' \
  | tr ' ' '\n' | grep -v "^${OLD_NODE}$" | head -n1)
NEW_TYPE=$(kubectl get node "$NEW_NODE" \
  -o jsonpath='{.metadata.labels.node\.kubernetes\.io/instance-type}')
NEW_PODS=$(kubectl get node "$NEW_NODE" -o jsonpath='{.status.allocatable.pods}')
echo "new_node=$NEW_NODE new_node_instance_type=$NEW_TYPE new_node_allocatable_pods=$NEW_PODS"
```

Beispiel für `m5.large` im Präfix-Modus: das Limit springt von `29` auf `434` (begrenzt
durch den Cap der managed node group `110`, sodass die tatsächliche Obergrenze `110` ist,
aber das ist immer noch deutlich mehr als die `29` des adressbasierten Modus).

Wir speichern Vergleich und Erklärung im Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/prefixdelegation.txt <<EOF
old_node=$OLD_NODE
old_node_allocatable_pods=$OLD_PODS
new_node=$NEW_NODE
new_node_instance_type=$NEW_TYPE
new_node_allocatable_pods=$NEW_PODS

old_node_allocatable_pods hat sich nicht geändert, weil kubelet max-pods nur einmal
berechnet, beim Start des Nodes, und prefix delegation nur neue Nodes betrifft, nicht
bereits laufende. new_node wurde nach der Aktivierung von prefix delegation erstellt,
daher belegen dessen ENI Präfixe /28 (je 16 Adressen) statt einzelner IPs, und das
Pod-Limit ist deutlich höher.
EOF
cat /var/work/tests/artifacts/2/prefixdelegation.txt
```

## Aufgabe 3. Planung der Subnetzgröße für Wachstum

Wir berechnen den endgültigen Bedarf: `850` Pods, Puffer `20%` für den Warm Pool, dann
weitere `15%` für das Rolling Update (die Puffer multiplizieren sich sequenziell):

```bash
python3 - <<'EOF'
base = 850
after_warm = base * 1.20
after_roll = after_warm * 1.15
print(f"base={base} after_warm_pool={after_warm:.0f} after_rolling_update={after_roll:.0f}")
EOF
```

Ergebnis: `850 * 1.20 = 1020`, `1020 * 1.15 = 1173` - der endgültige Bedarf beträgt etwa
`1173` Adressen. Wir vergleichen mit der Tabelle der verfügbaren Adressen pro
Subnetz-Präfix (AWS reserviert `5` Adressen pro Subnetz):

- `/24` - insgesamt `256`, verfügbar `251` - weniger als `1173`, passt nicht;
- `/22` - insgesamt `1024`, verfügbar `1019` - ebenfalls weniger als `1173`, passt nicht;
- `/20` - insgesamt `4096`, verfügbar `4091` - reicht mit großem Puffer.

`4091 / 1173 ≈ 3.5` mal Puffer, was sowohl die aktuelle Berechnung als auch künftiges
Wachstum abdeckt, daher wählen wir `/20`.

```bash
mkdir -p /var/work/tests/artifacts/3
cat > /var/work/tests/artifacts/3/cidrplan.txt <<'EOF'
Bedarf: 850 Pods * 1.20 (Puffer für Warm Pool) * 1.15 (Puffer für Rolling Update)
= 1173 Adressen (endgültiger Adressbedarf).

/24 (insgesamt 256, verfügbar 251) - passt nicht, verfügbar ist kleiner als der Bedarf.
/22 (insgesamt 1024, verfügbar 1019) - passt nicht, verfügbar ist kleiner als der Bedarf (1173).
/20 (insgesamt 4096, verfügbar 4091) - passt: 4091 / 1173 ~= 3.5-facher Puffer.

Wahl: /20. Der Warm Pool von Karpenter und ein gleichzeitiges Rolling Update halten
kurzzeitig zusätzliche Adressen belegt, daher muss das Subnetz deutlich größer sein als
der punktuelle Höchststand, nicht knapp bei 1173 Adressen liegen.
EOF
cat /var/work/tests/artifacts/3/cidrplan.txt
```

## Aufgabe 4. Secondary CIDR: wir erweitern den Adressplan des VPC

Wir ermitteln die `vpc-id` des Clusters und hängen einen secondary CIDR aus dem shared
address space von RFC 6598 an (`100.64.0.0/16` überlappt nicht mit dem primären CIDR
`10.10.0.0/16` dieses VPC):

```bash
VPC=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)

aws ec2 associate-vpc-cidr-block --vpc-id "$VPC" --cidr-block 100.64.0.0/16
```

Wir warten auf den Status `associated` (direkt nach dem Aufruf kann der Block noch
`associating` sein):

```bash
until aws ec2 describe-vpcs --vpc-ids "$VPC" \
    --query "Vpcs[].CidrBlockAssociationSet[?CidrBlock=='100.64.0.0/16'].CidrBlockState.State" \
    --output text | grep -q associated; do
  echo "waiting for secondary CIDR to become associated..."
  sleep 5
done

aws ec2 describe-vpcs --vpc-ids "$VPC" \
  --query 'Vpcs[].CidrBlockAssociationSet[].{CIDR:CidrBlock,State:CidrBlockState.State}'
```

Wir erstellen ein Subnetz im neuen Block:

```bash
SUBNET=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 100.64.1.0/24 \
  --availability-zone eu-central-1a --query 'Subnet.SubnetId' --output text)
echo "subnet=$SUBNET"
```

Wir speichern das Ergebnis im Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/4
{
  echo "secondary_cidr=100.64.0.0/16"
  aws ec2 describe-vpcs --vpc-ids "$VPC" \
    --query 'Vpcs[].CidrBlockAssociationSet[].{CIDR:CidrBlock,State:CidrBlockState.State}' \
    --output table
  echo "subnet_id=$SUBNET"
} > /var/work/tests/artifacts/4/secondary_cidr.txt
cat /var/work/tests/artifacts/4/secondary_cidr.txt
```

Würden wir statt `100.64.0.0/16` `172.16.0.0/12` oder `192.168.0.0/16` versuchen -
AWS würde das nicht zu einem VPC hinzufügen lassen, dessen primärer CIDR bereits im
Bereich `10.0.0.0/8` liegt (Überlappung privater RFC-1918-Bereiche), deshalb nimmt man
üblicherweise gerade RFC 6598.

## Aufgabe 5. Diagnose eines Adressmangels (ohne echten Ausfall)

Wir fassen die Infrastruktur des Labs nicht an: Subnetze werden nicht verkleinert und
Adressen nicht künstlich erschöpft. Wir betrachten den aktuellen Zustand der Subnetze des
Clusters - das sind dieselben Befehle, mit denen ein Adressmangel auf einem laufenden
Cluster diagnostiziert wird:

```bash
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,AvailableIpAddressCount]' \
  --output table
```

Wir speichern die Erklärung der Diagnose eines Adressmangels im Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/diagnostics.txt <<'EOF'
Wie man einen Mangel an IP-Adressen auf einem laufenden Cluster diagnostiziert:

1. Symptom am Pod: kubectl describe pod zeigt in Events das Ereignis
   FailedCreatePodSandBox von aws-cni - das ist das erste Signal, dass VPC CNI keine
   Adresse zuweisen konnte.

2. Allgemeiner Adressmangel in einem Subnetz: aws ec2 describe-subnets --query
   'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,AvailableIpAddressCount]' - wenn
   AvailableIpAddressCount dieser AZ 0 ist, ist das eine direkte Diagnose für
   erschöpfte Adressen in diesem Subnetz und dieser AZ.

3. Fragmentierung statt echtem Mangel: wenn prefix delegation aktiviert ist, aber kein
   zusammenhängender /28-Block im Subnetz vorhanden ist (Adressen sind auf einzeln
   belegte IPs verteilt), erscheint in den Logs von ipamd/aws-node ein Fehler
   InsufficientCidrBlocks, selbst wenn das AvailableIpAddressCount des Subnetzes groß
   aussieht. Das sind unterschiedliche Ursachen für dasselbe äußere Symptom (ein Pod
   bekommt keine Adresse), und sie werden unterschiedlich behoben: Adressmangel wird
   durch Erweiterung des CIDR oder eines secondary CIDR behoben (Aufgabe 4),
   Fragmentierung durch Freiräumen für einen zusammenhängenden Block oder ein neues
   Subnetz.
EOF
cat /var/work/tests/artifacts/5/diagnostics.txt
```

## Schnellprüfung

```bash
check_result
```
