[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 124 - solución de referencia (HPA, KEDA, Prometheus)

Todos los comandos se ejecutan en la máquina de trabajo (worker) por SSH. kubectl y helm ya
están configurados (el kubeconfig se genera mediante `aws eks update-kubeconfig` al
arrancar la máquina).

## Tarea 1. Namespace `eks-124`

```bash
kubectl create namespace eks-124
```

## Tarea 2. kube-prometheus-stack en el namespace `monitoring`

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.enabled=false \
  --set alertmanager.enabled=false \
  --set prometheus.prometheusSpec.resources.requests.cpu=200m \
  --set prometheus.prometheusSpec.resources.requests.memory=512Mi
```

Estos tres flags no son cosméticos. El laboratorio no necesita Grafana ni Alertmanager, y
Grafana es el pod más pesado del chart (aproximadamente 325 MiB en el banco de pruebas).
Los `requests` explícitos mueven a Prometheus de `BestEffort` a `Burstable`: tanto el
scheduler como Karpenter, que dimensiona el nodo según la suma de `requests`, pueden ver
sus necesidades. Sin esto, el stack de monitorización acaba en la instancia más barata, y
kubelet expulsa a Prometheus bajo presión de memoria - ver el análisis detallado en el
README del laboratorio.

Espera a que los pods estén listos:

```bash
kubectl get pods -n monitoring -w
```

Espera hasta que todos los pods lleguen a `Running` y `1/1` (o `2/2`) Ready - esto
normalmente tarda 2-3 minutos. Comprueba el Service que KEDA va a vigilar, y la clase QoS
del pod:

```bash
kubectl get svc -n monitoring kube-prometheus-stack-prometheus
kubectl get pod -n monitoring prometheus-kube-prometheus-stack-prometheus-0 \
  -o jsonpath='{.status.qosClass}{"\n"}'
```

La salida esperada del segundo comando es `Burstable`.

## Tarea 3. KEDA en el namespace `keda`

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm install keda kedacore/keda --namespace keda --create-namespace
```

Comprueba que el operator y el metrics apiserver están levantados:

```bash
kubectl get pods -n keda
```

Resultado esperado: pods con nombres del tipo `keda-operator-...` y
`keda-operator-metrics-apiserver-...` en estado `Running`.

## Tarea 4. Deployment `demo-app`

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: eks-124
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "200m"
            memory: "128Mi"
EOF

kubectl rollout status deployment/demo-app -n eks-124
```

## Tarea 5. ScaledObject con el scaler `prometheus`

La métrica de cAdvisor `container_cpu_usage_seconds_total` la recoge kube-prometheus-stack
de todos los pods de fábrica, sin necesidad de ServiceMonitor. Calculamos el uso total de
CPU de los pods del GENERADOR de carga de la tarea 6, no de `demo-app` en sí: la aplicación
escala según una carga ajena, y un HPA normal basado en CPU no puede hacer esto - las
métricas externas existen precisamente para esto.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: demo-app
  namespace: eks-124
spec:
  scaleTargetRef:
    name: demo-app
  minReplicaCount: 1
  maxReplicaCount: 5
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://kube-prometheus-stack-prometheus.monitoring.svc:9090
      query: sum(rate(container_cpu_usage_seconds_total{namespace="eks-124", pod=~"stress-generator.*"}[1m]))
      threshold: "0.1"
EOF
```

Puedes comprobar que la consulta realmente devuelve algo directamente desde el clúster
(mientras no haya generador, la respuesta estará vacía, y eso es normal - en ese caso KEDA
reporta cero al HPA):

```bash
kubectl run promq --rm -i --restart=Never -n default --image=curlimages/curl -- \
  -sG --data-urlencode \
  'query=sum(rate(container_cpu_usage_seconds_total{namespace="eks-124",pod=~"stress-generator.*"}[1m]))' \
  http://kube-prometheus-stack-prometheus.monitoring.svc:9090/api/v1/query
```

Comprueba que KEDA tomó el ScaledObject bajo su gestión y creó el HPA:

```bash
kubectl get scaledobject demo-app -n eks-124
kubectl get hpa -A | grep keda-hpa
kubectl get hpa keda-hpa-demo-app -n eks-124
```

El HPA se llama `keda-hpa-demo-app` - esta es la prueba de que KEDA no sustituye a HPA, sino
que crea y gestiona un `HorizontalPodAutoscaler` normal por debajo.

## Tarea 6. Prueba de carga: escalado hacia arriba

Primero registramos el estado antes de la carga:

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/6/hpa_before.txt
cat /var/work/tests/artifacts/6/hpa_before.txt
```

Creamos el generador de carga. Tiene su propia label (`app=stress-generator`) - la consulta
PromQL de la tarea 5 selecciona pods por NOMBRE, no por label, así que mezclar el generador
en el selector de `demo-app` es innecesario y perjudicial: dos Deployments con selectores
superpuestos son un antipatrón. `limits.cpu` es obligatorio, de lo contrario los cuatro
workers de CPU le quitan procesador a kubelet y el nodo se va a `NotReady`. `nodeSelector`
es necesario porque `polinux/stress` solo está construido para `amd64`, mientras que el
NodePool del laboratorio también permite `arm64`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stress-generator
  namespace: eks-124
spec:
  replicas: 2
  selector:
    matchLabels:
      app: stress-generator
  template:
    metadata:
      labels:
        app: stress-generator
    spec:
      nodeSelector:
        kubernetes.io/arch: amd64
      containers:
      - name: stress
        image: polinux/stress
        command: ["stress"]
        args: ["--cpu", "2"]
        resources:
          requests:
            cpu: "200m"
          limits:
            cpu: "500m"
EOF
```

Observamos cómo crece la métrica y el número de réplicas:

```bash
watch kubectl get hpa keda-hpa-demo-app -n eks-124
```

Esperamos 1-2 minutos (KEDA consulta Prometheus, HPA calcula las réplicas, Karpenter añade
un nodo si es necesario). En el banco de pruebas se veía así:

```
06:36:41 replicas=1 0/100m (avg)
06:37:04 replicas=1 1251m/100m (avg)
06:37:26 replicas=4 382m/100m (avg)
```

En cuanto `REPLICAS` sea mayor que `1`, guardamos:

```bash
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/6/hpa_after.txt
cat /var/work/tests/artifacts/6/hpa_after.txt
```

## Tarea 7. Retirada de la carga: escalado hacia abajo

```bash
kubectl delete deployment stress-generator -n eks-124
```

Los pods del generador desaparecen, sus series en Prometheus ya no existen, KEDA reporta
cero al HPA. El valor de `TARGETS` se anula en unos 30 segundos, pero las réplicas se
mantienen: `stabilizationWindowSeconds` para scaleDown en HPA es 300 segundos por defecto.
Una medición del banco de pruebas - métrica en cero a las 06:40:07, réplicas `5 -> 2 -> 1`
a las 06:44:40 y 06:45:07:

```bash
watch kubectl get hpa keda-hpa-demo-app -n eks-124
```

En cuanto `REPLICAS` vuelva a `1`, guardamos el artefacto:

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/7/hpa_after_cooldown.txt
cat /var/work/tests/artifacts/7/hpa_after_cooldown.txt
```

## Tarea 8. HPA normal frente a HPA creado por KEDA

```bash
kubectl get hpa -A
```

En la salida, el HPA `keda-hpa-demo-app` se ve idéntico por columnas a un HPA normal - los
mismos `TARGETS`, `MINPODS`, `MAXPODS`, `REPLICAS`. La única diferencia es el nombre
(prefijo `keda-hpa-`) y quién lo controla: un ingeniero crea y edita un HPA normal
directamente mediante un manifiesto `HorizontalPodAutoscaler`, mientras que
`keda-hpa-demo-app` es creado y controlado por el KEDA operator
a partir del recurso `ScaledObject` - elimina el `ScaledObject`, y KEDA elimina este HPA
junto con él.

Guardamos la explicación en el artefacto:

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/hpa_compare.txt <<'EOF'
En kubectl get hpa -A, un HPA normal y el HPA keda-hpa-demo-app se ven idénticos por
columnas: TARGETS/MINPODS/MAXPODS/REPLICAS - la única diferencia es el nombre y el
origen del objeto.

KEDA no reemplaza a HPA: el operator de KEDA vigila el ScaledObject y él mismo crea y
controla (control) un HorizontalPodAutoscaler normal llamado keda-hpa-<nombre del
ScaledObject>, mientras que el metrics adapter de KEDA le suministra el valor de la
métrica a través de external.metrics.k8s.io. Las réplicas las sigue calculando el mismo
mecanismo de HPA de siempre.
EOF
cat /var/work/tests/artifacts/8/hpa_compare.txt
```

## Verificación rápida

```bash
check_result
```
