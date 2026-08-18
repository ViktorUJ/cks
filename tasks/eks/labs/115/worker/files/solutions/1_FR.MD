[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 115 - solution de référence (logging : Fluent Bit, CloudWatch Logs, filtrage, rétention)

Toutes les commandes s'exécutent sur la machine worker via SSH. kubectl est déjà configuré
pour le cluster, le CLI `aws` est configuré pour le même compte et la même région. Le nom du
rôle IRSA et le nom du log group se trouvent dans le fichier `~/lab115_hints.txt`.

```bash
source ~/lab115_hints.txt 2>/dev/null || true
ROLE_ARN=$(grep '^role_arn' ~/lab115_hints.txt | awk '{print $3}')
LOG_GROUP=$(grep '^log_group_name' ~/lab115_hints.txt | awk '{print $3}')
CLUSTER=$(kubectl config current-context | sed 's|.*/||')
echo "$ROLE_ARN"
echo "$LOG_GROUP"
```

## Tâche 1. Namespace `eks-115`

```bash
kubectl create namespace eks-115
```

## Tâche 2. Symptôme : les logs disparaissent sans collecteur

Créez un Deployment dont le conteneur affiche un marqueur puis crashe - le
`restartPolicy: Always` du Deployment recrée le conteneur à l'intérieur du même pod, mais
le nom du pod ne change pas à travers les redémarrages du conteneur (c'est un cas différent
de la suppression du pod) :

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

Les deux appels affichent `BEFORE_MARKER_LAB115` - le pod est vivant, à la fois l'exécution
actuelle et l'exécution précédente du conteneur sont disponibles. Simulons maintenant ce
qui se passe lorsque le pod entier est recréé (remplacement de node, consolidation
Karpenter, mise à jour d'un Deployment) - on supprime le pod lui-même :

```bash
kubectl delete pod "$POD" -n eks-115
sleep 10
kubectl get po -n eks-115 -l app=flaky-before
```

Le Deployment a créé un pod sous un nouveau nom. Interrogeons l'ancien nom :

```bash
kubectl logs "$POD" -n eks-115 2>&1 | tee /tmp/notfound.txt
```

On obtient `Error from server (NotFound): pods "..." not found` - les logs de l'exécution
crashée ont disparu avec le pod, il n'y a plus nulle part où les récupérer (section 34.1).
Enregistrons cela dans l'artefact :

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "OLD_POD_NAME=$POD"
  echo "BEFORE_MARKER_LAB115"
  cat /tmp/notfound.txt
} > /var/work/tests/artifacts/2/before_symptom.txt
cat /var/work/tests/artifacts/2/before_symptom.txt
```

## Tâche 3. Fluent Bit DaemonSet avec un rôle IRSA

Ajoutez le dépôt de chart AWS et préparez `values.yaml` avec l'annotation du rôle, la
protection OOM sous backpressure (`Mem_Buf_Limit`, `storage.type filesystem`, section 34.7)
et la sortie vers CloudWatch Logs :

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

Vérifiez que l'annotation du rôle et la protection OOM sont bien arrivées dans la
ConfigMap :

```bash
kubectl get sa aws-for-fluent-bit -n amazon-cloudwatch -o yaml | grep role-arn
kubectl get cm aws-for-fluent-bit -n amazon-cloudwatch -o jsonpath='{.data.fluent-bit\.conf}' \
  | grep -E 'Mem_Buf_Limit|storage.type'
```

## Tâche 4. Correctif prouvé : les logs sont retrouvés après la suppression du pod

Le même scénario qu'à la tâche 2, mais cette fois Fluent Bit diffuse déjà les logs depuis le
node. Cette fois, le conteneur ne crashe pas - il vit assez longtemps pour que la ligne soit
expédiée :

```bash
kubectl create deployment flaky-after -n eks-115 \
  --image=busybox:1.36 -- sh -c 'echo AFTER_MARKER_LAB115; sleep 3600'
kubectl rollout status deployment/flaky-after -n eks-115

sleep 60   # on laisse à Fluent Bit le temps de lire le fichier et d'expédier l'enregistrement

POD2=$(kubectl get po -n eks-115 -l app=flaky-after -o jsonpath='{.items[0].metadata.name}')
echo "$POD2"

kubectl delete pod "$POD2" -n eks-115
sleep 10
kubectl logs "$POD2" -n eks-115 2>&1 | tee /tmp/notfound2.txt
```

`NotFound` à nouveau - mais cette fois la ligne n'est pas perdue, elle est déjà dans
CloudWatch Logs :

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "AFTER_MARKER_LAB115" \
  --query 'events[*].message' --output text | tee /tmp/found_after.txt
```

La ligne est retrouvée même si le pod portant ce nom est déjà supprimé - Fluent Bit l'avait
déjà expédiée depuis le node avant que le pod ne disparaisse. Enregistrons cela dans
l'artefact :

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

## Tâche 5. Filtrage : réduire le bruit avant l'expédition

Ajoutez une section `FILTER grep` à `values.yaml` pour rejeter les lignes avec `/healthz`
directement sur le node, avant l'ingestion dans CloudWatch (section 34.6 - réduire le bruit
à la source est moins coûteux que de nettoyer le stockage après coup) :

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

Seulement après que les nouveaux pods Fluent Bit soient prêts, on génère du trafic avec une
ligne bruyante et une ligne normale :

```bash
kubectl run access-log-gen -n eks-115 --image=busybox:1.36 --restart=Never \
  -- sh -c 'echo "GET /healthz 200"; sleep 3; echo NORMAL_MARKER_LAB115; sleep 3600'

sleep 60
```

Vérifiez les deux côtés du filtre :

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "healthz" --query 'events' --output text
# vide - la ligne a été rejetée par le filtre grep

aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "NORMAL_MARKER_LAB115" --query 'events[*].message' --output text
# l'enregistrement est là - le filtre ne touche pas les lignes normales
```

Enregistrez l'explication :

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/filter_check.txt <<'EOF'
Le FILTER grep avec Exclude log /healthz a rejeté la ligne "GET /healthz 200" directement
sur le node, avant l'expédition vers CloudWatch Logs - le log group n'a aucun enregistrement
de ce type. La ligne normale NORMAL_MARKER_LAB115 n'est pas touchée par le filtre et atteint
CloudWatch. Réduire le bruit de cette façon est moins coûteux que de nettoyer les logs dans
le stockage après coup : on paie pour l'ingestion, et une ligne filtrée ne crée jamais
d'ingestion (section 34.6).
EOF
cat /var/work/tests/artifacts/5/filter_check.txt
```

## Tâche 6. Politique de rétention sur le log group

Par défaut, les logs dans CloudWatch sont conservés pour toujours (`retentionInDays` vide).
Définissez une période :

```bash
aws logs put-retention-policy --log-group-name "$LOG_GROUP" --retention-in-days 7

mkdir -p /var/work/tests/artifacts/6
aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[].[logGroupName,retentionInDays]" --output table \
  | tee /var/work/tests/artifacts/6/retention.txt
```

## Tâche 7. Multiligne : une stack trace comme un seul enregistrement

`input.multilineParser` contient déjà `cri` - il fusionne ce que le container runtime
lui-même a divisé, en une ligne de log JSON complète. Ajouter le parser intégré `python` à
cet endroit via une virgule ne fonctionnera pas : `cri` correspond au `start_state` de
n'importe quelle ligne CRI, donc Fluent Bit n'applique que celui-là, et on n'arrive jamais à
`python` (issue fluent/fluent-bit #5235 - plusieurs parsers dans un seul `multiline.parser`
ne fonctionnent que si leurs valeurs `start_state` ne se chevauchent pas). La bonne approche
est un FILTER `multiline` séparé avec le type intégré `python` (section 34.7), qui doit
s'exécuter dans le pipeline avant le FILTER `kubernetes` (les enregistrements fusionnés sont
réémis au début du pipeline, et si `kubernetes` les avait déjà traités avant le filtre
multiline, il s'appliquerait une seconde fois sur le résultat) :

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

La section `filter.enabled: false` désactive le FILTER `kubernetes` intégré du chart (il
figure déjà dans `additionalFilters` avec le FILTER `multiline` et l'ancien FILTER `grep`
de la tâche 5 - sans `filter.enabled: false`, la config aurait deux FILTERs `kubernetes` à
la suite, le second étant redondant). Appliquez-le :

```bash
helm upgrade aws-for-fluent-bit eks/aws-for-fluent-bit \
  -n amazon-cloudwatch -f ~/values.yaml

kubectl rollout status daemonset/aws-for-fluent-bit -n amazon-cloudwatch --timeout=120s
```

Seulement après le redémarrage de Fluent Bit, on affiche quatre lignes à la suite, simulant
un Traceback Python :

```bash
kubectl run stacktrace-app -n eks-115 --image=busybox:1.36 --restart=Never \
  -- sh -c 'printf "Traceback (most recent call last):\n  File \"app.py\", line 10, in <module>\n    raise ValueError(\"CRASH_TRACE_LAB115\")\nValueError: CRASH_TRACE_LAB115\n"; sleep 3600'

sleep 60
```

Vérifiez que les quatre lignes sont arrivées comme un seul enregistrement CloudWatch, et non
quatre :

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "CRASH_TRACE_LAB115" \
  --query 'events[*].message' --output text | tee /tmp/multiline_msg.txt
```

Dans la sortie, un seul message contient à la fois `Traceback` et `CRASH_TRACE_LAB115` - le
parser `python` a fusionné les quatre lignes de log en un seul enregistrement. Sans cela,
CloudWatch aurait reçu quatre événements séparés, et Logs Insights les aurait comptés comme
quatre « crashs » différents. Enregistrons cela :

```bash
mkdir -p /var/work/tests/artifacts/7
{
  echo "=== événement CloudWatch fusionné ==="
  cat /tmp/multiline_msg.txt
  echo ""
  echo "Le FILTER multiline avec le type python intégré a fusionné les 4 lignes du Traceback"
  echo "en un seul enregistrement CloudWatch au lieu de les séparer en 4 événements distincts."
} > /var/work/tests/artifacts/7/multiline.txt
cat /var/work/tests/artifacts/7/multiline.txt
```

## Vérification rapide

```bash
check_result
```
