[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 116 - Musterlösung (IMDSv2 hop limit, Pod Security Admission, privater Endpoint)

Alle Befehle laufen auf der Worker-Maschine per SSH. kubectl ist bereits für den Cluster
konfiguriert (die kubeconfig wurde beim Start der Maschine über
`aws eks update-kubeconfig` erstellt).

## Aufgabe 1. Namespace `eks-116`

```bash
kubectl create namespace eks-116
```

## Aufgabe 2. Symptom: IMDS ist vom Pod aus nicht erreichbar

Der NodePool `hardened` (der einzige in dieser Lab) setzt auf allen seinen Nodes
`httpPutResponseHopLimit=1` über die `metadataOptions` der EC2NodeClass. Ein Paket von
einem Prozess auf dem Host erreicht IMDS in einem Hop, während ein Paket aus einem Pod
einen zusätzlichen Hop macht (der Network-Namespace des Containers) - und damit das
Limit überschreitet. Wir legen ein Deployment mit einem schlafenden Container an, um per
exec hineinzukommen:

```bash
kubectl create deployment probe --image=curlimages/curl:latest -n eks-116 \
  -- sleep 3600
kubectl rollout status deployment/probe -n eks-116
```

IMDSv2-Anfrage aus dem Pod (zuerst der Token, dann die Daten), mit Zeitlimit:

```bash
POD=$(kubectl get po -n eks-116 -l app=probe -o jsonpath='{.items[0].metadata.name}')
mkdir -p /var/work/tests/artifacts/2

kubectl exec -n eks-116 "$POD" -- sh -c '
  echo "=== PUT token ===";
  TOKEN=$(curl -sX PUT --max-time 5 "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600");
  if [ -z "$TOKEN" ]; then
    echo "no token received: request timed out (hop limit blocked the pod)";
  else
    echo "=== GET with token ===";
    curl -s --max-time 5 -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/iam/security-credentials/ \
      || echo "GET timed out (hop limit blocked the pod)";
  fi
' 2>&1 | tee /var/work/tests/artifacts/2/imds.txt

cat /var/work/tests/artifacts/2/imds.txt
```

Mit hop limit `1` erhält `curl` innerhalb der zugestandenen `5` Sekunden keine Antwort,
und in der Datei landet eine Zeile zum Timeout (`curl` gibt bei `-v`
`curl: (28) ... timeout` aus, und ohne Token fügt das Skript selbst den Hinweis
`timed out` hinzu).

## Aufgabe 3. Prüfung über die AWS API: hop limit und IMDSv2 auf dem Node

Wir ermitteln, auf welchem Node `probe` läuft, holen dessen `providerID` und extrahieren
die Instance-ID:

```bash
NODE=$(kubectl get po -n eks-116 -l app=probe -o jsonpath='{.items[0].spec.nodeName}')
PROVIDER_ID=$(kubectl get node "$NODE" -o jsonpath='{.spec.providerID}')
# providerID in der Form aws:///eu-central-1a/i-0abc123def456789
INSTANCE_ID=$(echo "$PROVIDER_ID" | awk -F'/' '{print $NF}')
echo "node=$NODE instance=$INSTANCE_ID"

mkdir -p /var/work/tests/artifacts/3
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[].Instances[].MetadataOptions' --output json \
  | tee /var/work/tests/artifacts/3/metadata_options.txt
```

In der Ausgabe müssen `"HttpTokens": "required"` und `"HttpPutResponseHopLimit": 1`
stehen - genau das, was `vng.metadataOptions` in
`eks_karpenter_hardened_vng/terragrunt.hcl` festgelegt hat und was die EC2NodeClass an
das Launch Template des Nodes weitergegeben hat.

## Aufgabe 4. Pod Security Admission: Ablehnung eines privilegierten Pods

Wir aktivieren restricted am Namespace über Labels (PSA ist in EKS integriert, aber ohne
Labels verhält sich ein Namespace standardmäßig wie `privileged` - nichts wird
eingeschränkt):

```bash
kubectl label namespace eks-116 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest
```

Wir versuchen einen privilegierten Pod - admission muss die Erstellung ablehnen:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl run priv-test -n eks-116 --image=busybox --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"priv-test","image":"busybox","securityContext":{"privileged":true}}]}}' \
  2>&1 | tee /var/work/tests/artifacts/4/psa_reject.txt

kubectl get pod priv-test -n eks-116 2>&1 | tee -a /var/work/tests/artifacts/4/psa_reject.txt
cat /var/work/tests/artifacts/4/psa_reject.txt
```

Erwartete Ausgabe, ähnlich wie:

```
Error from server (Forbidden): pods "priv-test" is forbidden: violates PodSecurity "restricted:latest": privileged (container "priv-test" must not set securityContext.privileged=true)
```

Der Pod wird nicht erstellt (`kubectl get pod priv-test` liefert `NotFound`), und die
Meldung enthält die Wörter `privileged` und `restricted`/`violates` - genau das fordern
die Abnahmekriterien.

## Aufgabe 5. Der erlaubte Weg: ein Pod, der zu restricted passt

Wir bauen einen Pod mit allen Feldern, die das Profil `restricted` verlangt.
`runAsNonRoot: true` verbietet nur den Start als root - das Image `busybox:latest`
deklariert standardmäßig keinen non-root-Benutzer, daher blockiert kubelet ohne
expliziten `runAsUser` (eine beliebige UID ungleich null) den Containerstart mit einem
eigenen Fehler, `container has runAsNonRoot and image will run as root`, und zwar erst
nachdem admission den Pod bereits durchgelassen hat:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: safe-pod
  namespace: eks-116
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:latest
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
EOF

kubectl get pod safe-pod -n eks-116 -o wide
```

Der Pod besteht admission und wechselt in den Zustand `Running` - derselbe Namespace,
dasselbe Profil `restricted`, aber die Anforderungen sind vollständig erfüllt:
`runAsNonRoot` mit explizitem `runAsUser`, `allowPrivilegeEscalation: false`,
`capabilities.drop: ["ALL"]`, `seccompProfile` `RuntimeDefault`.

## Aufgabe 6. Privater Zugriff auf die Control Plane und VPC-Endpoints

Wir prüfen die `resourcesVpcConfig` des Clusters - das Modul `eks_v2_control_plane`
aktiviert bereits beide Flags (`endpoint_public_access = true`,
`endpoint_private_access = true`):

```bash
CLUSTER=$(kubectl config current-context | sed 's|.*/||')
mkdir -p /var/work/tests/artifacts/6

aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig' --output json \
  | tee /var/work/tests/artifacts/6/private_endpoint.txt
```

In der Ausgabe steht `"endpointPrivateAccess": true`. Wir ergänzen die Datei um eine
Erklärung:

```bash
cat >> /var/work/tests/artifacts/6/private_endpoint.txt <<'EOF'

Für einen vollständig privaten Cluster (Nodes ohne Internetzugang) braucht man
VPC-Endpoints: ecr.api und ecr.dkr (um Container-Images zu ziehen), den s3-Gateway-
Endpoint (die Image-Layer von ECR liegen physisch in S3, daher lädt das Image ohne ihn
nicht herunter, selbst wenn ecr.api und ecr.dkr vorhanden sind), sts (Austausch des
IRSA-Tokens gegen temporäre Credentials), ec2 (Node-Registrierung und DNS-Name), logs
(Versand der Logs an CloudWatch) und eks (Zugriff auf die EKS API aus der VPC). Der
private Zugriff auf die Control Plane (in diesem Cluster bereits aktiviert) ist getrennt
von der Endpoint-Liste erforderlich - ohne ihn könnten sich Nodes aus einem privaten
Subnetz nicht am API-Server registrieren.
EOF

cat /var/work/tests/artifacts/6/private_endpoint.txt
```

## Schnellprüfung

```bash
check_result
```
