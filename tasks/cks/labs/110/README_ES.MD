[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 110 - gVisor RuntimeClass, Cilium WireGuard e Istio mTLS

## Objetivo

En este laboratorio de CKS montarás tres capas independientes de protección del workload: el runtime sandboxed
**gVisor** mediante `runsc`, el cifrado entre nodos de Cilium WireGuard y el mTLS service-to-service
de Istio. Al final no solo verás los ajustes, sino que los demostrarás con resultados
observables: la diferencia del kernel view de gVisor, los paquetes WireGuard sin HTTP marker y el distinto
resultado de una llamada desde el mesh y desde un cliente plaintext fuera del mesh.

## Compruébate antes de empezar

<details>
<summary>1. ¿En qué se diferencia, en esencia, el userspace kernel de gVisor del guest kernel de una máquina virtual?</summary>

gVisor (`runsc`) implementa su propio subconjunto de syscalls de Linux EN USERSPACE, interceptando las llamadas al sistema del contenedor y procesándolas él mismo, sin pasarlas directamente al kernel del host: el proceso del contenedor ve un "kernel" distinto (otro `uname -r`, otro comportamiento de algunos syscalls). Un guest kernel (por ejemplo, Kata Containers) ejecuta un kernel Linux COMPLETO dentro de una VM ligera: un aislamiento más fuerte, pero con el overhead de una virtualización completa, que gVisor no tiene.
</details>

<details>
<summary>2. ¿Qué autentica exactamente un WireGuard peer y por qué NO es lo mismo que la identity de un ServiceAccount?</summary>

WireGuard autentica los NODOS (nodes) del clúster mediante claves criptográficas generadas por Cilium para cada nodo: el cifrado ocurre a nivel del túnel node-to-node. Esto protege el tráfico ENTRE nodos frente a la escucha a nivel de red, pero no tiene relación con la identity de un Pod/ServiceAccount concreto dentro de ese tráfico: Cilium WireGuard no comprueba "quién" es el emisor a nivel de aplicación, solo "qué nodo".
</details>

<details>
<summary>3. ¿Por qué un `curl` exitoso con código 200 dentro del mesh NO demuestra que el plaintext client realmente fue bloqueado?</summary>

Una respuesta exitosa DENTRO del mesh demuestra únicamente que la conexión mTLS entre los dos sidecars funciona: es un positive control. Para demostrar que STRICT realmente bloquea el tráfico NO-mesh, hace falta un negative control aparte: un cliente SIN sidecar, que intente acceder al mismo servicio y reciba una denegación. Una sola prueba exitosa no basta; hacen falta ambas: allowed para la mesh identity, denied para el plaintext.
</details>

## Relación con el curso

- [Capítulo 22. Container Runtime Sandbox](../../course/22/es.md)
- [Capítulo 23. Cifrado Pod-to-Pod y mTLS](../../course/23/es.md)

## Infraestructura

Terragrunt crea Kubernetes `1.36.0` en `eu-central-1`:

| Componente | Finalidad |
|---|---|
| `k8s-1` control-plane | un workload node containerd normal, Cilium y `tcpdump` para capturar un paquete entre nodos |
| `k8s-1` worker `gvisor` | un nodo aparte con containerd, `runsc` instalado y el CRI handler `runsc` |
| CNI | **Cilium** (instalado mediante Cilium CLI con el Helm release `cilium`); WireGuard está deliberadamente desactivado hasta la tarea 4 |
| `worker` | máquina de trabajo con `kubectl`, `cilium`, `istioctl`, `check_result` y SSH aliases a los nodos |

Matriz comprobada el 2026-08-31 (contrástala antes de cada build): Kubernetes del curso
`1.36.0`; Cilium data plane: una lab-build soportada, cuya compatibilidad con
Kubernetes `1.36` hay que confirmar según la requirements matrix vigente; Cilium CLI `0.19.7`
(compatible con Cilium `1.17+`); Istio `1.30.4` (la rama `1.30` soporta oficialmente Kubernetes
`1.32–1.36`). La versión del examen aquí no determina la compatibilidad del lab tooling; según los datos de LF
ahora es `v1.34` y se comprueba aparte antes del examen.

Tras el bootstrap están disponibles dos workload placement labels:

```text
lab.cks.io/role=control-plane
sandbox.runtime/gvisor=true,lab.cks.io/role=gvisor
```

El control-plane está disponible para Pods normales sin tolerations. El nodo gVisor está marcado además con el taint
`sandbox.runtime/gvisor=true:NoSchedule`: en él solo caen los Pods que toleran ese taint
(los Pods con `RuntimeClass gvisor` reciben el toleration necesario de `scheduling.tolerations` de la clase).

Los namespaces `sandbox-110` y `market` ya existen. `market` tiene puesta de antemano
la etiqueta `istio-injection=enabled`; el Istio control plane no está instalado. Para acceder al
nodo sandbox desde el worker usa el alias `k8s110_node_gvisor`, y para el control-plane,
`k8s110_controlPlane_1`.

## Despliegue

```bash
TASK=110 make run_cks_task
```

Conéctate a la máquina de trabajo y elige el contexto ya preparado:

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

Crea el directorio de evidencias antes de empezar a trabajar:

```bash
mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6}
```

## Tareas

---
| **1** | **Configurar el runtime de containerd y crear el RuntimeClass para runsc** |
| :---: | :--- |
| Qué hacemos | • En `k8s110_node_gvisor` el binario `runsc` ya está instalado, pero el bootstrap ha quitado deliberadamente de `/etc/containerd/config.toml` la sección `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]` con `runtime_type = "io.containerd.runsc.v1"`: es una situación típica de examen con un config.toml roto.<br/>• Devuelve esa sección (la copia de seguridad está en `/etc/containerd/config.toml.bak`, o añádela a mano) y ejecuta `sudo systemctl restart containerd`.<br/>• Crea el `RuntimeClass` `gvisor` con el `handler: runsc` exacto.<br/>• En `scheduling` establece el `nodeSelector` `sandbox.runtime/gvisor: "true"`, para que un Pod con esta clase nunca caiga en un nodo normal, y los `tolerations` para el taint del nodo gVisor (`sandbox.runtime/gvisor=true:NoSchedule`); de lo contrario el Pod no llegará allí. |
| Criterios de aceptación | • En el nodo, `containerd` está activo y `config.toml` contiene una sección `runtimes.runsc` operativa con `runtime_type = "io.containerd.runsc.v1"`<br/>• `kubectl get runtimeclass gvisor` existe, el handler es igual a `runsc`, en `scheduling` hay `nodeSelector` y `tolerations` para el taint del nodo gVisor<br/>• `/var/work/tests/artifacts/1/runsc-runtime.txt` contiene la línea exacta `RuntimeClass gvisor: handler runsc` |

<details>
<summary>💡 Pista para la tarea 1</summary>

La copia de seguridad `/etc/containerd/config.toml.bak` es el camino de recuperación más rápido, pero comprueba su contenido antes de copiarla de vuelta (`diff` con el archivo actual), para entender qué falta exactamente. Tras restaurar la sección `runtimes.runsc`, ejecuta obligatoriamente `systemctl restart containerd`: la simple edición del archivo no aplica los cambios al proceso ya en funcionamiento.
</details>

---
| **2** | **Pod en el sandbox de gVisor** |
| :---: | :--- |
| Qué hacemos | • En `sandbox-110` crea un Pod `gvisor-sandbox` con `runtimeClassName: gvisor`, el contenedor `app` y la imagen `busybox:1.36`.<br/>• Indica en el Pod explícitamente el `nodeSelector` `sandbox.runtime/gvisor: "true"` y los `tolerations` para el taint del nodo gVisor (lo mismo que en el `scheduling` del RuntimeClass; sin ellos Kubernetes los añadirá por sí mismo desde el RuntimeClass, pero en el manifiesto eso no se verá).<br/>• Ejecuta en el contenedor un HTTP server en `8080` que devuelva la cadena `CKS110-WIREGUARD-MARKER`.<br/>• Crea un Service `gvisor-echo` en `8080` que seleccione este Pod.<br/>• Desactiva el automount del ServiceAccount token.<br/>• Guarda la salida de `uname -r` y `dmesg` del Pod en un artefacto: `dmesg` dentro del sandbox de gVisor empieza con la línea `Starting gVisor...` en lugar del log real del kernel del nodo: es una prueba directa del aislamiento, aparte de la diferencia de `uname -r`. |
| Criterios de aceptación | • El Pod está `Running` en un nodo `sandbox.runtime/gvisor=true`, el Service lo selecciona, y `/var/work/tests/artifacts/2/gvisor-kernel.txt` contiene la línea `gvisor uname -r: <valor real>` y la línea `Starting gVisor` de la salida de `dmesg` |

<details>
<summary>💡 Pista para la tarea 2</summary>

Si el Pod no arranca (se queda en `ContainerCreating` con el evento `FailedCreatePodSandBox`, por ejemplo `no runtime for "runsc" is configured`), lo más probable es que la tarea 1 no esté completamente terminada: el RuntimeClass debe apuntar realmente a un handler de containerd operativo. En el `busybox:1.36` usado hay un applet `httpd`: usa `httpd -f -p 8080 -h /www` para un HTTP server mínimo (la presencia del applet se puede comprobar mediante `busybox --list | grep '^httpd$'`).
</details>

---
| **3** | **Comparación con un Pod runc normal** |
| :---: | :--- |
| Qué hacemos | • Crea `runc-baseline` en `sandbox-110`: `busybox:1.36`, contenedor `app`, `sleep 3600`.<br/>• Sin `runtimeClassName`, con nodeSelector `lab.cks.io/role: control-plane` y sin SA token.<br/>• Compara su `uname -r` con el del gVisor Pod y guarda ambos resultados en `/var/work/tests/artifacts/3/runtime-comparison.txt`. |
| Criterios de aceptación | • El baseline Pod está `Running` en el control-plane y no tiene `runtimeClassName`<br/>• Su release difiere del gVisor release<br/>• En el artefacto están ambas líneas `gvisor uname -r:` y `runc uname -r:` con valores reales |

<details>
<summary>💡 Pista para la tarea 3</summary>

Este Pod se coloca deliberadamente en OTRO nodo (control-plane, no el nodo gvisor) mediante el nodeSelector `lab.cks.io/role: control-plane`: no es simplemente "cualquier Pod normal", sino una comparación controlada con una ubicación conocida. Si `uname -r` resulta igual en ambos Pods, comprueba si `gvisor-sandbox` realmente usa `runtimeClassName: gvisor`.
</details>

---
| **4** | **Habilitar el Cilium transparent encryption** |
| :---: | :--- |
| Qué hacemos | • Primero registra las versiones de Kubernetes, del Cilium agent y de Cilium CLI en `/var/work/tests/artifacts/4/tool-versions.txt` y asegúrate de que el data plane soporta Kubernetes `1.36`.<br/>• Habilita WireGuard en el Helm release existente, creado por `cilium install`: `cilium upgrade --version 1.20.1 --set encryption.enabled=true --set encryption.type=wireguard --wait`.<br/>• Reinicia los agentes (`kubectl -n kube-system rollout restart daemonset/cilium`): Helm cambia solo el ConfigMap, y la plantilla del DaemonSet permanece igual.<br/>• Comprueba `cilium-config` (`enable-wireguard: "true"`) y que ambos Cilium agents estén Ready.<br/>• Un patch directo del ConfigMap es admisible solo como una baseline-probe didáctica breve con un rollback confirmado obligatorio. No busques el comando `cilium encrypt enable`: el CLI cliente `cilium` no tiene ese subcomando.<br/>• Guarda el agent-side `cilium-dbg encrypt status` y `cilium-dbg debuginfo --output json` en `/var/work/tests/artifacts/4/cilium-encrypt-status.txt` (`cilium-dbg status` no tiene el flag `--all-encryption`). |
| Criterios de aceptación | • La version evidence existe y coincide con la imagen real del DaemonSet `kube-system/cilium`<br/>• Los Cilium agents (DaemonSet) están completamente Ready<br/>• Status muestra WireGuard y no muestra IPsec a la vez<br/>• El JSON de Debuginfo contiene evidence de peer/allowed-IP (o remote-node) del estado entre nodos<br/>• El ConfigMap `kube-system/cilium-config` contiene `enable-wireguard: "true"` como configuración efectiva aplicada desde los Helm values<br/>• El ajuste sobrevive al restart de un agent Pod (el checker reinicia el Pod y vuelve a comprobar el estado) |

<details>
<summary>💡 Pista para la tarea 4</summary>

Usa los Helm values del release existente `cilium` como source-of-truth duradero para habilitar WireGuard, y no comandos efímeros: un cambio hecho fuera de los Helm values puede no sobrevivir al restart del agente ni a la actualización del Helm release, y el test comprueba específicamente que el ajuste sobrevive al restart. `cilium-dbg` se invoca DENTRO del Pod del agente mediante `kubectl exec`, y no como un binario local aparte en el worker. `cilium-dbg status` NO tiene el flag `--all-encryption`: para una evidence detallada de peer/allowed-IP usa `cilium-dbg debuginfo --output json`.
</details>

---
| **5** | **Demostrar la ausencia de plaintext entre nodos** |
| :---: | :--- |
| Qué hacemos | • Construye una evidencia ANTES/DESPUÉS sobre el mismo flow entre nodos.<br/>• **Baseline (WireGuard desactivado):** en el control-plane ejecuta `tcpdump` sobre la IP del nodo remoto (`host <remote-node-ip>`, sin un filtro previo por `udp port 51871`); desactiva temporalmente WireGuard (`enable-wireguard: "false"` en `cilium-config`, `rollout restart daemonset/cilium`); ejecuta la petición `runc-baseline -> gvisor-echo`; guarda ese baseline-capture y asegúrate de que en él se ve el plaintext `CKS110-WIREGUARD-MARKER`.<br/>• **Después (WireGuard habilitado):** restablece `enable-wireguard: "true"`, espera a Ready y repite LA MISMA petición con EL MISMO scope de captura (`host <remote-node-ip>`, sin filtro por puerto).<br/>• El capture se toma en el control-plane (a un archivo en el nodo), luego se copia con `scp` a la máquina de trabajo en `/var/work/tests/artifacts/5/wireguard-tcpdump.txt`: en él ahora debe verse solo WireGuard UDP/`51871`, sin plaintext marker. |
| Criterios de aceptación | • El capture final (post-change) con el mismo peer/interface scope contiene UDP/`51871`, pero **no** contiene `CKS110-WIREGUARD-MARKER`<br/>• La llamada entre nodos distintos recibe con éxito el marker en la respuesta HTTP<br/>• El checker repite por sí mismo el post-change capture con el mismo peer/interface scope (sin limitarse de antemano solo a `udp port 51871`), y también desactiva temporalmente WireGuard por sí mismo y luego lo restablece para obtener su propia confirmación baseline de que el mismo flow en estado plaintext realmente expone el marker en el wire |

<details>
<summary>💡 Pista para la tarea 5</summary>

Captura el tráfico en la interfaz de red física REAL del nodo (por ejemplo `eth0`), y no en la interfaz virtual del Pod/veth ni en la interfaz interna de Cilium `cilium_wg0`: `cilium_wg0`, por el diseño del túnel WireGuard, lleva tráfico YA DESCIFRADO (ese es su propósito), por lo que una captura en `any` verá el marker allí incluso con el cifrado funcionando correctamente en el NIC físico. Determina la interfaz física concreta mediante `ip route get <remote-node-ip>` y usa precisamente esa. Si el capture se hace "dentro" del camino del Pod antes del cifrado de WireGuard, verás HTTP plaintext con independencia de si el cifrado node-to-node está habilitado. Ejecuta `tcpdump` EN SEGUNDO PLANO ANTES de hacer la petición HTTP, y no después. Un filtro de captura SOLO por `udp port 51871` excluye de antemano el TCP plaintext del resultado y por eso NO demuestra su ausencia: usa `host <remote-node-ip>` sin un filtro de puerto, para que un mismo scope pueda mostrar realmente la diferencia antes/después de habilitar WireGuard. El checker ejecuta su propio `tcpdump` simultáneamente con su petición (incluida una baseline-probe con desactivación temporal de WireGuard y un posterior restablecimiento verificado): tu artefacto es útil didácticamente, pero no es la única prueba; si el cifrado realmente no funciona en el momento de la comprobación, el live capture del checker lo detectará con independencia del contenido de tu archivo.
</details>

---
| **6** | **Istio PeerAuthentication STRICT** |
| :---: | :--- |
| Qué hacemos | • Instala la versión fijada de Istio `1.30.4` con el `istioctl` preparado (basta el minimal profile) y registra la versión del control plane.<br/>• En `market` crea un Deployment `market-api` y un Service `market-api`: la aplicación escucha en `8080` y el service port debe llamarse `http`. `market-api` debe funcionar en el nodo gVisor: `nodeSelector` `lab.cks.io/role: gvisor` y un toleration para su taint (`sandbox.runtime/gvisor=true:NoSchedule`).<br/>• Crea un Deployment injected `market-client` en `market` y un Pod plaintext `mesh-outside` en `default`; los tres workloads deben estar Running, **sin** `PeerAuthentication` STRICT.<br/>• **Baseline:** la misma petición plaintext outside a `market-api` debe recibir HTTP 200 (mTLS aún no se exige); guarda esta respuesta baseline aparte.<br/>• Aplica un `PeerAuthentication` `market-strict` del namespace `market` con `mtls.mode: STRICT` y repite LA MISMA petición outside: el plaintext client sin sidecar no debe recibir una application response exitosa, y la petición in-mesh debe recibir HTTP 200.<br/>• Guarda status/headers/exit code en `artifacts/6/market-inside.txt` y `market-outside.txt` (al final de ambos archivos añade la línea `exit_code=<código de salida de curl>`); no hagas match con una línea concreta de socket error. |
| Criterios de aceptación | • El namespace conserva `istio-injection=enabled`<br/>• `PeerAuthentication market-strict` tiene `STRICT`<br/>• Dentro del mesh hay HTTP 200, y la llamada plaintext desde fuera del mesh no recibe una respuesta HTTP exitosa (curl falla, no hay 2xx, `exit_code` en el archivo es non-zero), con independencia del texto exacto del error<br/>• Ambas pruebas están guardadas, `market-inside.txt` contiene `exit_code=0`<br/>• No sustituyas el plaintext client por un sidecar: precisamente la ausencia de sidecar demuestra la denegación de STRICT.<br/>• El checker además repite por sí mismo ANTES/DESPUÉS: cambia temporalmente la misma policy a `PERMISSIVE`, repite la misma petición plaintext y exige 200: esto demuestra que la denegación anterior la causó precisamente STRICT mTLS, y no un problema independiente de DNS/network<br/>• Después el checker restablece `STRICT` |

<details>
<summary>💡 Pista para la tarea 6</summary>

El Service port DEBE llamarse precisamente `http` (no `market-api` ni otra cosa): Istio usa la named port convention para determinar el protocolo y tratar correctamente el tráfico a través del sidecar. `market-client` se crea DESPUÉS de que el namespace recibiera `istio-injection=enabled`: si el Deployment se creó ANTES de esa etiqueta, el sidecar no se añadirá automáticamente y habrá que recrear el Pod (no el Deployment) para la inyección.
</details>

## Comprobación

```bash
check_result
```

La comprobación contiene `0 Init` y seis tests obligatorios. Los tests 1-3 comprueban
`RuntimeClass`, el placement y la diferencia real de `uname`; los tests 4-5 comprueban el status de
WireGuard, la petición entre nodos y la ausencia del marker en tcpdump; el test 6 vuelve a ejecutar ambas
llamadas mTLS y comprueba los artefactos. Si los Istio Pods aún se están creando, espera a
`kubectl get pods -n market` con `2/2 Running` en el workload injected.

## Solución

Solución de referencia: [worker/files/solutions/1_ES.MD](worker/files/solutions/1_ES.MD).

## Eliminación

```bash
TASK=110 make delete_cks_task
```
