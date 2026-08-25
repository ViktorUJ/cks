[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 15 - Solución de referencia

Versión de Istio utilizada: `1.29.1` (`istioctl` está preinstalado en el PC del trabajador).

## Objetivo

Instala Istio con una configuración **personalizada** mediante un manifiesto `IstioOperator`:
- comienza con el perfil `default`;
- configura dos opciones de `meshConfig`:
  - `accessLogFile: /dev/stdout` (registros de acceso de Envoy en stdout),
  - `outboundTrafficPolicy.mode: REGISTRY_ONLY` (bloquea la salida a hosts desconocidos);
- añade un **segundo** componente de gateway de entrada `ingressgateway-internal` junto al
  `istio-ingressgateway` predeterminado.

## Paso 1. Escribe el manifiesto IstioOperator

```bash
cat > custom-istio.yaml <<'EOF'
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: custom-istio
spec:
  profile: default
  meshConfig:
    accessLogFile: /dev/stdout
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY
  components:
    ingressGateways:
      - name: istio-ingressgateway
        enabled: true
      - name: ingressgateway-internal
        enabled: true
        label:
          istio: ingressgateway-internal
        k8s:
          service:
            type: ClusterIP
EOF
```

## Paso 2. Instala Istio con el manifiesto personalizado

```bash
istioctl install -f custom-istio.yaml -y
```

## Paso 3. Verifica la instalación

```bash
# control plane
kubectl get pods -n istio-system

# both ingress gateways
kubectl get deploy -n istio-system | grep -E 'ingressgateway'

# meshConfig landed in the istio configmap
kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}' | grep -E 'accessLogFile|outboundTrafficPolicy|REGISTRY_ONLY'
```

Resultado esperado:
- `istiod` está `Running`;
- los despliegues `istio-ingressgateway` e `ingressgateway-internal` están ambos listos;
- el configmap `istio` contiene `accessLogFile: /dev/stdout` y
  `outboundTrafficPolicy.mode: REGISTRY_ONLY`.

## (opcional) Paso 4. Observa REGISTRY_ONLY en acción

```bash
kubectl create namespace demo
kubectl label namespace demo istio-injection=enabled
kubectl -n demo run curl --image=curlimages/curl -it --rm --restart=Never -- \
  sh -c 'curl -sS -o /dev/null -w "%{http_code}\n" http://httpbin.org/get'
# -> 502 : egress is blocked because the host is not in the mesh registry
```

Con `outboundTrafficPolicy: REGISTRY_ONLY`, las llamadas a hosts externos que no están
declarados mediante un `ServiceEntry` se rechazan. Para permitir dicho tráfico, añadirías un
`ServiceEntry` (consulta el Laboratorio 05).
