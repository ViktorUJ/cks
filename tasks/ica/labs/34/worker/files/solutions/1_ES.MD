[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 34 - Solución de referencia

Istio `1.29.1` (perfil predeterminado, mTLS PERMISSIVE, salida `ALLOW_ANY`, sin authz) y OPA
Gatekeeper están preinstalados. El espacio de nombres `app` (inyectado) tiene `frontend` más dos
clientes curl, `good` (SA `good`) y `bad` (SA `bad`), y la SA `mesh-editor`; el espacio de nombres
`legacy` (no inyectado) tiene un cliente curl `legacy` sin sidecar. `istioctl` está en el PC del
worker.

## Objetivo (defensa en profundidad)

1. mTLS **STRICT** en toda la malla.
2. Autorización de **denegación predeterminada** + una autorización dirigida para `good`.
3. **Control de salida**: `REGISTRY_ONLY`.
4. **RBAC en CRD de Istio**: permitir la configuración de Istio, pero prohibir `EnvoyFilter`.
5. **OPA Gatekeeper**: rechazar `PeerAuthentication` con `mode: DISABLE`.
6. **Resiliencia ante omisión del sidecar**: NetworkPolicy como capa L3/L4 independiente.

## Paso 1. mTLS STRICT (en toda la malla)

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system      # root namespace -> mesh-wide
spec:
  mtls:
    mode: STRICT
EOF
```

Ahora el cliente `legacy` sin sidecar (texto sin cifrar) ya no puede acceder a `frontend`:

```bash
kubectl exec -n legacy deploy/legacy -c curl -- \
  curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 http://frontend.app.svc.cluster.local:8080/
# connection reset / 000
```

## Paso 2. Denegación predeterminada + autorización dirigida

```bash
# default-deny for the whole app namespace (empty spec)
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: app
spec: {}
EOF

# allow only the "good" identity to call frontend
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-good
  namespace: app
spec:
  selector:
    matchLabels:
      app: frontend
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/app/sa/good"]
EOF
```

```bash
kubectl exec -n app deploy/good -c curl -- curl -s -o /dev/null -w '%{http_code}\n' http://frontend.app.svc.cluster.local:8080/   # 200
kubectl exec -n app deploy/bad  -c curl -- curl -s -o /dev/null -w '%{http_code}\n' http://frontend.app.svc.cluster.local:8080/   # 403
```

## Paso 3. Control de salida: REGISTRY_ONLY

```bash
cat <<EOF > /tmp/iop.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  meshConfig:
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY
EOF
istioctl install -f /tmp/iop.yaml -y

# external host that is not in the registry is now blocked
kubectl exec -n app deploy/good -c curl -- \
  curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 http://www.example.com/   # 502 (blocked)
```

(Para permitir un host externo específico, añadirías un `ServiceEntry`, consulta el laboratorio 05.)

## Paso 4. RBAC en CRD de Istio (prohibir EnvoyFilter)

`EnvoyFilter` es el CRD de Istio más peligroso: inyecta configuración de Envoy sin procesar. Otorga
la gestión de configuración de Istio a `mesh-editor`, pero **excluye** `envoyfilters`:

```bash
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: mesh-editor
  namespace: app
rules:
  - apiGroups: ["networking.istio.io"]
    resources: ["virtualservices","destinationrules","gateways","serviceentries","sidecars","workloadentries"]
    verbs: ["get","list","watch","create","update","patch","delete"]
  - apiGroups: ["security.istio.io"]
    resources: ["authorizationpolicies","requestauthentications"]
    verbs: ["get","list","watch","create","update","patch","delete"]
  # envoyfilters intentionally NOT granted
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: mesh-editor
  namespace: app
roleRef:
  kind: Role
  name: mesh-editor
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: mesh-editor
    namespace: app
EOF
```

```bash
kubectl auth can-i create virtualservices.networking.istio.io --as=system:serviceaccount:app:mesh-editor -n app   # yes
kubectl auth can-i create envoyfilters.networking.istio.io     --as=system:serviceaccount:app:mesh-editor -n app   # no
```

## Paso 5. OPA Gatekeeper: prohibir la desactivación de mTLS

```bash
kubectl apply -f - <<'EOF'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sdenymtlsdisable
spec:
  crd:
    spec:
      names:
        kind: K8sDenyMtlsDisable
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sdenymtlsdisable
        violation[{"msg": msg}] {
          input.review.object.spec.mtls.mode == "DISABLE"
          msg := "PeerAuthentication with mode: DISABLE is not allowed"
        }
EOF

kubectl apply -f - <<'EOF'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDenyMtlsDisable
metadata:
  name: no-mtls-disable
spec:
  match:
    kinds:
      - apiGroups: ["security.istio.io"]
        kinds: ["PeerAuthentication"]
EOF
```

```bash
# should be DENIED
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: try-disable
  namespace: app
spec:
  mtls:
    mode: DISABLE
EOF
```

## Paso 6. NetworkPolicy (resiliencia ante omisión del sidecar)

mTLS/authz reside en el sidecar; si el tráfico omite el sidecar, no se aplican.
NetworkPolicy se aplica en el kernel mediante el CNI (Calico), una capa L3/L4 independiente:

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-allow-app
  namespace: app
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Ingress
  ingress:
    # app port 8080 only from pods in the app namespace
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: app
      ports:
        - port: 8080
          protocol: TCP
    # istio sidecar health (15021) / metrics (15090) from anywhere (kubelet, prometheus)
    - ports:
        - port: 15021
          protocol: TCP
        - port: 15090
          protocol: TCP
EOF
```

Solo los pods en `app` pueden acceder a `frontend` en `8080`; `legacy` se descarta antes de que
llegue al sidecar. El puerto `15021` permanece abierto para que la sonda de disponibilidad del
kubelet del sidecar de Istio siga pasando (de lo contrario, el pod pasaría a NotReady).

## Por qué funciona esto (modelo de amenazas)

- **mTLS STRICT**: solo se acepta tráfico de malla autenticado mutuamente; se rechazan los clientes
  de texto sin cifrar y los que no pertenecen a la malla. Cifrado + identidad de servicio.
- **Authz de denegación predeterminada**: mínimo privilegio: no se permite nada a menos que una
  autorización ALLOW explícita coincida, lo que limita el radio de impacto de una carga de trabajo comprometida.
- **Salida REGISTRY_ONLY**: un pod comprometido no puede exfiltrar datos a hosts externos
  arbitrarios; solo se puede acceder a destinos declarados.
- **RBAC en CRD**: restringir `EnvoyFilter` (y la configuración de Istio en general) evita que un
  usuario con privilegios excesivos reprograme el plano de datos.
- **OPA Gatekeeper**: convierte "nunca desactives mTLS" en una regla de admisión estricta, no en una convención.
- **NetworkPolicy**: control independiente a nivel de kernel que se mantiene incluso si se omite el
  sidecar: defensa en profundidad.
