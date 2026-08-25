[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 108 - Referenzlösung (AWS Load Balancer Controller: NLB für einen Service)

Alle Befehle laufen auf der Worker-Maschine über SSH. kubectl ist bereits für den Cluster
konfiguriert. Terraform hat die IAM-Rolle für den Controller bereits erstellt (Komponente
`eks_lbc_irsa`, Modul `eks_v2_lbc_irsa`) - es bleibt nur noch, ihren ARN zu holen und den
Controller selbst zu installieren.

## Aufgabe 1. Namespace `eks-108`

```bash
kubectl create namespace eks-108
```

## Aufgabe 2. ServiceAccount und Installation des AWS Load Balancer Controllers

Wir suchen den ARN der Rolle, die terraform erstellt hat (Rollenname
`<cluster-name>-lbc-irsa`):

```bash
ROLE_ARN=$(aws iam list-roles \
  --query "Roles[?contains(RoleName,'lbc-irsa')].Arn" --output text)
echo "$ROLE_ARN"
```

Wir erstellen das ServiceAccount in `kube-system` mit einer Annotation, die auf diese Rolle
zeigt. Der LBC wird über Helm mit `serviceAccount.create=false` installiert, daher muss das
ServiceAccount vorher existieren:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${ROLE_ARN}
EOF
```

Wir installieren den Controller selbst aus dem offiziellen Chart:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' | sed 's/.*\///')
VPC_ID=$(aws eks describe-cluster --name "${CLUSTER_NAME}" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)
echo "$VPC_ID"

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=eu-central-1 \
  --set vpcId="${VPC_ID}"

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
```

Der Controller läuft auf Fargate (Namespace `kube-system` unter dem Fargate-Profil), und
auf Fargate gibt es physisch keinen EC2 Instance Metadata Service (IMDS) - ohne explizite
`vpcId`/`region` versucht der Controller, die VPC-ID über IMDS zu ermitteln, und landet in
`CrashLoopBackOff` mit einem Fehler wie `failed to fetch VPC ID from instance metadata: ...
context deadline exceeded`. Auf verwalteten EC2-Nodes braucht man diese Flags nicht (IMDS
ist dort verfügbar), aber auf Fargate muss man sie immer explizit übergeben.

Wir prüfen, dass der Controller läuft und die Rolle sieht:

```bash
kubectl get deploy aws-load-balancer-controller -n kube-system
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml | grep role-arn
```

## Aufgabe 3. Deployment `web` (viktoruj/ping_pong, 2 Replicas)

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=2 -n eks-108
kubectl rollout status deployment/web -n eks-108
```

## Aufgabe 4. Service `web` vom Typ LoadBalancer: NLB statt CLB

Standardmäßig erstellt der in-tree cloud provider für einen Service vom Typ LoadBalancer
einen veralteten Classic Load Balancer. Die Annotation `aws-load-balancer-type: external`
übergibt die Reconciliation an den AWS Load Balancer Controller, der einen modernen Network
Load Balancer erstellt:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: eks-108
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 8080
EOF
```

Wir warten auf die externe Adresse:

```bash
kubectl get svc web -n eks-108 -w
```

Über AWS CLI bestätigen wir, dass tatsächlich ein NLB (Typ `network`) erstellt wurde, kein
CLB, und dass das Schema `internet-facing` ist:

```bash
HOSTNAME=$(kubectl get svc web -n eks-108 \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
LB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='${HOSTNAME}'].LoadBalancerArn" --output text)

mkdir -p /var/work/tests/artifacts/4
aws elbv2 describe-load-balancers --load-balancer-arns "$LB_ARN" \
  > /var/work/tests/artifacts/4/nlb.txt
cat /var/work/tests/artifacts/4/nlb.txt
```

In der Ausgabe sollte `Type` gleich `network` (NLB) sein, und `Scheme` gleich
`internet-facing`. Ohne die Annotation `aws-load-balancer-type` hätte der in-tree provider
`Type: classic` erstellt - genau das ist das Symptom „LoadBalancer angefordert, CLB
bekommen" aus Kapitel 26.

## Aufgabe 5. Überprüfung der Targets: Pod-IPs statt Node-Instance-IDs

`target-type: ip` registriert in der Target Group die von VPC CNI vergebenen Pod-Adressen,
nicht die Nodes über `InstanceId`. Wir prüfen das über `describe-target-groups` und
`describe-target-health`:

```bash
TG_ARN=$(aws elbv2 describe-target-groups --load-balancer-arn "$LB_ARN" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

mkdir -p /var/work/tests/artifacts/5
{
  aws elbv2 describe-target-groups --target-group-arns "$TG_ARN"
  aws elbv2 describe-target-health --target-group-arn "$TG_ARN"
} > /var/work/tests/artifacts/5/targets.txt

cat /var/work/tests/artifacts/5/targets.txt
```

In der Datei sollte `TargetType` gleich `ip` sein, und die `Target.Id` jedes Targets sollte
eine Adresse aus `10.10.0.0/16` sein (das VPC-Subnetz dieses Labs), nicht `i-...` (eine
Instance-ID). Genau so sieht eine NLB-Target-Group mit `target-type: ip` aus: der Controller
registriert die Pod-IP direkt und umgeht den NodePort, was den zusätzlichen Hop über
kube-proxy entfernt.

## Aufgabe 6. Diagnose: erfolgreiche Reconciliation versus AccessDenied

Wir schauen ins Controller-Log, um zu sehen, wie eine normale Service-Reconciliation
aussieht - dort sollte der ARN des erstellten Load Balancers auftauchen:

```bash
kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=200 \
  | grep -i 'successfully reconciled\|loadBalancerARN\|arn:aws:elasticloadbalancing' \
  | tail -n 10
```

Hätte das ServiceAccount keine angehängte Rolle (oder hätte die Rolle nicht die nötigen
Berechtigungen), könnte der Controller die ELBv2-API nicht aufrufen, und im Log würde eine
Meldung wie `AccessDenied: User: ... is not authorized to perform:
elasticloadbalancing:CreateLoadBalancer` erscheinen, und der Service würde ohne externe
Adresse in `<pending>` bleiben - weil die Reconciliation schon beim ersten API-Aufruf
fehlschlägt, noch bevor der NLB erstellt wird.

Wir speichern beide Beobachtungen in einem einzigen Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/6
{
  echo "=== Erfolgreiche Reconciliation (echtes Controller-Log) ==="
  kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=200 \
    | grep -i 'successfully reconciled\|arn:aws:elasticloadbalancing'
  echo
  echo "=== Erwartetes Symptom ohne IAM-Berechtigungen (nicht mit der aktiven Rolle reproduziert) ==="
  echo "AccessDenied: User: arn:aws:sts::<account>:assumed-role/<cluster>-lbc-irsa/... " \
       "is not authorized to perform: elasticloadbalancing:CreateLoadBalancer " \
       "on resource: arn:aws:elasticloadbalancing:<region>:<account>:loadbalancer/*"
  echo "Bei diesem Fehler bleibt der web-Service in <pending>: EXTERNAL-IP erscheint nie," \
       "weil der Controller den NLB nicht über die ELBv2-API erstellen konnte."
} > /var/work/tests/artifacts/6/reconcile.txt

cat /var/work/tests/artifacts/6/reconcile.txt
```

## Schnelle Prüfung

```bash
check_result
```
