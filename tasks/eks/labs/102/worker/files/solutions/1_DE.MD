[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 102 - Referenzlösung (Zugriff auf den Cluster: IAM, RBAC, Access Entries)

Alle Befehle werden auf der Worker-Maschine (worker) per SSH ausgeführt. kubectl ist
bereits für den Cluster konfiguriert. Die worker-Rolle hat `eks:*` (das reicht für alle
Access-Entry/Access-Policy-Befehle) und gezielte Rechte
`iam:CreateRole/GetRole/DeleteRole/PutRolePolicy` plus `sts:AssumeRole`, beschränkt auf
Rollen mit einem Namen der Form `*-test-*` - das reicht aus, um die Testrolle zu erstellen
und tatsächlich per assume-role in sie zu wechseln, ohne die Rechte anderer Labs zu
berühren.

## Auswahl des zweiten Principals

Der Cluster wird bereits vom Modul `eks_v2_control_plane` im Modus
`authenticationMode = API` erstellt (v21 `terraform-aws-modules/eks/aws` mit
`enable_cluster_creator_admin_permissions = true`). Die worker-Rolle hat bereits ihre eigene
Access Entry mit `AmazonEKSClusterAdminPolicy` (`terraform/modules/eks_v2_work_pc/iam.tf`) -
das bestätigt, dass API-Access-Entries im Cluster aktiviert sind und funktionieren.

Für die Aufgaben dieses Labs braucht man einen **zweiten** IAM-Principal, der noch keinen
Zugriff auf den Cluster hat. Die Node-Rolle von Karpenter eignet sich dafür nicht: Das
Submodul `terraform-aws-modules/eks/aws//modules/karpenter` erstellt für sie automatisch
eine Access Entry vom Typ `EC2_LINUX` (`create_access_entry = true` standardmäßig), und ein
IAM-Principal kann nicht in zwei Access Entries gleichzeitig stehen. Deshalb erstellt dieses
Lab eine separate Testrolle über die AWS CLI direkt vom worker aus, mit Vertrauen nur zur
worker-Rolle selbst (`sts:AssumeRole` ist ausschließlich für den ARN der worker-Rolle
erlaubt, für niemanden sonst).

## Aufgabe 1. Inventur: authenticationMode

```bash
mkdir -p /var/work/tests/artifacts/1
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.accessConfig' \
  > /var/work/tests/artifacts/1/accessconfig.json
cat /var/work/tests/artifacts/1/accessconfig.json
```

Die erwartete Ausgabe sieht in etwa so aus:

```json
{
    "authenticationMode": "API",
    "bootstrapClusterCreatorAdminPermissions": true
}
```

`authenticationMode` ist gleich `API` - im Cluster gibt es kein `aws-auth` ConfigMap, alle
Abbildungen von Principals laufen über Access Entries.

## Aufgabe 2. Test-IAM-Rolle als zweiter Principal

Wir ermitteln ARN und Account-ID der worker-Rolle (ihr erlauben wir das Assumen der
Testrolle):

```bash
WORKER_ARN=$(aws sts get-caller-identity --query Arn --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "$WORKER_ARN"
```

`get-caller-identity` zeigt für eine Instanz mit EC2-Profil den ARN der **Session**
(`assumed-role/.../i-...`), nicht den ARN der Rolle selbst. Für die Trust Policy und die
Access Entry braucht man den ARN der Rolle, daher setzen wir ihn aus der Session zusammen:

```bash
ROLE_NAME=$(echo "$WORKER_ARN" | sed -E 's#.*assumed-role/([^/]+)/.*#\1#')
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "$ROLE_ARN"
```

Wir erstellen die Testrolle. Der Name muss unbedingt `-test-` enthalten, sonst kann worker
sie weder erstellen noch assumen (seine IAM-Policy ist auf diese Teilzeichenkette
beschränkt):

```bash
TEST_ROLE_NAME="eks-task102-test-viewer"

cat > /tmp/trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": { "AWS": "${ROLE_ARN}" }
    }
  ]
}
EOF

aws iam create-role --role-name "$TEST_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust.json

TEST_ROLE_ARN=$(aws iam get-role --role-name "$TEST_ROLE_NAME" \
  --query 'Role.Arn' --output text)

mkdir -p /var/work/tests/artifacts/2
echo "$TEST_ROLE_ARN" > /var/work/tests/artifacts/2/test_role_arn.txt
cat /var/work/tests/artifacts/2/test_role_arn.txt
```

Die Rolle braucht intern keine weiteren IAM-Rechte außer assume - alle ihre tatsächlichen
Befugnisse gibt der Cluster über die Access Entry und Access Policy/RBAC vor, nicht IAM.

## Aufgabe 3. Access Entry für die Testrolle, Gruppe viewers

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)

aws eks create-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --kubernetes-groups viewers \
  --type STANDARD

aws eks describe-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN"
```

`username` setzen wir nicht - EKS vergibt ihn selbst, wie es die Dokumentation empfiehlt.
Der Principal ist dem Cluster nun bekannt und gehört zur Kubernetes-Gruppe `viewers`, aber
noch ohne jedes Recht: die Access Entry allein gibt keine Rechte, sie liefert nur das
Subjekt für RBAC.

## Aufgabe 4. ClusterRole und ClusterRoleBinding für die Gruppe viewers

Klassisches RBAC über der Access Entry, ohne Access Policy:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: viewers-pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: viewers-pod-reader
subjects:
- kind: Group
  name: viewers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: viewers-pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl get clusterrole viewers-pod-reader -o yaml
kubectl get clusterrolebinding viewers-pod-reader -o yaml
```

Die Gruppe `viewers` kann jetzt Pods in allen Namespaces lesen, und sonst nichts.

## Aufgabe 5. Manuelle Prüfung der Rechte über assume-role

Das ist ein Schritt, den der Studierende selbst mit den Händen ausführt - der Autotest
prüft nur das Artefakt mit dem Ergebnis, nicht das assume-role selbst (temporäre
Credentials werden innerhalb von `tests.bats` nicht benötigt).

Wir holen temporäre Credentials der Testrolle und ein separates kubeconfig unter einem
Alias:

```bash
CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name test-viewer-session)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

aws eks update-kubeconfig --name "$CLUSTER" --region eu-central-1 \
  --alias test-viewer --kubeconfig /tmp/test-viewer.kubeconfig

kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
kubectl --kubeconfig /tmp/test-viewer.kubeconfig create namespace test
```

Erwartetes Ergebnis: `get pods -A` funktioniert (nur Lesen ist über das RBAC-Binding an
die Gruppe `viewers` erlaubt), während `create namespace test` mit `Forbidden` fehlschlägt
- das RBAC für die Gruppe `viewers` enthält keine Rechte auf `namespaces`. Wir kehren zu
den Rechten von worker zurück:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

Wir speichern das Ergebnis der manuellen Prüfung als Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/rbac_check.txt <<'EOF'
kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
  -> funktioniert: das RBAC-Binding viewers-pod-reader gibt get/list auf pods.

kubectl --kubeconfig /tmp/test-viewer.kubeconfig create namespace test
  -> Forbidden: die Gruppe viewers hat keine Rechte, einen namespace zu erstellen,
     die access entry hat ein Subjekt geliefert, aber RBAC hat diese Aktion nicht erlaubt.
EOF
cat /var/work/tests/artifacts/5/rbac_check.txt
```

## Aufgabe 6. Access Policy AmazonEKSViewPolicy über der Access Entry

```bash
aws eks associate-access-policy --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster

aws eks list-associated-access-policies --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN"
```

Jetzt hat die Testrolle zwei unabhängige Rechtequellen: die RBAC-Gruppe `viewers`
(get/list auf Pods) und die Access Policy `AmazonEKSViewPolicy` (Lesen der meisten
Cluster-Ressourcen, ohne Secrets). Beachten Sie: `kubectl --kubeconfig
/tmp/test-viewer.kubeconfig auth can-i --list` zeigt die Rechte aus der Access Policy
nicht an - sie ist nicht durch RBAC-Objekte ausgedrückt, der einzige Weg, sie zu sehen,
ist `list-associated-access-policies`.

## Aufgabe 7. Diagnose: Unauthorized versus Forbidden

Wir zeigen den Unterschied an realen Befehlen. Wir legen eine weitere Rolle **ohne**
Access Entry an - sie wird dem Cluster unbekannt sein:

```bash
NOBODY_ROLE_NAME="eks-task102-test-nobody"
aws iam create-role --role-name "$NOBODY_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust.json
NOBODY_ARN=$(aws iam get-role --role-name "$NOBODY_ROLE_NAME" --query 'Role.Arn' --output text)

CREDS2=$(aws sts assume-role --role-arn "$NOBODY_ARN" --role-session-name nobody-session)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS2" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS2" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS2" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

aws eks update-kubeconfig --name "$CLUSTER" --region eu-central-1 \
  --alias test-nobody --kubeconfig /tmp/test-nobody.kubeconfig

kubectl --kubeconfig /tmp/test-nobody.kubeconfig get pods -A
# error: You must be logged in to the server (Unauthorized)

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
aws iam delete-role --role-name "$NOBODY_ROLE_NAME"
```

Wir vergleichen das mit dem Versuch, mit derselben Testrolle aus Aufgabe 5
(`test-viewer.kubeconfig`) einen namespace zu erstellen - dort kennt der Cluster den
Principal, aber RBAC erlaubt die Aktion nicht, also `Forbidden`. Der Unterschied liegt in
einem Punkt: `Unauthorized` bedeutet, der Cluster hat keine Access Entry für diesen ARN
gefunden (`aws eks list-access-entries` zeigt diesen ARN überhaupt nicht an), `Forbidden`
bedeutet, die Access Entry existiert, aber RBAC/Access Policy erlauben diese Aktion nicht.

```bash
aws eks list-access-entries --cluster-name "$CLUSTER"
```

Wir speichern die Erklärung als Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/unauthorized_vs_forbidden.txt <<'EOF'
Unauthorized (401): die Rolle eks-task102-test-nobody hat keine access entry im Cluster.
kubectl get pods -A mit ihrem kubeconfig antwortet "You must be logged in to the server
(Unauthorized)" - bis zum RBAC kam es gar nicht, die Authentifizierung ist gescheitert.
Prüfung: aws eks list-access-entries --cluster-name <cluster> enthält ihren ARN nicht.

Forbidden (403): die Rolle eks-task102-test-viewer hat eine access entry (Gruppe viewers)
und kann Pods lesen, aber kubectl create namespace test mit derselben Rolle antwortet
Forbidden - der Cluster kennt den Principal, aber das RBAC der Gruppe viewers erlaubt
das Erstellen von namespaces nicht.
EOF
cat /var/work/tests/artifacts/7/unauthorized_vs_forbidden.txt
```

## Aufgabe 8. Löschen der Access Entry und Wiederherstellung

Wir entfernen die Access Entry und stellen sicher, dass der Zugriff weg ist, und legen den
Eintrag anschließend erneut an (der Cluster bleibt in einem funktionsfähigen Zustand für
die Prüfung):

```bash
aws eks delete-access-entry --cluster-name "$CLUSTER" --principal-arn "$TEST_ROLE_ARN"

CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" --role-session-name test-viewer-2)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
# error: You must be logged in to the server (Unauthorized)

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

aws eks create-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --kubernetes-groups viewers --type STANDARD

aws eks describe-access-entry --cluster-name "$CLUSTER" --principal-arn "$TEST_ROLE_ARN"
```

`delete-access-entry` löscht zusammen mit dem Eintrag auch alle seine
Access-Policy-Assoziationen - die Policy aus Aufgabe 6 (`AmazonEKSViewPolicy`) stellt sich
nach dem Löschen des Eintrags nicht selbst wieder her. Wir stellen sie explizit wieder her,
damit die Umgebung im Zustand bleibt, der in Aufgabe 6 erreicht wurde:

```bash
aws eks associate-access-policy --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster

aws eks list-associated-access-policies --cluster-name "$CLUSTER" --principal-arn "$TEST_ROLE_ARN"
```

Wir speichern das Ergebnis des Löschen/Wiederherstellen-Zyklus als Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/delete_recreate.txt <<'EOF'
aws eks delete-access-entry --cluster-name <cluster> --principal-arn <test_role_arn>
kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
  -> error: You must be logged in to the server (Unauthorized): die gelöschte access entry
     hat den Principal dem Cluster sofort unbekannt gemacht.

aws eks create-access-entry --cluster-name <cluster> --principal-arn <test_role_arn> \
  --kubernetes-groups viewers --type STANDARD
  -> Zugriff wiederhergestellt, das RBAC-Binding an die Gruppe viewers wurde nicht
     geändert und funktioniert wieder.
EOF
cat /var/work/tests/artifacts/8/delete_recreate.txt
```

## Schnellprüfung

```bash
check_result
```
