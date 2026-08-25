[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 120 - Referenzlösung (Netzwerkausfälle, unhealthy Load-Balancer-Targets)

Alle Befehle laufen auf der Worker-Maschine über SSH. kubectl ist bereits für
den Cluster konfiguriert. Terraform hat bereits die "kaputte" security group
(Komponente `eks_network_break_demo`) und eine IRSA-Rolle für den AWS Load
Balancer Controller (`eks_lbc_irsa`) erstellt - Namen und ids stehen in
`~/lab120_hints.txt`.

```bash
cat ~/lab120_hints.txt
export SG_ID=$(grep '^broken_sg_id' ~/lab120_hints.txt | awk '{print $3}')
export NODE_SG=$(grep '^node_sg_id' ~/lab120_hints.txt | awk '{print $3}')
export CLUSTER=$(grep '^cluster_name' ~/lab120_hints.txt | awk '{print $3}')
```

## Aufgabe 1. Namespace und die Workload der Lab

```bash
kubectl create namespace eks-120

kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=2 -n eks-120
kubectl rollout status deployment/api -n eks-120

kubectl expose deployment api -n eks-120 --port=80 --target-port=8080 --name=api

kubectl create deployment client --image=busybox:1.36 -n eks-120 -- sleep 3600
kubectl rollout status deployment/client -n eks-120
```

## Aufgabe 2. Baseline-Konnektivität und SG-Diagnostik

```bash
CLIENT_POD=$(kubectl get pod -n eks-120 -l app=client -o jsonpath='{.items[0].metadata.name}')

mkdir -p /var/work/tests/artifacts/2
kubectl exec -n eks-120 "$CLIENT_POD" -- \
  wget -qO- --timeout=5 http://api.eks-120.svc.cluster.local \
  > /var/work/tests/artifacts/2/connectivity.txt
cat /var/work/tests/artifacts/2/connectivity.txt
```

Die Konnektivität funktioniert hier einwandfrei: die Node-SG lässt Traffic
zwischen Cluster-Pods zu, und SGs sind stateful, sodass die Antwort auf diese
Anfrage von selbst durchgeht (Kapitel 46.3). Schauen wir uns an, welche SGs
tatsächlich am ENI des `api`-Pods hängen:

```bash
API_IP=$(kubectl get pod -n eks-120 -l app=api -o jsonpath='{.items[0].status.podIP}')

Es kommt darauf an, welchen Filter Sie zum Finden des ENI verwenden. Mit VPC
CNI ist die IP des Pods eine **sekundäre** Adresse auf dem ENI der Node,
deshalb liefert der Filter `private-ip-address` (der die primäre Adresse des
Interfaces betrachtet) `null`. Sie benötigen `addresses.private-ip-address`,
der über alle Adressen des Interfaces sucht:

```bash
aws ec2 describe-network-interfaces \
  --filters "Name=addresses.private-ip-address,Values=${API_IP}" \
  --query 'NetworkInterfaces[0].Groups' \
  > /var/work/tests/artifacts/2/api_sg.txt
cat /var/work/tests/artifacts/2/api_sg.txt
```

## Aufgabe 3. Installation des AWS Load Balancer Controllers

```bash
LBC_ROLE_ARN=$(aws iam get-role --role-name "${CLUSTER}-lbc-irsa" \
  --query 'Role.Arn' --output text)

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${LBC_ROLE_ARN}
EOF

helm repo add eks https://aws.github.io/eks-charts
helm repo update

Ein wichtiges Detail dieser Umgebung: der Namespace `kube-system` fällt unter
das Fargate-Profil, deshalb laufen die Pods des Controllers auf Fargate, und
Fargate hat **kein IMDS**. Ohne IMDS kann der Controller Region und VPC nicht
selbst bestimmen und bricht mit `failed to get VPC ID: ... ec2imds ... context
deadline exceeded` ab. Deshalb werden `region` und `vpcId` explizit gesetzt:

```bash
REGION=eu-central-1
VPC_ID=$(aws eks describe-cluster --name "${CLUSTER}" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${REGION}" \
  --set vpcId="${VPC_ID}"

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
```

## Aufgabe 4. Symptom: NLB mit unhealthy targets

Wir setzen die "kaputte" SG als eigene security group des Balancers. Sobald
eine SG explizit über die Annotation angegeben wird, hört der LBC auf, für
uns die fehlende inbound rule zur Node-SG zu ergänzen - das ist genau der
Fehler (Kapitel 46.6):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: api-lb
  namespace: eks-120
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    service.beta.kubernetes.io/aws-load-balancer-security-groups: ${SG_ID}
spec:
  type: LoadBalancer
  selector:
    app: api
  ports:
    - port: 80
      targetPort: 8080
EOF

kubectl get svc api-lb -n eks-120 -w
```

Wir warten auf die externe Adresse, finden die target group und prüfen die
health der targets:

```bash
HOSTNAME=$(kubectl get svc api-lb -n eks-120 \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
LB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='${HOSTNAME}'].LoadBalancerArn" --output text)
TG_ARN=$(aws elbv2 describe-target-groups --load-balancer-arn "$LB_ARN" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

mkdir -p /var/work/tests/artifacts/4
aws elbv2 describe-target-health --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table > /var/work/tests/artifacts/4/unhealthy.txt
cat /var/work/tests/artifacts/4/unhealthy.txt
```

Alle targets sind `unhealthy` - die SG des Balancers lässt den health check
nicht zur Node-SG durch, und deshalb erreicht er auch den `api`-Pod nicht.

## Aufgabe 5. Diagnostik: welche SG den health check blockiert

```bash
aws ec2 describe-security-groups --group-ids "$SG_ID" \
  --query 'SecurityGroups[0].IpPermissions'
```

Die leere Liste bestätigt es: die SG des Balancers hat nicht eine einzige
inbound rule.

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/diagnosis.txt <<EOF
Die security group des Balancers (${SG_ID}) ist api-lb über die Annotation
aws-load-balancer-security-groups zugewiesen und enthält keine inbound rules.
Der health check vom NLB kommt als neue TCP-Verbindung von der security group
des Balancers zur security group der Node (${NODE_SG}) auf Port 8080 der
Anwendung an. Die security group der Node erlaubt keinen inbound Traffic von
der security group des Balancers auf diesem Port, deshalb schlägt der health
check fehl und die targets bleiben unhealthy (Kapitel 46.6).
EOF
cat /var/work/tests/artifacts/5/diagnosis.txt
```

## Aufgabe 6. Fix: authorize-security-group-ingress, targets healthy

Zwei Regeln: den health check und den Anwendungstraffic von der SG des
Balancers zur Node-SG erlauben, und den NLB-Listener für Clients auf Port 80
öffnen:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id "$NODE_SG" \
  --protocol tcp --port 8080 \
  --source-group "$SG_ID"

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 80 \
  --cidr 0.0.0.0/0
```

Wir warten, bis die targets `healthy` werden (üblicherweise 1-2 Minuten), und
prüfen mit curl:

```bash
sleep 90

mkdir -p /var/work/tests/artifacts/6
{
  aws elbv2 describe-target-health --target-group-arn "$TG_ARN" \
    --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State]' --output table
  echo
  curl -s --max-time 5 "http://${HOSTNAME}"
} > /var/work/tests/artifacts/6/healthy.txt
cat /var/work/tests/artifacts/6/healthy.txt
```

## Aufgabe 7. DNS funktioniert: eine kontrastierende Prüfung

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl run dnstest --image=busybox:1.36 --rm -i --restart=Never -- \
  sh -c 'nslookup kubernetes.default.svc.cluster.local; nslookup example.com' \
  > /var/work/tests/artifacts/7/dns.txt
cat /var/work/tests/artifacts/7/dns.txt
```

Wir fragen den internen Namen über seinen vollen FQDN ab. Das kurze
`kubernetes.default` liefert über `nslookup` von busybox `NXDOMAIN`: dieser
Resolver hängt die search domains aus `/etc/resolv.conf` nicht so an, wie es
ein gewöhnlicher Client tut, und diese Antwort wird leicht mit einem
DNS-Fehler verwechselt, der hier gar nicht vorliegt.

Beide Namen werden einwandfrei aufgelöst (`kubernetes.default.svc.cluster.local`
zur Adresse des `kubernetes`-Service, `example.com` zu externen Adressen) -
DNS ist in dieser Lab nicht die Ursache des Problems (Kapitel 46.5, 46.7), im
Gegensatz zur security group aus den Aufgaben 4-6.

## Aufgabe 8. Abschließende Checkliste: Symptom - wahrscheinliche Ursache - was zu prüfen ist

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/summary.txt <<EOF
Symptom: Die targets in der NLB target group sind unhealthy, der api-lb
Service liefert 503.
Wahrscheinliche Ursache: Die security group des Balancers erlaubt keinen
inbound Traffic zur Node-SG auf dem health-check-Port (Kapitel 46.6).
Was zu prüfen ist: aws elbv2 describe-target-health --target-group-arn <arn>
zeigt TargetHealth.Reason=Target.FailedHealthChecks, und aws ec2
describe-security-groups bestätigt, dass die SG des Balancers keine inbound
rule hat.
EOF
cat /var/work/tests/artifacts/8/summary.txt
```

## Kurzprüfung

```bash
check_result
```
