[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 127 - solución de referencia (ValidatingAdmissionPolicy con CEL)

Todos los comandos se ejecutan en la máquina worker por SSH. kubectl ya está configurado
en el clúster (el kubeconfig se ensambla mediante `aws eks update-kubeconfig` al arrancar
la máquina).

## Tarea 1. Namespace `eks-127`

```bash
kubectl create namespace eks-127
```

## Tarea 2. La política CEL en modo Audit deja pasar un pod con `:latest`

Creamos una `ValidatingAdmissionPolicy` y un `ValidatingAdmissionPolicyBinding` con
`validationActions: ["Audit"]`. La política se aplica solo al namespace `eks-127`
mediante un `namespaceSelector` (etiqueta `kubernetes.io/metadata.name`, que k8s coloca
en el namespace automáticamente):

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: disallow-latest-tag
spec:
  matchConstraints:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: eks-127
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, !c.image.endsWith(':latest'))"
      message: "la etiqueta :latest está запрещён, especifique una versión concreta de la imagen"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: disallow-latest-tag-binding
spec:
  policyName: disallow-latest-tag
  validationActions: ["Audit"]
EOF
```

Comprobamos que ambos objetos están en su sitio:

```bash
kubectl get validatingadmissionpolicy disallow-latest-tag
kubectl get validatingadmissionpolicybinding disallow-latest-tag-binding
```

Ahora creamos un pod con imagen `:latest` en modo `Audit` - debe CREARSE, porque `Audit`
solo escribe la violación en el log de auditoría sin bloquear la solicitud:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: latest-audit-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

kubectl get pod latest-audit-pod -n eks-127
```

El pod se crea aunque viole la regla - ese es el sentido de `Audit`: probar la política sin
arriesgarse a romper la carga existente.

## Tarea 3. Cambiamos a Deny - un pod con `:latest` es rechazado

Actualizamos el Binding, cambiando solo `validationActions`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: disallow-latest-tag-binding
spec:
  policyName: disallow-latest-tag
  validationActions: ["Deny"]
EOF
```

Intentamos crear otro pod con `:latest` - ahora el apiserver debe rechazar la solicitud:

```bash
mkdir -p /var/work/tests/artifacts/3
cat <<'EOF' | kubectl apply -f - 2> /var/work/tests/artifacts/3/denied.txt
apiVersion: v1
kind: Pod
metadata:
  name: latest-deny-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

cat /var/work/tests/artifacts/3/denied.txt
```

El archivo `denied.txt` debe contener el mensaje de error del apiserver con el texto de la
política (las palabras `latest` y `запрещён`). El pod `latest-deny-pod` NO se crea -
`kubectl get pod latest-deny-pod -n eks-127` devolverá `NotFound`.

## Tarea 4. Un pod legítimo con etiqueta explícita pasa incluso con Deny

La política solo comprueba `:latest`, por lo que un pod con una versión concreta de la
imagen pasa sin problemas. La etiqueta `53833ea` es una etiqueta de commit real en
`viktoruj/ping_pong`, existe y está compilada para amd64 y arm64. Es importante usar una
etiqueta existente: la admisión solo mira la cadena de la imagen, así que un pod con una
etiqueta inventada también se crearía y quedaría colgado en `ErrImagePull` - la política
formalmente "no molestó", pero no quedaría nada con qué verificar esa afirmación:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: tagged-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:53833ea
EOF

kubectl get pod tagged-pod -n eks-127
```

## Tarea 5. Segunda política CEL: resources.requests obligatorio

Otra `ValidatingAdmissionPolicy` directamente en modo `Deny` - exigimos que cada contenedor
tenga `resources.requests` definido:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-resources-requests
spec:
  matchConstraints:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: eks-127
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, has(c.resources) && has(c.resources.requests))"
      message: "cada contenedor debe tener resources.requests definido"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-resources-requests-binding
spec:
  policyName: require-resources-requests
  validationActions: ["Deny"]
EOF
```

Un pod sin `requests` es rechazado:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-requests-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:53833ea
EOF
```

El comando devuelve un error de admisión, y `kubectl get pod no-requests-pod -n eks-127`
mostrará `NotFound`. Un pod con `requests` definido pasa normalmente:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: requests-ok-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:53833ea
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
EOF

kubectl get pod requests-ok-pod -n eks-127
```

## Tarea 6. `failurePolicy: Fail` y en qué se diferencia de un webhook externo

Establecemos explícitamente `failurePolicy: Fail` en la primera política (es el valor por
defecto, pero lo fijamos explícitamente):

```bash
kubectl patch validatingadmissionpolicy disallow-latest-tag --type merge \
  -p '{"spec":{"failurePolicy":"Fail"}}'

kubectl get validatingadmissionpolicy disallow-latest-tag -o jsonpath='{.spec.failurePolicy}'
```

`failurePolicy` reacciona ante un error al EVALUAR la expresión CEL (por ejemplo, acceder a
un campo que no existe en un objeto de una versión de API antigua), no ante la
inaccesibilidad de un servicio externo. La `ValidatingAdmissionPolicy` integrada no tiene
ningún webhook externo - CEL se evalúa directamente dentro del apiserver, por lo que no
tiene el riesgo de "el webhook no respondió", propio de
Kyverno y Gatekeeper (allí las reglas las ejecuta un servicio aparte detrás de un webhook,
y si no está disponible, `failurePolicy: Fail` hace que las solicitudes se encolen o se
bloqueen).

Guardamos la explicación en un artefacto:

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/failurepolicy.txt <<'EOF'
failurePolicy en una ValidatingAdmissionPolicy solo reacciona ante un error al evaluar la
expresión CEL (por ejemplo, acceder a un campo ausente del objeto), no ante la
inaccesibilidad de un servicio externo.

La ValidatingAdmissionPolicy integrada no tiene ningún webhook externo: la expresión CEL
se evalúa directamente dentro del apiserver, sin ninguna llamada de red hacia afuera. Por
eso aquí no existe el riesgo "el webhook no respondió",
característico de Kyverno y Gatekeeper, donde las reglas las ejecuta un servicio aparte
detrás de un webhook, y el apiserver espera su respuesta.
EOF
cat /var/work/tests/artifacts/6/failurepolicy.txt
```

## Verificación rápida

```bash
check_result
```

Comandos útiles para revisar el estado de las políticas:

```bash
kubectl get validatingadmissionpolicy
kubectl get validatingadmissionpolicybinding
kubectl get validatingadmissionpolicy disallow-latest-tag -o yaml
```
