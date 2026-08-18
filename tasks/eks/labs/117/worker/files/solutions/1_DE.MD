[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 117 - Musterlösung (NAT pro AZ vs. ein einziges NAT, VPC endpoints, cross-AZ)

Alle Befehle laufen auf der Worker-Maschine per SSH. kubectl ist bereits für den
Cluster konfiguriert (die kubeconfig wurde beim Start der Maschine über
`aws eks update-kubeconfig` erstellt).

```bash
export CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
export VPC=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)
kubectl create namespace eks-117
```

## Aufgabe 1. Wie viele NAT Gateways, und in welchen Zonen

Das Netzwerk dieser Lab ist so aufgebaut, dass ein NAT Gateway nur in zwei der drei
privaten AZs existiert. Finden wir alle NAT Gateways in dieser VPC:

```bash
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" \
  --query 'NatGateways[].[NatGatewayId,SubnetId,State]' --output table
```

Bestimmen wir für jedes NAT die AZ seines Subnets:

```bash
NAT1=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" \
  --query 'NatGateways[0].NatGatewayId' --output text)
NAT1_SUBNET=$(aws ec2 describe-nat-gateways --nat-gateway-ids "$NAT1" \
  --query 'NatGateways[0].SubnetId' --output text)
NAT1_AZ=$(aws ec2 describe-subnets --subnet-ids "$NAT1_SUBNET" \
  --query 'Subnets[0].AvailabilityZone' --output text)

NAT2=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" \
  --query 'NatGateways[1].NatGatewayId' --output text)
NAT2_SUBNET=$(aws ec2 describe-nat-gateways --nat-gateway-ids "$NAT2" \
  --query 'NatGateways[0].SubnetId' --output text)
NAT2_AZ=$(aws ec2 describe-subnets --subnet-ids "$NAT2_SUBNET" \
  --query 'Subnets[0].AvailabilityZone' --output text)

echo "nat1=$NAT1 az=$NAT1_AZ / nat2=$NAT2 az=$NAT2_AZ"
```

Beide AZs mit einem NAT sind `eu-central-1a` und `eu-central-1b`. Das private Subnet in
`eu-central-1c` existiert (es trägt das Tag `karpenter.sh/discovery`, sodass Karpenter
dort Nodes platzieren kann), aber in dieser Zone gibt es kein NAT Gateway:

```bash
mkdir -p /var/work/tests/artifacts/1
cat > /var/work/tests/artifacts/1/natdiscovery.txt <<EOF
nat_count=2
nat_1_id=$NAT1
nat_1_az=$NAT1_AZ
nat_2_id=$NAT2
nat_2_az=$NAT2_AZ
no_nat_az=eu-central-1c
EOF
cat /var/work/tests/artifacts/1/natdiscovery.txt
```

## Aufgabe 2. Die cross-AZ-Falle reproduzieren

Finden wir die Route table des Subnets `private-subnet-3` (es liegt in
`eu-central-1c`, ohne NAT):

```bash
RTB_C=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=private-subnet-3" \
  --query 'RouteTables[0].RouteTableId' --output text)
echo "route table AZ 1c = $RTB_C"
```

Richten wir die `0.0.0.0/0`-Route dieser Route table auf das NAT Gateway einer der
Nachbarzonen - wir nehmen `NAT1` (in `eu-central-1a`), und genau das ist der Schritt,
der den cross-AZ-Pfad erzeugt:

```bash
aws ec2 create-route --route-table-id "$RTB_C" \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT1"

aws ec2 describe-route-tables --route-table-ids "$RTB_C" \
  --query 'RouteTables[0].Routes'
```

Erstellen wir eine Last, die gezielt die Zone `eu-central-1c` anfordert, damit
Karpenter dort einen Node hochfährt. Das Image ist `curlimages/curl:latest` mit einer
schlafenden `command`: aus diesem Pod prüfen wir später Egress per `kubectl exec`,
daher braucht der Container eine Shell und `curl`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crossaz
  namespace: eks-117
spec:
  replicas: 1
  selector:
    matchLabels:
      app: crossaz
  template:
    metadata:
      labels:
        app: crossaz
    spec:
      nodeSelector:
        topology.kubernetes.io/zone: eu-central-1c
      containers:
      - name: app
        image: curlimages/curl:latest
        command: ["sleep", "3600"]
EOF

kubectl rollout status deployment/crossaz -n eks-117
```

Prüfen wir den Node und seine Zone, dann Egress aus dem Pod:

```bash
POD=$(kubectl get po -n eks-117 -l app=crossaz -o jsonpath='{.items[0].metadata.name}')
NODE=$(kubectl get po -n eks-117 -l app=crossaz -o jsonpath='{.items[0].spec.nodeName}')
NODE_ZONE=$(kubectl get node "$NODE" \
  -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
echo "node=$NODE zone=$NODE_ZONE"

HTTP_CODE=$(kubectl exec -n eks-117 "$POD" -- \
  curl -s -o /dev/null -w '%{http_code}' https://checkip.amazonaws.com)
echo "egress_http_code=$HTTP_CODE"
```

Egress funktioniert (`200`), aber genau das ist die Falle aus Kapitel 31: der Pod lebt
in `eu-central-1c`, während seine Pakete zunächst die AZ-Grenze zum NAT in
`eu-central-1a` überschreiten und erst dann hinausgehen. Dieser Sprung wird als
cross-AZ-Traffic separat von der Verarbeitungsgebühr des NAT abgerechnet - das heißt,
man bezahlt für dasselbe Byte zweimal. Das korrekte Muster ist ein NAT Gateway in
jeder AZ, die Nodes hat (wie es in dieser Lab für `eu-central-1a` und `eu-central-1b`
bereits umgesetzt ist), damit der Traffic eines Nodes nie seine eigene Zone verlässt,
bevor er ein NAT erreicht.

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/crossaz.txt <<EOF
subnet_c_route_table_id=$RTB_C
nat_gateway_id_used=$NAT1
nat_gateway_az_used=$NAT1_AZ
pod_node=$NODE
pod_node_zone=$NODE_ZONE
egress_http_code=$HTTP_CODE

Die 0.0.0.0/0-Route des Subnets in eu-central-1c zeigt auf ein NAT Gateway in einer
anderen Zone ($NAT1_AZ), sodass der gesamte ausgehende Traffic eines Nodes in
eu-central-1c cross-AZ läuft: zuerst ein Inter-AZ-Sprung zum NAT, dann die Verarbeitung
auf dem NAT selbst. Das wird doppelt abgerechnet - einmal für Inter-AZ-Traffic
(cross-AZ) und einmal für die vom NAT verarbeiteten Gigabytes. Das korrekte Muster ist
ein NAT Gateway in jeder AZ, die Nodes hat, damit Traffic nie eine Zonengrenze
überschreitet.
EOF
cat /var/work/tests/artifacts/2/crossaz.txt
```

## Aufgabe 3. Gateway VPC endpoint für S3 - eine kostenlose Route

Finden wir die Route tables aller drei privaten Subnets:

```bash
RTB_A=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=private-subnet-1" \
  --query 'RouteTables[0].RouteTableId' --output text)
RTB_B=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=private-subnet-2" \
  --query 'RouteTables[0].RouteTableId' --output text)
echo "rtb_a=$RTB_A rtb_b=$RTB_B rtb_c=$RTB_C"
```

Erstellen wir einen Gateway-Endpoint für S3 und hängen ihn sofort an alle drei
Route tables:

```bash
S3_EP=$(aws ec2 create-vpc-endpoint --vpc-id "$VPC" \
  --vpc-endpoint-type Gateway --service-name com.amazonaws.eu-central-1.s3 \
  --route-table-ids "$RTB_A" "$RTB_B" "$RTB_C" \
  --query 'VpcEndpoint.VpcEndpointId' --output text)

until aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$S3_EP" \
    --query 'VpcEndpoints[0].State' --output text | grep -q available; do
  echo "waiting for the S3 endpoint to become available..."
  sleep 5
done

aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$S3_EP" \
  --query 'VpcEndpoints[0].{State:State,RouteTableIds:RouteTableIds}'
```

Ein Gateway-Endpoint für S3 erzeugt kein ENI und wird weder stündlich noch für
verarbeitete Gigabytes abgerechnet - er ist nur ein Eintrag in der Route table, was ihn
zum ersten und kosteneffizientesten Optimierungsschritt macht:

```bash
mkdir -p /var/work/tests/artifacts/3
cat > /var/work/tests/artifacts/3/s3endpoint.txt <<EOF
vpc_endpoint_id=$S3_EP
state=available
route_tables=$RTB_A,$RTB_B,$RTB_C

Ein Gateway-Endpoint für S3 ist nur ein Eintrag in der Route table, und er ist
kostenlos (бесплат): es gibt weder eine stündliche Gebühr noch eine Gebühr pro
verarbeiteten Daten, anders als bei einem Interface-Endpoint.
EOF
cat /var/work/tests/artifacts/3/s3endpoint.txt
```

## Aufgabe 4. Interface VPC endpoint für einen traffic-intensiven Service

Wählen wir `sts`: jeder Pod, der IRSA oder EKS Pod Identity nutzt, tauscht sein Token
bei jedem Start und bei jedem Credentials-Refresh über STS gegen temporäre Credentials
ein, und ohne einen Endpoint läuft dieser Austausch bei jeder solchen Anfrage über NAT.
(Die Alternative ist `ecr.api`: Autorisierung der Image-Registry bei jedem Pull; beide
Wahlmöglichkeiten werden vom Test akzeptiert.)

Nehmen wir die Default-Security-Group und erlauben sofort eingehendes HTTPS von der
VPC-CIDR darin. Ohne diese Regel würde der Endpoint erstellt, aber unerreichbar sein:
die eingehende Regel der Default-Security-Group erlaubt nur Traffic von Mitgliedern
derselben Gruppe, während Karpenters Nodes und Pods in anderen Gruppen leben.

```bash
SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC" \
  "Name=group-name,Values=default" --query 'SecurityGroups[0].GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id "$SG" \
  --protocol tcp --port 443 --cidr 10.10.0.0/16

STS_EP=$(aws ec2 create-vpc-endpoint --vpc-id "$VPC" \
  --vpc-endpoint-type Interface --service-name com.amazonaws.eu-central-1.sts \
  --subnet-ids "$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=private-subnet-1" \
    --query 'Subnets[0].SubnetId' --output text)" \
    "$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=private-subnet-2" \
    --query 'Subnets[0].SubnetId' --output text)" \
  --security-group-ids "$SG" --private-dns-enabled \
  --query 'VpcEndpoint.VpcEndpointId' --output text)

until aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$STS_EP" \
    --query 'VpcEndpoints[0].State' --output text | grep -q available; do
  echo "waiting for the sts endpoint to become available..."
  sleep 5
done

aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$STS_EP" \
  --query 'VpcEndpoints[0].{State:State,PrivateDnsEnabled:PrivateDnsEnabled}'
```

Prüfen wir, dass der Endpoint tatsächlich aus dem Cluster heraus antwortet -
`private_dns_enabled=true` bedeutet, dass der Name `sts.eu-central-1.amazonaws.com`
jetzt in der gesamten VPC zu den privaten Adressen des Endpoint-ENIs auflöst, und wenn
die `443`-Regel nicht hinzugefügt worden wäre, würde STS für jeden Pod gleichzeitig
aufhören zu funktionieren:

```bash
kubectl exec -n eks-117 "$POD" -- nslookup sts.eu-central-1.amazonaws.com
kubectl exec -n eks-117 "$POD" -- \
  curl -s -o /dev/null -w '%{http_code}\n' --connect-timeout 8 \
  https://sts.eu-central-1.amazonaws.com
```

Der Name löst zu Adressen aus `10.10.15.0/24` und `10.10.16.0/24` auf (das sind die
ENIs des Endpoints), und `curl` liefert Code `302` - eine echte STS-Antwort über
PrivateLink. Code `000` und ein Timeout hätten bedeutet, dass die Security Group des
Endpoints keinen Traffic von den Pods durchlässt.

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/interfaceendpoint.txt <<EOF
service_chosen=sts
vpc_endpoint_id=$STS_EP
state=available
private_dns_enabled=true

Gewählt wurde sts: IRSA und EKS Pod Identity tauschen bei jedem Pod-Start und bei
jedem Credentials-Refresh ein Token über STS gegen temporäre Schlüssel ein, das ist
eine häufige Anfrage, und ohne einen Endpoint läuft sie über NAT. Ein
Interface-Endpoint entfernt diesen Traffic von NAT, zum Preis einer stündlichen
Gebühr pro ENI in jeder AZ zuzüglich einer Gebühr für verarbeitete Gigabytes.
EOF
cat /var/work/tests/artifacts/4/interfaceendpoint.txt
```

## Aufgabe 5. NAT-Metriken: wie viele Bytes über jedes Gateway liefen

Ermitteln wir die Summe von `BytesOutToDestination` der letzten paar Stunden für jedes
NAT (Namespace `AWS/NATGateway`):

```bash
START=$(date -u -d '3 hours ago' +%Y-%m-%dT%H:%M:%S)
END=$(date -u +%Y-%m-%dT%H:%M:%S)

NAT_A_SUM=$(aws cloudwatch get-metric-statistics --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination --statistics Sum --period 3600 \
  --dimensions Name=NatGatewayId,Value="$NAT1" \
  --start-time "$START" --end-time "$END" \
  --query 'sum(Datapoints[].Sum)' --output text)
[[ "$NAT_A_SUM" == "None" ]] && NAT_A_SUM=0

NAT_B_SUM=$(aws cloudwatch get-metric-statistics --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination --statistics Sum --period 3600 \
  --dimensions Name=NatGatewayId,Value="$NAT2" \
  --start-time "$START" --end-time "$END" \
  --query 'sum(Datapoints[].Sum)' --output text)
[[ "$NAT_B_SUM" == "None" ]] && NAT_B_SUM=0

TOTAL=$(python3 -c "print(int(${NAT_A_SUM%.*}) + int(${NAT_B_SUM%.*}))")
echo "nat_a=$NAT1 sum=$NAT_A_SUM / nat_b=$NAT2 sum=$NAT_B_SUM / total=$TOTAL"
```

`NAT1` ist dasselbe NAT Gateway, auf das Aufgabe 2 die Route des Subnets in
`eu-central-1c` gerichtet hat. Es hat sowohl den regulären Traffic seiner eigenen Zone
`eu-central-1a` als auch den cross-AZ-Traffic vom Node `crossaz` übernommen, sodass für
denselben Zeitraum ein größeres Volumen an `BytesOutToDestination` erwartet wird als
bei `NAT2`, das nur seine eigene AZ bedient:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/natmetrics.txt <<EOF
nat_a_id=$NAT1
nat_a_bytes_out_sum=${NAT_A_SUM%.*}
nat_b_id=$NAT2
nat_b_bytes_out_sum=${NAT_B_SUM%.*}
total_bytes_out_sum=$TOTAL

Metrik: AWS/NATGateway BytesOutToDestination, Summe über die Datenpunkte im Zeitraum.
NAT $NAT1 hat zusätzlich zum regulären Traffic seiner eigenen Zone den cross-AZ-Traffic
vom Node crossaz in eu-central-1c (Aufgabe 2) übernommen, daher wird ein größeres
BytesOutToDestination-Volumen erwartet als bei $NAT2, das nur seine eigene AZ bedient.
EOF
cat /var/work/tests/artifacts/5/natmetrics.txt
```

Wenn die Testlast es geschafft hat, merklichen Traffic zu erzeugen (zum Beispiel
wiederholte `curl`-Anfragen aus dem Pod `crossaz`), ist der Unterschied der Summen
bereits im ersten Metrik-Fenster sichtbar; wenn die Last einmalig war, kann der
Unterschied klein sein - entscheidend ist die Tatsache, dass das NAT, das den
cross-AZ-Node übernommen hat, ein nicht kleineres Volumen zeigt als das andere.

## Schnellprüfung

```bash
check_result
```
