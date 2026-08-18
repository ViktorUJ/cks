[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 121 - Referenzlösung (Zugriffs-Fehlersuche: access entries, IRSA, kubeconfig)

Alle Befehle laufen auf der Worker-Maschine über SSH. kubectl ist bereits für den Cluster
konfiguriert, und terraform hat bereits den S3-Bucket und die IRSA-Rolle der Komponente
`eks_irsa_break_demo` erstellt - ihre Namen und ARNs stehen in der Hinweisdatei
`/home/ubuntu/lab121_hints.txt`.

```bash
cat ~/lab121_hints.txt
```

Der Rest der Lösung verwendet Variablen aus dieser Datei:

```bash
export BUCKET_NAME=$(grep '^bucket_name' ~/lab121_hints.txt | awk '{print $3}')
export IRSA_ROLE_ARN=$(grep '^irsa_role_arn' ~/lab121_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab121_hints.txt | awk '{print $3}')
```

Das Lab deckt zwei unabhängige Zugriffsachsen aus Kapitel 47 ab: ein Mensch/eine CI kommt
nicht in den Cluster (Aufgaben 1-4), und ein Pod erhält `AccessDenied` bei AWS (Aufgaben
5-8).

## Aufgabe 1. Namespace `eks-121`

```bash
kubectl create namespace eks-121
```

## Aufgabe 2. Unauthorized-Symptom: eine Rolle ohne access entry

Wir erstellen eine Test-IAM-Rolle ganz ohne access entry. Die Rolle des Workers erlaubt
nur die Verwaltung von Rollen mit `-test-` im Namen (siehe `iam.tf` des Moduls
`eks_v2_work_pc`), daher muss der Name dieses Teilstück enthalten:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TEST_ROLE_NAME="eks-task121-test-noaccess"

cat > /tmp/trust-worker.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "AWS": "$(aws sts get-caller-identity --query Arn --output text)" },
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role --role-name "$TEST_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust-worker.json

export TEST_ROLE_ARN=$(aws iam get-role --role-name "$TEST_ROLE_NAME" \
  --query 'Role.Arn' --output text)
```

Die Rolle des Workers trägt `sts:AssumeRole` speziell für ARNs mit `-test-` im Namen,
sodass wir diese Rolle direkt annehmen können:

Hier ist die Reihenfolge wichtig. Wir bauen die separate kubeconfig **mit den Credentials
des Workers, bevor** wir `assume-role` ausführen: `aws eks update-kubeconfig` ruft
`eks:DescribeCluster` auf, und die Test-Rolle hat überhaupt keine IAM-Policy, sodass der
Befehl unter dieser Rolle mit `AccessDeniedException` fehlschlagen würde und die Datei
nicht erstellt würde. Das ist übrigens der dritte Fehlertyp in dieser Kette:
`AccessDenied` von IAM (keine Berechtigung für die AWS-API) unterscheidet sich sowohl von
`Unauthorized` (die Identität ist nicht in den Cluster gemappt) als auch von `Forbidden`
(RBAC). `kubectl` selbst holt sich dann ein Token über `aws eks get-token`, und dieses
Token stammt jeweils von der Identität, deren Credentials in den Umgebungsvariablen
stehen:

```bash
aws eks update-kubeconfig --name "$CLUSTER_NAME" --kubeconfig /tmp/kubeconfig-test

CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name lab121-noaccess --duration-seconds 900)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')
```

Wir prüfen den Zugriff dieser Identität auf den Cluster - ohne access entry ist sie nicht
gemappt, daher erwarten wir `Unauthorized` (Kapitel 47, Abschnitt 47.3):

```bash
mkdir -p /var/work/tests/artifacts/2
kubectl --kubeconfig /tmp/kubeconfig-test get pods -A \
  > /var/work/tests/artifacts/2/unauthorized.txt 2>&1
cat /var/work/tests/artifacts/2/unauthorized.txt
```

Die Datei sollte eine Zeile mit dem Wort `Unauthorized` enthalten - der API-Server konnte
diese IAM-Identität keinem access entry oder aws-auth-Eintrag zuordnen.

Wir stellen die Credentials des Workers wieder her (die Session-Variablen werden nicht
mehr benötigt):

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

## Aufgabe 3. Unauthorized beheben: access entry + AmazonEKSViewPolicy

Wir erstellen einen access entry für die Test-Rolle und gewähren ihr die Zugriffspolicy
`AmazonEKSViewPolicy` im cluster-Scope (Kapitel 47, Abschnitt 47.4):

```bash
aws eks create-access-entry --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$TEST_ROLE_ARN" --type STANDARD

aws eks associate-access-policy --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster
```

Wir wiederholen `assume-role` (die erste Session ist bereits abgelaufen oder beendet) und
dieselbe Anfrage mit derselben temporären kubeconfig - sie sollte jetzt die Pod-Liste
zurückgeben, nicht `Unauthorized`:

```bash
CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name lab121-access --duration-seconds 900)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')

mkdir -p /var/work/tests/artifacts/3
kubectl --kubeconfig /tmp/kubeconfig-test get pods -A \
  > /var/work/tests/artifacts/3/authorized.txt 2>&1
cat /var/work/tests/artifacts/3/authorized.txt
```

Die Datei enthält jetzt Zeilen wie `NAMESPACE ... POD ...` - der access entry hat den
`Unauthorized`-Fehler behoben.

## Aufgabe 4. Forbidden-Symptom: View-Zugriff erlaubt kein Schreiben

Die Rolle hat nur `AmazonEKSViewPolicy` (lesend). Wir versuchen, mit derselben temporären
kubeconfig einen Namespace zu erstellen - RBAC sollte das mit `Forbidden` ablehnen
(Kapitel 47, Abschnitt 47.3):

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl --kubeconfig /tmp/kubeconfig-test create namespace test-forbidden \
  > /var/work/tests/artifacts/4/forbidden.txt 2>&1
cat /var/work/tests/artifacts/4/forbidden.txt
```

Wir ergänzen in derselben Datei eine Erklärung des Unterschieds zwischen Aufgabe 2
(`Unauthorized`) und Aufgabe 4 (`Forbidden`):

```bash
cat >> /var/work/tests/artifacts/4/forbidden.txt <<'EOF'

Difference: in task 2 the role wasn't mapped into the cluster at all - the API server
couldn't prove the identity, that's Unauthorized (an authentication failure, the authn
layer). In task 4 the identity is already proven and mapped via an access entry, but RBAC
(AmazonEKSViewPolicy only grants read) doesn't allow create namespace - that's Forbidden
(an authorization failure, the authz layer). The fixes differ: Unauthorized is fixed in the
mapping (access entry / aws-auth), Forbidden is fixed in RBAC (Role, ClusterRole, policy
binding).
EOF
cat /var/work/tests/artifacts/4/forbidden.txt

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

## Aufgabe 5. Ein ServiceAccount mit der korrekten IRSA-Annotation

Die Rolle `eks_irsa_break_demo` wurde von terraform bereits mit einer trust policy
erstellt, die genau `system:serviceaccount:eks-121:demo-reader` vertraut (Kapitel 16,
Kapitel 47 Abschnitt 47.6):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-reader
  namespace: eks-121
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: irsa-app
  namespace: eks-121
spec:
  serviceAccountName: demo-reader
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/irsa-app -n eks-121 --timeout=120s
```

Wir prüfen die Identität und lesen das Objekt aus S3:

```bash
mkdir -p /var/work/tests/artifacts/5
{
  echo "--- caller identity ---"
  kubectl exec irsa-app -n eks-121 -- aws sts get-caller-identity
  echo "--- s3 object ---"
  kubectl exec irsa-app -n eks-121 -- aws s3 cp "s3://${BUCKET_NAME}/hello.txt" -
} > /var/work/tests/artifacts/5/irsa_ok.txt
cat /var/work/tests/artifacts/5/irsa_ok.txt
```

`Arn` in der Ausgabe sollte wie `assumed-role/<prefix>-irsa-role/...` aussehen, und der
zweite Block sollte die Zeile `hello from s3` sein (das Objekt, das terraform dort
abgelegt hat).

## Aufgabe 6. AccessDenied-Symptom: eine fehlerhafte Annotation in einem anderen Namespace

Wir erstellen eine zweite SA mit der GLEICHEN Annotation auf derselben Rolle, aber im
Namespace `default`. Die trust policy der Rolle erwartet
`sub = system:serviceaccount:eks-121:demo-reader`, während das `sub` dieser SA
`system:serviceaccount:default:demo-reader-broken` sein wird - die Bedingung passt nicht
(Kapitel 47, Abschnitt 47.6):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-reader-broken
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-app
  namespace: default
spec:
  serviceAccountName: demo-reader-broken
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/broken-app -n default --timeout=120s
```

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl exec broken-app -n default -- aws sts get-caller-identity \
  > /var/work/tests/artifacts/6/broken.txt 2>&1
cat /var/work/tests/artifacts/6/broken.txt
```

Der Befehl sollte mit einem Token-Austauschfehler fehlschlagen: `AccessDenied` oder
`WebIdentityErr` (die genaue Meldung unterscheidet sich je nach SDK/CLI-Version, aber der
Punkt ist derselbe - STS hat `sts:AssumeRoleWithWebIdentity` abgelehnt, weil das `sub` im
Token nicht zur Bedingung der trust policy passte).

## Aufgabe 7. Diagnose: Annotationen vergleichen und die Ursache im `sub`

Wir vergleichen die SA-Annotation in beiden Namespaces und erklären die Ursache:

```bash
mkdir -p /var/work/tests/artifacts/7
{
  echo "--- eks-121/demo-reader ---"
  kubectl get sa demo-reader -n eks-121 \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
  echo
  echo "--- default/demo-reader-broken ---"
  kubectl get sa demo-reader-broken -n default \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
  echo
  echo
  cat <<'TXT'
Both annotations point at the same IRSA role, but the role's trust policy checks the sub
condition on the STS token: system:serviceaccount:<namespace>:<serviceaccount>. For
demo-reader that's system:serviceaccount:eks-121:demo-reader - it matches the role's
condition, so the exchange is allowed. For demo-reader-broken the token carries
sub=system:serviceaccount:default:demo-reader-broken - a different namespace and a
different SA name, so the StringEquals condition doesn't match, and
sts:AssumeRoleWithWebIdentity is rejected regardless of the fact that the role ARN in the
annotation is the same.
TXT
} > /var/work/tests/artifacts/7/diagnostics.txt
cat /var/work/tests/artifacts/7/diagnostics.txt
```

## Aufgabe 8. Zusammenfassung: die zwei Zugriffsachsen

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/summary.txt <<'EOF'
The human axis (tasks 2-4) lives in the chain kubectl - IAM - EKS authenticator - RBAC:
Unauthorized means the IAM identity couldn't be proven or mapped into the cluster at all
(fixed via an access entry or aws-auth), while Forbidden means the identity is already
known, but RBAC didn't allow that specific action (fixed via Role/ClusterRoleBinding). The
pod axis (tasks 5-7) lives in the chain pod - ServiceAccount - STS - IAM role: AccessDenied
or WebIdentityErr means the role's trust policy didn't match the ServiceAccount token's sub
(fixed by editing the sub condition in the trust policy or the SA annotation). The key
difference: on the first axis the fix is RBAC inside the cluster, on the second axis the fix
is the IAM role's trust policy in AWS, and the two must not be confused.
EOF
cat /var/work/tests/artifacts/8/summary.txt
```

## Schnellprüfung

```bash
check_result
```
