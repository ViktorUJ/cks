[Русская версия](README_RUS.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)


# Laboratorio: Autoescalado de aplicaciones con KEDA y Prometheus

## Descripción

Este laboratorio muestra cómo escalar automáticamente una aplicación web en Amazon EKS mediante **KEDA** (Kubernetes Event-Driven Autoscaling) basándose en métricas de **Prometheus**. La aplicación exporta sus propias métricas de solicitudes, Prometheus las recopila y KEDA escala el deployment hacia arriba y hacia abajo según el número real de solicitudes por segundo (RPS).

El clúster ya está preparado con **Karpenter** y dos NodePool dedicados:
- `monitoring` — para el stack de monitorización (Prometheus, KEDA, metrics-server)
- `default` — para la aplicación de prueba

**Lo que aprenderá:**
- Cómo instalar el Prometheus Operator oficial (kube-prometheus-stack) mediante Helm
- Cómo fijar cargas de trabajo a nodos dedicados mediante nodeAffinity y tolerations
- Cómo publicar Prometheus mediante LoadBalancer para un acceso rápido
- Cómo recopilar métricas personalizadas de la aplicación mediante ServiceMonitor
- Cómo instalar KEDA y configurar un ScaledObject basado en una consulta a Prometheus
- Cómo generar carga y observar el autoescalado ascendente/descendente
- Cómo eliminar correctamente los recursos cloud (LoadBalancer, nodos de Karpenter)

## Contenido
- [Preparación del entorno](#preparación-del-entorno)
  - [Inicio del laboratorio](#inicio-del-laboratorio)
  - [Recursos creados](#recursos-creados)
  - [Requisitos previos](#requisitos-previos)
- [Visualización de NodePool](#visualización-de-nodepool)
- [Instalación del stack de monitorización](#instalación-del-stack-de-monitorización)
  - [Prometheus Operator y metrics-server](#prometheus-operator-y-metrics-server)
  - [Verificación de la instalación](#verificación-de-la-instalación)
- [Despliegue de la aplicación](#despliegue-de-la-aplicación)
- [Recopilación de métricas de la aplicación](#recopilación-de-métricas-de-la-aplicación)
  - [Creación de ServiceMonitor](#creación-de-servicemonitor)
  - [Verificación del target](#verificación-del-target)
  - [Verificación de métricas en Prometheus](#verificación-de-métricas-en-prometheus)
- [Instalación de KEDA](#instalación-de-keda)
- [Configuración del autoescalado](#configuración-del-autoescalado)
  - [Métricas disponibles de la aplicación](#métricas-disponibles-de-la-aplicación)
  - [Creación de ScaledObject](#creación-de-scaledobject)
- [Generación de carga y observación del escalado](#generación-de-carga-y-observación-del-escalado)
- [Limpieza de recursos](#limpieza-de-recursos)
- [Conclusión](#conclusión)


## Preparación del entorno

### Inicio del laboratorio
[Iniciar la plataforma mediante docker](https://github.com/ViktorUJ/cks/blob/master/docs%2Frun_from_docker.MD)

Para iniciar el laboratorio, ejecute el comando:

```bash
TASK=03 make run_eks_task
```

**Qué ocurre al ejecutar este comando:**
- Terraform/Terragrunt despliega automáticamente toda la infraestructura necesaria en AWS
- El proceso tarda aproximadamente 15-20 minutos
- La salida del comando mostrará información importante (conexión SSH, nombres de recursos)

### Recursos creados

Al ejecutar el comando se desplegará la siguiente infraestructura de AWS:

#### Infraestructura de red (VPC)
- **VPC** con bloque CIDR `10.10.0.0/16` en la región `eu-central-1`
- **Subredes públicas** para recursos con acceso a Internet (`eks-AZ-1`, `eks-AZ-2`)
- **Subredes privadas** para nodos EKS y RDS
- **NAT Gateway** para tráfico saliente a Internet desde las subredes privadas

#### Clúster EKS
- **EKS Control Plane** versión `1.35`
- **Perfil de Fargate** para pods de sistema (`kube-system`, `karpenter`) — tenga en cuenta que CoreDNS se ejecuta en Fargate
- **Karpenter** versión `1.8.1` (controlador de autoescalado)
- **EKS Add-ons**: coredns, kube-proxy, vpc-cni, eks-pod-identity-agent

#### NodePool de Karpenter preconfigurados
- **`default`** — para cargas de trabajo de la aplicación (consolida nodos vacíos tras 30 s)
- **`monitoring`** — dedicado al stack de monitorización, con taint `dedicated=monitoring:NoSchedule` y label `work_type=monitoring` (consolida tras 300 s)

#### Archivo principal de configuración

Todos los parámetros de infraestructura se definen en el archivo `tasks/eks/labs/03/env.hcl`. Para cambiar la configuración, edite los parámetros correspondientes en este archivo.

### Requisitos previos

Asegúrese de tener:
- **AWS CLI** con los permisos de acceso adecuados
- Límites de nodos aumentados en la región `eu-central-1` (si es necesario)
- Conexión SSH a un nodo worker (consulte la cadena de conexión en la salida de `make run_eks_task`)
- `kubectl`, `helm` y `jq` disponibles en el nodo worker


## Visualización de NodePool

Ya están preparados dos NodePool. Verifiquémoslos:

```bash
kubectl get nodepools.karpenter.sh
```

**Resultado esperado:**
```
NAME         NODECLASS    NODES   READY   AGE
default      default      0       True    2m46s
monitoring   monitoring   0       True    2m43s
```

- **`monitoring`** — para Prometheus, KEDA y metrics-server
- **`default`** — para la aplicación de prueba

Veamos el NodePool `monitoring` con más detalle:

```bash
kubectl get nodepools.karpenter.sh monitoring -o yaml
```

**Partes clave de la especificación:**
```yaml
spec:
  template:
    metadata:
      labels:
        work_type: monitoring        # se utiliza en nodeAffinity
    spec:
      taints:
      - effect: NoSchedule
        key: dedicated
        value: monitoring            # aquí solo llegarán los pods con el toleration adecuado
```

**Qué significa esto:** los pods de monitorización deben tener tanto `nodeAffinity` en `work_type=monitoring` como un `toleration` para `dedicated=monitoring:NoSchedule`. Esto garantiza que el stack de monitorización se ejecute en sus propios nodos y que no llegue allí nada innecesario.


## Instalación del stack de monitorización

### Prometheus Operator y metrics-server

Instalamos **kube-prometheus-stack** (el Prometheus Operator oficial) y **metrics-server** mediante Helm. Grafana está deshabilitado. Todos los componentes se fijan al NodePool `monitoring` mediante `nodeAffinity` + `tolerations`.

> **Nota de seguridad:** el Service de Prometheus que aparece a continuación se publica mediante un LoadBalancer público **sin autenticación**. Esto se hace solo por comodidad para el laboratorio. En producción, Prometheus debe estar protegido (autenticación / proxy OAuth2, restricción por IP mediante Security Groups o NetworkPolicy, Ingress con TLS).

```bash
# Añadimos repositorios de Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# Creamos el archivo values para Prometheus
cat <<'EOF' > prometheus-values.yaml
# ATENCIÓN: LoadBalancer de Prometheus está abierto sin autenticación.
# Esto es solo para el laboratorio. En producción, proteja Prometheus
# con autenticación, restricción por IP (Security Groups / NetworkPolicy) y TLS.

grafana:
  enabled: false

kubeStateMetrics:
  enabled: true

nodeExporter:
  enabled: true

prometheus:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    loadBalancerSourceRanges:
      - "0.0.0.0/0"
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorNamespaceSelector: {}
    serviceMonitorSelector: {}
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: work_type
                  operator: In
                  values:
                    - monitoring
    tolerations:
      - key: dedicated
        value: monitoring
        effect: NoSchedule

prometheusOperator:
  admissionWebhooks:
    patch:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: work_type
                    operator: In
                    values:
                      - monitoring
      tolerations:
        - key: dedicated
          value: monitoring
          effect: NoSchedule
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: work_type
                operator: In
                values:
                  - monitoring
  tolerations:
    - key: dedicated
      value: monitoring
      effect: NoSchedule

alertmanager:
  alertmanagerSpec:
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: work_type
                  operator: In
                  values:
                    - monitoring
    tolerations:
      - key: dedicated
        value: monitoring
        effect: NoSchedule

kube-state-metrics:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: work_type
                operator: In
                values:
                  - monitoring
  tolerations:
    - key: dedicated
      value: monitoring
      effect: NoSchedule

prometheus-node-exporter:
  tolerations:
    - key: dedicated
      value: monitoring
      effect: NoSchedule
EOF

# Creamos el archivo values para metrics-server
cat <<'EOF' > metrics-server-values.yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: work_type
              operator: In
              values:
                - monitoring
tolerations:
  - key: dedicated
    value: monitoring
    effect: NoSchedule
EOF

# Instalamos Prometheus Operator
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f prometheus-values.yaml

# Instalamos metrics-server
helm install metrics-server metrics-server/metrics-server \
  --namespace monitoring \
  -f metrics-server-values.yaml
```

**Explicaciones de values:**
- `serviceMonitorSelectorNilUsesHelmValues: false` + los selectores vacíos permiten a Prometheus detectar ServiceMonitor de **todos** los namespace (necesario para recopilar más tarde las métricas de la aplicación).
- Cada componente declara `nodeAffinity` (`work_type=monitoring`), por lo que se programa **solo** en nodos de monitorización. Un `nodeSelector` por sí solo no es suficiente: affinity garantiza la ubicación.
- `node-exporter` recibe únicamente toleration (debe ejecutarse en cada nodo como DaemonSet).

### Verificación de la instalación

```bash
# Todos los pods de monitorización deben estar Running en los nodos de monitorización
kubectl get pods -n monitoring -o wide

# Los nodos de monitorización deben iniciarse
kubectl get nodes -l work_type=monitoring

# metrics-server debe estar funcionando
kubectl top nodes

# Obtenemos la dirección del LoadBalancer de Prometheus (UI de Prometheus en el puerto 9090)
kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' ; echo
```

Abra `http://<LB-ADDRESS>:9090` en el navegador para acceder a la UI de Prometheus.


## Despliegue de la aplicación

Despliegue la aplicación de prueba (`ping_pong`). El Service publica dos puertos: `http` (80 → 8080) y `metrics` (9090 → 9090).

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/03/worker/files/tasks/1.yaml
```

Compruebe que la aplicación se haya iniciado:

```bash
kubectl get po -n team-19
```

**Resultado esperado:**
```
NAME                     READY   STATUS    RESTARTS   AGE
team19-598dc8484-vlqkd   1/1     Running   0          2m54s
```

Compruebe el NodeClaim: debe haber un nodo independiente para la monitorización y otro para la aplicación:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Resultado esperado:**
```
NAME               TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-n5mxw      t4g.small   spot       eu-central-1a   ip-10-10-15-217.eu-central-1.compute.internal   True    16m
monitoring-rlm6f   t4g.small   spot       eu-central-1a   ip-10-10-15-53.eu-central-1.compute.internal    True    24m
```


## Recopilación de métricas de la aplicación

### Creación de ServiceMonitor

La aplicación exporta métricas de Prometheus en el puerto `9090` en la ruta `/metrics`. El puerto `metrics` ya está definido en el Service de la aplicación, por lo que solo se necesita un ServiceMonitor. El label `release: prometheus` permite que Prometheus Operator lo detecte.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: team19
  namespace: team-19
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: team19
  endpoints:
  - port: metrics
    interval: 15s
    path: /metrics
EOF
```

### Verificación del target

```bash
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# El target debe estar presente y en buen estado (health: up)
curl -s "http://${PROM_URL}:9090/api/v1/targets" \
  | jq '.data.activeTargets[] | select(.labels.namespace=="team-19") | {endpoint: .scrapeUrl, health: .health}'
```

### Verificación de métricas en Prometheus

```bash
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Comprobamos la métrica requests_total
curl -s "http://${PROM_URL}:9090/api/v1/query" \
  --data-urlencode 'query=requests_total{namespace="team-19"}' | jq '.data.result'
```

Si el resultado está vacío `[]`, significa que ServiceMonitor aún no ha sido detectado. Espere un poco y repita, o compruebe el estado del target anterior.

También puede abrir `http://<PROM_URL>:9090` en el navegador e introducir `requests_total` en el campo Expression.

> **Consejo:** el valor de la métrica se devuelve como `"value": [<timestamp>, "<valor>"]`. El primer número es la hora del scrape y el segundo (cadena) es el propio valor. Será `0` mientras no haya tráfico hacia la aplicación.


## Instalación de KEDA

KEDA se ejecuta en los mismos nodos que Prometheus (NodePool `monitoring`). El chart de Helm de KEDA aplica `tolerations` y `affinity` de nivel superior a **todos** sus componentes (operator, metrics apiserver, webhooks).

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

cat <<'EOF' > keda-values.yaml
# Tolerations y affinity globales para todos los componentes de KEDA
tolerations:
  - key: dedicated
    value: monitoring
    effect: NoSchedule

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: work_type
              operator: In
              values:
                - monitoring
EOF

helm install keda kedacore/keda \
  --namespace monitoring \
  -f keda-values.yaml
```

### Verificación de KEDA

```bash
# Los pods de KEDA deben estar Running en los nodos de monitorización
kubectl get pods -n monitoring -l app.kubernetes.io/instance=keda -o wide

# Los CRD de KEDA deben estar instalados
kubectl get crd | grep keda
```

> **Nota:** `metrics-apiserver` de KEDA es un componente interno de KEDA (proporciona métricas externas para Kubernetes HPA). Esto **no** es lo mismo que el `metrics-server` del clúster instalado antes: se necesitan ambos.


## Configuración del autoescalado

### Métricas disponibles de la aplicación

La aplicación `ping_pong` exporta las siguientes métricas de Prometheus (puerto 9090, ruta `/metrics`):

| Métrica | Tipo | Descripción |
|---------|-----|----------|
| `requests_total` | Counter | Número total de solicitudes |
| `requests_per_second` | Gauge | RPS instantáneo (ruidoso, no se restablece a 0 en inactividad) |
| `requests_per_minute` | Gauge | RPM instantáneo |
| `goroutines` | Gauge | Número actual de goroutines |

Para el escalado usamos **`rate(requests_total[1m])`**, no el gauge sin procesar `requests_per_second`. `rate()` basado en un contador proporciona un RPS suavizado real, que crece linealmente con la carga y cae honestamente a 0 cuando se detiene el tráfico; gracias a ello, es fácil elegir el umbral.

### Creación de ScaledObject

Regla: réplicas = `ceil(sum(rate(requests_total[1m])) / threshold)`. Se configura una reducción rápida mediante `behavior`, para que los pods se eliminen rápidamente tras la caída de carga.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: team19-scaledobject
  namespace: team-19
spec:
  scaleTargetRef:
    name: team19
  minReplicaCount: 1
  maxReplicaCount: 10
  pollingInterval: 10
  cooldownPeriod: 10
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          # Reducción rápida: ventana de estabilización de 10 s, se puede eliminar hasta el 100% de los pods
          stabilizationWindowSeconds: 10
          policies:
          - type: Percent
            value: 100
            periodSeconds: 10
        scaleUp:
          stabilizationWindowSeconds: 0
          policies:
          - type: Percent
            value: 100
            periodSeconds: 10
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
      # rate(requests_total[1m]) -> RPS real desde el contador; sum en todos los pods.
      # réplicas = ceil(sum(rate) / threshold)
      query: sum(rate(requests_total{namespace="team-19", service="team19"}[1m]))
      threshold: "10"
      activationThreshold: "3"
EOF
```

**Explicaciones:**
- `threshold` — RPS objetivo **por pod** que el HPA intenta mantener.
- `activationThreshold: 3` significa que KEDA mantiene una réplica mientras el RPS total no supere 3, lo que evita oscilaciones en inactividad.
- La `query` usa `sum(...)` (RPS total, independiente del número de réplicas), por lo que el número deseado de réplicas es estable. El uso de `avg(...)` aquí provocaría oscilaciones al añadir pods.

Compruebe el ScaledObject y el HPA creado por este:

```bash
kubectl get scaledobject -n team-19
kubectl get hpa -n team-19
```


## Generación de carga y observación del escalado

Inicie un pod que genere carga en el Service de la aplicación. El bucle interno envía N solicitudes y el `sleep 1` externo establece el ritmo; por ello, el número en `seq 1 N` equivale aproximadamente al RPS objetivo.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: traffic-generator
  namespace: team-19
spec:
  containers:
  - name: loader
    image: busybox
    command:
    - /bin/sh
    - -c
    - |
      echo "Starting traffic generation..."
      while true; do
        for i in $(seq 1 50); do
          wget -q -O /dev/null http://team19.team-19.svc.cluster.local:80/ &
        done
        sleep 1
      done
EOF
```

### Observación del escalado

Un único `watch` muestra inmediatamente los pods, HPA y RPS por pod desde Prometheus. La consulta PromQL se codifica como URL (`--data-urlencode`); de lo contrario, los símbolos `{`, `}` y `=` rompen el parser.

```bash
export PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

watch 'kubectl get pods -n team-19 ; echo ; kubectl get hpa -n team-19 ; echo ; echo -n "rps per pod = " ; curl -s "http://${PROM_URL}:9090/api/v1/query" --data-urlencode "query=sum(rate(requests_total{namespace=\"team-19\", service=\"team19\"}[1m])) / count(up{namespace=\"team-19\", service=\"team19\"})" | jq -r ".data.result[0].value[1]"'
```

**Lo que debe ver:** a medida que aumenta la carga, el número de pods tiende a `ceil(rps_total / threshold)`. La columna `TARGETS` del HPA (RPS por pod) coincide con `rps per pod`, que muestra watch.

> **Consejo para el ajuste:** pods ≈ (número en `seq 1 N`) / threshold. Con `seq 1 50` y `threshold: 10` se obtendrán unos 5 pods. Aumente el número para obtener más pods.

### Detención de la carga

```bash
kubectl delete pod traffic-generator -n team-19
```

Tras detener el tráfico, `rate(requests_total[1m])` cae a 0. Durante `cooldownPeriod` (10 s) más la ventana de estabilización de reducción (10 s), KEDA vuelve a escalar hasta `minReplicaCount: 1`.


## Limpieza de recursos

### Eliminación de la aplicación

```bash
# Eliminamos ScaledObject (KEDA dejará de gestionar el HPA)
kubectl delete scaledobject team19-scaledobject -n team-19

# Eliminamos el generador de tráfico (si todavía se está ejecutando)
kubectl delete pod traffic-generator -n team-19 --ignore-not-found

# Eliminamos ServiceMonitor
kubectl delete servicemonitor team19 -n team-19 --ignore-not-found

# Eliminamos la propia aplicación (deployment, service, namespace)
kubectl delete -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/03/worker/files/tasks/1.yaml
```

### Eliminación de Prometheus (importante: elimina LoadBalancer)

La eliminación de la release de Helm elimina el Service de tipo LoadBalancer y AWS libera el ELB.

```bash
# Eliminamos prometheus (esto eliminará el Service LoadBalancer -> AWS ELB)
helm uninstall prometheus -n monitoring

# Eliminamos metrics-server y keda
helm uninstall metrics-server -n monitoring
helm uninstall keda -n monitoring
```

Comprobamos que LoadBalancer (ELB) se haya eliminado realmente:

```bash
# El Service prometheus no debe existir
kubectl get svc -n monitoring | grep prometheus

# Confirmamos en AWS que el ELB se ha eliminado
aws elb describe-load-balancers --region eu-central-1 \
  --query "LoadBalancerDescriptions[].DNSName"
```

Si por alguna razón el Service permanece y bloquea la eliminación del ELB, elimínelo manualmente:

```bash
kubectl delete svc prometheus-kube-prometheus-prometheus -n monitoring --ignore-not-found
```

A continuación, elimine el namespace:

```bash
kubectl delete namespace monitoring
```

> **Importante:** elimine siempre el Service de tipo LoadBalancer **antes de** eliminar los nodos o el clúster.
> Si primero elimina los nodos/el clúster, el AWS ELB puede quedar "colgado" como un recurso huérfano,
> y tendrá que eliminarlo manualmente mediante la consola o CLI.

### Verificación de que Karpenter eliminó todos los nodos

Después de eliminar todas las cargas de trabajo, los nodos `default` y `monitoring` quedan vacíos, y Karpenter debe consolidarlos (eliminarlos).

```bash
# Observamos cómo el número de nodeclaims disminuye hasta cero
watch kubectl get nodeclaims.karpenter.sh
```

Karpenter elimina los nodos vacíos según el `consolidateAfter` de cada NodePool
(`default` = 30 s, `monitoring` = 300 s), por lo que los nodos de monitorización tardan más en eliminarse.

Espere hasta que ambos comandos devuelvan un resultado vacío:

```bash
kubectl get nodeclaims.karpenter.sh
kubectl get nodes -l work_type
```

Si un nodo no se elimina, compruebe los pods que impiden la consolidación (por ejemplo, pods sin controlador o con `karpenter.sh/do-not-disrupt`):

```bash
kubectl get pods -A -o wide --field-selector spec.nodeName=<имя-ноды>
```

### Eliminación de la infraestructura

Solo después de que Karpenter haya eliminado todos los nodos, elimine la infraestructura del laboratorio:

```bash
TASK=03 make delete_eks_task
```

Introduzca `y` para confirmar. La eliminación tarda aproximadamente 10-15 minutos.

> Eliminar la infraestructura antes de que Karpenter elimine sus nodos puede dejar instancias EC2 huérfanas.


## Conclusión

¡Felicidades! Ha creado un sistema de autoescalado event-driven en EKS.

**Lo que hizo:**

1. **Stack de monitorización** — instaló el Prometheus Operator oficial y metrics-server, fijándolos a nodos dedicados mediante nodeAffinity y tolerations
2. **Publicación** — publicó Prometheus mediante LoadBalancer para un acceso rápido (solo para el laboratorio, sin autenticación)
3. **Métricas personalizadas** — recopiló las propias métricas de solicitudes de la aplicación mediante ServiceMonitor
4. **KEDA** — instaló KEDA y configuró un ScaledObject basado en una consulta a Prometheus
5. **Autoescalado** — escaló la aplicación según el RPS real mediante `rate(requests_total[1m])` con reducción rápida
6. **Limpieza** — eliminó correctamente LoadBalancer y permitió que Karpenter liberara los nodos antes de eliminar la infraestructura

**Conclusiones clave:**

- Utilice `rate()` basado en un contador para un autoescalado estable y predecible en lugar de gauges instantáneos ruidosos
- Utilice `sum(...)` (y no `avg(...)`) en la consulta del escalador para que el número deseado de réplicas no oscile al añadir pods
- Fije las cargas de trabajo de infraestructura a nodos dedicados mediante nodeAffinity **y** tolerations
- Elimine siempre el Service de tipo LoadBalancer antes de eliminar el clúster para evitar ELB huérfanos

**Recursos adicionales:**
- [Documentación de KEDA](https://keda.sh/docs/)
- [Prometheus scaler en KEDA](https://keda.sh/docs/latest/scalers/prometheus/)
- [Chart kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Documentación de Karpenter](https://karpenter.sh/docs/)
