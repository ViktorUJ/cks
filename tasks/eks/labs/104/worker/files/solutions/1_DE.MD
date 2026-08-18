[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 104 - Referenzlösung (workload identity: IRSA und Pod Identity)

Alle Befehle werden auf der Arbeitsmaschine (worker) über SSH ausgeführt. kubectl ist
bereits auf den Cluster konfiguriert, und terraform hat bereits den S3-Bucket, das
Secrets-Manager-Secret und beide IAM-Rollen angelegt - ihre Namen und ARNs stehen in der
Hinweisdatei `/home/ubuntu/lab104_hints.txt`.

```bash
cat ~/lab104_hints.txt
```

Im Folgenden werden Variablen aus dieser Datei verwendet - setzen Sie Ihre eigenen Werte
ein oder exportieren Sie sie am Anfang der Sitzung:

```bash
export BUCKET_NAME=$(grep '^bucket_name' ~/lab104_hints.txt | awk '{print $3}')
export SECRET_NAME=$(grep '^secret_name' ~/lab104_hints.txt | awk '{print $3}')
export IRSA_ROLE_ARN=$(grep '^irsa_role_arn' ~/lab104_hints.txt | awk '{print $3}')
export POD_IDENTITY_ROLE_ARN=$(grep '^pod_identity_role_arn' ~/lab104_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab104_hints.txt | awk '{print $3}')
```

## Aufgabe 1. Namespace `eks-104`

```bash
kubectl create namespace eks-104
```

## Aufgabe 2. ServiceAccount mit IRSA-Annotation

Die Rolle `irsa_role_arn` wurde bereits von terraform mit einer trust policy erstellt, die
genau diesem `ServiceAccount` vertraut (`system:serviceaccount:eks-104:s3-reader-irsa` -
Kapitel 16). Wir erstellen das SA mit der Annotation:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-reader-irsa
  namespace: eks-104
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

kubectl get sa s3-reader-irsa -n eks-104 -o yaml
```

## Aufgabe 3. Pod mit IRSA: Identität prüfen

Wir erstellen einen Pod, der dieses SA verwendet. Der Pod Identity Webhook injiziert beim
Start des Pods die Variablen `AWS_ROLE_ARN` und `AWS_WEB_IDENTITY_TOKEN_FILE` (Kapitel 16):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: irsa-app
  namespace: eks-104
spec:
  serviceAccountName: s3-reader-irsa
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/irsa-app -n eks-104 --timeout=120s
```

Wir prüfen, dass das SDK im Pod die Credentials über web identity erhalten hat und nicht
über die Node-Rolle:

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl exec irsa-app -n eks-104 -- aws sts get-caller-identity \
  > /var/work/tests/artifacts/3/irsa_identity.txt
cat /var/work/tests/artifacts/3/irsa_identity.txt
```

In der Ausgabe sollte `Arn` etwa wie
`arn:aws:sts::<account>:assumed-role/<prefix>-irsa-role/...` aussehen - das belegt, dass
der Pod unter der IRSA-Rolle läuft und nicht unter der Node-Rolle.

## Aufgabe 4. Objekt aus S3 über IRSA lesen

Die Rolle `irsa` trägt für diesen konkreten Bucket nur `s3:ListBucket` und
`s3:GetObject` (Kapitel 16, least privilege). Wir lesen das Objekt, das terraform in den
Bucket gelegt hat:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec irsa-app -n eks-104 -- aws s3 cp "s3://${BUCKET_NAME}/hello.txt" - \
  > /var/work/tests/artifacts/4/s3_read.txt
cat /var/work/tests/artifacts/4/s3_read.txt
```

In der Datei sollte die Zeile `hello from s3` stehen - der Inhalt des Objekts, das vom
Modul `eks_v2_workload_identity_demo` abgelegt wurde.

## Aufgabe 5. Pod-Identity-Assoziation

Im Gegensatz zu IRSA braucht Pod Identity keine Annotation am SA - die Verbindung
`Namespace + SA -> Rolle` lebt in der EKS-API, nicht in Kubernetes (Kapitel 17). Wir
erstellen das SA und die Assoziation:

```bash
kubectl create serviceaccount secret-reader-podid -n eks-104

aws eks create-pod-identity-association \
  --cluster-name "${CLUSTER_NAME}" \
  --namespace eks-104 \
  --service-account secret-reader-podid \
  --role-arn "${POD_IDENTITY_ROLE_ARN}"

mkdir -p /var/work/tests/artifacts/5
aws eks list-pod-identity-associations --cluster-name "${CLUSTER_NAME}" --namespace eks-104 \
  > /var/work/tests/artifacts/5/association.txt
cat /var/work/tests/artifacts/5/association.txt
```

## Aufgabe 6. Pod mit Pod Identity: Secret statt Node-Rolle

Wir erstellen einen Pod mit dem SA `secret-reader-podid`. Der Agent
`eks-pod-identity-agent` (in dieser Lab bereits als managed addon installiert) liefert ihm
die Credentials der Rolle `pod_identity_role_arn` über den lokalen Endpoint
`169.254.170.23` (Kapitel 17):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: podid-app
  namespace: eks-104
spec:
  serviceAccountName: secret-reader-podid
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/podid-app -n eks-104 --timeout=120s
```

Wir lesen das Secret und prüfen die Identität in einem Befehl:

```bash
mkdir -p /var/work/tests/artifacts/6
{
  echo "--- caller identity ---"
  kubectl exec podid-app -n eks-104 -- aws sts get-caller-identity
  echo "--- secret value ---"
  kubectl exec podid-app -n eks-104 -- aws secretsmanager get-secret-value \
    --secret-id "${SECRET_NAME}" --query SecretString --output text
} > /var/work/tests/artifacts/6/secret_read.txt
cat /var/work/tests/artifacts/6/secret_read.txt
```

`Arn` aus `get-caller-identity` zeigt `assumed-role/<prefix>-pod-identity-role/...`, und
der Wert des Secrets ist ein JSON mit den Feldern `username`/`password`
(`demo`/`demo123`), die terraform in Secrets Manager abgelegt hat.

## Aufgabe 7. Symptom: die Node-Rolle hat keinen Zugriff auf den Bucket

Wir erstellen einen Pod **ohne** Bindung an IRSA oder Pod Identity - er erbt nur die
Rechte der Node-Rolle (Kapitel 16, Abschnitt 16.1: „man gibt der Node eine Rolle - und die
Rechte sickern zu allen Pods durch" funktioniert auch umgekehrt, die Node-Rolle trägt
überhaupt keine anwendungsbezogenen Rechte):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: plain-app
  namespace: eks-104
spec:
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/plain-app -n eks-104 --timeout=120s
```

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl exec plain-app -n eks-104 -- aws s3 ls "s3://${BUCKET_NAME}/" \
  > /var/work/tests/artifacts/7/node_role_denied.txt 2>&1
cat /var/work/tests/artifacts/7/node_role_denied.txt
```

Der Befehl sollte mit dem Fehler `AccessDenied` (oder `is not authorized to perform`)
scheitern - die Node-Rolle trägt für diesen Bucket kein `s3:*`, sie hat nur die Rechte der
Systemkomponenten (Pull aus ECR, Betrieb der CNI). Das zeigt anschaulich den Unterschied:
ohne IRSA oder Pod Identity erhält ein Pod nur, was die Node-Rolle hat, nicht „alles, was
irgendwo im Account konfiguriert ist".

## Schnelle Überprüfung

```bash
check_result
```
