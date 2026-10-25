[Русская версия](CHEATSHEET_RU.md) · [Eng version](CHEATSHEET.md) · [Version française](CHEATSHEET_FR.md) · [Deutsche Version](CHEATSHEET_DE.md) · [ქართული ვერსია](CHEATSHEET_GE.md) · [繁體中文版](CHEATSHEET_TW.md) · [日本語版](CHEATSHEET_JP.md)

[← Contenidos del curso](README_ES.md) · [Glosario](GLOSSARY_ES.md) · [Índice de solución de problemas (RU)](TROUBLESHOOTING_INDEX_RU.md)

# Hoja de referencia de CKS: comandos YAML y CLI listos para usar

Un solo archivo sin teoría ni explicaciones extensas: fragmentos de trabajo canónicos de las soluciones a los laboratorios del curso `101-114`. Cada bloque identifica su origen (laboratorio/tarea), por lo que puedes encontrar la explicación completa en `worker/files/solutions/1_ES.MD` de la práctica de laboratorio correspondiente. Utilice `Ctrl+F`/búsqueda de página durante un laboratorio o examen.

> Estos fragmentos se adaptaron y acortaron de las soluciones de laboratorio `101-114` para una referencia rápida (es posible que se hayan simplificado las variables, la sangría y los pasos de soporte). Si algo difiere de la última versión de laboratorio, siga el archivo README/solución de ese laboratorio.

## Cómo utilizar este archivo

- [Árboles de decisión](#decision-trees): cuando necesitas elegir la herramienta adecuada para una tarea.
- Las secciones de dominio a continuación: cuando sabe lo que necesita y desea un fragmento listo para usar.
- [Índice alfabético de términos y laboratorios](GLOSSARY_ES.md): para un término/indicador CLI vinculado a un capítulo.
- [Referencia de síntomas (RU)](TROUBLESHOOTING_INDEX_RU.md): cuando algo ha fallado y necesita encontrar la causa rápidamente.

---

<a id="decision-trees"></a>

## Árboles de decisión

### Restringir privilegios/acceso: PSA vs ValidatingAdmissionPolicy vs AppArmor vs seccomp

```mermaid
flowchart TD
    A["Tarea: restringir privilegios/acceso a Pod"] --> B{"¿Dónde se aplica el control?"}
    B -->|"En la entrada API"| C{"¿Qué se está controlando?"}
    C -->|"Banderas estándar: no root, eliminar TODOS, sin escalada de privilegios"| D["Pod Security Admission (PSA)<br/>label pod-security.kubernetes.io/enforce=restricted"]
    C -->|"Condición personalizada: automountServiceAccountToken, etiquetas, campos personalizados"| E["ValidatingAdmissionPolicy (CEL)<br/> o Kyverno ValidatingPolicy"]
    B -->|"En el nodo del kernel Linux durante la ejecución"| F{"Tipo de restricción"}
    F -->|"Acceso a archivos, rutas, sockets de red."| G["Perfil AppArmor<br/>spec.securityContext.appArmorProfile"]
    F -->|"Llamadas al sistema (syscalls)"| H["Perfil Seccomp<br/>spec.securityContext.seccompProfile"]
    F -->|"Cargando módulos del kernel en un nodo"| I["modprobe blacklist /etc/modprobe.d/"]
    B -->|"Aislar el núcleo de la carga de trabajo del host"| J["Zona de pruebas de tiempo de ejecución de contenedor (gVisor/Kata)<br/>RuntimeClass handler: runsc"]
```

### Cifrado de tráfico: NetworkPolicy vs cifrado CNI vs malla mTLS

```mermaid
flowchart TD
    A["Tarea: proteger el tráfico de Pod a Pod"] --> B{"¿Qué se necesita?"}
    B -->|"Restringir QUIÉN puede conectarse (L3/L4)"| C["Kubernetes NetworkPolicy"]
    B -->|"L3/L4 más método/ruta HTTP u otra condición L7 (solo Cilium)"| C2["CiliumNetworkPolicy"]
    B -->|"Cifre el tráfico ENTRE nodos de forma transparente hacia las aplicaciones"| D["Cilium WireGuard/IPsec cifrado transparente<br/>ConfigMap enable-wireguard / Helm encryption.enabled"]
    B -->|"Requerir mTLS y autenticación basada en identidad ENTRE servicios"| E["Service mesh (Istio) PeerAuthentication STRICT"]
    C --> C3["Kubernetes NetworkPolicy: solo L3/L4, <br/> sin HTTP/conocimiento de contenido de protocolo"]
    D --> F["No verifica la identidad de la aplicación, <br/> solo protege el tráfico a nivel de nodo"]
    E --> G["No reemplaza NetworkPolicy.<br/>Lab110 usa el modo sidecar.<br/>El moderno Istio también admite el modo ambient (ztunnel)"]
```

### Cadena de suministro: escaneo frente a firmas frente a procedencia/certificaciones frente a SBOM frente a aplicación de la admisión

```mermaid
flowchart TD
    A["Tarea: asegurar una cadena de suministro de imágenes"] --> B{"¿Qué propiedad debe demostrarse?"}
    B -->|"Vulnerabilidades conocidas del sistema operativo/biblioteca"| C["trivy image --scanners vuln"]
    B -->|"Inventario de paquetes, no vulnerabilidades"| D["SBOM: bom generate (SPDX) / syft (CycloneDX)"]
    B -->|"La firma coincide con el resumen y la clave/identidad confiable"| E["cosign sign / cosign verify"]
    B -->|"Cómo y a partir de qué se construyó la imagen: procedencia/certificación"| E2["cosign attest / cosign verify-attestation"]
    B -->|"Condición obligatoria para la admisión al grupo."| F{"¿Qué se controla al momento de la admisión?"}
    F -->|"Firma (Cosign)"| G["Kyverno ImageValidatingPolicy<br/>verifyImageSignatures"]
    F -->|"Lista de permitidos de registro/repositorio"| H["Kyverno ValidatingPolicy CEL<br/>image().registry()/.repository() == exact"]
    C --> I["No prueba origen, sólo CVE conocidos"]
    D --> J["No prueba seguridad, sólo inventario."]
    E --> K["cosign verify demuestra firma/identidad, <br/>NO procedencia, un reclamo separado (E2)"]
    E --> L["cosign verify local en CI no bloquea kubectl apply.<br/>ASe requiere cumplimiento de admisión (F) para eso"]
```

### Detección en tiempo de ejecución: registros de auditoría frente a Falco frente a ambos

```mermaid
flowchart TD
    A["Tarea: detectar/investigar un evento de tiempo de ejecución"] --> B{"¿Qué pasó?"}
    B -->|"Solicitud Kubernetes API: cliente kubectl/API"| C["Registro de auditoría<br/>RequestResponse/Metadata por recurso"]
    B -->|"Llamada al sistema dentro de un contenedor/en un nodo"| D["Falco<br/>condición en spawned_process/proc.cmdline/container.*"]
    B -->|"Acción de omisión de kube-apiserver: directa ctr/crictl"| E["Visible para Falco,<br/>NO para el registro de auditoría: diferentes capas de observación"]
    C --> F["Evidencia a nivel de solicitud:<br/>quién/cuándo/verbo/resultado, NO monitoreo continuo del estado de configuración"]
    D --> G["Evidencia a nivel de llamada al sistema:<br/>comportamiento real del proceso en el momento del evento"]
```

---

## 1. Cluster Setup

### Política de red: Y, O y `ipBlock.except`
*Fuente: laboratorio 101, tarea 6.*

Y: ambos selectores en el mismo elemento `from`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-ingress-from-legacy
  namespace: cks-101
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: cks-101-legacy
          podSelector:
            matchLabels:
              app: legacy-client
      ports:
        - protocol: TCP
          port: 8080
```

O: elementos separados de `from` (diferentes de AND arriba):

```yaml
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: cks-101-legacy
        - podSelector:
            matchLabels:
              app: legacy-client
```

`ipBlock` con una excepción (por ejemplo, el punto final de metadatos del nodo):

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-legacy-egress
  namespace: cks-101-legacy
spec:
  podSelector:
    matchLabels:
      app: legacy-client
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 169.254.169.254/32
```

### Política de red Cilium: L3/L4/L7
*Fuente: laboratorio 102, tarea 3.*

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-policy
  namespace: cks-102
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            role: frontend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: GET
                path: "/"
```

### kube-bench: ejecutando e interpretando la salida
*Fuente: laboratorio 103, tarea 1.*

```bash
mkdir -p /var/work/tests/artifacts/1
scp -r /opt/kube-bench control-plane:/tmp/kube-bench
ssh control-plane 'sudo rm -rf /opt/kube-bench && sudo mv /tmp/kube-bench /opt/kube-bench'
ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --targets master,controlplane,node' \
  | tee /var/work/tests/artifacts/1/kube-bench.txt
grep -E '\[(PASS|WARN|FAIL)\]' /var/work/tests/artifacts/1/kube-bench.txt | head
```

> El `kube-bench 0.16.0` fijado no tiene ningún perfil más nuevo que `cis-1.12` (su `version_mapping` integrado termina en `"1.34": "cis-1.12"`). Especifique este perfil explícitamente en lugar de confiar en la detección automática y marque los resultados de las versiones más recientes de Kubernetes como `forced-approximate`.

---

## 2. Cluster Hardening

### RBAC: rol mínimo y enlace de roles
*Fuente: laboratorio 104, tarea 1.*

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: auditor
  namespace: security-104
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-observer
  namespace: security-104
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: auditor-pod-observer
  namespace: security-104
subjects:
- kind: ServiceAccount
  name: auditor
  namespace: security-104
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-observer
```

### ServiceAccount sin montaje automático de fichas
*Fuente: laboratorio 104, tarea 3.*

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: no-token-sa
  namespace: security-104
automountServiceAccountToken: false
---
apiVersion: v1
kind: Pod
metadata:
  name: no-token
  namespace: security-104
spec:
  serviceAccountName: no-token-sa
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

### Volumen Secret: `defaultMode: 0400` (= `256` decimal)
*Fuente: laboratorio 104, tarea 6.*

> `kubectl get pod -o json` muestra `defaultMode: 0400` como `256` decimal. Escribir `defaultMode: 400` (sin un cero a la izquierda) significa `400` decimal, NO `0400`/`256` octal: un error común en los exámenes.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-vulnerable
  namespace: security-104
spec:
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: db-creds-vol
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: db-creds-vol
    secret:
      secretName: db-creds
      defaultMode: 0400
```

### Actualización menor de kubeadm: plano de control primero, trabajadores después
*Fuente: laboratorio 113, tareas 1-2.*

> El orden importa: finalice COMPLETO la actualización del plano de control (incluido el descordón) antes de actualizar a un trabajador, o violará la política de sesgo de versión. En el plano de control utilice `kubeadm upgrade apply`; en trabajadores utilice `kubeadm upgrade node` (no `apply`). `pkgs.k8s.io` tiene un repositorio apto separado para cada versión menor. Cambie `sources.list.d/kubernetes.list` al menor de destino ANTES de `apt install kubeadm`.

```bash
# Cambie el repositorio al menor de destino (ejemplo: 1.36)
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -qq

# Plano de control: actualice kubeadm, inspeccione el plan, ejecute la actualización
sudo apt-mark unhold kubeadm && sudo apt-get install -y --allow-change-held-packages kubeadm && sudo apt-mark hold kubeadm
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.36.1 -y

# Solo DESPUÉS de aplicar correctamente: drenaje -> actualizar kubelet/kubectl -> reiniciar -> uncordon
kubectl drain <control-plane-node> --ignore-daemonsets --delete-emptydir-data
sudo apt-mark unhold kubelet kubectl && sudo apt-get install -y --allow-change-held-packages kubelet kubectl && sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet
kubectl uncordon <control-plane-node>

# Trabajador (después de que el plano de control esté listo en la versión de destino): NODO de actualización de kubeadm, no se aplica
sudo kubeadm upgrade node
```

---

## 3. System Hardening

### AppArmor: cargar un perfil y asignarlo a un Pod
*Fuente: laboratorio 106, tareas 2 y 8.*

```bash
ssh control-plane 'sudo apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile'
ssh control-plane 'sudo aa-status | grep k8s-106-broken-profile'
```

El campo actual es `spec.securityContext.appArmorProfile` (NO la antigua anotación beta `container.apparmor.security.beta.kubernetes.io/...`):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-writer
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: k8s-106-deny-write
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: work
      mountPath: /work
  volumes:
  - name: work
    emptyDir: {}
```

### Seccomp: Perfil Localhost JSON y referencia Pod
*Fuente: laboratorio 106, tareas 4 a 5.*

```json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": ["unshare"],
      "action": "SCMP_ACT_ERRNO",
      "errnoRet": 1
    }
  ]
}
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: localhost-seccomp
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/cks-106-deny-unshare.json
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

> `localhostProfile` siempre es relativo a la raíz kubelet seccomp (normalmente `/var/lib/kubelet/seccomp/`), no una ruta de archivo absoluta.

---

## 4. Minimize Microservice Vulnerabilities

### Pod Admisión de seguridad: `restricted`
*Fuente: laboratorio 107, tarea 1.*

```bash
kubectl label namespace psa-restricted-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36
```

### ValidatingAdmissionPolicy + Encuadernación: CEL para `automountServiceAccountToken`
*Fuente: laboratorio 107, tarea 6.*

> `allowPrivilegeEscalation: false` y `capabilities.drop: ["ALL"]` ya están cubiertos por PSA `restricted` arriba y NO se duplican deliberadamente en este VAP. Aquí CEL se usa solo para una condición personalizada que PSA no verifica.

```yaml
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

### Configuración de cifrado: cifrar Secrets en etcd (`aescbc`)
*Fuente: laboratorio 109, tarea 2.*

```bash
umask 077
key=$(head -c 32 /dev/urandom | base64 -w0)
cat > /etc/kubernetes/enc/encryption-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: cks-109-aescbc
        secret: ${key}
  - identity: {}
EOF
```

> El orden del proveedor es importante: el primer proveedor maneja las NUEVAS escrituras; Los proveedores posteriores solo leen registros antiguos. Un `identity: {}` final permite leer el Secrets existente sin cifrar hasta que se vuelva a cifrar por completo.

### gVisor: containerd `runsc` y RuntimeClass
*Fuente: laboratorio 110, tarea 1.*

```bash
ssh k8s110_node_gvisor 'sudo tee -a /etc/containerd/config.toml > /dev/null <<EOF
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF
sudo systemctl restart containerd'
```

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
scheduling:
  nodeSelector:
    sandbox.runtime/gvisor: "true"
```

### Cilium WireGuard: habilitación de cifrado transparente
*Fuente: laboratorio 110, tarea 4.*

Instalación Helm-managed:

```bash
helm upgrade cilium cilium/cilium -n kube-system --reuse-values \
  --set encryption.enabled=true --set encryption.type=wireguard
```

Instalación de ConfigMap-based (cuando no hay ninguna versión de Helm):

```bash
kubectl -n kube-system patch configmap cilium-config --type merge \
  -p '{"data":{"enable-wireguard":"true"}}'
kubectl -n kube-system rollout restart daemonset/cilium
```

### Istio PeerAuthentication: `STRICT` mTLS
*Fuente: laboratorio 110, tarea 6.*

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: market-strict
  namespace: market
spec:
  mtls:
    mode: STRICT
```

---

## 5. Supply Chain Security

### Trivy: escaneo de imágenes JSON
*Fuente: laboratorio 111, tarea 1.*

```bash
trivy image --scanners vuln --vuln-type os,library --format json \
  --output trivy-report.json "$IMAGE"
```

### Trivy: lista completa de paquetes
*Fuente: laboratorio 111, tarea 5.*

```bash
trivy image --list-all-pkgs --format json "$IMAGE" > packages.json
jq -r '[.Results[].Packages[]? | "\(.Name)=\(.Version)"] | unique | .[:3][]' packages.json
```

### SBOM: SPDX con `bom`, CycloneDX con `syft`
*Fuente: laboratorio 111, tareas 6 a 7.*

```bash
bom generate --format json --output bom.spdx.json --image "$IMAGE"
syft "$IMAGE" -o "cyclonedx-json=syft.cdx.json"
```

### `trivy sbom`: escaneando un archivo SBOM existente
*Fuente: laboratorio 111, tarea 8.*

```bash
trivy sbom --format json --output sbom-scan.json bom.spdx.json
```

> Utilice `trivy sbom <file>`, NO `trivy image <file>`; la ruta se pasa como SBOM, no como referencia de imagen.

### Cosign: generación de claves, firma y verificación (basada en claves y sin claves)
*Fuente: laboratorio 111, tareas 7, 9a, 9c.*

```bash
cosign generate-key-pair
cosign sign --key cosign.key --yes "$HARDENED_IMAGE"
cosign verify --key cosign.pub "$HARDENED_IMAGE"
```

Verificación sin llave de un artefacto público firmado por OIDC:

```bash
cosign verify \
  --certificate-oidc-issuer https://accounts.google.com \
  --certificate-identity keyless@distroless.iam.gserviceaccount.com \
  gcr.io/distroless/static:nonroot
```

### Kyverno ImageValidatingPolicy: Cosign verificación de firma al ingreso
*Fuente: laboratorio 111, tarea 9a.*

```yaml
apiVersion: policies.kyverno.io/v1
kind: ImageValidatingPolicy
metadata:
  name: require-signed-catalog-images
spec:
  failurePolicy: Fail
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  matchImageReferences:
  - glob: "${HARDENED_REPO}*"
  attestors:
  - name: catalogReleaseKey
    cosign:
      key:
        data: |-
          <con sangría cosign.pub PEM>
  validations:
  - message: "catalog image must have a valid release signature"
    expression: >-
      (images.containers + images.?initContainers.orValue([]) +
      images.?ephemeralContainers.orValue([])).map(image,
        verifyImageSignatures(image, [attestors.catalogReleaseKey]) > 0).all(ok, ok)
```

### Kyverno ValidatingPolicy: lista de permitidos exacta de registro/repositorio (sin coincidencia de prefijos)
*Fuente: laboratorio 112, tarea 9.*

> Utilice `==` exacto, no `startsWith`/coincidencia de prefijo. De lo contrario, `library/busybox-evil` aprueba la política simplemente porque su nombre COMIENZA con la cadena permitida.

```yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-trusted-registry-runtime-112
spec:
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      resources: ["pods"]
      operations: ["CREATE"]
  matchConditions:
  - name: only-runtime-112
    expression: "object.metadata.namespace == 'runtime-112'"
  validations:
  - expression: >
      object.spec.containers.all(c,
        image(c.image).registry() == 'docker.io' &&
        image(c.image).repository() == 'library/busybox')
    message: "CKS112_TRUSTED_REPO_POLICY: only docker.io/library/busybox is allowed in runtime-112"
  validationActions: [Deny]
```

---

## 6. Monitoring, Logging & Runtime Security

### AuditPolicy: orden correcto de las reglas
*Fuente: laboratorio 112, tarea 4.*

> El orden importa: el servidor API aplica la PRIMERA regla de coincidencia de arriba a abajo. Las reglas específicas deben preceder al resumen general al final.

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages: ["RequestReceived"]
rules:
# 1. Reducción de ruido para eventos de alto volumen y bajo riesgo
- level: None
  resources:
  - group: ""
    resources: ["events"]
- level: None
  nonResourceURLs: ["/healthz*", "/livez*", "/readyz*", "/version"]
# 2. Regla específica: complete ConfigMaps (el cuerpo no es sensible)
- level: RequestResponse
  namespaces: ["runtime-112"]
  resources:
  - group: ""
    resources: ["configmaps"]
# 3. Secrets: Solo metadatos, para evitar registrar cuerpos secretos
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
# 4. Registro alternativo para el API restante (debe ser el ÚLTIMO)
- level: Metadata
```

### Falco: regla personalizada (condición/salida/prioridad)
*Fuente: laboratorio 112, tarea 3.*

```yaml
- rule: CKS112 Custom Shell Marker
  desc: Detect the controlled CKS lab marker in a container process command line
  condition: spawned_process and container and proc.cmdline contains "CKS112_CUSTOM_EVENT"
  output: "CKS112 custom shell marker container=%container.id pid=%proc.pid ppid=%proc.ppid user=%user.name command=%proc.cmdline"
  priority: WARNING
```

### Falco: anular la macro `user_expected_terminal_shell_in_container_conditions`
*Fuente: laboratorio 112, tarea 7.*

```yaml
- macro: user_expected_terminal_shell_in_container_conditions
  condition: (k8s.ns.name = "runtime-112" and k8s.pod.name = "ci-runner")
  override:
    condition: replace
```

> Esto difiere de `user_shell_container_exclusions` (que pertenece a otra regla, **Run shell untrusted**). Los nombres de macros similares son fáciles de confundir.

### Falco: JSON y salida de archivo
*Fuente: laboratorio 112, tarea 7.*

```yaml
# /etc/falco/config.d/output.yaml
json_output: true
file_output:
  enabled: true
  filename: /var/log/falco/events.log
```

### `crictl`: correlación de una alerta con un Pod/espacio de nombres
*Fuente: laboratorio 112, tarea 6.*

```bash
# 1. El ID de contenedor corto y el host PID ya se extrajeron de la alerta Falco.
CONTAINER_ID=$(sudo crictl ps -a -q | awk "/^${SHORT_ID}/ {print; exit}")
sudo crictl inspect "$CONTAINER_ID" > cri-container.json
SANDBOX_ID=$(jq -r '.status.sandboxId' cri-container.json)
sudo crictl inspectp "$SANDBOX_ID" > cri-sandbox.json
POD=$(jq -r '.status.metadata.name' cri-sandbox.json)
NAMESPACE=$(jq -r '.status.metadata.namespace' cri-sandbox.json)
```

### `/proc/<PID>/`: navegando durante una investigación
*Fuente: laboratorio 112, tarea 6.*

```bash
sudo cat /proc/$HOST_PID/status
sudo tr '\0' ' ' </proc/$HOST_PID/cmdline; echo
sudo cat /proc/$HOST_PID/cgroup
sudo ps -eo pid,ppid,user,lstart,args --forest
```

> Recoge estos artefactos MIENTRAS el proceso esté activo. Una vez eliminado su Pod, el `/proc/<PID>` correspondiente desaparece permanentemente.

### Sistema de archivos raíz inmutable con `/tmp` grabable
*Fuente: laboratorio 112, tarea 5.*

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: immutable-app
  namespace: runtime-112
spec:
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: writable-tmp
      mountPath: /tmp
  volumes:
  - name: writable-tmp
    emptyDir: {}
```

---

[← Contenidos del curso](README_ES.md) · [Glosario](GLOSSARY_ES.md) · [Índice de solución de problemas (RU)](TROUBLESHOOTING_INDEX_RU.md)
