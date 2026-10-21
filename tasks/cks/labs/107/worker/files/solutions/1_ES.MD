[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 107 - solución de referencia: Pod Security Admission e immutable root filesystem

> Ejecuta los comandos en la máquina de trabajo. El contexto `cluster1-admin@cluster1` ya está
> configurado. Los namespace `psa-restricted-107` y `psa-observe-107` los creó el script
> de arranque, pero deliberadamente no tienen PSA labels.

## 1. Enforce restricted y comprobación de la denegación

PSA aplica los Pod Security Standards según los labels del namespace. Fijaremos la versión
del estándar, para que el comportamiento no cambie con una futura actualización de Kubernetes:

```bash
kubectl label namespace psa-restricted-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36
```

Comprobaremos el admission sin guardar el objeto peligroso. `hostNetwork` está prohibido por el nivel
`restricted`, por lo que el comando debe terminar con el error `violates PodSecurity`:

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-by-restricted
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
YAML
```

## 2 y 5. Hardened Pod y emptyDir escribible

Crea el Pod directamente en su forma segura definitiva. El nivel `restricted` exige
non-root, seccomp, prohibición de escalation y eliminación de capabilities. El read-only root filesystem
reduce las consecuencias de una escritura en el contenedor; a la aplicación solo se le deja `/tmp` en un
`emptyDir`.

```yaml
# restricted-app.yaml
apiVersion: v1
kind: Pod
metadata:
  name: restricted-app
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
    volumeMounts:
    - name: writable-tmp
      mountPath: /tmp
  volumes:
  - name: writable-tmp
    emptyDir:
      medium: Memory
```

```bash
kubectl apply -f restricted-app.yaml
kubectl get pod restricted-app -n psa-restricted-107
```

Demuestra ambos resultados con una llamada en vivo, y no solo leyendo el YAML: el contenedor funciona con
`runAsUser: 1000` con un root read-only, por lo que la escritura fuera de `/tmp` debe terminar con
un error del sistema de archivos, y la escritura en el `emptyDir` montado - tener éxito:

```bash
kubectl exec -n psa-restricted-107 restricted-app -- sh -c 'touch /root-write-test.txt'
# touch: /root-write-test.txt: Read-only file system

kubectl exec -n psa-restricted-107 restricted-app -- sh -c 'echo probe > /tmp/test.txt && cat /tmp/test.txt'
# probe
```

Si `restricted-app` ya se creó sin read-only filesystem, el campo del Pod no se puede cambiar;
elimínalo y créalo de nuevo (si lo haces ya después de la tarea 6, añade al `spec`
el campo `automountServiceAccountToken: false`; de lo contrario la política de la tarea 6 rechazará el Pod):

```bash
kubectl delete pod restricted-app -n psa-restricted-107
kubectl apply -f restricted-app.yaml
```

## 3. Audit y warn para baseline

Estos modos no prohíben la petición. `warn` devuelve una advertencia al cliente, y `audit`
añade al audit event del API server la annotation
`pod-security.kubernetes.io/audit-violations`. Para una adopción gradual no establezcas
`enforce` en el namespace de observación:

```bash
kubectl label namespace psa-observe-107 \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/audit-version=v1.36 \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/warn-version=v1.36
```

> **Salvedad de versión.** `v1.36` está fijada para Kubernetes 1.36.0 en esta infraestructura
> didáctica. A fecha de 2026-09-06 el CKS oficial está orientado a `v1.35`; este es un
> ejemplo forward-looking, y al prepararte para el examen usa `*-version=v1.35`.

> **Límite de la prueba de audit.** El laboratorio no configura un audit-log sink, por lo que
> `pod-security.kubernetes.io/audit-violations` no se puede extraer con el comando `kubectl`.
> El resultado realmente comprobable más abajo es el PSA Warning y el admission exitoso; la audit
> annotation está explicada, pero no es un artefacto comprobable de esta infraestructura.

## 4. Asegurarse de que warn/audit no bloquean el Pod

Este Pod infringe baseline por `hostNetwork`, pero es aceptado, porque en el namespace
no hay `enforce`. `kubectl apply` mostrará la advertencia de PSA; no la ignores al
migrar un workload de producción.

```yaml
# baseline-audit-sample.yaml
apiVersion: v1
kind: Pod
metadata:
  name: baseline-audit-sample
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f baseline-audit-sample.yaml
kubectl get pod baseline-audit-sample -n psa-observe-107
kubectl get namespace psa-restricted-107 --show-labels
kubectl get namespace psa-observe-107 --show-labels
```

## 6. Native ValidatingAdmissionPolicy sin Kyverno/Gatekeeper

PSA `restricted` ya exige `allowPrivilegeEscalation: false` y `capabilities.drop`
que contenga `ALL`: la tarea 2 muestra precisamente eso, y es una parte integrada del Pod Security
Standard, y no una laguna. Pero PSS `restricted` **no comprueba** `automountServiceAccountToken`:
un Pod puede recibir silenciosamente un ServiceAccount token montado y pasar PSA por completo. Para
este control aparte, realmente no cubierto, procede precisamente una `ValidatingAdmissionPolicy` custom.

```yaml
# require-no-automount-token.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-no-automount-token
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  validations:
  - expression: >-
      has(object.spec.automountServiceAccountToken) &&
      object.spec.automountServiceAccountToken == false
    message: "spec.automountServiceAccountToken must be explicitly set to false"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-no-automount-token-binding
spec:
  policyName: require-no-automount-token
  validationActions: [Deny]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: psa-restricted-107
```

```bash
kubectl apply -f require-no-automount-token.yaml
kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding
```

Demuestra los tres estados mediante server-side dry-run, sin guardar un Pod permanente. El Pod sin
el campo debe recibir DENY de la pareja exacta policy + binding, `false` debe pasar, y
`true` debe recibir DENY de la misma pareja. El primer Pod
cumple por completo PSA `restricted` (non-root, seccomp, `allowPrivilegeEscalation:
false`, `capabilities.drop: ["ALL"]`): PSA por sí mismo lo habría aceptado, por lo que el rechazo debe
venir precisamente de la nueva policy, y no de `violates PodSecurity`:

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: vap-unsafe-check
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
YAML
# Error from server: ... ValidatingAdmissionPolicy 'require-no-automount-token'
# with binding 'require-no-automount-token-binding' denied request: ...
```

El mismo Pod con `automountServiceAccountToken: false` añadido debe pasar:

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: vap-safe-check
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
YAML
```

El valor explícito `true` también debe ser rechazado por la misma policy y binding:

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: vap-explicit-true-check
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: true
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
YAML
# Error from server: ... ValidatingAdmissionPolicy 'require-no-automount-token'
# with binding 'require-no-automount-token-binding' denied request: ...
```

`Binding.matchResources.namespaceSelector` limita la policy solo a `psa-restricted-107`:
los Pod de otros namespace (por ejemplo `psa-observe-107`) no los comprueba esta regla y no
reciben un Deny de más.

## 7. Controller-driven admission denial

Primero un Deployment sencillo, no hardened: PSA todavía no es enforce, todo pasa:

```bash
kubectl -n psa-controller-107 create deployment controller-app --image=busybox:1.36 -- sh -c "sleep 3600"
kubectl -n psa-controller-107 rollout status deployment/controller-app
```

Habilitamos enforce: el Pod existente no se toca:

```bash
kubectl label namespace psa-controller-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36
kubectl -n psa-controller-107 get pod
# controller-app-xxxx sigue Running - PSA no actúa sobre los objetos ya existentes
```

Eliminamos el Pod: el ReplicaSet intenta crear un reemplazo y recibe un rechazo:

```bash
kubectl -n psa-controller-107 delete pod -l app=controller-app
kubectl -n psa-controller-107 get events --sort-by=.lastTimestamp | tail -5
# ... FailedCreate ... violates PodSecurity "restricted:v1.36": ...
kubectl -n psa-controller-107 get deploy controller-app
# controller-app   0/1     1            0           ...   <- READY 0/1, AVAILABLE 0
```

Arreglamos el template: añadimos los mismos campos de hardening que en la tarea 2:

```bash
kubectl -n psa-controller-107 edit deployment controller-app
```

En `spec.template.spec` sustituye la línea `securityContext: {}` por el bloque de abajo, y en el contenedor `busybox`
(el nombre del contenedor es `busybox`, creado por `kubectl create deployment`) añade tu propio `securityContext`:

```yaml
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: busybox
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
```

Guarda y espera al rollout:

```bash
kubectl -n psa-controller-107 rollout status deployment/controller-app
```

```
deployment "controller-app" successfully rolled out
```

```bash
check_result
```
