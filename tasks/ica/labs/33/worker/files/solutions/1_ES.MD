[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 33 - Solución de referencia

Istio `1.29.1` (perfil predeterminado, descubrimiento de todo el clúster, sin ámbito de Sidecar) y OPA
Gatekeeper están preinstalados. Existen tres espacios de nombres:

- `app` (inyectado, `mesh=enabled`) - `frontend`;
- `shop` (inyectado, `mesh=enabled`) - `catalog` + un `probe` sin sidecar;
- `legacy` (NO inyectado, sin etiqueta `mesh`) - `legacy-app`.

`istioctl` está disponible en el PC del trabajador.

## Objetivo

1. Habilita los **selectores de descubrimiento** para que istiod solo supervise los espacios de nombres con `mesh=enabled`
   (descarta `legacy`).
2. Añade un ámbito de salida de **Sidecar** en `app` para que sus proxies solo conozcan `app` + `istio-system`
   (descarta `shop`).
3. Observa las **señales de referencia** de istiod.
4. Aplica una política de despliegue con **OPA Gatekeeper**.

## Paso 1. Selectores de descubrimiento

Vuelve a aplicar la instalación con `meshConfig.discoverySelectors` que coincida con `mesh=enabled`
(`istio-system`, `app`, `shop` la tienen; `legacy` no):

```bash
cat <<EOF > /tmp/iop.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  meshConfig:
    discoverySelectors:
      - matchLabels:
          mesh: enabled
EOF
istioctl install -f /tmp/iop.yaml -y
```

Verifica que `legacy` desaparece de la malla (desde un proxy que aún no tiene ámbito de Sidecar):

```bash
istioctl proxy-config clusters deploy/catalog.shop | grep legacy-app || echo "legacy dropped"
```

## Paso 2. Ámbito de salida de Sidecar en app

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: app
spec:
  egress:
    - hosts:
        - "./*"
        - "istio-system/*"
EOF
```

`./*` = el propio espacio de nombres del proxy (`app`), más `istio-system/*` para el plano de control y
las gateways. Todo lo demás (incluido `shop`) se elimina de los proxies de `app`:

```bash
istioctl proxy-config clusters deploy/frontend.app | grep catalog.shop || echo "shop dropped from app"
```

## Paso 3. Señales de referencia de istiod

```bash
# convergence time + push count (the key control-plane signals)
kubectl exec -n shop deploy/probe -c probe -- \
  curl -s http://istiod.istio-system:15014/metrics \
  | grep -E 'pilot_proxy_convergence_time|pilot_xds_pushes'

# how many proxies are connected / config sync state
istioctl proxy-status
```

`pilot_proxy_convergence_time` es la señal principal: cuánto tarda un cambio en llegar a los
proxies. `pilot_xds_pushes` cuenta los envíos. Un tiempo de convergencia creciente o errores de envío indica que
el plano de control está bajo presión; las palancas de ámbito de los pasos 1-2 son las que lo reducen.

## Paso 4. Política de despliegue de OPA Gatekeeper

Exige que cada espacio de nombres declare la etiqueta de inyección (una política clásica de higiene de despliegue
procedente del capítulo). Crea la plantilla y la restricción:

```bash
kubectl apply -f - <<'EOF'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("namespace is missing required labels: %v", [missing])
        }
EOF

kubectl apply -f - <<'EOF'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: ns-must-have-injection
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Namespace"]
  parameters:
    labels: ["istio-injection"]
EOF
```

Verifica que la política se aplica (debería ser **denegada**):

```bash
kubectl create ns test-no-label
# Error ... admission webhook "validation.gatekeeper.sh" denied the request:
# namespace is missing required labels: {"istio-injection"}
```

## Por qué funciona esto

- Los **selectores de descubrimiento** limitan qué espacios de nombres supervisa istiod. Los espacios de nombres sin
  la etiqueta del selector son invisibles para el plano de control; sus servicios nunca se convierten en
  clústeres/endpoints en ningún proxy, lo que reduce el tamaño de configuración y el trabajo de envío. La mayor ventaja se da cuando
  parte del clúster no está en la malla.
- El **ámbito de salida de Sidecar** limita, por espacio de nombres, sobre qué servicios se informa a un proxy.
  Con `./*` + `istio-system/*`, un proxy de `app` ya no lleva configuración para `shop` (ni para el
  resto de la malla). Esto reduce la configuración de cada proxy y la distribución de envíos desde istiod.
- Las **señales de referencia** (`pilot_proxy_convergence_time`, `pilot_xds_pushes`, proxies conectados,
  CPU/mem de istiod) muestran si el plano de control puede seguir el ritmo; las palancas de ámbito son las
  principales herramientas para reducir el tiempo de convergencia.
- **OPA Gatekeeper** convierte las prácticas recomendadas en reglas de admisión: los recursos no conformes se
  rechazan al crearse, no simplemente se desaconsejan.
