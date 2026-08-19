[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 128 - Musterlösung (Gateway API auf AWS: ALB Gateway API und VPC Lattice)

Alle Befehle laufen auf der Arbeitsmaschine (worker) per SSH. kubectl ist bereits auf den
Cluster konfiguriert. Terraform hat bereits IAM-Rollen für beide Controller erstellt
(Komponenten `eks_lbc_irsa`, `eks_vpclattice_irsa`) - ihre ARNs stehen in
`~/lab128_hints.txt`.

```bash
cat ~/lab128_hints.txt
export CLUSTER=$(kubectl config current-context | sed 's|.*/||')
export LBC_ROLE_ARN=$(grep '^lbc_role_arn' ~/lab128_hints.txt | awk '{print $3}')
export LATTICE_ROLE_ARN=$(grep '^vpclattice_role_arn' ~/lab128_hints.txt | awk '{print $3}')
export NODE_SG=$(grep '^node_sg_id' ~/lab128_hints.txt | awk '{print $3}')
export VPC_ID=$(grep '^vpc_id' ~/lab128_hints.txt | awk '{print $3}')
export ACCOUNT_ID=$(grep '^account_id' ~/lab128_hints.txt | awk '{print $3}')
export REGION=eu-central-1
```

## Aufgabe 1. Gateway-API-CRDs und Namespaces des Labs

```bash
kubectl apply --server-side=true \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

kubectl create namespace eks-128
kubectl create namespace eks-128-backend
```

## Aufgabe 2. AWS Load Balancer Controller und ein Gateway der ALB-Klasse (L7)

```bash
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

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${REGION}" \
  --set vpcId="${VPC_ID}"

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
```

`region` und `vpcId` sind hier zwingend, und das ist nicht kosmetisch. Der Pod des
Controllers landet in `kube-system`, und dieser Namespace ist von einem Fargate-Profil
abgedeckt, wo es überhaupt keinen IMDS gibt. Ohne die Flags fällt der Controller in
`CrashLoopBackOff` mit
`failed to get VPC ID ... ec2imds: GetMetadata ... context deadline exceeded` (auf dem
Testaufbau überprüft). Dieselbe Falle erwartet jeden Controller, den Sie in `kube-system`
auf Fargate installieren (Kapitel 15 und 26).

Wir erstellen die `GatewayClass` für ALB und das `Gateway` selbst:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: aws-alb
spec:
  controllerName: gateway.k8s.aws/alb
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web
  namespace: eks-128
spec:
  gatewayClassName: aws-alb
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

kubectl get gateway web -n eks-128 -o wide
```

`gateway.k8s.aws/alb` ist derselbe AWS Load Balancer Controller wie in den Labs 108/109,
nur dass der Eingang mit Gateway-API-Ressourcen statt Ingress beschrieben wird: die
L7-Routen `HTTPRoute` und `GRPCRoute` werden zu Listenern und Regeln des ALB (Kapitel 28,
Abschnitt 28.4).

## Aufgabe 3. HTTPRoute auf ALB: Anwendungsrouting

```bash
kubectl create deployment frontend --image=viktoruj/ping_pong:latest \
  --replicas=2 -n eks-128
kubectl rollout status deployment/frontend -n eks-128
kubectl expose deployment frontend -n eks-128 --port=80 --target-port=8080

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app
  namespace: eks-128
spec:
  parentRefs:
    - kind: Gateway
      name: web
      sectionName: http
  rules:
    - backendRefs:
        - name: frontend
          port: 80
EOF
```

Eine einzelne Route reicht nicht: dem Controller muss gesagt werden, welchen Zieltyp er
registrieren soll. Der Standardtyp wird als `instance` abgeleitet, und `instance`
erfordert einen Service vom Typ `NodePort` oder `LoadBalancer`. Mit `ClusterIP` bleibt der
Load Balancer unterprogrammiert: das `Gateway` gerät in `Accepted: False` mit
`reason: Invalid`, und im Controller-Log wiederholt sich
`TargetGroup port is empty. When using Instance targets, your service must be of type
'NodePort' or 'LoadBalancer'` (auf dem Testaufbau reproduziert). In der Ingress-Welt wurde
das durch die Annotation `alb.ingress.kubernetes.io/target-type: ip` behoben, in Gateway
API gibt es statt einer Annotation ein eigenes typisiertes Objekt, das im Namespace
seines eigenen Service liegen muss:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.k8s.aws/v1
kind: TargetGroupConfiguration
metadata:
  name: frontend
  namespace: eks-128
spec:
  targetReference:
    name: frontend
  defaultConfiguration:
    targetType: ip
EOF
```

Wir warten auf die Adresse und bestätigen über AWS CLI, dass es sich tatsächlich um einen
ALB handelt:

```bash
for i in $(seq 1 30); do
  ADDR=$(kubectl get gateway web -n eks-128 -o jsonpath='{.status.addresses[0].value}')
  [[ -n "$ADDR" ]] && break
  sleep 10
done
echo "gateway address: $ADDR"

LB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='${ADDR}'].LoadBalancerArn" --output text)

mkdir -p /var/work/tests/artifacts/3
aws elbv2 describe-load-balancers --load-balancer-arns "$LB_ARN" \
  > /var/work/tests/artifacts/3/alb.txt
cat /var/work/tests/artifacts/3/alb.txt
```

In der Ausgabe sollte `Type` gleich `application` sein - ein `Gateway` der Klasse
`aws-alb` erstellt einen ALB genauso, wie es ein `Ingress` mit
`ingressClassName: alb` in Lab 109 tat, nur über eine typisierte Ressource statt
Annotationen.

Es bleibt noch, auf `Programmed: True` zu warten und zu bestätigen, dass der Verkehr
tatsächlich fließt. Der Load Balancer ist intern (`internal-...`), daher wird die Anfrage
vom Worker aus gestellt - er ist in derselben VPC:

```bash
for i in $(seq 1 30); do
  p=$(kubectl get gateway web -n eks-128 \
    -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}')
  [[ "$p" == "True" ]] && break
  sleep 10
done
kubectl get gateway web -n eks-128 -o wide

curl -s -o /dev/null -w "http=%{http_code}\n" "http://${ADDR}/"
```

Die Antwort `http=200` kommt ein bis zwei Minuten nach `Programmed: True`: zuerst wird
der ALB aktiv, dann durchlaufen die Ziele den Health-Check (der Zielstatus ist über
`aws elbv2 describe-target-health` sichtbar).

## Aufgabe 4. AWS Gateway API Controller und ein Gateway der VPC-Lattice-Klasse

Zuerst öffnen wir die SG der Nodes für VPC-Lattice-Verkehr - ohne diese Regel erhalten die
Pods keinen Verkehr aus dem Service Network (Kapitel 28, Abschnitt 28.4 der
Deployment-Dokumentation des Controllers):

```bash
PREFIX_LIST_ID=$(aws ec2 describe-managed-prefix-lists \
  --query "PrefixLists[?PrefixListName=='com.amazonaws.eu-central-1.vpc-lattice'].PrefixListId" \
  --output text)

aws ec2 authorize-security-group-ingress --group-id "$NODE_SG" \
  --ip-permissions "PrefixListIds=[{PrefixListId=${PREFIX_LIST_ID}}],IpProtocol=-1"
```

Wir installieren den Controller: Namespace, ServiceAccount mit der Rolle, ein Helm-Chart
mit dem Parameter `defaultServiceNetwork` - der Controller erstellt das Service Network
`eks-task128-mesh` selbst und assoziiert die VPC des Clusters damit. Das Chart und das
Image liegen in einer öffentlichen ECR und werden anonym gezogen, `helm registry login`
ist nicht nötig (die Worker-Rolle hat kein `ecr-public:GetAuthorizationToken`, und das ist
korrekt - eine öffentliche Registry ist ohne Token lesbar):

```bash
kubectl create namespace aws-application-networking-system

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gateway-api-controller
  namespace: aws-application-networking-system
  annotations:
    eks.amazonaws.com/role-arn: ${LATTICE_ROLE_ARN}
EOF

helm install gateway-api-controller \
  oci://public.ecr.aws/aws-application-networking-k8s/aws-gateway-controller-chart \
  --version=v1.1.0 \
  --namespace aws-application-networking-system \
  --set=serviceAccount.create=false \
  --set=defaultServiceNetwork=eks-task128-mesh \
  --set=awsRegion="${REGION}" \
  --set=awsAccountId="${ACCOUNT_ID}" \
  --set=clusterVpcId="${VPC_ID}" \
  --set=clusterName="${CLUSTER}"

kubectl rollout status deployment -n aws-application-networking-system --timeout=180s
```

Diese letzten vier Flags sind aus demselben Grund zwingend wie `region` und `vpcId` beim
LBC, aber das Symptom ist ein anderes und sollte man sich merken. Der Pod dieses
Controllers läuft auf einem gewöhnlichen EC2-Node, IMDS existiert also grundsätzlich,
aber IMDSv2 kommt mit Hop-Limit 1, und eine Anfrage aus dem Netzwerk-Namespace des Pods
wird verworfen. Ohne die Flags scheitert der Controller sofort mit
`init config failed: vpcId is not specified: EC2MetadataError ... status code: 401`
(auf dem Testaufbau überprüft). Genau dieses Hop-Limit wird in den Kapiteln 10 und 19
behandelt: es schützt die Anmeldeinformationen der Node-Rolle vor Pods und bricht dabei
jeden Controller, der sich auf die Metadaten verlässt.

Wir erstellen die `GatewayClass` für VPC Lattice und das `Gateway` selbst:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1beta1
kind: GatewayClass
metadata:
  name: amazon-vpc-lattice
spec:
  controllerName: application-networking.k8s.aws/gateway-api-controller
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: eks-task128-mesh
  namespace: eks-128
spec:
  gatewayClassName: amazon-vpc-lattice
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

kubectl get gateway eks-task128-mesh -n eks-128 -o wide
```

Der Name des `Gateway` ist hier nicht beliebig, und das ist die Hauptfalle dieser
Aufgabe. Der VPC-Lattice-Controller sucht das Service Network nach dem NAMEN des
`Gateway`-Objekts, nicht nach dem Wert von `defaultServiceNetwork`. Nennen Sie das
`Gateway` `mesh`, und es bleibt für immer `Programmed: False` mit der Meldung
`VPC Lattice Service Network not found`, weil das Netzwerk im Account
`eks-task128-mesh` heißt (auf dem Testaufbau überprüft: zwei `Gateway`-Objekte
nebeneinander, das mit übereinstimmendem Namen zeigt `Programmed: True` und die ARN des
Netzwerks in der Meldung, das mit abweichendem Namen zeigt `not found`). Daraus folgt
die Regel: Name des `Gateway` = Name des Service Network.

Ein `Gateway` der Klasse `amazon-vpc-lattice` spiegelt sich in einem VPC Lattice Service
Network wider: es ist eine East-West-Verbindung zwischen Cluster-Services, kein
Eingangspunkt von außen wie `aws-alb` (Kapitel 28, Abschnitt 28.5).

## Aufgabe 5. Symptom: HTTPRoute ohne ReferenceGrant

Wir bringen das Backend in einem benachbarten Namespace hoch:

```bash
kubectl create deployment backend --image=viktoruj/ping_pong:latest \
  --replicas=1 -n eks-128-backend
kubectl rollout status deployment/backend -n eks-128-backend
kubectl expose deployment backend -n eks-128-backend --port=80 --target-port=8080

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.k8s.aws/v1
kind: TargetGroupConfiguration
metadata:
  name: backend
  namespace: eks-128-backend
spec:
  targetReference:
    name: backend
  defaultConfiguration:
    targetType: ip
EOF
```

`TargetGroupConfiguration` wird aus demselben Grund benötigt wie in Aufgabe 3, und zeigt
zugleich die Trennung der Zuständigkeit: das Objekt liegt im Namespace des
Service-Eigentümers, nicht neben der Route.

Die Route `rates` liegt in `eks-128`, verweist aber auf einen Service in
`eks-128-backend`. Ihr Elternobjekt ist das `Gateway` `web` der Klasse `aws-alb`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: rates
  namespace: eks-128
spec:
  parentRefs:
    - kind: Gateway
      name: web
      sectionName: http
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /rates
      backendRefs:
        - name: backend
          namespace: eks-128-backend
          port: 80
EOF
```

Dieselbe Route, aber auf einem `Gateway` der Klasse `amazon-vpc-lattice` - das ist das
Kontrollexperiment, nötig für die Schlussfolgerung der Aufgabe:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: rates-lattice
  namespace: eks-128
spec:
  parentRefs:
    - kind: Gateway
      name: eks-task128-mesh
      sectionName: http
  rules:
    - backendRefs:
        - name: backend
          namespace: eks-128-backend
          port: 80
EOF

sleep 25
mkdir -p /var/work/tests/artifacts/5
{
  echo "rates status=$(kubectl get httproute rates -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')"
  echo "rates reason=$(kubectl get httproute rates -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].reason}')"
  echo "rates message=$(kubectl get httproute rates -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].message}')"
  echo "rates-lattice status=$(kubectl get httproute rates-lattice -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')"
  echo "rates-lattice reason=$(kubectl get httproute rates-lattice -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].reason}')"
} > /var/work/tests/artifacts/5/refnotpermitted.txt
cat /var/work/tests/artifacts/5/refnotpermitted.txt
```

Wir verwenden nicht `kubectl -o yaml | grep -A...`: bei CRD-Objekten (unstructured) werden
die Condition-Felder in alphabetischer Reihenfolge serialisiert (`reason`, `status` stehen
vor `type`), daher ist es zuverlässiger, die benötigte Condition direkt über `jsonpath`
herauszuziehen.

Ein `backendRefs`-Eintrag mit einem `namespace`-Feld verweist auf einen Service in einem
fremden Namespace - standardmäßig ist eine solche Referenz verboten, damit ein Entwickler
aus `eks-128` nicht ohne Erlaubnis des Eigentümers Verkehr auf einen fremden Service
lenken kann (Kapitel 28, Abschnitt 28.2). Bei der Route `rates` wird die Condition
`ResolvedRefs` `status: "False"`, `reason: RefNotPermitted` sein, mit der Meldung
`No explicit ReferenceGrant exists to allow the reference.`

Aber hier ist das Ergebnis, um das es beim Kontrollexperiment eigentlich geht: die
Condition von `rates-lattice` ist sofort `ResolvedRefs: True`, obwohl in
`eks-128-backend` noch überhaupt kein `ReferenceGrant` existiert (auf dem Testaufbau
überprüft). Die Regel `ReferenceGrant` ist Teil der Gateway-API-Spezifikation, aber
EINGEHALTEN wird sie von der Implementierung, nicht vom API-Server: der AWS Load Balancer
Controller prüft sie, der VPC-Lattice-Controller Version v1.1.0 nicht. Daraus die
praktische Schlussfolgerung: dasselbe YAML ergibt in zwei Gateway-API-Implementierungen
eine unterschiedliche Vertrauensgrenze zwischen Teams, und man kann sich auf
`ReferenceGrant` als Schutz nur dort verlassen, wo man das Verhalten des Controllers
überprüft hat.

## Aufgabe 6. Fix: ReferenceGrant erlaubt die Cross-Namespace-Referenz

`ReferenceGrant` wird vom Eigentümer des **Ziel**-Backends erstellt - dem Namespace
`eks-128-backend`, nicht von demjenigen, der die Referenz herstellt:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-from-eks-128
  namespace: eks-128-backend
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: eks-128
  to:
    - group: ""
      kind: Service
EOF

sleep 15
mkdir -p /var/work/tests/artifacts/6
{
  echo "ResolvedRefs status=$(kubectl get httproute rates -n eks-128 \
    -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')"
  echo "curl /rates http=$(curl -s -o /dev/null -w '%{http_code}' -m 10 "http://${ADDR}/rates")"
} > /var/work/tests/artifacts/6/resolved.txt
cat /var/work/tests/artifacts/6/resolved.txt
```

In der zweiten Zeile des Artefakts prüfen wir nicht den Status, sondern den Verkehr
selbst: `http=200` vom Pod `backend` bedeutet, dass die gesamte Kette zusammengefügt
wurde - die Route wurde durch den Grant erlaubt, die Target Group vom Typ `ip` wurde
erstellt, die Ziele haben den Health-Check bestanden. Wenn `ResolvedRefs` bereits `True`
ist, `curl` aber `503` liefert, warten Sie eine Minute: die Zielregistrierung erfolgt,
nachdem die Target Group erscheint.

Nach dem Erscheinen des `ReferenceGrant` wechselt die Condition `ResolvedRefs` von
`rates` innerhalb von Sekunden zu `True` - der Controller bewertet die erlaubten
Referenzen bei der nächsten Reconciliation neu, und die Route beginnt, `backend` im
benachbarten Namespace aufzulösen. Beachten Sie, dass die Erlaubnis vom EIGENTÜMER-
Namespace des Ziels erteilt wird: löschen Sie das `ReferenceGrant`, und die Route fällt
zurück auf `RefNotPermitted`, obwohl niemand die Route selbst geändert hat.

## Schnellprüfung

```bash
check_result
```
