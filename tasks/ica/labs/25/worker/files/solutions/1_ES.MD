[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 25: solución de referencia

Istio `1.29.1` y Prometheus están instalados. **Flagger** se ejecuta en `istio-system`. El espacio de nombres
`test` (istio-injection) contiene la aplicación de demostración **podinfo** (`6.0.0`), un
**flagger-loadtester** (genera tráfico durante el análisis), y existe un `public-gateway`
en `istio-system`.

## Objetivo

Crea un recurso `Canary` para que Flagger controle la **entrega progresiva**: con cada
nueva imagen, desplaza gradualmente el tráfico al canary, comprueba las métricas y realiza
la promoción automática (o la reversión automática si falla).

## Paso 1. Crear el Canary

```bash
kubectl apply -f - <<'EOF'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: test
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  progressDeadlineSeconds: 300
  autoscalerRef:
    apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    name: podinfo
  service:
    port: 9898
    targetPort: 9898
    gateways:
    - istio-system/public-gateway
    hosts:
    - app.example.com
  analysis:
    interval: 30s
    threshold: 5
    maxWeight: 50
    stepWeight: 20
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 30s
    webhooks:
    - name: load-test
      url: http://flagger-loadtester.test/
      timeout: 5s
      metadata:
        cmd: "hey -z 2m -q 10 -c 2 http://podinfo-canary.test:9898/"
EOF
```

## Paso 2. Esperar a que Flagger se inicialice

```bash
kubectl -n test get canary podinfo -w   # wait until STATUS = Initialized
kubectl -n test get deploy
# Flagger created: podinfo-primary, services podinfo/podinfo-canary/podinfo-primary,
# destinationrules and a virtualservice.
```

## Paso 3. Activar una versión canary

```bash
kubectl -n test set image deployment/podinfo podinfod=ghcr.io/stefanprodan/podinfo:6.0.1
```

Flagger detecta la nueva revisión e inicia el análisis: desplaza el 20% → 40% → 50% del
tráfico al canary, comprobando `request-success-rate` y `request-duration` en cada
intervalo. El loadtester sigue enviando tráfico para que existan métricas.

## Paso 4. Observar la promoción

```bash
kubectl -n test describe canary/podinfo
# ... Advance podinfo.test canary weight 20/40/50
# ... Copying podinfo.test template spec to podinfo-primary.test
# ... Promotion completed!

kubectl -n test get canary podinfo         # STATUS = Succeeded
kubectl -n test get deploy podinfo-primary -o jsonpath='{.spec.template.spec.containers[*].image}'
# -> ghcr.io/stefanprodan/podinfo:6.0.1
```

La promoción tarda aproximadamente de 2 a 3 minutos con la configuración anterior. Ejecuta `check_result` después de
que `podinfo-primary` se haya actualizado a `6.0.1`.

## Reversión automática (opcional)

Activa otra versión e inyecta fallos durante el análisis:

```bash
kubectl -n test set image deployment/podinfo podinfod=ghcr.io/stefanprodan/podinfo:6.0.2
POD=$(kubectl -n test get pod -l app=flagger-loadtester -o jsonpath='{.items[0].metadata.name}')
kubectl -n test exec -it "$POD" -- hey -z 1m -c 5 -q 10 http://podinfo-canary.test:9898/status/500
```

Cuando las comprobaciones de métricas fallidas alcanzan el umbral, Flagger se detiene y revierte: el tráfico
vuelve al primary, el canary se escala a cero y STATUS pasa a ser `Failed`.

## Cómo funciona

- Flagger observa el `Deployment` objetivo. Ante un cambio de especificación, crea o actualiza un
  despliegue **canary** y desplaza progresivamente el tráfico mediante los pesos de
  `VirtualService`/`DestinationRule` de Istio.
- En cada paso consulta **Prometheus** para las métricas configuradas; si se mantienen dentro
  de los umbrales, avanza; de lo contrario, revierte tras `threshold` fallos.
- `podinfo-primary` siempre mantiene la versión "conocida como buena"; el tráfico en producción lo sirve el
  primary hasta que el canary se aprueba por completo y se promociona.
- Esto convierte un canary manual arriesgado (cambio de tráfico del Laboratorio 06) en una versión automatizada,
  controlada por métricas y con reversión integrada: la esencia de la entrega progresiva.
