[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 126 - Referenzlösung (security groups for pods)

Alle Befehle laufen auf der Worker-Maschine per SSH, genau wie in den übrigen Labs des
Kurses: Die Worker-Rolle hat Rechte bekommen, um eine Security Group und deren Regeln zu
erstellen sowie die Richtlinie `AmazonEKSVPCResourceController` an die Rolle des Clusters
anzuhängen (siehe README, Abschnitt "Infrastruktur").

Variablen, die für die gesamte Lösung gelten:

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
CLUSTER=$(kubectl config current-context | awk -F/ '{print $NF}')
REGION=eu-central-1
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.resourcesVpcConfig.vpcId' --output text)
echo "cluster=$CLUSTER vpc=$VPC_ID"
```

## Aufgabe 1. Namespace `eks-126`

```bash
kubectl create namespace eks-126
```

## Aufgabe 2. Kontrolle der Voraussetzungen

Wir ermitteln den Namen der Rolle der control plane und prüfen die angehängten
Richtlinien (auf dem Worker):

```bash
ROLE_ARN=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.roleArn' --output text)
ROLE_NAME=$(echo "$ROLE_ARN" | sed 's|.*/||')
echo "cluster role: $ROLE_NAME"
aws iam list-attached-role-policies --role-name "$ROLE_NAME"
```

Standardmäßig ist sie dort nicht vorhanden (die Rolle hat nur `AmazonEKSClusterPolicy`
und die Verschlüsselungsrichtlinie), also hängen wir sie an:

```bash
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSVPCResourceController
```

Die Richtlinie gehört an die Rolle der **control plane** (des Clusters), nicht an die
Rolle der Karpenter-Node - genau sie erlaubt EKS, branch ENIs zu erstellen/löschen und
deren IPs zu verwalten.

Wir prüfen die drei Variablen des VPC CNI - alle sind bereits von Terraform über die
`configuration` des Add-ons `vpc-cni` gesetzt:

```bash
kubectl describe daemonset aws-node -n kube-system \
  | grep -E 'ENABLE_POD_ENI|POD_SECURITY_GROUP_ENFORCING_MODE|DISABLE_TCP_EARLY_DEMUX'
```

Erwartete Ausgabe: `ENABLE_POD_ENI: true`, `POD_SECURITY_GROUP_ENFORCING_MODE: strict`,
`DISABLE_TCP_EARLY_DEMUX: true`. Die erste aktiviert das Trunk-Interface, die zweite
belässt die Kontrolle der SG-Regeln des Pods für Traffic von der Node (im Modus `standard`
gäbe es sie nicht, und das Symptom aus Aufgabe 4 würde nicht auftreten), die dritte
erlaubt `kubelet`, TCP zum Pod auf der branch ENI zu öffnen.

Wir speichern beide Nachweise:

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "cluster role: $ROLE_NAME"
  aws iam list-attached-role-policies --role-name "$ROLE_NAME"
  echo "---"
  kubectl describe daemonset aws-node -n kube-system | grep ENABLE_POD_ENI
} > /var/work/tests/artifacts/2/prereqs.txt
cat /var/work/tests/artifacts/2/prereqs.txt
```

## Aufgabe 3. Unvollständige Security Group und SecurityGroupPolicy

Wir erstellen eine SG in der VPC der Lab. Wichtig: Wir setzen NICHT das Tag
`karpenter.sh/discovery`, sonst würde die EC2NodeClass diese SG als SG der Nodes
auswählen:

```bash
SG_ID=$(aws ec2 create-security-group \
  --group-name eks-task126-secured-pod-sg \
  --description "security group for secured-app pods (lab 126, intentionally incomplete)" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' --output text)
echo "$SG_ID"
```

Wir fügen vorerst keine `authorize-security-group-ingress`- und `egress`-Regeln hinzu:
Eine frische SG hat nur den AWS-Standard-allow-all-egress und null eingehende Regeln
(inbound) - genau dieser Zustand erzeugt das Symptom.

Wir erstellen die `SecurityGroupPolicy`:

```bash
mkdir -p /var/work/tests/artifacts/3
echo -n "$SG_ID" > /var/work/tests/artifacts/3/sg_id.txt

cat <<EOF | kubectl apply -f -
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: secured-sgp
  namespace: eks-126
spec:
  podSelector:
    matchLabels:
      app: secured
  securityGroups:
    groupIds:
      - ${SG_ID}
EOF

kubectl get securitygrouppolicy secured-sgp -n eks-126 -o yaml
```

## Aufgabe 4. Symptom: Running, aber niemals Ready

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secured-app
  namespace: eks-126
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secured
  template:
    metadata:
      labels:
        app: secured
    spec:
      nodeSelector:
        work_type: nitro
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          periodSeconds: 5
          failureThreshold: 3
EOF

kubectl rollout status deployment/secured-app -n eks-126 --timeout=180s || true
kubectl get pod -n eks-126 -l app=secured
```

Der Pod bleibt bei `0/1 Ready` hängen, obwohl die Phase `Running` ist - die branch ENI
wurde erstellt, aber die SG des Pods lässt die Probe von kubelet nicht durch. Wir speichern
die Diagnose:

```bash
mkdir -p /var/work/tests/artifacts/4
POD=$(kubectl get pod -n eks-126 -l app=secured -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod "$POD" -n eks-126 > /var/work/tests/artifacts/4/pod_not_ready.txt
grep -i 'readiness probe failed\|unhealthy' /var/work/tests/artifacts/4/pod_not_ready.txt
```

Das Event sieht so aus (auf dem Testaufbau geprüft):

```
Warning  Unhealthy  49s (x33 over 5m44s)  kubelet  Readiness probe failed:
Get "http://10.10.16.177:8080/": context deadline exceeded
```

Wir vergewissern uns, dass der Pod tatsächlich auf einer branch ENI läuft und nicht auf
der ENI der Node:

```bash
kubectl get pod "$POD" -n eks-126 \
  -o jsonpath='{.metadata.annotations.vpc\.amazonaws\.com/pod-eni}{"\n"}'
kubectl get pod "$POD" -n eks-126 -o jsonpath='{.spec.containers[0].resources.limits}{"\n"}'
aws ec2 describe-network-interfaces --filters "Name=group-id,Values=$SG_ID" \
  --query 'NetworkInterfaces[].[NetworkInterfaceId,InterfaceType,Status,PrivateIpAddress]' \
  --output text
```

In der Annotation stehen `eniId`, `vlanId` und eine `associationID` der Form
`trunk-assoc-...`, in den Limits `vpc.amazonaws.com/pod-eni: 1`, und das Interface hat den
Typ `branch` mit derselben IP wie der Pod.

## Aufgabe 5. Behebung der Proben: eine inbound-Regel von der SG der Nodes

Wir finden die SG der Karpenter-Nodes über die Node, auf der `secured-app` läuft (auf dem
Worker):

```bash
NODE=$(kubectl get pod "$POD" -n eks-126 -o jsonpath='{.spec.nodeName}')
INSTANCE_ID=$(kubectl get node "$NODE" -o jsonpath='{.spec.providerID}' | sed 's|.*/||')
NODE_SG=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)
echo "node=$NODE instance=$INSTANCE_ID node_sg=$NODE_SG"
```

Wir fügen eine inbound-Regel in die SG des Pods hinzu:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 8080 \
  --source-group "$NODE_SG"
```

Wir warten, bis die Probe durchkommt, und speichern das Ergebnis:

```bash
sleep 15
kubectl get pod -n eks-126 -l app=secured
mkdir -p /var/work/tests/artifacts/5
kubectl get pod "$POD" -n eks-126 > /var/work/tests/artifacts/5/pod_ready.txt
cat /var/work/tests/artifacts/5/pod_ready.txt
```

`READY` sollte `1/1` zeigen - kubelet kann jetzt die branch ENI des Pods auf dem
Probe-Port erreichen.

## Aufgabe 6. Diagnose und Behebung von DNS

Wir prüfen die Auflösung aus `secured-app` heraus. Das Image `viktoruj/ping_pong:latest`
hat keine Shell-Werkzeuge für DNS (aus `scratch` gebaut), daher verwenden wir einen
separaten Diagnose-Pod mit demselben Label `app: secured`, damit `secured-sgp` auch auf
ihn wirkt:

```bash
kubectl run dns-probe -n eks-126 --image=busybox --restart=Never \
  --labels='app=secured' \
  --overrides='{"spec":{"nodeSelector":{"work_type":"nitro"}}}' \
  -- sleep 3600
kubectl wait --for=condition=Ready pod/dns-probe -n eks-126 --timeout=120s || true

mkdir -p /var/work/tests/artifacts/6
kubectl exec dns-probe -n eks-126 -- nslookup kubernetes.default.svc.cluster.local \
  > /var/work/tests/artifacts/6/dns_before.txt 2>&1 || true
cat /var/work/tests/artifacts/6/dns_before.txt
```

Die Ausgabe ist `;; connection timed out; no servers could be reached`. Wichtig ist, die
Ursache richtig zu benennen: egress spielt hier keine Rolle, eine frische SG hat die
Standardregel allow-all-egress, und die Anfrage geht hinaus. Das Paket geht am Eingang
der Empfängerseite verloren, die für unsere SG keine eingehende Regel (ingress) hat.
CoreDNS läuft in dieser Lab auf Fargate hinter der cluster primary security group:

```bash
CLUSTER_PRIMARY_SG=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
echo "cluster primary sg (CoreDNS on Fargate): $CLUSTER_PRIMARY_SG"
```

Wir fügen inbound `53` TCP und UDP an die cluster primary SG hinzu, mit unserer SG des
Pods als Quelle. Diese eine Regel reicht aus, Security Groups sind stateful: Die Antwort
auf eine erlaubte eingehende Anfrage geht ohne eigene Regel zurück.

```bash
aws ec2 authorize-security-group-ingress --group-id "$CLUSTER_PRIMARY_SG" \
  --ip-permissions \
    "IpProtocol=tcp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$SG_ID}]" \
    "IpProtocol=udp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$SG_ID}]"
```

Wir prüfen die Auflösung erneut:

```bash
sleep 5
kubectl exec dns-probe -n eks-126 -- nslookup kubernetes.default.svc.cluster.local \
  > /var/work/tests/artifacts/6/dns_after.txt 2>&1
cat /var/work/tests/artifacts/6/dns_after.txt
```

Jetzt der zweite Schritt, nach dem Prinzip der minimalen Rechte. Der Standard-allow-all-
egress der SG des Pods bedeutet "dem Pod ist alles nach außen erlaubt" - für einen Pod mit
eigener Security Group ist das genau das, wovor wir zu fliehen versuchten. Wir schränken
egress auf `53` ein und vergewissern uns, dass DNS weiter funktioniert:

```bash
aws ec2 revoke-security-group-egress --group-id "$SG_ID" \
  --protocol -1 --port all --cidr 0.0.0.0/0
aws ec2 authorize-security-group-egress --group-id "$SG_ID" \
  --ip-permissions \
    "IpProtocol=tcp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$CLUSTER_PRIMARY_SG}]" \
    "IpProtocol=udp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$CLUSTER_PRIMARY_SG}]"

kubectl delete pod dns-probe -n eks-126 --ignore-not-found
kubectl run dns-probe -n eks-126 --image=busybox --restart=Never --labels='app=secured' \
  --overrides='{"spec":{"nodeSelector":{"work_type":"nitro"}}}' \
  --command -- sh -c 'nslookup kubernetes.default.svc.cluster.local'
sleep 45
kubectl logs dns-probe -n eks-126 | tee -a /var/work/tests/artifacts/6/dns_after.txt
```

Wir stellen das Artefakt zusammen:

```bash
cat > /var/work/tests/artifacts/6/dns_fix.txt <<EOF
Vor der Behebung (dns_before.txt): nslookup zu kubernetes.default schlug fehl mit
";; connection timed out; no servers could be reached".

Die Ursache liegt NICHT im egress: Die frische security group ${SG_ID} hat die
Standardregel allow-all-egress, die Anfrage aus dem Pod geht hinaus. Das Paket wird am
EINGANG der Empfängerseite verworfen - der cluster primary security group
${CLUSTER_PRIMARY_SG}, hinter der CoreDNS auf Fargate läuft, fehlt eine eingehende Regel
(inbound) für unsere SG. Die Regel wird genau dort benötigt, und eine reicht aus: Security
Groups sind stateful, die Antwort auf eine erlaubte eingehende Anfrage geht selbst zurück.

Behebung: inbound 53 TCP und UDP an ${CLUSTER_PRIMARY_SG} mit source-group ${SG_ID}.
Danach löst nslookup kubernetes.default.svc.cluster.local auf (dns_after.txt).

Zweiter Schritt: Der Standard-allow-all-egress wurde von der SG des Pods entfernt, statt
dessen bleibt ein expliziter egress 53 TCP und UDP zu ${CLUSTER_PRIMARY_SG}. DNS
funktioniert weiterhin - das zeigt, dass egress auf der Quellseite und ingress auf der
Empfängerseite zwei unabhängige Regeln sind und dem Pod nicht der gesamte ausgehende
Traffic für DNS erlaubt werden muss.
EOF
cat /var/work/tests/artifacts/6/dns_fix.txt
```

## Aufgabe 7. Falle: eine Node, unterschiedliche Security Groups

Wir machen ein Experiment: zwei Pods mit UNTERSCHIEDLICHEN Security Groups auf derselben
Node. Wir legen eine zweite SG und eine zweite `SecurityGroupPolicy` für das Label
`app: other` an:

```bash
mkdir -p /var/work/tests/artifacts/7
SG2=$(aws ec2 create-security-group \
  --group-name eks-task126-other-pod-sg \
  --description "second pod sg for the same-node experiment (lab 126)" \
  --vpc-id "$VPC_ID" --query 'GroupId' --output text)
echo "second pod sg: $SG2"

cat <<EOF | kubectl apply -f -
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: other-sgp
  namespace: eks-126
spec:
  podSelector:
    matchLabels:
      app: other
  securityGroups:
    groupIds:
      - ${SG2}
EOF
```

Wir bestimmen den Pod des Deployments (genau ihn, nicht die Diagnose-Pods - sie tragen
ebenfalls das Label `app: secured`) und starten daneben einen Pod mit einer anderen SG:

```bash
APP_POD=$(kubectl get pod -n eks-126 -l app=secured \
  -o jsonpath='{range .items[?(@.metadata.ownerReferences[0].kind=="ReplicaSet")]}{.metadata.name}{"\n"}{end}' \
  | head -1)
APP_IP=$(kubectl get pod "$APP_POD" -n eks-126 -o jsonpath='{.status.podIP}')
APP_NODE=$(kubectl get pod "$APP_POD" -n eks-126 -o jsonpath='{.spec.nodeName}')
echo "secured-app=$APP_POD ip=$APP_IP node=$APP_NODE"

kubectl delete pod othersg -n eks-126 --ignore-not-found --wait=true
kubectl run othersg -n eks-126 --image=busybox --restart=Never --labels='app=other' \
  --overrides="{\"spec\":{\"nodeName\":\"$APP_NODE\"}}" \
  --command -- sh -c "wget -T 10 -qO- http://$APP_IP:8080/ ; echo RC=\$?"
sleep 55
kubectl logs othersg -n eks-126 | tee /var/work/tests/artifacts/7/before.txt
```

Ergebnis - `wget: download timed out`: Der Pod hat seine eigene SG, der Nachbar seine
eigene, es gibt keine Erlaubnis zwischen ihnen. Wir fügen eine Regel hinzu und
wiederholen:

```bash
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 8080 --source-group "$SG2"

kubectl delete pod othersg -n eks-126 --ignore-not-found --wait=true
kubectl run othersg -n eks-126 --image=busybox --restart=Never --labels='app=other' \
  --overrides="{\"spec\":{\"nodeName\":\"$APP_NODE\"}}" \
  --command -- sh -c "wget -T 10 -qO- http://$APP_IP:8080/ ; echo RC=\$?"
sleep 55
kubectl logs othersg -n eks-126 | tee /var/work/tests/artifacts/7/after.txt
```

Jetzt geht die Anfrage durch (`RC=0`). Das heißt, im Modus `strict` wirken die Regeln der
SG des Pods auch innerhalb einer Node - beide Pods laufen auf ihren eigenen branch ENIs,
und die Regel entscheidet. Wir stellen das Artefakt zusammen:

```bash
{
  echo "=== Pod des Deployments mit SecurityGroupPolicy secured-sgp (branch ENI) ==="
  kubectl get pod "$APP_POD" -n eks-126 -o wide
  echo
  echo "=== Pod mit ANDERER Security Group (other-sgp), dieselbe Node ==="
  kubectl get pod othersg -n eks-126 -o wide
  echo
  echo "=== vor der Regel ==="
  cat /var/work/tests/artifacts/7/before.txt
  echo "=== nach der Regel inbound 8080 von der zweiten SG ==="
  cat /var/work/tests/artifacts/7/after.txt
  echo
  echo "=== wo CoreDNS läuft ==="
  kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
  cat <<'TXT'

Ergebnis des Experiments. Unser Modus POD_SECURITY_GROUP_ENFORCING_MODE ist strict, und
darin gelten die Regeln der Security Group des Pods sogar für Traffic innerhalb einer
Node: zwei Pods mit unterschiedlichen SGs auf derselben Node verbanden sich zunächst nicht
(download timed out), und nach dem Hinzufügen einer inbound-Regel verbanden sie sich. Die
Diagnose hier ist also die gewöhnliche - die Regeln ansehen, nicht die Topologie.

Der Kontrast, den man kennen sollte (AWS-Dokumentation, Modus standard): Im Modus standard
werden die Regeln der SG des Pods NICHT auf Traffic zwischen Pods und Services auf
derselben Node angewendet, einschließlich kubelet und nodeLocalDNS, und Pods mit
unterschiedlichen Security Groups auf derselben Node kommunizieren überhaupt nicht,
weil sie sich in unterschiedlichen Subnetzen mit abgeschalteter Routung befinden. Dort
lässt sich dieselbe Situation nicht mit einer Regel beheben, sondern nur durch Verteilen
der Pods auf verschiedene Nodes. Genau deshalb reproduziert sich im standard auch das
Symptom der Aufgaben 4 und 5 nicht: Die Probe von kubelet geht an den SG-Regeln vorbei,
und readiness gelingt selbst mit einer Security Group ohne eine einzige inbound-Regel.
TXT
} > /var/work/tests/artifacts/7/same_node_trap.txt
cat /var/work/tests/artifacts/7/same_node_trap.txt
```

## Schnellkontrolle

```bash
check_result
```
