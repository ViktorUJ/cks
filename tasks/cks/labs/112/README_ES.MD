[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 112 - Runtime: Falco, audit-logs e immutable root filesystem

## Objetivo

En este laboratorio de CKS configurarás el control de los eventos de runtime en el nodo y el audit-logging de la API
del control plane, y después harás el workload inmutable en runtime. El trabajo se hace en un solo
nodo: el `control-plane` es a la vez el workload-node, por lo que Falco ve los eventos
de los Pods de prueba, y kube-apiserver está en el static Pod manifest.

## Compruébate antes de empezar

<details>
<summary>1. ¿Por qué el audit log de Kubernetes no puede sustituir a Falco para la detección en runtime?</summary>

El audit log registra eventos a nivel de REQUEST hacia el API server (quién, qué y cuándo solicitó mediante `kubectl`/API): es evidence a nivel del control plane. Falco, en cambio, observa las LLAMADAS AL SISTEMA (syscalls) dentro de los contenedores en funcionamiento en el nodo: por ejemplo, la apertura de una shell, el spawn de un proceso, la escritura en un archivo. Una acción del tipo `docker exec`/`crictl exec` o un lanzamiento directo mediante `ctr` en el nodo NO pasa en absoluto por la Kubernetes API y no llegará al audit log, pero Falco la verá como un evento de syscall.
</details>

<details>
<summary>2. ¿Cuál es la diferencia entre los niveles `RequestResponse` y `Metadata` de la audit-política y por qué para Secret hace falta precisamente `Metadata`?</summary>

`RequestResponse` registra el cuerpo completo de la petición Y de la respuesta, incluido el contenido del recurso. `Metadata` registra solo los metadatos de la petición (quién, cuándo, qué recurso, qué verb) SIN cuerpo. Para `secrets` esto es crítico: `RequestResponse` registraría el valor del propio secret (codificado en base64, pero igualmente datos sensibles) en el audit log como un archivo legible en el disco: esto crea una nueva superficie de fuga. `Metadata` da un rastro forensic ("quién leyó este Secret y cuándo") sin copiar el propio secret al log.
</details>

<details>
<summary>3. ¿Por qué `readOnlyRootFilesystem: true` no equivale a una protección completa frente al compromiso de un contenedor en runtime?</summary>

`readOnlyRootFilesystem` bloquea la escritura en el sistema de archivos raíz del contenedor, lo que impide al atacante modificar los binarios de la aplicación o instalar persistence en el disco del contenedor. Pero NO impide: (a) los writable volumes/emptyDir que el propio Pod monta explícitamente (por ejemplo `/tmp`), (b) la ejecución de acciones en la memoria del proceso (RCE sin escritura en disco), (c) los ataques de red desde dentro del contenedor, (d) la lectura de Secret/ConfigMap ya montados. La inmutabilidad del rootfs es una capa de protección, no un aislamiento completo.
</details>

## Relación con el curso

- [Capítulo 29. Análisis de comportamiento en tiempo de ejecución: Falco](../../course/29/es.md)
- [Capítulo 30. Detección de amenazas e investigación de las fases del ataque](../../course/30/es.md)
- [Capítulo 31. Inmutabilidad de los contenedores en runtime](../../course/31/es.md)
- [Capítulo 32. Audit-logs de Kubernetes](../../course/32/es.md)
- [Capítulo 26. Registries, firma y validación de artefactos](../../course/26/es.md) - la tarea 9 vincula el admission-control del registry allowlist con la detección en runtime de su elusión (no la signature verification: esa la comprueba el laboratorio 111).

## Infraestructura

| Componente | Finalidad |
|---|---|
| `k8s-1` | Kubernetes `1.36.0` de un solo nodo, containerd y Calico; nombre del nodo `control-plane` |
| `worker` | máquina de trabajo con `kubectl`, `check_result` y acceso SSH `ssh control-plane` |
| `runtime-112` | namespace preparado; en él ya hay un Secret `audit-secret` |

El bootstrap deliberadamente **no** instala Falco y **no** habilita el audit backend. Solo
prepara el directorio `/etc/kubernetes/audit`, el directorio de logs
`/var/log/kubernetes/audit` y un Secret para una petición controlada a la API. No cambies el CNI,
la versión del clúster, el Secret ni los manifests de Kubernetes fuera de la tarea 4.

## Despliegue

```bash
TASK=112 make run_cks_task
```

En la máquina de trabajo:

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
ssh control-plane 'sudo -n true'
```

## Cómo trabajar con el nodo

Abre dos terminales: el **terminal 1** es `ssh control-plane`, luego `sudo -i` (operaciones sobre el nodo:
Falco, audit, `crictl`, `/proc`), el **terminal 2** es la máquina de trabajo (`kubectl`, `scp`, comprobaciones).
Los artefactos obtenidos en el nodo guárdalos en un archivo en el `control-plane` y cópialos a la máquina de trabajo
con el comando `scp` a `/var/work/tests/artifacts/<número de la tarea>/`.

## Tareas

Antes del containment es útil evaluar mentalmente el blast radius: si el ServiceAccount
del Pod comprometido puede leer Secrets, crear workload o llegar a otros
namespace. Esto se puede y conviene comprobar rápido con `kubectl auth can-i` en nombre del
ServiceAccount `falco-shell` como paso adicional; no es obligatorio, no influye en los
criterios de aceptación y no se comprueba.

---
| **1** | **Instalar y ejecutar Falco en el workload-node** |
| :---: | :--- |
| Qué hacemos | • En el `control-plane` instala el paquete de Falco del repositorio oficial de Falco y arranca el servicio.<br/>• Usa el modern eBPF engine; no instales el kernel module a mano.<br/>• Habilita el servicio mediante systemd. |
| Criterios de aceptación | • `falco --version` se ejecuta<br/>• `systemctl is-active falco` devuelve `active`<br/>• La configuración contiene `engine.kind: modern_ebpf` |

<details>
<summary>💡 Pista para la tarea 1</summary>

El modern eBPF engine se configura mediante `engine.kind: modern_ebpf` en `/etc/falco/falco.yaml` (y no mediante un kernel module driver aparte, que hace falta para el legacy engine); si tras la instalación Falco no arranca o falla al iniciarse, comprueba `journalctl -u falco-modern-bpf` (el paquete instala la unit `falco-modern-bpf.service`, y `falco.service` es solo un alias de ella: `systemctl status/restart falco` funciona, pero `journalctl -u falco` está vacío) en busca de errores de carga del eBPF program, que pueden indicar un kernel incompatible.
</details>

---
| **2** | **Registrar el evento estándar de shell en un contenedor** |
| :---: | :--- |
| Qué hacemos | • Crea en `runtime-112` un Pod `falco-shell` con `busybox:1.36`, déjalo Running (`sleep 3600`) y habilita `stdin: true`, `tty: true`.<br/>• Abre en él un `/bin/sh` interactivo y espera a la regla de Falco **Terminal shell in container**.<br/>• Guarda la línea adecuada del journal de Falco (se lee en el `control-plane`) en un archivo en el nodo y cópiala con `scp` a `/var/work/tests/artifacts/2/falco-shell.log` en la máquina de trabajo. |
| Criterios de aceptación | • El Pod `falco-shell` Running<br/>• El artefacto no está vacío y contiene la línea de alerta `A shell was spawned in a container with an attached terminal` (así es como la regla **Terminal shell in container** imprime el evento en la salida de texto de Falco 0.45; el nombre de la regla solo está en la salida JSON)<br/>• El evento debe haberlo recibido Falco, y no haberse escrito a mano |

<details>
<summary>💡 Pista para la tarea 2</summary>

Simplemente crear un Pod con `stdin: true, tty: true` no basta: hay que abrir REALMENTE una sesión interactiva (`kubectl exec -it falco-shell -- /bin/sh`), para que Falco registre precisamente el spawn de un proceso shell dentro del contenedor. Busca el evento mediante `journalctl -u falco-modern-bpf --no-pager | grep "shell was spawned"` en el `control-plane` (mediante SSH desde el worker), y no intentes escribir la línea en el archivo a mano: el test espera el timestamp/formato real del journal.
</details>

---
| **3** | **Añadir e invocar una custom Falco rule** |
| :---: | :--- |
| Qué hacemos | • En el `control-plane` añade a `/etc/falco/falco_rules.local.yaml` una regla con el nombre `CKS112 Custom Shell Marker`.<br/>• Debe capturar un spawned process en un contenedor cuyo `proc.cmdline` contenga `CKS112_CUSTOM_EVENT`.<br/>• Debe imprimir la frase exacta `CKS112 custom shell marker` junto con `container=%container.id`, `pid=%proc.pid`, `ppid=%proc.ppid`, `user=%user.name` y `command=%proc.cmdline`.<br/>• Reinicia Falco.<br/>• Ejecuta en `falco-shell` cualquier comando corto que tenga el marker en su línea de comandos, por ejemplo: `kubectl exec -n runtime-112 falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT'`.<br/>• Encuentra en el journal de Falco en el `control-plane` la línea de este disparo (en ella está `CKS112 custom shell marker`), guárdala en un archivo en el nodo y cópiala con `scp` a `/var/work/tests/artifacts/3/falco-custom.log`. La línea debe ser una línea real del journal; una escrita a mano no se acepta. |
| Criterios de aceptación | • El archivo local de reglas existe, contiene el nombre de la regla, la condición del marker y los identificadores de investigación<br/>• El servicio Falco está activo<br/>• El artefacto journal real contiene el marker, el container ID y el PID |

<details>
<summary>💡 Pista para la tarea 3</summary>

Una custom rule en `falco_rules.local.yaml` requiere una `condition` que use `spawned_process` (o `evt.type=execve`) junto con `proc.cmdline contains "CKS112_CUSTOM_EVENT"`: sin la condición base por tipo de evento la regla puede no dispararse en absoluto o dispararse con eventos incorrectos. Tras editar el archivo, ejecuta `systemctl restart falco` para una confirmación determinista de que las reglas se aplicaron. En el Falco actual también es posible un reload automático con `watch_config_files: true` habilitado, pero en este laboratorio se usa un restart explícito.
</details>

---
| **4** | **Habilitar el audit-logging: RequestResponse para ConfigMap, Metadata para Secret** |
| :---: | :--- |
| Qué hacemos | • En el `control-plane` crea `/etc/kubernetes/audit/policy.yaml`. La policy debe registrar `RequestResponse` **solo en el namespace `runtime-112`** para el core resource `configmaps` (un ejemplo forensic controlado sobre un recurso no sensible).<br/>• Para el core resource `secrets` usa solo `Metadata`, **para que el cuerpo del Secret no llegue al journal**.<br/>• Reduce realmente el ruido con reglas `None` explícitas para el tráfico de alto volumen/bajo riesgo y con `omitStages: [RequestReceived]`.<br/>• Termina la policy con un catch-all seguro `Metadata` como *fallback logging*, y no como supresión de ruido.<br/>• En el static manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` añade `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`, `--audit-log-path=/var/log/kubernetes/audit/audit.log` y la rotación (`--audit-log-maxage`, `--audit-log-maxbackup`, `--audit-log-maxsize`).<br/>• Añade los hostPath volume/volumeMount necesarios para el directorio de policy y el directorio de logs. Espera a que la API se recupere.<br/>• Crea un ConfigMap `audit-config` en `runtime-112`, léelo (`kubectl get configmap audit-config -n runtime-112 -o json`) y guarda el RequestResponse event en `/var/work/tests/artifacts/4/configmap-request-response.json`.<br/>• Después lee `kubectl get secret audit-secret -n runtime-112 -o json` y guarda su Metadata event en `/var/work/tests/artifacts/4/secret-metadata.json`. Los Events se toman del audit log en el `control-plane`: guárdalos en el nodo y cópialos con `scp`. |
| Criterios de aceptación | • Kube-apiserver healthy<br/>• El Static manifest contiene ambos flags de audit y los montajes<br/>• La policy establece `RequestResponse` para `configmaps` y `Metadata` para `secrets`<br/>• En `/var/work/tests/artifacts/4/configmap-request-response.json` hay un RequestResponse event de ConfigMap<br/>• En `/var/work/tests/artifacts/4/secret-metadata.json` hay un evento de Secret de nivel `Metadata` **sin los campos `requestObject`/`responseObject`** (el cuerpo del Secret no está registrado) |

<details>
<summary>💡 Pista para la tarea 4</summary>

El orden de las reglas en la audit policy importa: Kubernetes aplica la PRIMERA regla que coincida, de arriba abajo, por lo que la regla específica para `configmaps`/`secrets` en `runtime-112` debe ir ANTES del catch-all general `Metadata` al final del archivo: si el catch-all va el primero, "interceptará" todas las peticiones antes que las reglas específicas. Tras editar el static manifest, el kubelet recogerá por sí mismo los cambios (no hace falta `kubectl apply`/restart), pero espera a que `kubectl get --raw=/readyz` vuelva a devolver éxito antes de continuar.
</details>

---
| **5** | **Crear un Pod con el root filesystem de solo lectura** |
| :---: | :--- |
| Qué hacemos | • Crea en `runtime-112` un Pod `immutable-app`: contenedor `app`, imagen `busybox:1.36`, `sleep 3600`.<br/>• En el contenedor habilita `securityContext.readOnlyRootFilesystem: true`.<br/>• Crea un `emptyDir` `writable-tmp` y móntalo en `/tmp` sin `readOnly: true`. No uses `hostPath`.<br/>• Demuestra que `touch /cks-112-write-denied` no tiene éxito y `touch /tmp/allowed` sí; guarda el resultado de la denegación en `/var/work/tests/artifacts/5/rootfs-write-denied.log`. |
| Criterios de aceptación | • Pod Running<br/>• Root filesystem read-only<br/>• `/tmp` es un `emptyDir` writable<br/>• En el Pod no hay `hostPath`<br/>• La escritura en rootfs está bloqueada, en `/tmp` está permitida<br/>• El artefacto no está vacío |

<details>
<summary>💡 Pista para la tarea 5</summary>

Guarda precisamente la SALIDA DE ERROR del comando `touch /cks-112-write-denied` (`Read-only file system` en stderr), y no simplemente el hecho de que el comando terminó con un código distinto de cero: el test comprueba el contenido del log. No confundas `emptyDir` (efímero, vive con el Pod) con `hostPath` (persistente en el nodo, prohibido en esta tarea): ambos "resuelven" técnicamente la tarea de un directorio writable, pero solo el primero está permitido aquí.
</details>

---
| **6** | **Cadena mínima de containment desde el alert hasta el aislamiento** |
| :---: | :--- |
| Qué hacemos | • Tras habilitar el audit backend, ejecuta en `falco-shell` un proceso controlado de larga duración, en cuya línea de comandos esté `CKS112_CUSTOM_EVENT`, por ejemplo: `kubectl exec -n runtime-112 falco-shell -- sh -c 'sleep 600; echo completed' CKS112_CUSTOM_EVENT &`. El proceso vive 10 minutos: mientras esté vivo, se puede tomar su `/proc/<PID>`.<br/>• **Empieza la investigación por un nuevo Falco alert**, y no por el Pod manifest. Del alert extrae el short container ID y el host PID.<br/>• En el `control-plane` mediante `crictl ps/inspect/inspectp` correlaciona container → Pod sandbox → namespace/Pod; mediante la Kubernetes API determina el nodo. Guarda `crictl inspect` e `inspectp`.<br/>• Mientras el proceso esté vivo, guarda `/proc/<PID>/status`, `cmdline`, `cgroup` y el árbol PID/PPID/user.<br/>• En el audit log encuentra el evento `pods/exec` de `runtime-112/falco-shell` y guárdalo sin request/response body.<br/>• Clasifica la fase como `Execution`, la técnica como `Container Administration Command`, elabora `evidence-summary.txt`. Los archivos tomados en el `control-plane` cópialos con `scp` a `/var/work/tests/artifacts/6/`.<br/>• Después aplica una `NetworkPolicy` default-deny ingress+egress `incident-quarantine`, elimina el Pod comprometido y guarda la comprobación negativa: un nuevo `kubectl exec` no pasa.<br/>• Es una cadena mínima de containment: la credential revocation/rotation y la remediation completa requieren un proceso de incident-response aparte. |
| Criterios de aceptación | • En `/var/work/tests/artifacts/6/` hay un Falco alert real, CRI inspect/inspectp, tres artefactos de `/proc`, process lineage, un Metadata audit event de `pods/exec`, el resumen final y el resultado del containment<br/>• El Pod `falco-shell` no existe<br/>• `incident-quarantine` selecciona todos los Pod y cierra ingress+egress<br/>• Un nuevo exec tiene un non-zero exit code |

<details>
<summary>💡 Pista para la tarea 6</summary>

El orden estricto de las acciones es importante para la fiabilidad de la investigación: empieza por el Falco alert (es lo que realmente pondría en marcha el incident response), y NO por el nombre de Pod ya conocido; de lo contrario simplemente confirmas lo que ya sabes, y no llevas a cabo una correlation real. Recoge los artefactos `/proc/<PID>/*` mientras el proceso esté VIVO: en cuanto elimines el Pod (el último paso), `/proc` de ese PID desaparecerá para siempre, por lo que el orden "primero la evidence, luego el containment" es irreversible si se confunde.
</details>

---
| **7** | **Override de un macro upstream de Falco, añadir evidence de Pod/namespace al output, JSON a un archivo** |
| :---: | :--- |
| Qué hacemos | • La regla estándar de Falco **Terminal shell in container** se dispararía también con una herramienta legítima de CI/CD que abre habitualmente una shell en un contenedor (por ejemplo, `kubectl debug` o un sidecar con un script de mantenimiento). En lugar de editar la propia regla, haz un override del macro upstream, destinado precisamente a esta regla.<br/>• En `/etc/falco/falco_rules.local.yaml` redefine `user_expected_terminal_shell_in_container_conditions` (por defecto `(never_true)` en la propia regla **Terminal shell in container**; no lo confundas con `user_shell_container_exclusions`, que pertenece a la regla aparte **Run shell untrusted**/"Shell spawned by untrusted binary"), para que admita el Pod concreto `ci-runner` en el namespace `runtime-112`.<br/>• Usa `k8s.pod.name` y `k8s.ns.name`, y no `container.name`: `container.name` es el nombre del **contenedor** (en esta tarea `app`), y no del Pod, y la coincidencia por el nombre del contenedor casi siempre dará un allowlist incorrecto o demasiado amplio.<br/>• El output estándar de la regla **Terminal shell in container** no contiene `k8s.pod.name`/`k8s.ns.name` (comprueba tú mismo el `falco_rules.yaml` upstream: no están allí); sin este campo, la correlation de un alert concreto con un Pod concreto no es fiable. Mediante el mismo mecanismo `override` añade (`output: append`) a la regla `k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name` al final del output.<br/>• Crea en `runtime-112` un Pod `ci-runner` con `busybox:1.36` con un `sh` interactivo (`stdin: true`, `tty: true`) y confirma que para él **no** se genera el alert `Terminal shell in container`, mientras que para `immutable-app` de la tarea 5 (sin excepción) el alert sigue disparándose.<br/>• Aparte, mediante `/etc/falco/config.d/cks112-output.yaml` habilita `json_output: true` y `file_output.enabled: true` con `file_output.filename: /var/log/falco/events.log`; reinicia Falco.<br/>• Confirma mediante JSON estructurado (`jq .output_fields`), y no con un `grep` de texto, que el alert registrado para `immutable-app` contiene `k8s.pod.name == "immutable-app"` y `k8s.ns.name == "runtime-112"`. |
| Criterios de aceptación | • `falco_rules.local.yaml` contiene `macro: user_expected_terminal_shell_in_container_conditions` con una condición que se refiere a `k8s.pod.name = "ci-runner"` y `k8s.ns.name = "runtime-112"` (no `never_true`, no `container.name`), y un `override: output: append` aparte, que añade `%k8s.ns.name`/`%k8s.pod.name` a la regla `Terminal shell in container`<br/>• La shell en `ci-runner` no genera alert durante el tiempo de observación, y la shell en `immutable-app` sí<br/>• `config.d/cks112-output.yaml` contiene `json_output: true` y `file_output: {enabled: true, filename: /var/log/falco/events.log}`<br/>• `/var/log/falco/events.log` contiene una línea JSON válida con `rule == "Terminal shell in container"` y `output_fields["k8s.pod.name"] == "immutable-app"`, `output_fields["k8s.ns.name"] == "runtime-112"`<br/>• El Pod `falco-shell` de la tarea 2 en este momento ya está eliminado (tarea 6) y no se usa aquí |

<details>
<summary>💡 Pista para la tarea 7</summary>

Es fácil confundir dos mecanismos de override distintos: el override de `macro` cambia la CONDICIÓN de disparo de la regla (a quién excluir), y el override de `output` con `append` cambia solo el FORMATO de la salida (qué imprimir): para esta tarea hacen falta AMBOS, en bloques separados `- macro: ...` y `- rule: ... / override: / output: append`. Comprueba literalmente la escritura de `user_expected_terminal_shell_in_container_conditions`: Falco tiene varios macros de nombre parecido para distintas reglas (el `user_shell_container_exclusions` mencionado en la tarea pertenece a OTRA regla); usar un macro incorrecto no dará un error de carga, pero el allowlist simplemente no funcionará.
</details>

---
| **8** | **Audit webhook backend en lugar de/junto con el archivo local** |
| :---: | :--- |
| Qué hacemos | • Usa el receptor HTTP `audit-receiver` ya preparado por el bootstrap (Deployment + Service en el puerto `8080`, imagen `ghcr.io/mendhak/http-https-echo:40`), que recibe los audit-events.<br/>• En el `control-plane` crea `/etc/kubernetes/audit/webhook-config.yaml` en formato kubeconfig con `server: http://<ClusterIP del receptor>:8080/audit` (para el laboratorio se admite HTTP; en producción el webhook requiere HTTPS y client certificate; consulta el capítulo 32).<br/>• En el static manifest `kube-apiserver.yaml` añade `--audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml` y `--audit-webhook-batch-max-wait=1s` (retardo de batch reducido para la observabilidad en el laboratorio), conservando los `--audit-policy-file` y `--audit-log-path` ya configurados de la tarea 4: el webhook complementa, y no sustituye, el local file backend.<br/>• Tras la recuperación de la API, ejecuta cualquier petición auditable (por ejemplo, `kubectl get configmap audit-config -n runtime-112`) y confirma en los logs de `audit-receiver` que el evento se entregó. |
| Criterios de aceptación | • `audit-receiver` Running con Service<br/>• `webhook-config.yaml` es un kubeconfig válido con `server` apuntando a este Service<br/>• El Static manifest de kube-apiserver contiene `--audit-webhook-config-file` y `--audit-webhook-batch-max-wait`, y también los flags del file backend de la tarea 4 conservados<br/>• Kube-apiserver healthy tras el cambio<br/>• Los logs de `audit-receiver` contienen al menos un audit event JSON del cuerpo de la petición con el campo `objectRef` |

<details>
<summary>💡 Pista para la tarea 8</summary>

`webhook-config.yaml` tiene FORMATO KUBECONFIG (con `clusters`/`users`/`contexts`), y no es un YAML arbitrario con un campo `server`: si la estructura del archivo no corresponde al kubeconfig schema, kube-apiserver no podrá analizarlo y no arrancará en absoluto. No olvides que el webhook COMPLEMENTA el file backend, y no lo sustituye: si eliminas los flags `--audit-policy-file`/`--audit-log-path` de la tarea 4, los tests de la tarea 4 dejarán de pasar.
</details>

---
| **9** | **Tarea de integración: eludir el admission allowlist mediante containerd directamente y detectar el intento mediante Falco** |
| :---: | :--- |
| Qué hacemos | • Esta tarea vincula Supply Chain Security (consulta el [laboratorio 111](../111/README_ES.MD) y el [capítulo 26](../../course/26/es.md)) con el Runtime Security de este laboratorio. **Diferencia importante respecto del laboratorio 111**: allí `ImageValidatingPolicy` comprueba la **firma criptográfica** (Cosign). Aquí la policy comprueba solo el **registry/repository allowlist** (permitted registry, sin signature/attestor): un admission control más simple, pero igual de real, con el mismo principio: funciona solo en el API admission path y no ve las acciones que no acuden a él.<br/>• El Controlled abuse fixture de esta tarea es un lab-owned local registry, y no el Docker Hub público: el bootstrap ya preparó en el `control-plane` tres imágenes con distintos digest en el local containerd content store y guardó sus nombres en `/etc/cks112/registry.env` (`CKS112_REGISTRY=cks112.local:5000`, `CKS112_TRUSTED_REPO=cks112/trusted`, `CKS112_UNTRUSTED_REPO=cks112/untrusted`, `CKS112_TRUSTED_IMAGE`, `CKS112_UNTRUSTED_IMAGE`, `CKS112_PREFIX_IMAGE`): carga (`source`) este archivo al principio de la tarea y usa solo estos valores.<br/>• Instala Kyverno (`install-kyverno`, como en el laboratorio 111) y crea una `ValidatingPolicy` `require-trusted-registry-runtime-112` (native CEL, `apiVersion: policies.kyverno.io/v1`), que mediante `image(c.image).registry()`/`.repository()` (Kyverno CEL Image library) **rechace** cualquier Pod en `runtime-112` cuya image no sea exactamente igual a `registry: $CKS112_REGISTRY` y `repository: $CKS112_TRUSTED_REPO`: no `startsWith`, para no dejar pasar nombres parecidos como `cks112/trusted-evil`. Da a la policy un mensaje de denial único, por ejemplo `CKS112_TRUSTED_REPO_POLICY: only $CKS112_TRUSTED_IMAGE is allowed`.<br/>• Confirma este camino: aplica un Pod `blocked-attempt` con la image `$CKS112_UNTRUSTED_IMAGE` (que no está en el allowlist) y guarda la salida del admission denial en `9/admission-deny.txt`.<br/>• Después, en el `control-plane`, mediante `cks112-run $CKS112_UNTRUSTED_IMAGE cks112-bypass-1 'echo CKS112_CTR_BYPASS; sleep 5'` (la imagen ya está presente localmente desde el bootstrap, no hace falta un nuevo pull) simula un camino que no pasa por el API server y que el admission controller no ve (el helper lo lanza por sí mismo mediante CRI en modo detached; usa un ID único para repetir la comprobación y después elimina el contenedor mediante `cks112-rm <id>`).<br/>• **Antes de escribir la regla de Falco, determina el valor REAL observed del campo `%container.image.repository` para el `$CKS112_TRUSTED_IMAGE` de confianza en tu stack containerd/Falco**: este campo se forma de forma distinta en distintas versiones (posiblemente con el hostname del registry, posiblemente sin él), por lo que no supongas el formato de antemano: con una regla temporal con un marker seguro imprime el valor en el log y guárdalo como `$TRUSTED_REPO` (guarda la evidence en `9/observed-trusted-repo.txt`).<br/>• Añade a `falco_rules.local.yaml` una custom rule `CKS112 Runtime Bypass of Admission`, que capture un spawned process con `proc.cmdline` que contenga `CKS112_CTR_BYPASS` **y** `container.image.repository` que no esté en el allowlist, y que imprima `container.image.repository` junto con los identificadores del proceso. Usa la comparación **exacta** `container.image.repository != "$TRUSTED_REPO"` con el valor observado (no una comprobación `startswith`/prefix: `not container.image.repository startswith "$TRUSTED_REPO"` dejaría pasar, es decir, no notaría, un repository como `<observed-value>-evil`, porque su nombre simplemente empieza por la subcadena permitida: el mismo error que evita la Kyverno policy de arriba mediante `==`, y no `startsWith`).<br/>• Además, comprueba ambos casos controlados: el `$CKS112_TRUSTED_IMAGE` de confianza NO debe provocar el disparo de la regla (solo por el criterio de repository; el propio marker `CKS112_CTR_BYPASS` aun así puede comprobarse aparte), y una imagen con el repository `<observed-value>-evil` DEBE provocar el disparo: precisamente esto demuestra que la comparación es exacta, y no prefix-based.<br/>• Guarda el disparo en `9/falco-bypass-attempt.log` (los archivos tomados en el `control-plane` se copian con `scp` a `/var/work/tests/artifacts/9/`). |
| Criterios de aceptación | • Kyverno instalado y Available<br/>• La `ValidatingPolicy require-trusted-registry-runtime-112` existe con `apiVersion: policies.kyverno.io/v1`, validation action `Deny`, usa `image(...).registry()`/`.repository()` para una comparación exacta (no `startsWith`), y su `message`/`messageExpression` contiene el marcador único `CKS112_TRUSTED_REPO_POLICY`<br/>• El Pod `blocked-attempt` no está creado (admission denial), `9/admission-deny.txt` contiene precisamente este marcador (no cualquier error genérico de admission)<br/>• `9/observed-trusted-repo.txt` contiene el valor realmente observado de `%container.image.repository` de la imagen de confianza<br/>• `falco_rules.local.yaml` contiene la regla `CKS112 Runtime Bypass of Admission` con una condición **exacta** (no `startswith`/prefix) sobre `container.image.repository`, que usa precisamente este valor observado<br/>• `9/falco-bypass-attempt.log` contiene un disparo no vacío con `CKS112_CTR_BYPASS` y un image repository fuera del allowlist (sufijo `-evil` al valor observado): este repository está elegido a propósito como prefix-trap: debe detectarse, a pesar de que empieza por una cadena permitida |

<details>
<summary>💡 Pista para la tarea 9</summary>

La idea clave de la tarea: `cks112-run` (un wrapper de `crictl` que crea el contenedor directamente mediante CRI) acude a containerd, esquivando kube-apiserver y, por tanto, CUALQUIER admission controller (incluido Kyverno): es una demostración de que el admission control protege solo el camino a través de la Kubernetes API, y no todo el nodo. Tu regla de Falco debe comprobar mediante `and` en una sola `condition`: un proceso de contenedor (`container.id != host`; el propio comando de lanzamiento en el host también contiene el marker), el marker `CKS112_CTR_BYPASS` Y un repository fuera del allowlist: si compruebas solo el marker, la regla se disparará incluso con procesos de prueba legítimos con un cmdline parecido.
</details>

---
| **10** | **Detectar el acceso a `/dev/mem` mediante una clase aparte de condición de Falco y detener el workload** |
| :---: | :--- |
| Qué hacemos | • Las tareas 3, 7 y 9 usaron una condición sobre `spawned_process`/`proc.cmdline`: detección por el lanzamiento de un proceso. Aquí hace falta una clase de Falco condition esencialmente distinta: detección por la **apertura de un archivo/dispositivo**.<br/>• En `runtime-112` ya hay un Deployment `mem-scanner` (2 réplicas), cuyas dos réplicas abren periódicamente `/dev/mem` desde dentro del contenedor: un workload de aplicación normal no tiene motivo para hacer eso, y ese acceso es un indicador fuerte de una configuración peligrosa o de un intento de eludir el aislamiento del contenedor. La ruta `/dev/mem` dentro del contenedor es un synthetic safe fixture (el backing device en realidad es el `/dev/null` del host, no la memoria física real del host); para Falco esto no importa: la regla detecta el propio syscall `open`/`openat`/`openat2` por el nombre de archivo `fd.name = /dev/mem`, con independencia de qué dispositivo hay realmente detrás.<br/>• En el `control-plane` añade a `/etc/falco/falco_rules.local.yaml` la regla `CKS112 Container access to /dev/mem` con la condición `evt.type in (open, openat, openat2) and fd.name = /dev/mem and container.id != host`, priority `CRITICAL`, el output debe contener `container_id=%container.id`, `k8s_pod=%k8s.pod.name` y `k8s_ns=%k8s.ns.name`. Reinicia Falco.<br/>• Encuentra el disparo en el journal y determina a través de él el Pod **concreto** (no adivines por el nombre: usa `k8s_pod` del propio alert); según el alert concreto, determina qué réplica exacta creó el evento registrado. Guarda la línea de la alerta en el nodo y cópiala con `scp` a `/var/work/tests/artifacts/10/falco-devmem.log`.<br/>• Ejecuta `kubectl scale deployment mem-scanner -n runtime-112 --replicas=0` y guarda el estado final (`kubectl get deployment mem-scanner -n runtime-112 -o json`) en `/var/work/tests/artifacts/10/scaled-down.json`. |
| Criterios de aceptación | • `falco_rules.local.yaml` contiene una regla con el nombre `CKS112 Container access to /dev/mem`, una condición sobre `fd.name = /dev/mem` (no sobre `proc.cmdline`/spawned_process) y `container.id != host`, priority `CRITICAL`<br/>• Falco activo<br/>• `10/detected-pod.json` registra el Pod real y la owner chain antes del containment<br/>• `10/falco-devmem.log` es una línea real del journal con esta regla y un `k8s_pod` no vacío<br/>• El Deployment `mem-scanner` está escalado a `replicas: 0`<br/>• `10/scaled-down.json` confirma `spec.replicas == 0` |

<details>
<summary>💡 Pista para la tarea 10</summary>

No confundas esta condición con las tareas 3/7/9: allí `spawned_process`/`execve` captura el LANZAMIENTO de un proceso por la línea de comandos, y aquí `open`/`openat`/`openat2` captura la APERTURA de un archivo/dispositivo concreto, con independencia de qué proceso lo haga y con qué argumentos de línea de comandos. `container.id != host` descarta los procesos de sistema legítimos en el propio nodo (no en un contenedor), a los que el acceso a `/dev/mem` puede hacerles falta por otras razones. No escales el Deployment antes de encontrar el alert: primero la detección mediante Falco, luego el containment, de lo contrario no demostrarás que encontraste el Pod precisamente mediante el monitoreo, y no eligiéndolo de antemano por el nombre. Primero obtén el Falco alert y solo a partir de su `k8s_pod` determina la réplica concreta que creó este evento.
</details>

## Comprobación

```bash
check_result
```

La comprobación contiene Init y diez tests independientes. Comprueba el estado de Falco y
kube-apiserver por SSH, los objetos de la API, la evidence de CRI/`/proc`, la audit correlation, el containment
y la denegación real de escritura en rootfs. Tras
cambiar el static Pod manifest no reinicies el kubelet sin necesidad: el kubelet notará por sí mismo
el cambio. Si la API no está disponible temporalmente, espera a `kubectl get --raw=/readyz`.
Guarda el backup del archivo `kube-apiserver.yaml` solo fuera de `/etc/kubernetes/manifests`: el kubelet lee cualquier archivo sin punto inicial de ese directorio.

## Solución

Solución de referencia: [worker/files/solutions/1_ES.MD](worker/files/solutions/1_ES.MD).

## Eliminación

```bash
TASK=112 make delete_cks_task
```
