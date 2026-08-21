[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 115 - solución de referencia (logging: Fluent Bit, CloudWatch Logs, filtrado, retención)

Todos los comandos se ejecutan en la máquina de trabajo por SSH. kubectl ya está configurado
para el clúster, la CLI `aws` está configurada para la misma cuenta y región. El nombre del
rol IRSA y el nombre del log group están en el archivo `~/lab115_hints.txt`.

```bash
source ~/lab115_hints.txt 2>/dev/null || true
ROLE_ARN=$(grep '^role_arn' ~/lab115_hints.txt | awk '{print $3}')
LOG_GROUP=$(grep '^log_group_name' ~/lab115_hints.txt | awk '{print $3}')
CLUSTER=$(kubectl config current-context | sed 's|.*/||')
echo "$ROLE_ARN"
echo "$LOG_GROUP"
```

## Tarea 1. Namespace `eks-115`

```bash
kubectl create namespace eks-115
```

## Tarea 2. Síntoma: los logs desaparecen sin recolector

Creamos un Deployment cuyo contenedor imprime un marcador y falla - el `restartPolicy:
Always` del Deployment recrea el contenedor dentro del mismo pod, pero el nombre del pod no
cambia entre reinicios del contenedor (este es un caso distinto de la eliminación del pod):

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

Ambas llamadas muestran `BEFORE_MARKER_LAB115` - el pod está vivo, tanto la ejecución actual
como la anterior del contenedor están disponibles. Ahora simulamos qué pasa cuando se
recrea el pod entero (reemplazo de node, consolidación de Karpenter, una actualización del
Deployment) - eliminamos el propio pod:

```bash
kubectl delete pod "$POD" -n eks-115
sleep 10
kubectl get po -n eks-115 -l app=flaky-before
```

El Deployment creó un pod con un nombre nuevo. Consultemos el nombre anterior:

```bash
kubectl logs "$POD" -n eks-115 2>&1 | tee /tmp/notfound.txt
```

Obtenemos `Error from server (NotFound): pods "..." not found` - los logs de la ejecución
que falló desaparecieron junto con el pod, ya no hay de dónde recuperarlos (sección 34.1).
Registramos esto en el artefacto:

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "OLD_POD_NAME=$POD"
  echo "BEFORE_MARKER_LAB115"
  cat /tmp/notfound.txt
} > /var/work/tests/artifacts/2/before_symptom.txt
cat /var/work/tests/artifacts/2/before_symptom.txt
```

## Tarea 3. DaemonSet de Fluent Bit con un rol IRSA

Añadimos el repositorio de charts de AWS y preparamos `values.yaml` con la anotación del
rol, protección contra OOM bajo contrapresión (`Mem_Buf_Limit`, `storage.type filesystem`,
sección 34.7) y salida hacia CloudWatch Logs:

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

Verificamos que la anotación del rol y la protección contra OOM llegaron al ConfigMap:

```bash
kubectl get sa aws-for-fluent-bit -n amazon-cloudwatch -o yaml | grep role-arn
kubectl get cm aws-for-fluent-bit -n amazon-cloudwatch -o jsonpath='{.data.fluent-bit\.conf}' \
  | grep -E 'Mem_Buf_Limit|storage.type'
```

## Tarea 4. Arreglo comprobado: los logs se encuentran tras eliminar el pod

El mismo escenario que en la tarea 2, pero ahora Fluent Bit ya está enviando los logs desde
el node. Esta vez el contenedor no falla - vive lo suficiente para que la línea sea enviada:

```bash
kubectl create deployment flaky-after -n eks-115 \
  --image=busybox:1.36 -- sh -c 'echo AFTER_MARKER_LAB115; sleep 3600'
kubectl rollout status deployment/flaky-after -n eks-115

sleep 60   # damos tiempo a Fluent Bit para leer el archivo y enviar el registro

POD2=$(kubectl get po -n eks-115 -l app=flaky-after -o jsonpath='{.items[0].metadata.name}')
echo "$POD2"

kubectl delete pod "$POD2" -n eks-115
sleep 10
kubectl logs "$POD2" -n eks-115 2>&1 | tee /tmp/notfound2.txt
```

`NotFound` otra vez - pero esta vez la línea no se pierde, ya está en CloudWatch Logs:

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "AFTER_MARKER_LAB115" \
  --query 'events[*].message' --output text | tee /tmp/found_after.txt
```

La línea se encuentra aunque el pod con ese nombre ya esté eliminado - Fluent Bit ya la
había enviado desde el node antes de que el pod desapareciera. Registramos esto en el
artefacto:

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

## Tarea 5. Filtrado: recortando el ruido antes del envío

Añadimos una sección `FILTER grep` a `values.yaml` para descartar las líneas con
`/healthz` directamente en el node, antes de la ingesta en CloudWatch (sección 34.6 -
recortar el ruido en el origen es más económico que limpiar el almacenamiento después del
hecho):

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

Solo después de que los nuevos pods de Fluent Bit estén activos generamos tráfico con una
línea ruidosa y otra normal:

```bash
kubectl run access-log-gen -n eks-115 --image=busybox:1.36 --restart=Never \
  -- sh -c 'echo "GET /healthz 200"; sleep 3; echo NORMAL_MARKER_LAB115; sleep 3600'

sleep 60
```

Comprobamos ambos lados del filtro:

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "healthz" --query 'events' --output text
# vacío - la línea fue descartada por el filtro grep

aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "NORMAL_MARKER_LAB115" --query 'events[*].message' --output text
# el registro está ahí - el filtro no toca las líneas normales
```

Registramos la explicación:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/filter_check.txt <<'EOF'
FILTER grep con Exclude log /healthz descartó la línea "GET /healthz 200" directamente en
el node, antes del envío a CloudWatch Logs - el log group no tiene ese registro en
absoluto. La línea normal NORMAL_MARKER_LAB115 no es tocada por el filtro y llega a
CloudWatch. Recortar el ruido de esta manera es más económico que limpiar los logs en el
almacenamiento después del hecho: se paga por la ingesta, y una línea filtrada nunca genera
ingesta (sección 34.6).
EOF
cat /var/work/tests/artifacts/5/filter_check.txt
```

## Tarea 6. Política de retención en el log group

Por defecto, los logs en CloudWatch se conservan para siempre (`retentionInDays` vacío).
Configuramos un período:

```bash
aws logs put-retention-policy --log-group-name "$LOG_GROUP" --retention-in-days 7

mkdir -p /var/work/tests/artifacts/6
aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[].[logGroupName,retentionInDays]" --output table \
  | tee /var/work/tests/artifacts/6/retention.txt
```

## Tarea 7. Multiline: un stack trace como un solo registro

`input.multilineParser` ya contiene `cri` - fusiona lo que el propio runtime del contenedor
divide, en una única línea de log JSON. Añadir ahí el parser incorporado `python` mediante
una coma no funcionará: `cri` coincide con el `start_state` de cualquier línea de CRI, así
que Fluent Bit solo aplica ese, y nunca llega a `python` (issue fluent/fluent-bit #5235 -
varios parsers en un solo `multiline.parser` solo funcionan si sus valores de `start_state`
no se superponen). El enfoque correcto es un FILTER `multiline` separado con el tipo
incorporado `python` (sección 34.7), que debe ejecutarse en el pipeline antes del FILTER
`kubernetes` (los registros fusionados se vuelven a emitir al inicio del pipeline, y si
`kubernetes` ya los procesó antes del filtro multiline, se aplicaría una segunda vez al
resultado):

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

La sección `filter.enabled: false` desactiva el FILTER `kubernetes` incorporado del chart
(ya va en `additionalFilters` junto con el FILTER `multiline` y el antiguo FILTER `grep` de
la tarea 5 - sin `filter.enabled: false` la configuración tendría dos FILTERs `kubernetes`
seguidos, el segundo redundante). Aplicamos:

```bash
helm upgrade aws-for-fluent-bit eks/aws-for-fluent-bit \
  -n amazon-cloudwatch -f ~/values.yaml

kubectl rollout status daemonset/aws-for-fluent-bit -n amazon-cloudwatch --timeout=120s
```

Solo después de que Fluent Bit se reinicie imprimimos cuatro líneas seguidas, simulando un
Traceback de Python:

```bash
kubectl run stacktrace-app -n eks-115 --image=busybox:1.36 --restart=Never \
  -- sh -c 'printf "Traceback (most recent call last):\n  File \"app.py\", line 10, in <module>\n    raise ValueError(\"CRASH_TRACE_LAB115\")\nValueError: CRASH_TRACE_LAB115\n"; sleep 3600'

sleep 60
```

Comprobamos que las cuatro líneas llegaron como un solo registro de CloudWatch, no cuatro:

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "CRASH_TRACE_LAB115" \
  --query 'events[*].message' --output text | tee /tmp/multiline_msg.txt
```

En la salida, un mensaje contiene tanto `Traceback` como `CRASH_TRACE_LAB115` - el parser
`python` fusionó las cuatro líneas de log en un solo registro. Sin esto, CloudWatch habría
recibido cuatro eventos separados, y Logs Insights los contaría como cuatro "crashes"
distintos. Registramos esto:

```bash
mkdir -p /var/work/tests/artifacts/7
{
  echo "=== merged CloudWatch event ==="
  cat /tmp/multiline_msg.txt
  echo ""
  echo "FILTER multiline con el tipo incorporado python fusionó 4 líneas de Traceback en"
  echo "un solo registro de CloudWatch en lugar de dividirlas en 4 eventos separados."
} > /var/work/tests/artifacts/7/multiline.txt
cat /var/work/tests/artifacts/7/multiline.txt
```

## Verificación rápida

```bash
check_result
```
