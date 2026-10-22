[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 108 - solución de referencia: Kyverno admission policies

> Todos los comandos se ejecutan en la máquina de trabajo. El contexto ya está configurado; el namespace
> `policy-108` lo creó el script de arranque. Primero instala Kyverno y espera al
> webhook: de lo contrario, las siguientes policy basadas en CEL no comprobarán las peticiones de admission.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
```

## 1. Instalar Kyverno

En el worker hay un installer fijado preparado: instala el Helm chart de Kyverno
`3.9.0` (Kyverno `1.19`) en el namespace `kyverno`. Se puede revisar antes de ejecutarlo.

```bash
cat /usr/local/bin/install-kyverno
install-kyverno
kubectl get pods -n kyverno
kubectl get crd validatingpolicies.policies.kyverno.io
kubectl get crd mutatingpolicies.policies.kyverno.io
```

Espera a que al menos un Deployment en `kyverno` tenga `AVAILABLE > 0`.

> **Migration note.** Los antiguos ejemplos de `kyverno.io/v1` `Policy`/`ClusterPolicy` siguen siendo
> útiles solo para el mantenimiento de clústeres existentes. En Kyverno `1.19` están deprecated,
> y en `1.20` está prevista su eliminación. Las nuevas policy de este laboratorio usan
> `policies.kyverno.io/v1`.

## 2. Prohibir la etiqueta `latest`

Crea una `ValidatingPolicy` en modo `Deny`. La regla comprueba las tres listas de contenedores:
`containers`, `initContainers` y `ephemeralContainers`; de lo contrario, una imagen prohibida se puede
colar fácilmente mediante un init- o ephemeral-container, y el propio Pod igualmente pasará el admission.

```yaml
# deny-latest-tag.yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: deny-latest-tag
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE, UPDATE]
      resources: [pods, pods/ephemeralcontainers]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  variables:
  - name: images
    expression: >-
      object.spec.containers.map(c, c.image)
      + object.spec.?initContainers.orValue([]).map(c, c.image)
      + object.spec.?ephemeralContainers.orValue([]).map(c, c.image)
  validations:
  - message: Images must use an explicit non-latest tag or a digest.
    expression: >-
      variables.images.all(image,
        image.contains('@') ||
        (image.matches('^(?:.*/)?[^/:]+:[^/]+$') && !image.endsWith(':latest')))
```

```bash
kubectl apply -f deny-latest-tag.yaml
```

La tarea permite DOS formas de image reference: non-latest tag O digest. Comprueba
explícitamente que la forma con digest pasa (y no solo que pasa un versioned tag); de lo contrario, es fácil
escribir una policy que rechace por accidente TODAS las digest references:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: digest-pinned-ok
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause@sha256:5a92cb1de40c9c50e1c72e83bf35b9b32ce88e0d1b93f5e2727d97a44c176f56
EOF
# se espera: éxito (ningún error de admission)
```

Asegúrate de que el tratamiento de la etiqueta tiene en cuenta los dos puntos del puerto del registry: `registry.example:5000/app`
no contiene image tag y debe ser rechazado como latest implícito. El digest debe
aceptarse también en las demás listas de contenedores, por ejemplo, en `initContainers` y mediante
`kubectl debug --image=...` para `ephemeralContainers`.

## 3. Exigir `runAsNonRoot`

La policy exige precisamente el valor `true` en el `securityContext` a nivel de Pod; el valor
implícito y `false` no pasan. Además están prohibidos `runAsUser: 0` a nivel de
Pod y los container-level overrides `runAsNonRoot: false` / `runAsUser: 0` en las
tres container lists; de lo contrario, el securityContext a nivel de container podrá sobrescribir el
`runAsNonRoot: true` a nivel de Pod y ejecutar un proceso root.

```yaml
# require-run-as-non-root.yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-run-as-non-root
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE, UPDATE]
      resources: [pods, pods/ephemeralcontainers]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  validations:
  - message: Pod and every container must have an effective non-root security context.
    expression: >-
      has(object.spec.securityContext) &&
      object.spec.securityContext.?runAsNonRoot.orValue(false) &&
      object.spec.securityContext.?runAsUser.orValue(1) != 0 &&
      object.spec.containers.all(c,
        !has(c.securityContext) ||
        (c.securityContext.?runAsNonRoot.orValue(true) &&
         c.securityContext.?runAsUser.orValue(1) != 0)) &&
      object.spec.?initContainers.orValue([]).all(c,
        !has(c.securityContext) ||
        (c.securityContext.?runAsNonRoot.orValue(true) &&
         c.securityContext.?runAsUser.orValue(1) != 0)) &&
      object.spec.?ephemeralContainers.orValue([]).all(c,
        !has(c.securityContext) ||
        (c.securityContext.?runAsNonRoot.orValue(true) &&
         c.securityContext.?runAsUser.orValue(1) != 0))
```

```bash
kubectl apply -f require-run-as-non-root.yaml
```

## 4. Permitir solo los registry aprobados

Se permiten `registry.k8s.io` y la ruta organizativa dedicada `ghcr.io/cks-lab`. CEL
une las tres container lists y aplica un único allowlist a cada imagen.

```yaml
# allow-approved-registries.yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: allow-approved-registries
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE, UPDATE]
      resources: [pods, pods/ephemeralcontainers]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  variables:
  - name: images
    expression: >-
      object.spec.containers.map(c, c.image)
      + object.spec.?initContainers.orValue([]).map(c, c.image)
      + object.spec.?ephemeralContainers.orValue([]).map(c, c.image)
  validations:
  - message: Images must come from registry.k8s.io or ghcr.io/cks-lab.
    expression: >-
      variables.images.all(image,
        image.startsWith('registry.k8s.io/') ||
        image.startsWith('ghcr.io/cks-lab/'))
```

```bash
kubectl apply -f allow-approved-registries.yaml
```

Comprobación sin crear un Pod y sin image pull. `docker.io` es solo UN valor
untrusted concreto; comprueba que la policy realmente es un ALLOWLIST (prohíbe CUALQUIER
registry salvo los dos permitidos), y no simplemente un denylist de `docker.io` con la cadena literal;
de lo contrario, una imagen unqualified, otro registry de terceros o un host de escritura parecida pasarán
de largo con facilidad.

Los positive controls deben cubrir ambos prefix permitidos (`registry.k8s.io/` y
`ghcr.io/cks-lab/`) en `containers`, `initContainers` y `ephemeralContainers`; no
limites uno de los registry solo a los contenedores normales.

Los negative controls (cada uno de estos manifests debe ser rechazado):

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-unqualified-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: busybox:1.36
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-quay-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: quay.io/prometheus/busybox:v0.24.0
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-lookalike-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io.evil.example/pause:3.10
EOF
```

Los cuatro deben ser rechazados. El primer Pod de abajo infringe la regla con el contenedor
principal, el segundo, solo con `initContainers`; ambos deben ser rechazados:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-registry-main
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-init-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  initContainers:
  - name: init
    image: docker.io/library/busybox:1.36
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
```

Ambos comandos deben terminar con un error de la admission policy. Para un intento explícito de eludirla mediante
`ephemeralContainers`, crea un Pod permitido y después ejecuta `kubectl debug` primero con
`docker.io/library/busybox:1.36` (se espera un denial) y después con
`registry.k8s.io/e2e-test-images/busybox:1.36-1` (se espera éxito). Precisamente
`pods/ephemeralcontainers` en `matchConstraints` protege el update del subresource.

## 5. Opcional: mutation de un label

Esta `MutatingPolicy` no rechaza el Pod, sino que añade un label mediante CEL
`ApplyConfiguration`, pero solo si el label aún no está definido. La tarea exige precisamente una
semántica de defaulting («si no está»): un Pod que ya lleva este label con OTRO
valor (por ejemplo, de otro propietario/herramienta) no debe recibirlo
sobrescrito a la fuerza.

```yaml
# add-kyverno-managed-label.yaml
apiVersion: policies.kyverno.io/v1
kind: MutatingPolicy
metadata:
  name: add-kyverno-managed-label
spec:
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE]
      resources: [pods]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  mutations:
  - patchType: ApplyConfiguration
    applyConfiguration:
      expression: >-
        has(object.metadata.labels) &&
        'security.cks.io/managed-by' in object.metadata.labels
        ? Object{}
        : Object{
            metadata: Object.metadata{
              labels: {"security.cks.io/managed-by": "kyverno"}
            }
          }
```

```bash
kubectl apply -f add-kyverno-managed-label.yaml
kubectl apply --dry-run=server -o json -f - <<'EOF' \
  | jq -r '.metadata.labels["security.cks.io/managed-by"]'
apiVersion: v1
kind: Pod
metadata:
  name: mutation-check
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
# se espera: kyverno

kubectl apply --dry-run=server -o json -f - <<'EOF' \
  | jq -r '.metadata.labels["security.cks.io/managed-by"]'
apiVersion: v1
kind: Pod
metadata:
  name: mutation-check-existing-label
  namespace: policy-108
  labels:
    security.cks.io/managed-by: external
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
# se espera: external (la mutation NO sobrescribe el valor ya definido)
```

Ejecuta `check_result`. La tarea 5 se muestra en la comprobación, pero es opcional: la ausencia de la
mutation policy no afecta al aprobado de las tareas 1–4, 6 y 7.

## 6. ImagePolicyWebhook: backend externo

A diferencia de las tareas 1-5, aquí la decisión sobre la imagen la toma un backend HTTPS externo mediante la
API `ImageReview`, y no una expresión CEL dentro de Kyverno. La documentación upstream de
ImagePolicyWebhook exige explícitamente que la backend connection use TLS ("It is
required that the backend communicate over TLS"), por eso usamos un certificado
autofirmado, y no HTTP.

El backend ya está preparado en la máquina de trabajo:

```bash
cat /opt/image-policy-backend/server.py
```

Crea el namespace y el ConfigMap con el código del backend:

```bash
kubectl create namespace image-policy --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap image-policy-backend-src -n image-policy \
  --from-file=server.py=/opt/image-policy-backend/server.py \
  --dry-run=client -o yaml | kubectl apply -f -
```

Crea el Service **antes** del Deployment: hace falta el `ClusterIP` para el SAN correcto en el
certificado:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: image-policy-backend
  namespace: image-policy
spec:
  selector:
    app: image-policy-backend
  ports:
  - port: 8443
    targetPort: 8443
EOF

BACKEND_IP=$(kubectl get service image-policy-backend -n image-policy -o jsonpath='{.spec.clusterIP}')
echo "$BACKEND_IP"
```

Emite un certificado autofirmado con este `ClusterIP` en el SAN y guárdalo en un Secret:

```bash
workdir=$(mktemp -d)
openssl req -x509 -nodes -newkey rsa:2048 -days 3 \
  -keyout "$workdir/tls.key" -out "$workdir/tls.crt" \
  -subj "/CN=image-policy-backend" \
  -addext "subjectAltName=IP:${BACKEND_IP}"

kubectl create secret tls image-policy-backend-tls -n image-policy \
  --cert="$workdir/tls.crt" --key="$workdir/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -
```

Despliega el Deployment, montando tanto el código como el certificado:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: image-policy-backend
  namespace: image-policy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: image-policy-backend
  template:
    metadata:
      labels:
        app: image-policy-backend
    spec:
      containers:
      - name: backend
        image: python:3.12-slim
        command: ["python3", "/opt/image-policy/server.py"]
        ports:
        - containerPort: 8443
        volumeMounts:
        - name: src
          mountPath: /opt/image-policy
        - name: tls
          mountPath: /opt/image-policy/tls
          readOnly: true
      volumes:
      - name: src
        configMap:
          name: image-policy-backend-src
      - name: tls
        secret:
          secretName: image-policy-backend-tls
EOF

kubectl rollout status deployment/image-policy-backend -n image-policy --timeout=90s
```

Copia el certificado CA (aquí es autofirmado, por lo que el certificado del servidor es a la vez su
propia CA) al `control-plane`, para que kube-apiserver pueda verificar la cadena al
conectarse al backend, y entra en el nodo:

```bash
CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')
scp "$workdir/tls.crt" "$CP":/tmp/image-policy-ca.crt
rm -rf "$workdir"
echo "$BACKEND_IP"     # hará falta en el nodo
ssh "$CP"
sudo -i
```

En el `control-plane` crea el admission config y el kubeconfig para el backend. Las rutas están en el disco **del propio
control-plane**:

```bash
# en el control-plane (root)
mkdir /etc/kubernetes/image-policy
mv /tmp/image-policy-ca.crt /etc/kubernetes/image-policy/ca.crt

cat > /etc/kubernetes/image-policy/admission-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/kubernetes/image-policy/kubeconfig
      allowTTL: 30
      denyTTL: 30
      retryBackoff: 500
      defaultAllow: false
EOF

BACKEND_IP=10.111.15.20     # escribe el ClusterIP que mostró "echo $BACKEND_IP"
cat > /etc/kubernetes/image-policy/kubeconfig <<EOF
apiVersion: v1
kind: Config
clusters:
- name: image-policy-backend
  cluster:
    certificate-authority: /etc/kubernetes/image-policy/ca.crt
    server: https://${BACKEND_IP}:8443/imagepolicy
users:
- name: kube-apiserver
contexts:
- name: image-policy
  context:
    cluster: image-policy-backend
    user: kube-apiserver
current-context: image-policy
EOF
```

Edita el static manifest **en el `control-plane`** (ya estás en la sesión root). No sustituyas
el `--enable-admission-plugins` existente por completo: añade `ImagePolicyWebhook` al valor actual
(normalmente ya está `NodeRestriction`), añade `--admission-control-config-file` y
`--runtime-config`, y monta el nuevo directorio como hostPath:

```bash
# en el control-plane (root)
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
# fragmento de /etc/kubernetes/manifests/kube-apiserver.yaml en el control-plane
spec:
  containers:
  - name: kube-apiserver
    command:
    - kube-apiserver
    - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook   # añádelo a la lista existente
    - --admission-control-config-file=/etc/kubernetes/image-policy/admission-config.yaml
    - --runtime-config=imagepolicy.k8s.io/v1alpha1=true               # añádelo, si runtime-config ya estaba definido
    volumeMounts:
    - name: image-policy
      mountPath: /etc/kubernetes/image-policy
      readOnly: true
  volumes:
  - name: image-policy
    hostPath:
      path: /etc/kubernetes/image-policy
      type: DirectoryOrCreate
```

Tras guardar, sal del nodo; el kubelet recogerá por sí mismo el cambio del static Pod:

```bash
exit   # de root
exit   # del control-plane
```

Espera a que la API se recupere:

```bash
until kubectl get --raw=/readyz 2>/dev/null | grep -q '^ok$'; do sleep 5; done
```

Comprueba ambos casos:

```bash
kubectl run webhook-latest-must-fail --image=nginx:latest
# Error from server (Forbidden): pods "webhook-latest-must-fail" is forbidden:
# image policy webhook backend denied one or more images: Images using latest tag are not allowed

kubectl run webhook-pinned-ok --image=nginx:1.27.3
kubectl get pod webhook-pinned-ok
# STATUS: Running
```

`ImagePolicyWebhook` usa el backend de `/opt/image-policy-backend/server.py`:
en `default` y en los demás namespace (salvo `policy-108`) prohíbe el latest
explícito/implícito; `policy-108` lo controlan por completo las tres policy de Kyverno de las tareas 2–4.
Es un aislamiento de mecanismos de laboratorio, y no un patrón universal de producción.
La annotation de usuario `alpha.image-policy.k8s.io/break-glass` NO concede el permiso:
el reenvío de annotations en ImageReview no es una verificación de autenticidad.

`defaultAllow: false` significa fail-closed: si el backend no está disponible, los nuevos Pod/image
se prohíben, y no se permiten. Compruébalo explícitamente, pero NO escales
`image-policy-backend` a 0 réplicas: `ImagePolicyWebhook` es un admission
plugin cluster-wide sin excepción por namespace en nuestra configuración, por lo que comprueba también el Pod
del propio backend. Si quitas temporalmente todas las réplicas y luego intentas devolverlas,
la creación de un Pod backend NUEVO pasará ELLA MISMA por el mismo ImagePolicyWebhook (en ese momento
no disponible) y será rechazada con un `defaultAllow: false` correcto:
se produce un deadlock del que `kubectl rollout status` no saldrá. En su lugar,
desconecta el Service del backend cambiando el `selector` por un valor inexistente: esto no
crea ni elimina ningún Pod, solo quita temporalmente los `Endpoints`:

```bash
kubectl get service image-policy-backend -n image-policy -o jsonpath='{.spec.selector}'
# guarda este valor para restaurarlo más tarde

kubectl patch service image-policy-backend -n image-policy \
  -p '{"spec":{"selector":{"app":"image-policy-backend-detached-for-probe"}}}'
kubectl get endpoints image-policy-backend -n image-policy -w
# Ctrl+C cuando ENDPOINTS quede vacío

kubectl run webhook-should-fail-closed --image="nginx:fail-closed-check-$(date +%s%N)"
# se espera: Forbidden - el backend no está disponible, defaultAllow:false prohíbe el admission
# (usamos una etiqueta AÚN NO vista, y no simplemente la fecha en segundos, para no toparnos con
# la caché TTL de la respuesta del backend a esa misma etiqueta del intento anterior)

kubectl patch service image-policy-backend -n image-policy \
  -p '{"spec":{"selector":{"app":"image-policy-backend"}}}'
kubectl get endpoints image-policy-backend -n image-policy -w
# Ctrl+C cuando ENDPOINTS vuelva a aparecer - es el mismo Pod que antes del probe, no hizo falta ninguna
# reconstrucción/recreación
```

Es la misma decisión fundamental fail-closed descrita en el [capítulo 26 del curso](../../../../../course/26/es.md) para la
configuración de producción de ImagePolicyWebhook.

## 7. Gatekeeper: completar el blocklist de Rego en el ConstraintTemplate

Gatekeeper y el `ConstraintTemplate`/`Constraint` iniciales (incompletos) ya están desplegados
por el bootstrap del clúster en un namespace aparte `gatekeeper-108`: es un tercer admission
engine aparte en este laboratorio (después de Kyverno e ImagePolicyWebhook), que comprueba precisamente la
habilidad con OPA/Rego. `gatekeeper-108` está aislado de las tareas 1-5 de Kyverno (`policy-108`)
a propósito: de lo contrario el mismo Pod de prueba podría ser rechazado a la vez por Kyverno y por
Gatekeeper, y el origen del denial sería ambiguo. Mira el Rego actual:

```bash
kubectl get constrainttemplate k8sblockedregistries -o yaml
```

`spec.targets[].rego` declara los registry bloqueados mediante hechos separados:

```rego
blocked_registry("untrusted-registry.example")
blocked_registry("docker-fake.test")
```

`very-bad-registry.test` no está entre ellos: precisamente esa línea hay que añadir. El `Constraint
deny-bad-registries` ya es totalmente correcto y no usa `spec.parameters` en absoluto:
no hace falta editarlo; la corrección está PRECISAMENTE en el Rego dentro del
`ConstraintTemplate`, no en el Constraint. Edita el template (por ejemplo `kubectl edit
constrainttemplate k8sblockedregistries`, o `get -o yaml` → edición → `apply -f -`),
añadiendo una línea nueva sin eliminar las existentes:

```rego
blocked_registry("untrusted-registry.example")
blocked_registry("docker-fake.test")
blocked_registry("very-bad-registry.test")
```

Comprueba los tres resultados del server-side dry-run, sin crear un Pod permanente: el nuevo
registry debe ser denied, el antiguo (ya bloqueado) debe seguir denied (no hay regresión),
el de confianza debe pasar:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: gatekeeper-new-bad-check
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF
# se espera: Error from server ... admission webhook "validation.gatekeeper.sh" denied
# the request: [deny-bad-registries] image registry very-bad-registry.test is blocked
# by k8sblockedregistries

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: gatekeeper-old-bad-check
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF
# se espera: también Error from server ... - la regla antigua no debe perderse

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: gatekeeper-trusted-check
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
# se espera: éxito (ningún error de admission)
```

Asegúrate de que el rechazo realmente vino de Gatekeeper (`validation.gatekeeper.sh`), y
no de una de las `ValidatingPolicy` de Kyverno de las tareas 2-4: el mensaje de error nombra explícitamente
el webhook y el nombre de tu Constraint. No resuelvas la tarea mediante `Constraint.spec.parameters`:
en esta versión de la policy el Constraint no los usa en absoluto.

Ejecuta `check_result`.
