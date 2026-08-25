[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 18 - Solución de referencia

Istio `1.29.1` está instalado (gateway de entrada en NodePort `32080`) con el rastreo
distribuido conectado al proveedor de extensión `zipkin` (`zipkin.istio-system:9411`). El
complemento **Jaeger** está desplegado como backend de rastreo. La aplicación `ping-pong` está desplegada en
el espacio de nombres `app` y expuesta en `http://myapp.local:32080/`. El registro de acceso está
**deshabilitado** de forma predeterminada y todavía no existe ningún recurso `Telemetry`.

## Objetivo

Usa la **API de Telemetry** para:
- habilitar el registro de acceso de Envoy para el espacio de nombres `app` (proveedor integrado `envoy`);
- habilitar el rastreo mediante el proveedor `zipkin` con muestreo al 100% para que los rastreos se
  recopilen realmente en Jaeger.

## Paso 1. Confirma que los registros de acceso están DESACTIVADOS

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
curl -s -o /dev/null http://myapp.local:32080/
kubectl logs -n app "$POD" -c istio-proxy --tail=50   # no access log lines
```

## Paso 2. Configura registros y rastreos mediante Telemetry

```bash
cat > telemetry.yaml <<'EOF'
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: app-telemetry
  namespace: app
spec:
  accessLogging:
    - providers:
        - name: envoy
  tracing:
    - providers:
        - name: zipkin
      randomSamplingPercentage: 100.0
EOF

kubectl apply -f telemetry.yaml
```

## Paso 3. Genera tráfico

```bash
for i in $(seq 30); do curl -s -o /dev/null http://myapp.local:32080/; done
```

## Paso 4. Verifica la recopilación

Registros de acceso (en stdout del sidecar):

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n app "$POD" -c istio-proxy --tail=50 | grep 'GET / HTTP'
```

Rastreos (en Jaeger, consultado desde dentro del clúster):

```bash
kubectl exec -n app deploy/curl-client -- \
  curl -s 'http://tracing.istio-system:80/jaeger/api/services' | tr ',' '\n' | grep ping-pong
```

También puedes realizar un reenvío de puerto de la interfaz de Jaeger:

```bash
kubectl -n istio-system port-forward svc/tracing 16686:80
# open http://localhost:16686/jaeger and pick the ping-pong service
```

## Dónde van los registros y los rastreos

| Señal | Proveedor | Destino |
|---|---|---|
| Registros de acceso | `envoy` (integrado) | stdout del sidecar → `kubectl logs -c istio-proxy` |
| Rastreos | proveedor de extensión `zipkin` | Jaeger (`zipkin.istio-system:9411`) → interfaz de Jaeger |

## Cómo funciona

- La **API de Telemetry** (`telemetry.istio.io`) configura declarativamente registros, métricas
y rastreos, y admite una jerarquía de ámbito: todo el mesh (espacio de nombres raíz) → espacio de nombres →
carga de trabajo (`selector`).
- **`accessLogging.providers.name: envoy`** escribe registros de acceso en stdout del sidecar.
- **`tracing.providers.name: zipkin`** dirige los spans al proveedor de extensión `zipkin`
declarado en `meshConfig.extensionProviders`, que los reenvía a Jaeger.
  Sin una referencia de proveedor, la política de muestreo no tendría dónde enviar los spans.
- **`randomSamplingPercentage: 100`** rastrea cada solicitud (usa un valor bajo en
  producción para controlar la sobrecarga).
