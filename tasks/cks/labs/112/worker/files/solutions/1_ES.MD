[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 112 - solución de referencia: Falco, audit-logs e inmutabilidad

Trabajamos como en el examen. Abre **dos terminales** y déjalos abiertos hasta el final del laboratorio:

- **Terminal 1 - control-plane:** `ssh control-plane`, luego `sudo -i` (en adelante todos los comandos en el nodo
  se ejecutan como root, sin `sudo`). El único nodo control plane también ejecuta workloads.
- **Terminal 2 - máquina de trabajo:** aquí `kubectl`, `scp` y las comprobaciones.

Los artefactos obtenidos en el nodo se guardan en `/tmp/art/<número de la tarea>/` en el control-plane y se
copian a la máquina de trabajo con el comando `scp` a `/var/work/tests/artifacts/<número>/`.

## Dónde encontrar ejemplos en la documentación

| Qué se necesita | Página y sección |
| :--- | :--- |
| Instalación de Falco desde apt (clave, repositorio, `apt-get install -y falco`), las variables `FALCO_DRIVER_CHOICE` / `FALCO_FRONTEND`, `systemctl enable falco-modern-bpf.service` | [Falco - Install: apt (Debian/Ubuntu), Environment variables, Systemd setup](https://falco.org/docs/setup/packages/#install-with-apt) |
| Redefinición de reglas y macros de Falco (`override: condition/output: replace/append`) | [Falco - Overriding rules: Examples of using the override section](https://falco.org/docs/concepts/rules/overriding/#examples-of-using-the-override-section) |
| Audit Policy (niveles `None`/`Metadata`/`Request`/`RequestResponse`, `omitStages`, `rules`), los flags `--audit-policy-file`, `--audit-log-path`, `--audit-log-maxage/-maxbackup/-maxsize`, el montaje `hostPath`, el webhook backend | [Kubernetes - Auditing: Audit policy, Log backend, Webhook backend](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#audit-policy) |
| `readOnlyRootFilesystem` y `emptyDir` | [Kubernetes - Configure a Security Context for a Pod or Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) |
| `NetworkPolicy` deny-all | [Kubernetes - Network Policies: Default deny all ingress and all egress traffic](https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-deny-all-ingress-and-all-egress-traffic) |
| Kyverno `ValidatingPolicy` | [Kyverno - Validating Policies](https://kyverno.io/docs/policy-types/validating-policy/) |

Primer arranque en la máquina de trabajo (terminal 2):

```bash
kubectl config use-context cluster1-admin@cluster1
export NS=runtime-112
mkdir -p /var/work/tests/artifacts/{2,3,4,5,6,9,10}
```

Primer arranque en el nodo (terminal 1):

```bash
ssh control-plane
sudo -i
mkdir -p /tmp/art/{2,3,4,6,9,10}
```

## 1. Instalación de Falco con modern eBPF

Instalamos Falco desde el repositorio APT oficial (comandos de la página Install de la documentación de
Falco). Modern eBPF no requiere compilar ni cargar a mano un kernel module.

```bash
# terminal 1 (control-plane, root)
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" >> /etc/apt/sources.list.d/falcosecurity.list
apt-get update -y
```

**Ejecuta la instalación como un comando aparte:** `apt-get` vacía el búfer de entrada del terminal, por lo que
las líneas pegadas justo detrás se pierden.

```bash
# terminal 1 (control-plane, root)
FALCO_FRONTEND=noninteractive FALCOCTL_ENABLED='' FALCO_DRIVER_CHOICE=modern_ebpf apt-get install -y falco
```

```bash
# terminal 1 (control-plane, root)
mkdir -p /etc/falco/config.d
cat > /etc/falco/config.d/engine-kind.yaml <<EOF
engine:
  kind: modern_ebpf
EOF
# El paquete instala la unit falco-modern-bpf.service, y falco.service es solo un alias de ella;
# `systemctl enable falco` sobre el alias termina con un error, por eso habilitamos la unit real.
systemctl enable --now falco-modern-bpf
falco --version; systemctl is-active falco; grep -R modern_ebpf /etc/falco
sleep 20
```

`sleep 20` hace falta porque en el primer arranque el modern eBPF probe se abre con varios
reintentos (en el journal se ven varias líneas `Opening 'syscall' source`): mientras no está
abierto, Falco no registra eventos, y la shell de la tarea 2 puede pasar desapercibida. Si
no hay alerta, repite el `exec` pasados unos segundos.

Si el servicio no arranca, primero mira `journalctl -u falco-modern-bpf -b --no-pager`.
No sustituyas el engine por un kernel module: en este laboratorio se exige precisamente `modern_ebpf`.

## 2. Regla estándar para una shell en un contenedor

```bash
# terminal 2 (máquina de trabajo)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: falco-shell
  namespace: runtime-112
spec:
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    stdin: true
    tty: true
EOF
kubectl wait -n "$NS" --for=condition=Ready pod/falco-shell --timeout=120s
kubectl exec -it -n "$NS" falco-shell -- /bin/sh
# Dentro de la shell: exit
```

Guarda el evento real de Falco: se toma del journal en el control-plane. Falco escribe el evento con
un pequeño retraso, por lo que espera un par de segundos tras salir de la shell. No crees el artefacto
a mano:

```bash
# terminal 1 (control-plane, root)
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'A shell was spawned in a container with an attached terminal' | tail -1 > /tmp/art/2/falco-shell.log
cat /tmp/art/2/falco-shell.log
```

```bash
# terminal 2
scp control-plane:/tmp/art/2/falco-shell.log /var/work/tests/artifacts/2/
```

## 3. Regla local y marker controlado

Falco ya carga `/etc/falco/falco_rules.local.yaml`; añadiremos la regla precisamente allí.
`spawned_process` conserva la compatibilidad con las reglas de Falco, y `container` no permite
que haga match el mismo marker ejecutado en el host.

```bash
# terminal 1 (control-plane, root)
cat > /etc/falco/falco_rules.local.yaml <<EOF
- rule: CKS112 Custom Shell Marker
  desc: Detect the controlled CKS lab marker in a container process command line
  condition: spawned_process and container and proc.cmdline contains "CKS112_CUSTOM_EVENT"
  output: "CKS112 custom shell marker container=%container.id pid=%proc.pid ppid=%proc.ppid user=%user.name command=%proc.cmdline"
  priority: WARNING
EOF
systemctl restart falco && systemctl is-active falco && sleep 10
```

```bash
# terminal 2
kubectl exec -n "$NS" falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT >/dev/null'
```

```bash
# terminal 1
sleep 2
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'CKS112 custom shell marker' | tail -1 > /tmp/art/3/falco-custom.log
cat /tmp/art/3/falco-custom.log
```

```bash
# terminal 2
scp control-plane:/tmp/art/3/falco-custom.log /var/work/tests/artifacts/3/
```

Tras cada `restart falco` en la solución hay un `sleep 10`: Falco carga las reglas y los metadatos de
los contenedores durante unos 5 segundos, y los eventos ocurridos antes no los escribirá en el journal.

## 4. Audit: RequestResponse para ConfigMap, Metadata para Secret

Crearemos la policy según la regla del capítulo 32: el request/response completo lo escribimos solo para
el recurso no sensible `configmaps` en `runtime-112`; para `secrets` tomamos `Metadata`, para que el cuerpo del Secret
(tokens, contraseñas) no llegue al audit log. `None` y `omitStages` realmente reducen el high-volume
noise; el catch-all final `Metadata` es fallback logging, y no supresión de ruido. El orden de las reglas es importante:
las reglas específicas van antes del catch-all. La estructura del archivo es del ejemplo de la documentación (sección Audit
policy).

```bash
# terminal 1 (control-plane, root)
cat > /etc/kubernetes/audit/policy.yaml <<EOF
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages: ["RequestReceived"]
rules:
# 1. Noise reduction: high-volume events and health probes are not forensic evidence here.
- level: None
  resources:
  - group: ""
    resources: ["events"]
- level: None
  nonResourceURLs: ["/healthz*", "/livez*", "/readyz*", "/version"]
# 2. ConfigMap: constrained forensic RequestResponse example.
- level: RequestResponse
  namespaces: ["runtime-112"]
  resources:
  - group: ""
    resources: ["configmaps"]
# 3. Secret matters for investigation, but its body must not be logged.
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
# 4. Fallback logging for the rest of the API (not noise reduction).
- level: Metadata
EOF
```

Edita `/etc/kubernetes/manifests/kube-apiserver.yaml` en el control-plane (`vim`). En el `command`
del contenedor `kube-apiserver` añade:

```yaml
- --audit-policy-file=/etc/kubernetes/audit/policy.yaml
- --audit-log-path=/var/log/kubernetes/audit/audit.log
- --audit-log-maxage=7
- --audit-log-maxbackup=3
- --audit-log-maxsize=100
```

En los `volumeMounts` del mismo contenedor añade:

```yaml
- name: audit-policy
  mountPath: /etc/kubernetes/audit
  readOnly: true
- name: audit-log
  mountPath: /var/log/kubernetes/audit
```

En `spec.volumes` añade:

```yaml
- name: audit-policy
  hostPath:
    path: /etc/kubernetes/audit
    type: Directory
- name: audit-log
  hostPath:
    path: /var/log/kubernetes/audit
    type: DirectoryOrCreate
```

```bash
# terminal 1 (control-plane, root)
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

Es un static Pod: el kubelet recreará automáticamente el API server (alrededor de un minuto, hasta entonces
`kubectl` responde `connection refused`). Espera a que esté listo:

```bash
# terminal 2: repite hasta que el comando devuelva "ok"
kubectl get --raw=/readyz
```

```bash
# terminal 1: los flags llegaron al manifest en funcionamiento
grep -E -- '--audit-(policy-file|log-path|log-max)' /etc/kubernetes/manifests/kube-apiserver.yaml
```

Crea el ConfigMap y genera ambas peticiones, luego guarda un evento JSON adecuado de cada una
como artefactos:

```bash
# terminal 2
kubectl create configmap audit-config -n "$NS" --from-literal=note=cks112 --dry-run=client -o yaml | kubectl apply -f -
kubectl get configmap audit-config -n "$NS" -o json >/dev/null
kubectl get secret audit-secret -n "$NS" -o json >/dev/null
```

```bash
# terminal 1 (control-plane, root)
# ConfigMap: RequestResponse event completo (datos no sensibles).
jq -c 'select(.level == "RequestResponse" and .objectRef.resource == "configmaps" and .objectRef.namespace == "runtime-112" and .objectRef.name == "audit-config")' /var/log/kubernetes/audit/audit.log | tail -1 > /tmp/art/4/configmap-request-response.json

# Secret: solo Metadata, sin cuerpo.
jq -c 'select(.objectRef.resource == "secrets" and .objectRef.namespace == "runtime-112" and .objectRef.name == "audit-secret")' /var/log/kubernetes/audit/audit.log | tail -1 > /tmp/art/4/secret-metadata.json
```

```bash
# terminal 2
scp control-plane:/tmp/art/4/*.json /var/work/tests/artifacts/4/
```

Comprueba que el ConfigMap está registrado con cuerpo, y el Secret solo a nivel `Metadata` y
**sin** `requestObject`/`responseObject`:

```bash
# terminal 2
jq '{level, verb, objectRef, hasBody: (has("requestObject") or has("responseObject"))}' \
  /var/work/tests/artifacts/4/configmap-request-response.json
jq '{level, verb, objectRef, hasRequestObject: has("requestObject"), hasResponseObject: has("responseObject")}' \
  /var/work/tests/artifacts/4/secret-metadata.json
```

## 5. Root filesystem inmutable

`emptyDir` da a la aplicación un lugar controlado para los archivos de runtime; el root filesystem
permanece read-only. `hostPath` no hace falta y no se admite.

```bash
# terminal 2
kubectl apply -f - <<EOF
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
EOF
kubectl wait -n "$NS" --for=condition=Ready pod/immutable-app --timeout=120s
```

Demostraremos ambas propiedades y guardaremos el mensaje de denegación:

```bash
# terminal 2
kubectl exec -n "$NS" immutable-app -- sh -c 'touch /cks-112-write-denied' > /var/work/tests/artifacts/5/rootfs-write-denied.log 2>&1
cat /var/work/tests/artifacts/5/rootfs-write-denied.log
# touch: /cks-112-write-denied: Read-only file system
kubectl exec -n "$NS" immutable-app -- sh -c 'touch /tmp/allowed && test -f /tmp/allowed'
```

## 6. Cadena mínima de containment desde el alert hasta el aislamiento

El audit backend ya funciona, por lo que un nuevo `kubectl exec` dejará API evidence. Ejecutamos
un proceso controlado de larga duración: el marker permanece en la command line el tiempo suficiente para
comprobar `/proc`. En producción un proceso sospechoso no se vuelve a ejecutar; aquí es una
planted evidence segura de un laboratorio de un solo uso.

```bash
# terminal 1 (control-plane, root): el momento de inicio de la ejecución (tomamos la hora del control-plane,
# donde luego leemos el journal)
START=$(date '+%Y-%m-%d %H:%M:%S')
```

```bash
# terminal 2
DIR=/var/work/tests/artifacts/6
kubectl exec -n "$NS" falco-shell -- \
  sh -c 'sleep 600; echo completed' CKS112_CUSTOM_EVENT >/tmp/cks112-incident-exec.log 2>&1 &
INCIDENT_EXEC_PID=$!
```

Después todo lo hacemos en el control-plane mientras el proceso esté vivo: tomamos el alert y de él el container id y
el host pid (empezamos por el alert, y no adivinamos):

```bash
# terminal 1 (control-plane, root)
cd /tmp/art/6
journalctl -u falco-modern-bpf -b --since "$START" --no-pager | grep -F 'CKS112 custom shell marker' | tail -1 > falco-alert.log
cat falco-alert.log

SHORT_ID=$(sed -n 's/.*container=\([^ ]*\).*/\1/p' falco-alert.log | tail -1)
HOST_PID=$(sed -n 's/.* pid=\([0-9][0-9]*\) .*/\1/p' falco-alert.log | tail -1)
echo "SHORT_ID=$SHORT_ID HOST_PID=$HOST_PID"

CONTAINER_ID=$(crictl ps -a -q | grep "^$SHORT_ID" | head -1)
crictl inspect $CONTAINER_ID > cri-container.json
SANDBOX_ID=$(jq -r '.status.sandboxId // .status.sandboxID // .info.sandboxID // empty' cri-container.json)
crictl inspectp $SANDBOX_ID > cri-sandbox.json
printf 'container_init_pid=%s\n' "$(jq -r '.info.pid // empty' cri-container.json)" > cri-mapping.txt

cat /proc/$HOST_PID/status > proc-status.txt
tr '\0' ' ' < /proc/$HOST_PID/cmdline > proc-cmdline.txt; echo >> proc-cmdline.txt
cat /proc/$HOST_PID/cgroup > proc-cgroup.txt
ps -eo pid,ppid,user,lstart,args --forest > process-tree.txt
```

Ahora correlacionamos el API event. El `kubectl exec` moderno funciona sobre WebSocket, por lo que en audit se
ve como `get` (con SPDY-fallback, `create`), ambas variantes sirven. Para `pods/exec` basta
`Metadata`: el command del request body puede contener un secret, por lo que `RequestResponse` aquí no hace falta.

```bash
# terminal 1 (control-plane, root)
jq -c 'select(.level == "Metadata" and (.verb == "create" or .verb == "get") and .objectRef.resource == "pods" and .objectRef.subresource == "exec" and .objectRef.namespace == "runtime-112" and .objectRef.name == "falco-shell")' /var/log/kubernetes/audit/audit.log | tail -1 > audit-exec.json
jq '{verb, level, hasRequestObject: has("requestObject")}' audit-exec.json
```

```bash
# terminal 2: recoger todos los archivos de la cadena y elaborar el summary final
scp 'control-plane:/tmp/art/6/*' /var/work/tests/artifacts/6/

SHORT_ID=$(sed -n 's/.*container=\([^ ]*\).*/\1/p' "$DIR/falco-alert.log" | tail -1)
HOST_PID=$(sed -n 's/.* pid=\([0-9][0-9]*\) .*/\1/p' "$DIR/falco-alert.log" | tail -1)
CONTAINER_ID=$(jq -r '.status.id' "$DIR/cri-container.json")
POD=$(jq -r '.status.metadata.name' "$DIR/cri-sandbox.json")
NAMESPACE=$(jq -r '.status.metadata.namespace' "$DIR/cri-sandbox.json")
NODE=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}')
CONTAINER_INIT_PID=$(jq -r '.info.pid // empty' "$DIR/cri-container.json")

cat > "$DIR/evidence-summary.txt" <<EOF
alert_rule=CKS112 Custom Shell Marker
namespace=$NAMESPACE
pod=$POD
node=$NODE
runtime=containerd
container_id=$CONTAINER_ID
container_init_pid=$CONTAINER_INIT_PID
host_pid=$HOST_PID
audit_verb=$(jq -r .verb "$DIR/audit-exec.json")
audit_subresource=exec
attack_phase=Execution
technique=Container Administration Command
containment=quarantine-and-delete
EOF
cat "$DIR/evidence-summary.txt"
```

Primero guardamos la evidence, luego aislamos el namespace a nivel de red y eliminamos el
Pod comprometido. Es una cadena mínima de containment, y no una investigación completa:
la credential revocation/rotation, la búsqueda de otros workloads y la restauración del owner/controller se realizan con
un proceso IR aparte. El último comando demuestra un outcome negativo, y no busca un texto
concreto del error.

```bash
# terminal 2
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: incident-quarantine
  namespace: runtime-112
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  ingress: []
  egress: []
EOF

kubectl delete pod falco-shell -n "$NS" --wait=true
wait "$INCIDENT_EXEC_PID" 2>/dev/null
kubectl exec -n "$NS" falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT' > "$DIR/post-containment-exec.log" 2>&1
printf 'pod=deleted\nnetworkpolicy=incident-quarantine\nexec_exit=%s\n' "$?" > "$DIR/containment.txt"
cat "$DIR/containment.txt"
# exec_exit=1 (no 0)
```

## 7. Override de un macro upstream y salida a JSON/archivo

La regla estándar **Terminal shell in container** se disparará también con una herramienta
legítima. El lugar correcto para una excepción environment-specific no es editar
la propia regla, sino hacer un override del macro upstream reservado precisamente para esta regla:
`user_expected_terminal_shell_in_container_conditions` (por defecto `(never_true)`, es decir,
no hay excepciones). No lo confundas con el `user_shell_container_exclusions` de nombre parecido:
ese pertenece a la regla aparte **Run shell untrusted** ("Shell spawned by untrusted
binary") y no afecta a **Terminal shell in container**. Usa `k8s.pod.name` y
`k8s.ns.name`, y no `container.name`: `container.name` es el nombre del **contenedor** (aquí
`app`), y no del Pod, y la coincidencia por el nombre del contenedor casi siempre da un allowlist incorrecto o demasiado
amplio.

```bash
# terminal 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- macro: user_expected_terminal_shell_in_container_conditions
  condition: (k8s.ns.name = "runtime-112" and k8s.pod.name = "ci-runner")
  override:
    condition: replace
EOF
systemctl restart falco && sleep 10
```

Crea un Pod con una shell interactiva con un nombre que ahora está excluido:

```bash
# terminal 2
kubectl apply -n runtime-112 -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ci-runner
  labels:
    app: ci-runner
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    stdin: true
    tty: true
EOF
kubectl wait -n runtime-112 --for=condition=Ready pod/ci-runner --timeout=60s
kubectl exec -n runtime-112 -it ci-runner -- sh -c 'echo shell-open; sleep 2'
```

Comprueba aparte que `immutable-app` de la tarea 5 (sin excepción) sigue dando alert: el override
no debe apagar silenciosamente la regla entera:

```bash
# terminal 2
kubectl exec -n runtime-112 -it immutable-app -- sh -c 'echo shell-open; sleep 2'
```

```bash
# terminal 1
journalctl -u falco-modern-bpf -b --no-pager -n 200 | grep -F 'A shell was spawned in a container with an attached terminal'
```

El output estándar de la regla **Terminal shell in container** no contiene `k8s.pod.name`/
`k8s.ns.name` (se puede comprobar en el control-plane: `grep -A3 "rule: Terminal shell in container" /etc/falco/falco_rules.yaml`
mostrará el `output` sin esos campos). Sin la evidence de Pod/namespace en el propio alert, la correlation fiable
de un disparo concreto con un Pod concreto es imposible: un `grep` de texto por el nombre del Pod en el journal
simplemente no encontrará coincidencias. Añadimos estos campos mediante el mismo mecanismo `override`, pero con
`output: append` en lugar de `condition: replace`:

```bash
# terminal 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: Terminal shell in container
  output: ' k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name'
  override:
    output: append
EOF
systemctl restart falco && sleep 10
```

En `/etc/falco/config.d/` habilita el formato JSON y la salida a archivo. Falco 0.38+ por defecto
recoge los `config_files` de este directorio; añadir directamente a `falco.yaml` crea
claves top-level duplicadas al repetir la ejecución y sobrevive peor a la actualización del paquete:
`config.d` está pensado precisamente para adiciones locales:

```bash
# terminal 1 (control-plane, root)
mkdir -p /var/log/falco /etc/falco/config.d
cat > /etc/falco/config.d/cks112-output.yaml <<EOF
json_output: true
file_output:
  enabled: true
  filename: /var/log/falco/events.log
EOF
systemctl restart falco && sleep 10
```

Confirmamos de forma estructurada, mediante `output_fields`, y no con un `grep` de texto por el nombre del Pod:
esto funciona de forma fiable con independencia de cómo esté formateada exactamente la línea `output`:

```bash
# terminal 2
kubectl exec -n runtime-112 -it immutable-app -- sh -c 'echo shell-open; sleep 2'
```

```bash
# terminal 1 (control-plane, root)
sleep 2
tail -n 20 /var/log/falco/events.log \
  | jq -c 'select(.rule == "Terminal shell in container" and .output_fields["k8s.pod.name"] == "immutable-app" and .output_fields["k8s.ns.name"] == "runtime-112")' \
  | tail -1 \
  | jq '{pod: .output_fields["k8s.pod.name"], ns: .output_fields["k8s.ns.name"]}'
# {"pod": "immutable-app", "ns": "runtime-112"}
```

## 8. Audit webhook backend

`audit-receiver` ya lo desplegó el script de arranque. Crea un webhook kubeconfig que apunte
a su Service; para el laboratorio se admite HTTP, en producción el webhook requiere HTTPS y client
certificate (capítulo 32).

```bash
# terminal 2: ClusterIP del Service audit-receiver
kubectl get svc audit-receiver -n runtime-112 -o jsonpath='{.spec.clusterIP}'; echo
```

```bash
# terminal 1 (control-plane, root)
RECEIVER_IP=10.111.15.20     # escribe el ClusterIP que mostró el terminal 2
cat > /etc/kubernetes/audit/webhook-config.yaml <<EOF
apiVersion: v1
kind: Config
clusters:
- name: audit-receiver
  cluster:
    server: http://${RECEIVER_IP}:8080/audit
users:
- name: kube-apiserver-audit
  user: {}
contexts:
- name: audit-webhook
  context:
    cluster: audit-receiver
    user: kube-apiserver-audit
current-context: audit-webhook
EOF
```

Añade los flags del webhook al static manifest, **conservando** los flags del file backend ya configurados
en la tarea 4: el webhook complementa el log local, y no lo sustituye:

```bash
# terminal 1 (control-plane, root)
mkdir -m 700 /etc/kubernetes/backup
cp -p /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/backup/kube-apiserver.yaml.pre-webhook
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Añadir al command:
#   - --audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml
#   - --audit-webhook-batch-max-wait=1s
```

Espera a que la API se recupere y ejecuta una petición auditable:

```bash
# terminal 2: repite readyz hasta que devuelva "ok", luego una petición auditable
kubectl get --raw=/readyz
kubectl get configmap audit-config -n runtime-112 -o json >/dev/null
```

Comprueba que el webhook entregó el evento al receptor:

```bash
# terminal 2
sleep 3
RECEIVER_POD=$(kubectl get pod -n runtime-112 -l app=audit-receiver -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n runtime-112 "$RECEIVER_POD" --tail=50 | grep -A5 objectRef
```

Comprobación intermedia:

```bash
check_result
```

## 9. Tarea de integración: elusión del admission mediante containerd y detección mediante Falco

Esta tarea vincula Supply Chain Security (laboratorio 111, capítulo 26) con el Runtime Security de este
laboratorio: la comprobación de admission (Kyverno) no ve un contenedor si se creó directamente mediante
containerd, esquivando kube-apiserver. Falco, a diferencia del admission controller, funciona a
nivel de kernel syscalls y ve **todos** los contenedores del nodo con independencia de cómo se hayan
lanzado.

**Importante: no lo confundas con el laboratorio 111**: allí la policy comprueba la firma criptográfica
(Cosign). Aquí la policy comprueba solo el registry/repository allowlist: un admission
control más simple sin signature/attestor. Ambos comparten el mismo principio: el admission funciona
solo en el API admission path.

Los lab-owned local registry names los preparó el bootstrap (no el Docker Hub público: el controlled
abuse fixture de esta tarea debe ser safe y lab-owned, y no depender de la disponibilidad de un registry
externo en el momento de la comprobación). Están en `/etc/cks112/registry.env` en el control-plane; cárgalos
en ambos terminales:

```bash
# terminal 1 (control-plane, root)
source /etc/cks112/registry.env
echo "CKS112_REGISTRY=$CKS112_REGISTRY CKS112_TRUSTED_REPO=$CKS112_TRUSTED_REPO"
START_TS=$(date '+%Y-%m-%d %H:%M:%S')     # el momento de inicio de la ejecución
install-kyverno
```

```bash
# terminal 2
scp control-plane:/etc/cks112/registry.env /tmp/cks112-registry.env
source /tmp/cks112-registry.env
echo "CKS112_REGISTRY=$CKS112_REGISTRY CKS112_TRUSTED_REPO=$CKS112_TRUSTED_REPO"
```

(`install-kyverno` es la misma versión de Kyverno que en el laboratorio 111.)

Creamos una `ValidatingPolicy` native con un allowlist sobre el trusted registry. Usamos la Kyverno CEL
Image library (`image(...).registry()`/`.repository()`) para una comparación exacta, y no
`startsWith`; de lo contrario `${CKS112_TRUSTED_REPO}-evil` también pasaría la policy, porque su
image string simplemente empieza por la subcadena permitida. El mensaje de denial contiene
el marcador único `CKS112_TRUSTED_REPO_POLICY`, para que BATS después pueda distinguir precisamente esta
policy de cualquier otro admission webhook/policy del clúster:

```bash
# terminal 2
kubectl apply -f - <<YAML
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-trusted-registry-runtime-112
spec:
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      resources: ["pods", "pods/ephemeralcontainers"]
      operations: ["CREATE", "UPDATE"]
  matchConditions:
  - name: only-runtime-112
    expression: "object.metadata.namespace == 'runtime-112'"
  validations:
  - expression: >
      object.spec.containers.all(c,
        image(c.image).registry() == '${CKS112_REGISTRY}' &&
        image(c.image).repository() == '${CKS112_TRUSTED_REPO}') &&
      (!has(object.spec.initContainers) || object.spec.initContainers.all(c,
        image(c.image).registry() == '${CKS112_REGISTRY}' &&
        image(c.image).repository() == '${CKS112_TRUSTED_REPO}')) &&
      (!has(object.spec.ephemeralContainers) || object.spec.ephemeralContainers.all(c,
        image(c.image).registry() == '${CKS112_REGISTRY}' &&
        image(c.image).repository() == '${CKS112_TRUSTED_REPO}'))
    message: "CKS112_TRUSTED_REPO_POLICY: only ${CKS112_TRUSTED_IMAGE} is allowed in runtime-112"
  validationActions: [Deny]
YAML
```

Confirmamos el admission denial para una imagen fuera del allowlist:

```bash
# terminal 2 (espera unos 10 segundos tras crear la policy)
kubectl apply -n runtime-112 -f - > /var/work/tests/artifacts/9/admission-deny.txt 2>&1 <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: blocked-attempt
spec:
  containers:
  - name: app
    image: ${CKS112_UNTRUSTED_IMAGE}
    imagePullPolicy: IfNotPresent
    command: ["sleep", "60"]
YAML
cat /var/work/tests/artifacts/9/admission-deny.txt
# Error from server: ... CKS112_TRUSTED_REPO_POLICY: only ... is allowed in runtime-112
```

Ahora modelamos un camino que el admission controller no ve: el contenedor se crea directamente
en el container runtime mediante CRI, esquivando por completo kube-apiserver. Para ello en el control-plane hay
un helper `cks112-run <imagen> <id> '<comando>'` (un wrapper de `crictl runp/create/start`) y
`cks112-rm <id>` para la limpieza. Por qué no `ctr run`: los contenedores creados mediante `ctr` no son
conocidos por CRI, y Falco para ellos siempre escribe `container.image.repository = <NA>`: las imágenes trusted y
untrusted serían indistinguibles. Un contenedor creado mediante CRI, Falco lo ve con la imagen.
Cada ejecución recibe un sufijo único `$RUN_ID`, y todos los ID creados por ella usan
ese sufijo, por lo que una nueva ejecución no chocará con los restos del intento anterior:

```bash
# terminal 1 (control-plane, root)
RUN_ID="$(date +%s%N)"
BYPASS_1="cks112-bypass-1-$RUN_ID"
OBSERVE_REPO="cks112-observe-repo-$RUN_ID"
PROBE_ALLOWED="cks112-probe-allowed-$RUN_ID"
BYPASS_2="cks112-bypass-2-$RUN_ID"
PREFIX_TRAP="cks112-prefix-trap-$RUN_ID"

# CKS112_UNTRUSTED_IMAGE ya está en el almacén local de containerd tras el bootstrap: no hace falta pull.
cks112-run $CKS112_UNTRUSTED_IMAGE $BYPASS_1 'echo CKS112_CTR_BYPASS; sleep 5'
```

> `container.id != host` es obligatorio: el comando `cks112-run ... 'echo CKS112_CTR_BYPASS'` se
> ejecuta en el host, y su command line contiene el marker. Sin esta condición la regla
> se dispararía con el proceso de lanzamiento del host (su repository está vacío, es decir, no es igual a trusted),
> e incluso una imagen de confianza daría un alert falso.
>
> Falco muestra para la imagen no el tag con el que se ejecutó el contenedor, sino el primer
> nombre de imagen por orden alfabético (una imagen puede tener varios nombres). Por eso los nombres de las imágenes de laboratorio usan
> el registry-host `cks112.local:5000`, que se ordena antes que `docker.io`.

Antes de escribir la condición exacta, determinamos el valor REAL observed de
`%container.image.repository` de la imagen de confianza en este stack containerd/Falco:
no lo suponemos de antemano. Distintas versiones de container runtime/Falco pueden formar
este campo de forma distinta (con el hostname del registry o sin él), por lo que la única forma
fiable es ejecutar un contenedor de confianza con una observe-regla temporal y ver qué
escribe realmente Falco:

```bash
# terminal 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: CKS112 Observe Trusted Repository Value
  desc: Temporary rule to capture the exact observed container.image.repository string for the trusted image
  condition: spawned_process and container.id != host and proc.cmdline contains "CKS112_OBSERVE_REPO"
  output: "CKS112 observed repository=%container.image.repository tag=%container.image.tag"
  priority: INFORMATIONAL
EOF
systemctl restart falco && sleep 10

# CKS112_TRUSTED_IMAGE ya está localmente tras el bootstrap: no hace falta pull.
cks112-run $CKS112_TRUSTED_IMAGE $OBSERVE_REPO 'echo CKS112_OBSERVE_REPO; sleep 5'
sleep 3
TRUSTED_REPO=$(journalctl -u falco-modern-bpf -b --no-pager -n 50 | grep -oP 'CKS112 observed repository=\K[^ ]+' | tail -1)
echo "TRUSTED_REPO=$TRUSTED_REPO"
cks112-rm $OBSERVE_REPO
```

Guarda el valor `$TRUSTED_REPO` (por ejemplo `cks112/trusted` o
`cks112.local:5000/cks112/trusted`: precisamente lo que realmente mostró tu versión de Falco/containerd)
como evidence, para que la condición de abajo esté vinculada de forma comprobable al valor observado,
y no a una suposición:

```bash
# terminal 1
echo "$TRUSTED_REPO" > /tmp/art/9/observed-trusted-repo.txt
cat /tmp/art/9/observed-trusted-repo.txt
```

Ahora añadimos la regla final a continuación de la observe-regla temporal (`>>`, sin
sobrescribir el archivo, para no perder las reglas de las tareas 3 y 7). La condición usa la comparación
**exacta** con el `$TRUSTED_REPO` observado, y no una comprobación `startswith`/prefix:
`not container.image.repository startswith "$TRUSTED_REPO"` dejaría pasar (no notaría)
un repository como `<TRUSTED_REPO>-evil`, porque su nombre simplemente EMPIEZA por la subcadena
permitida; es decir, Falco lo consideraría parte del allowlist, aunque en realidad esté fuera del
repository admisible. Es la misma trampa que evita la Kyverno policy de arriba mediante `==`, y no
`startsWith`; la condición de admission y la condición de Falco deben comprobar la misma repository
property de la misma forma (exact) y con el mismo valor observado; de lo contrario no
son equivalentes como security control:

```bash
# terminal 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: CKS112 Runtime Bypass of Admission
  desc: Process spawned in a container whose image is outside the runtime-112 trusted registry allowlist, indicating a container started outside kube-apiserver/admission (e.g. via crictl/CRI directly)
  condition: >
    spawned_process and
    container.id != host and
    proc.cmdline contains "CKS112_CTR_BYPASS" and
    container.image.repository != "$TRUSTED_REPO"
  output: >
    CKS112 runtime bypass of admission detected
    (command=%proc.cmdline container_id=%container.id
    repo=%container.image.repository tag=%container.image.tag
    pid=%proc.pid ppid=%proc.ppid user=%user.name)
  priority: CRITICAL
  tags: [cks112, supply_chain, admission_bypass]
EOF
systemctl restart falco && sleep 10
```

Antes de repetir el bypass con una imagen untrusted, comprobamos ambos casos controlados, para
demostrar que la comparación realmente es exacta, y no prefix-based. Primero la imagen de confianza: para
ella no debe haber alerta (negative control):

```bash
# terminal 1 (control-plane, root)
cks112-run $CKS112_TRUSTED_IMAGE $PROBE_ALLOWED 'echo CKS112_CTR_BYPASS; sleep 5'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep -F 'CKS112 runtime bypass of admission' | grep -F 'CKS112_CTR_BYPASS' > /tmp/art/9/probe-trusted.log
wc -l < /tmp/art/9/probe-trusted.log        # 0: no hay alerta para el repository permitido
cks112-rm $PROBE_ALLOWED
```

Retiramos el primer container/task antes de repetir, para no dejar un proceso "colgado", y
lanzamos el segundo con un nuevo ID único: para él la alerta es obligatoria:

```bash
# terminal 1 (control-plane, root)
cks112-rm $BYPASS_1

cks112-run $CKS112_UNTRUSTED_IMAGE $BYPASS_2 'echo CKS112_CTR_BYPASS; sleep 5'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep 'CKS112 runtime bypass of admission' > /tmp/art/9/falco-bypass-attempt.log
cp /tmp/art/9/falco-bypass-attempt.log /tmp/art/9/probe-untrusted.log
cks112-rm $BYPASS_2
```

Por último, demostramos el propio prefix-trap: un repository construido como `${TRUSTED_REPO}-evil`
EMPIEZA por la misma subcadena que el `$TRUSTED_REPO` permitido, pero no es igual a él exactamente.
Si la Falco condition usara `startswith` (como en la variante ingenua
de esta regla), esa imagen pasaría DESAPERCIBIDA: precisamente por eso la condición corregida
`!=` debe capturarla. La imagen prefix-trap la preparó el bootstrap (`$CKS112_PREFIX_IMAGE`,
un digest aparte):

```bash
# terminal 1 (control-plane, root)
cks112-run $CKS112_PREFIX_IMAGE $PREFIX_TRAP 'sleep 2; echo CKS112_CTR_BYPASS; sleep 6'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep -F 'CKS112 runtime bypass of admission' | grep -F "${TRUSTED_REPO}-evil" > /tmp/art/9/probe-prefix.log
cat /tmp/art/9/probe-prefix.log >> /tmp/art/9/falco-bypass-attempt.log
cks112-rm $PREFIX_TRAP
```

```bash
# terminal 2: recoger los archivos de la tarea 9
scp 'control-plane:/tmp/art/9/*' /var/work/tests/artifacts/9/
```

> **Estructura de los archivos de evidence de la tarea 9.** `falco-bypass-attempt.log` es el artifact
> combinado principal que se verifica en la aceptación automática (contiene ambas alertas:
> untrusted y prefix-trap, pero no debe contener una alerta para el trusted repo). Además
> cada probe escribe su propio archivo para el diagnóstico manual: `probe-trusted.log` (debe estar
> vacío: ese es el negative control), `probe-untrusted.log` y `probe-prefix.log`.

La conclusión clave de esta tarea: el registry allowlist en admission y Falco en runtime no son
capas intercambiables, sino complementarias. El admission detiene el camino a través de la Kubernetes
API, pero no sabe nada de los procesos lanzados directamente mediante el container runtime en el nodo;
Falco no puede **bloquear** de antemano la creación de ese contenedor, pero lo ve tras el
lanzamiento con independencia de qué API (o de su ausencia) se haya usado. El mismo principio
se aplica a la signature verification del laboratorio 111: la diferencia es solo que allí la policy
comprueba la firma, y aquí simplemente el registry/repository. Una conclusión adicional de
la comprobación prefix-trap de arriba: la Falco condition y la Kyverno CEL policy deben usar la MISMA
semántica de comparación (`==`/`!=`, y no `startsWith`/prefix); de lo contrario dejan de ser
security-controles equivalentes, aunque ambas comprueben formalmente "el mismo" repository.

## 10. Detectar el acceso a `/dev/mem` mediante una file/device-open condition

Las tareas 3, 7 y 9 construyeron la condition en torno a `spawned_process`/`proc.cmdline`: detección
por el LANZAMIENTO de un proceso y sus argumentos. Aquí se usa una clase esencialmente distinta
de condición de Falco: detección por la APERTURA de un archivo/dispositivo concreto, con independencia de
qué proceso y con qué argumentos de línea de comandos lo haga.

El Deployment `mem-scanner` (2 réplicas) ya lo desplegó el bootstrap; ambas réplicas periódicamente
abren `/dev/mem` desde dentro del contenedor. La ruta `/dev/mem` dentro del contenedor es un synthetic
safe fixture (el backing device en realidad es el `/dev/null` del host, y no la memoria
física real del host); para una condición de Falco por el nombre de archivo (`fd.name = /dev/mem`) eso es indistinguible:
se detecta el propio syscall `open`/`openat`/`openat2`. Añade la regla en el
`control-plane`:

```bash
# terminal 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF
- rule: CKS112 Container access to /dev/mem
  desc: Detect an open of /dev/mem from a container process
  condition: >
    evt.type in (open, openat, openat2) and
    fd.name = /dev/mem and
    container.id != host
  output: >
    CKS112 Container access to /dev/mem
    (container_id=%container.id k8s_pod=%k8s.pod.name k8s_ns=%k8s.ns.name
    proc=%proc.name pid=%proc.pid user=%user.name)
  priority: CRITICAL
  tags: [container, mitre_privilege_escalation, mitre_defense_evasion]
EOF
systemctl restart falco && sleep 10
```

Espera al siguiente ciclo periódico de `mem-scanner` (cada ~15 segundos) y encuentra el
disparo. El identificador del Pod tómalo DEL propio alert (`k8s_pod=`), y no adivines de antemano
cuál de las dos réplicas es la culpable: es la misma regla básica "empieza por el
alert" que en la tarea 6:

```bash
# terminal 1 (control-plane, root)
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'CKS112 Container access to /dev/mem' | tail -1 > /tmp/art/10/falco-devmem.log
cat /tmp/art/10/falco-devmem.log
exit   # de root
exit   # del control-plane
```

```bash
# terminal 2
scp control-plane:/tmp/art/10/falco-devmem.log /var/work/tests/artifacts/10/
```

Una vez confirmada la detección por el propio Falco (y no por el Pod manifest), guarda el Pod
nombrado en el alert y asegúrate de que realmente pertenece al ReplicaSet del Deployment
`mem-scanner` antes del escalado:

```bash
# terminal 2
ALERT_POD=$(sed -n 's/.*k8s_pod=\([^ ]*\).*/\1/p' /var/work/tests/artifacts/10/falco-devmem.log | tail -1)
echo "$ALERT_POD"
kubectl get pod "$ALERT_POD" -n runtime-112 -o json > /var/work/tests/artifacts/10/detected-pod.json
```

Después detenemos el workload:

```bash
# terminal 2
kubectl scale deployment mem-scanner -n runtime-112 --replicas=0
kubectl get deployment mem-scanner -n runtime-112 -o json > /var/work/tests/artifacts/10/scaled-down.json
jq '.spec.replicas' /var/work/tests/artifacts/10/scaled-down.json
# se espera: 0
```

`container.id != host` en la condición no es un detalle decorativo: sin ella la regla se dispararía
también con procesos de sistema legítimos del nodo (por ejemplo, herramientas de diagnóstico de memoria),
lanzados fuera de contenedores, creando false positives ruidosos en cada nodo del clúster.

Al final ejecuta `check_result`.
