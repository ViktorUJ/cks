[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 115 - Referenzlösung (Logging: Fluent Bit, CloudWatch Logs, Filterung, Retention)

Alle Befehle werden auf der Worker-Maschine per SSH ausgeführt. kubectl ist bereits für den
Cluster konfiguriert, die `aws` CLI ist für dasselbe Konto und dieselbe Region konfiguriert.
Der Name der IRSA-Rolle und der Name der Log-Gruppe stehen in der Datei
`~/lab115_hints.txt`.

```bash
source ~/lab115_hints.txt 2>/dev/null || true
ROLE_ARN=$(grep '^role_arn' ~/lab115_hints.txt | awk '{print $3}')
LOG_GROUP=$(grep '^log_group_name' ~/lab115_hints.txt | awk '{print $3}')
CLUSTER=$(kubectl config current-context | sed 's|.*/||')
echo "$ROLE_ARN"
echo "$LOG_GROUP"
```

## Aufgabe 1. Namespace `eks-115`

```bash
kubectl create namespace eks-115
```

## Aufgabe 2. Symptom: Logs verschwinden ohne Collector

Erstellen Sie ein Deployment, dessen Container einen Marker ausgibt und abstürzt - die
`restartPolicy: Always` des Deployments erstellt den Container innerhalb desselben Pods neu,
aber der Pod-Name ändert sich über Container-Neustarts hinweg nicht (das ist ein separater
Fall von der Pod-Löschung):

```bash
kubectl create deployment flaky-before -n eks-115 \
  --image=busybox:1.36 -- sh -c 'echo BEFORE_MARKER_LAB115; sleep 5; exit 1'
kubectl wait --for=condition=Available deployment/flaky-before -n eks-115 --timeout=60s \
  2>/dev/null || true
sleep 15

POD=$(kubectl get po -n eks-115 -l app=flaky-before -o jsonpath='{.items[0].metadata.name}')
kubectl logs "$POD" -n eks-115
kubectl logs "$POD" -n eks-115 --previous
```

Beide Aufrufe zeigen `BEFORE_MARKER_LAB115` - der Pod ist am Leben, sowohl der aktuelle als
auch der vorherige Container-Lauf sind verfügbar. Jetzt simulieren wir, was passiert, wenn
der gesamte Pod neu erstellt wird (Node-Austausch, Karpenter-Konsolidierung, ein
Deployment-Update) - wir löschen den Pod selbst:

```bash
kubectl delete pod "$POD" -n eks-115
sleep 10
kubectl get po -n eks-115 -l app=flaky-before
```

Das Deployment hat einen Pod unter einem neuen Namen erstellt. Fragen wir den alten Namen ab:

```bash
kubectl logs "$POD" -n eks-115 2>&1 | tee /tmp/notfound.txt
```

Wir erhalten `Error from server (NotFound): pods "..." not found` - die Logs des
abgestürzten Laufs sind mit dem Pod verschwunden, es gibt keinen Ort mehr, um sie
abzurufen (Abschnitt 34.1). Dokumentieren Sie das im Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "OLD_POD_NAME=$POD"
  echo "BEFORE_MARKER_LAB115"
  cat /tmp/notfound.txt
} > /var/work/tests/artifacts/2/before_symptom.txt
cat /var/work/tests/artifacts/2/before_symptom.txt
```

## Aufgabe 3. Fluent Bit DaemonSet mit einer IRSA-Rolle

Fügen Sie das AWS-Chart-Repository hinzu und bereiten Sie `values.yaml` mit der
Rollen-Annotation, dem OOM-Schutz bei Backpressure (`Mem_Buf_Limit`, `storage.type
filesystem`, Abschnitt 34.7) und dem Output nach CloudWatch Logs vor:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

cat > ~/values.yaml <<EOF
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: "${ROLE_ARN}"

service:
  extraService: |
    HTTP_Server  On
    HTTP_Listen  0.0.0.0
    HTTP_PORT    2020
    storage.path /var/fluent-bit/state/flb-storage/

input:
  memBufLimit: 50MB
  multilineParser: "cri"
  extraInputs: |
    storage.type      filesystem

cloudWatchLogs:
  enabled: true
  region: "eu-central-1"
  logGroupName: "${LOG_GROUP}"
  logStreamPrefix: "fluentbit-"
  autoCreateGroup: true
EOF

helm install aws-for-fluent-bit eks/aws-for-fluent-bit \
  --namespace amazon-cloudwatch --create-namespace \
  -f ~/values.yaml

kubectl rollout status daemonset/aws-for-fluent-bit -n amazon-cloudwatch --timeout=120s
kubectl get pods -n amazon-cloudwatch -o wide
```

Prüfen Sie, dass die Rollen-Annotation und der OOM-Schutz im ConfigMap angekommen sind:

```bash
kubectl get sa aws-for-fluent-bit -n amazon-cloudwatch -o yaml | grep role-arn
kubectl get cm aws-for-fluent-bit -n amazon-cloudwatch -o jsonpath='{.data.fluent-bit\.conf}' \
  | grep -E 'Mem_Buf_Limit|storage.type'
```

## Aufgabe 4. Fix bestätigt: Logs werden nach Pod-Löschung gefunden

Dasselbe Szenario wie in Aufgabe 2, aber jetzt streamt Fluent Bit bereits Logs von der Node.
Dieses Mal stürzt der Container nicht ab - er lebt lange genug, damit die Zeile versendet
wird:

```bash
kubectl create deployment flaky-after -n eks-115 \
  --image=busybox:1.36 -- sh -c 'echo AFTER_MARKER_LAB115; sleep 3600'
kubectl rollout status deployment/flaky-after -n eks-115

sleep 60   # Fluent Bit Zeit geben, die Datei zu lesen und den Eintrag zu versenden

POD2=$(kubectl get po -n eks-115 -l app=flaky-after -o jsonpath='{.items[0].metadata.name}')
echo "$POD2"

kubectl delete pod "$POD2" -n eks-115
sleep 10
kubectl logs "$POD2" -n eks-115 2>&1 | tee /tmp/notfound2.txt
```

Wieder `NotFound` - aber diesmal ist die Zeile nicht verloren, sie ist bereits in
CloudWatch Logs:

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "AFTER_MARKER_LAB115" \
  --query 'events[*].message' --output text | tee /tmp/found_after.txt
```

Die Zeile wird gefunden, obwohl der Pod mit diesem Namen bereits gelöscht ist - Fluent Bit
hatte sie bereits von der Node versendet, bevor der Pod verschwand. Dokumentieren Sie das im
Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/4
{
  echo "OLD_POD_NAME=$POD2"
  cat /tmp/notfound2.txt
  echo "=== found in CloudWatch Logs ==="
  cat /tmp/found_after.txt
} > /var/work/tests/artifacts/4/after_fixed.txt
cat /var/work/tests/artifacts/4/after_fixed.txt
```

## Aufgabe 5. Filterung: Rauschen vor dem Versand abschneiden

Fügen Sie `values.yaml` einen `FILTER grep`-Abschnitt hinzu, um Zeilen mit `/healthz` direkt
auf der Node zu verwerfen, vor der Ingestion in CloudWatch (Abschnitt 34.6 - Rauschen an der
Quelle abzuschneiden ist günstiger als das nachträgliche Aufräumen des Speichers):

```bash
cat >> ~/values.yaml <<'EOF'

additionalFilters: |
  [FILTER]
      Name   grep
      Match  kube.*
      Exclude log /healthz
EOF

helm upgrade aws-for-fluent-bit eks/aws-for-fluent-bit \
  -n amazon-cloudwatch -f ~/values.yaml

kubectl rollout status daemonset/aws-for-fluent-bit -n amazon-cloudwatch --timeout=120s
```

Erst nachdem die neuen Fluent Bit Pods laufen, erzeugen wir Traffic mit einer lauten Zeile
und einer normalen:

```bash
kubectl run access-log-gen -n eks-115 --image=busybox:1.36 --restart=Never \
  -- sh -c 'echo "GET /healthz 200"; sleep 3; echo NORMAL_MARKER_LAB115; sleep 3600'

sleep 60
```

Prüfen Sie beide Seiten des Filters:

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "healthz" --query 'events' --output text
# leer - die Zeile wurde vom grep-Filter verworfen

aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "NORMAL_MARKER_LAB115" --query 'events[*].message' --output text
# der Eintrag ist da - der Filter fasst normale Zeilen nicht an
```

Dokumentieren Sie die Erklärung:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/filter_check.txt <<'EOF'
FILTER grep mit Exclude log /healthz hat die Zeile "GET /healthz 200" direkt auf der Node
verworfen, vor dem Versand an CloudWatch Logs - die Log-Gruppe enthält diesen Eintrag
überhaupt nicht. Die normale Zeile NORMAL_MARKER_LAB115 wird vom Filter nicht angefasst und
erreicht CloudWatch. Rauschen auf diese Weise abzuschneiden ist günstiger als das
nachträgliche Aufräumen von Logs im Speicher: man bezahlt für die Ingestion, und eine
herausgefilterte Zeile erzeugt nie eine Ingestion (Abschnitt 34.6).
EOF
cat /var/work/tests/artifacts/5/filter_check.txt
```

## Aufgabe 6. Retention-Policy auf der Log-Gruppe

Standardmäßig werden Logs in CloudWatch für immer aufbewahrt (`retentionInDays` leer).
Setzen Sie eine Periode:

```bash
aws logs put-retention-policy --log-group-name "$LOG_GROUP" --retention-in-days 7

mkdir -p /var/work/tests/artifacts/6
aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[].[logGroupName,retentionInDays]" --output table \
  | tee /var/work/tests/artifacts/6/retention.txt
```

## Aufgabe 7. Multiline: ein Stack-Trace als ein Eintrag

`input.multilineParser` enthält bereits `cri` - er führt zusammen, was die
Container-Runtime selbst aufteilt, zu einer vollständigen JSON-Log-Zeile. Den eingebauten
`python`-Parser dort per Komma hinzuzufügen funktioniert nicht: `cri` passt auf den
`start_state` jeder CRI-Zeile, sodass Fluent Bit nur diesen anwendet, und er kommt nie zu
`python` (Issue fluent/fluent-bit #5235 - mehrere Parser in einem einzigen
`multiline.parser` funktionieren nur, wenn ihre `start_state`-Werte sich nicht überlappen).
Der richtige Ansatz ist ein separater `multiline`-FILTER mit dem eingebauten Typ `python`
(Abschnitt 34.7), der in der Pipeline vor dem `kubernetes`-FILTER laufen muss
(zusammengeführte Einträge werden am Anfang der Pipeline erneut ausgegeben, und wenn
`kubernetes` sie bereits vor dem multiline-Filter verarbeitet hat, würde er ein zweites Mal
auf das Ergebnis angewendet):

```bash
cat >> ~/values.yaml <<'EOF'

filter:
  enabled: false

additionalFilters: |
  [FILTER]
      Name                  multiline
      Match                 kube.*
      multiline.key_content log
      multiline.parser      python

  [FILTER]
      Name                kubernetes
      Match               kube.*
      Kube_URL            https://kubernetes.default.svc.cluster.local:443
      Merge_Log           On
      Merge_Log_Key       data
      Keep_Log            On
      K8S-Logging.Parser  On
      K8S-Logging.Exclude On
      Buffer_Size         32k

  [FILTER]
      Name   grep
      Match  kube.*
      Exclude log /healthz
EOF
```

Der Abschnitt `filter.enabled: false` deaktiviert den eingebauten `kubernetes`-FILTER des
Charts (er geht bereits in `additionalFilters` zusammen mit dem `multiline`-FILTER und dem
alten `grep`-FILTER aus Aufgabe 5 ein - ohne `filter.enabled: false` hätte die
Konfiguration zwei `kubernetes`-FILTER hintereinander, der zweite überflüssig). Wenden Sie
es an:

```bash
helm upgrade aws-for-fluent-bit eks/aws-for-fluent-bit \
  -n amazon-cloudwatch -f ~/values.yaml

kubectl rollout status daemonset/aws-for-fluent-bit -n amazon-cloudwatch --timeout=120s
```

Erst nachdem Fluent Bit neu gestartet ist, geben wir vier Zeilen nacheinander aus, die einen
Python-Traceback simulieren:

```bash
kubectl run stacktrace-app -n eks-115 --image=busybox:1.36 --restart=Never \
  -- sh -c 'printf "Traceback (most recent call last):\n  File \"app.py\", line 10, in <module>\n    raise ValueError(\"CRASH_TRACE_LAB115\")\nValueError: CRASH_TRACE_LAB115\n"; sleep 3600'

sleep 60
```

Prüfen Sie, dass alle vier Zeilen als ein CloudWatch-Eintrag angekommen sind, nicht als vier:

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "CRASH_TRACE_LAB115" \
  --query 'events[*].message' --output text | tee /tmp/multiline_msg.txt
```

In der Ausgabe enthält eine Nachricht sowohl `Traceback` als auch `CRASH_TRACE_LAB115` - der
`python`-Parser hat die vier Log-Zeilen zu einem Eintrag zusammengeführt. Ohne ihn hätte
CloudWatch vier separate Events erhalten, und Logs Insights hätte das als vier
verschiedene "Abstürze" gezählt. Dokumentieren Sie das:

```bash
mkdir -p /var/work/tests/artifacts/7
{
  echo "=== merged CloudWatch event ==="
  cat /tmp/multiline_msg.txt
  echo ""
  echo "FILTER multiline mit dem eingebauten Typ python hat 4 Traceback-Zeilen zu einem"
  echo "CloudWatch-Eintrag zusammengeführt, statt sie in 4 separate Events aufzuteilen."
} > /var/work/tests/artifacts/7/multiline.txt
cat /var/work/tests/artifacts/7/multiline.txt
```

## Schnellprüfung

```bash
check_result
```
