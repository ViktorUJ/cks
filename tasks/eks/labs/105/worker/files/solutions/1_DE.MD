[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 105 - Referenzlösung (Secrets: KMS envelope encryption, External Secrets)

Alle Befehle werden auf der Worker-Maschine (worker) per SSH ausgeführt. kubectl ist
bereits für den Cluster konfiguriert, und terraform hat bereits ein Secret in Secrets
Manager und eine IRSA-Rolle für den ESO-Controller erstellt - ihre Namen und ARNs liegen in
der Hinweisdatei `/home/ubuntu/lab105_hints.txt`.

```bash
cat ~/lab105_hints.txt
```

Variablen aus der Hinweisdatei für die folgenden Befehle:

```bash
export SECRET_NAME=$(grep '^secret_name' ~/lab105_hints.txt | awk '{print $3}')
export ROLE_ARN=$(grep '^role_arn' ~/lab105_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab105_hints.txt | awk '{print $3}')
```

## Aufgabe 1. Namespace `eks-105`

```bash
kubectl create namespace eks-105
```

## Aufgabe 2. Schicht 1: Prüfung von KMS envelope encryption

Ab Kubernetes 1.28 verschlüsselt EKS standardmäßig alle API-Objekte (einschließlich
`Secret`) mit einem AWS-Schlüssel, ohne dass Sie etwas dafür tun müssen. Wir prüfen die
Verschlüsselungskonfiguration des Clusters:

```bash
mkdir -p /var/work/tests/artifacts/2
aws eks describe-cluster --name "${CLUSTER_NAME}" --query 'cluster.encryptionConfig' \
  > /var/work/tests/artifacts/2/encryption_config.txt
cat /var/work/tests/artifacts/2/encryption_config.txt
```

In der Ausgabe enthält das Listenelement `"resources": ["secrets"]` - das bestätigt, dass
Schicht 1 (envelope encryption von Secrets in etcd) aktiviert ist. Wenn statt eines AWS
owned key ein eigener customer managed key (CMK) benötigt wird, geschieht das über einen
separaten Befehl `aws eks associate-encryption-config` - man kann einen eigenen CMK
hinzufügen, aber die Verschlüsselung nicht deaktivieren (das ist ein irreversibler
Vorgang), daher bleiben wir hier beim Standardschlüssel von AWS.

## Aufgabe 3. Installation des External Secrets Operator über Helm

Die Rolle `role_arn` wurde bereits von terraform mit einer Trust Policy erstellt, die genau
dem SA `external-secrets` im Namespace `external-secrets` vertraut (Kapitel 16, IRSA). Wir
installieren ESO über Helm und binden die Rolle sofort über eine Annotation am
ServiceAccount:

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets --create-namespace \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${ROLE_ARN}"

kubectl rollout status deployment/external-secrets -n external-secrets
kubectl get pods -n external-secrets
```

Wir prüfen, dass die Annotation am SA des Controllers gesetzt wurde:

```bash
kubectl get sa external-secrets -n external-secrets -o yaml | grep -A1 annotations
```

## Aufgabe 4. SecretStore und ExternalSecret

Wir erstellen ein `SecretStore` (namespace-scoped - Isolation nach Teams, Kapitel 18.5),
dann ein `ExternalSecret`, das auf das Demo-Secret aus terraform verweist:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-sm
  namespace: eks-105
spec:
  provider:
    aws:
      service: SecretsManager
      region: eu-central-1
EOF

cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: eks-105
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: aws-sm
    kind: SecretStore
  target:
    name: db-credentials
  data:
    - secretKey: password
      remoteRef:
        key: ${SECRET_NAME}
        property: password
EOF
```

Wir warten auf die Synchronisation und prüfen das native `Secret`:

```bash
kubectl wait --for=jsonpath='{.status.conditions[0].reason}'=SecretSynced \
  externalsecret/db-credentials -n eks-105 --timeout=120s

kubectl get externalsecret db-credentials -n eks-105
kubectl get secret db-credentials -n eks-105 -o jsonpath='{.data.password}' | base64 -d
echo
```

Der Wert sollte mit dem Passwort übereinstimmen, das terraform in Secrets Manager
hinterlegt hat (`S3cr3tPass123`). `refreshInterval: 1m` wurde bewusst klein gewählt - in
Aufgabe 6 müssen wir die Neusynchronisation nach einer manuellen Änderung des Secrets in
AWS schnell sehen können.

## Aufgabe 5. Pod mit Volume: robuster Synchronisationspfad

Wir mounten das `Secret` als Volume (volumeMount), nicht über env - genau das empfiehlt
Kapitel 18.5 für Werte, die sich ohne Neuerstellung des Pods aktualisieren sollen (kubelet
aktualisiert die Dateien im Volume selbst, wenn sich das `Secret` ändert):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: vol-reader
  namespace: eks-105
spec:
  containers:
  - name: app
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
    volumeMounts:
    - name: db-creds
      mountPath: /etc/db-creds
      readOnly: true
  volumes:
  - name: db-creds
    secret:
      secretName: db-credentials
EOF

kubectl wait --for=condition=Ready pod/vol-reader -n eks-105 --timeout=120s
```

Wir lesen den Wert aus der Datei im Volume:

```bash
mkdir -p /var/work/tests/artifacts/5
kubectl exec vol-reader -n eks-105 -- cat /etc/db-creds/password \
  > /var/work/tests/artifacts/5/volume_password.txt
echo >> /var/work/tests/artifacts/5/volume_password.txt
cat /var/work/tests/artifacts/5/volume_password.txt
```

## Aufgabe 6. Pod mit env: Symptom eines veralteten Werts

Wir erstellen einen zweiten Pod, der dasselbe `Secret` liest, aber über eine
Umgebungsvariable:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: env-reader
  namespace: eks-105
spec:
  containers:
  - name: app
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
EOF

kubectl wait --for=condition=Ready pod/env-reader -n eks-105 --timeout=120s
kubectl exec env-reader -n eks-105 -- printenv DB_PASSWORD
```

Wir ändern den Wert des Secrets direkt in Secrets Manager (nicht über Kubernetes):

```bash
aws secretsmanager put-secret-value --secret-id "${SECRET_NAME}" \
  --secret-string '{"username":"appuser","password":"RotatedPass456"}'
```

Wir warten das `refreshInterval` (in Aufgabe 4 auf `1m` gesetzt) plus etwas Reserve ab und
prüfen, dass ESO das native `Secret` neu synchronisiert hat:

```bash
sleep 90
kubectl get secret db-credentials -n eks-105 -o jsonpath='{.data.password}' | base64 -d
echo
```

Der Wert im `Secret` ist bereits neu (`RotatedPass456`) - ESO hat seine Arbeit gemacht.
Jetzt schauen wir uns den Pod mit env an, der vor der Rotation erstellt wurde:

```bash
kubectl exec env-reader -n eks-105 -- printenv DB_PASSWORD
```

Der Pod zeigt immer noch den alten Wert (`S3cr3tPass123`). Der Grund: Umgebungsvariablen
eines Containers werden beim Start des Prozesses festgelegt, daher hat die Aktualisierung
des `Secret` in etcd keinen Einfluss auf sie - der Pod muss neu erstellt werden (`kubectl
rollout restart` für ein Deployment, oder manuelles Löschen und Erstellen für einen
einzelnen Pod), um den neuen Wert über env zu erhalten. Das ist kein Fehler von ESO,
sondern eine Eigenschaft von env in Kubernetes - im Gegensatz zum Volume, das kubelet ohne
Neuerstellung des Pods auf der Festplatte aktualisiert (Aufgabe 5).

Wir halten die Beobachtung in einem Artefakt fest:

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/rotation.txt <<'EOF'
Nach put-secret-value in Secrets Manager und der Neusynchronisation von ExternalSecret hat
sich das native Secret db-credentials in etcd mit dem neuen Passwortwert aktualisiert - ESO
hat regulär funktioniert.

Der Pod env-reader liest das Passwort über env (secretKeyRef), und die
Umgebungsvariablen eines Containers werden einmalig beim Start des Prozesses festgelegt.
Der Wert von env aktualisiert sich nach einer Änderung des Secret nicht ohne
Neuerstellung des Pods - das ist kein Fehler von ESO, sondern eine Eigenschaft von env in
Kubernetes. Der Pod vol-reader (Aufgabe 5) liest dasselbe Secret über volumeMount - so ein
Volume aktualisiert kubelet automatisch auf der Festplatte, ohne den Pod neu zu erstellen.

Kurz auf Englisch: the env value is stale and does not update until the pod is recreated.
EOF
cat /var/work/tests/artifacts/7/rotation.txt
```

## Schnellprüfung

```bash
check_result
```
