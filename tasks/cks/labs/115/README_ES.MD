[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 115 - Cilium bootstrap, kube-proxy replacement y Mutual Authentication

> **Advanced / production track. No forma parte del requisito formal del CKS Core exam.**
> Este laboratorio sale del marco del examen CKS y es útil como habilidad de producción: la instalación de
> Cilium desde cero como reemplazo completo de kube-proxy, y Cilium Mutual Authentication sobre
> la base de SPIRE. Si te preparas solo para el examen, la prioridad son los laboratorios 101-114.

## Descripción

El control-plane de este laboratorio se ha levantado mediante `kubeadm init --skip-phases=addon/kube-proxy`: sin
el DaemonSet de `kube-proxy` y **sin un CNI instalado**. El Node permanece `NotReady` hasta que tú
instales Cilium. Esto es deliberado: el laboratorio trata por completo de la instalación manual de Cilium como
reemplazo completo de kube-proxy (`kubeProxyReplacement`), de la habilitación incremental de WireGuard
transparent encryption y de Cilium Mutual Authentication sobre la base de SPIRE: cada paso
se instala y se comprueba por separado, y no se entrega ya hecho.

Los CLI `cilium`/`hubble` ya están instalados en el worker y apuntan al clúster real
(`~/.kube/config`), pero la propia instalación de Cilium en el clúster la haces tú.

## Despliegue

```bash
TASK=115 make run_cks_task
```

Tras el despliegue, conéctate por SSH con el comando de la salida de Terraform (`worker_pc_ssh`).
El Node estará `NotReady` justo después del login: es el baseline esperado, y no un error.

## Objetivo

Instalar Cilium como reemplazo completo de kube-proxy en un clúster kubeadm kube-proxy-free ya levantado,
habilitar el cifrado WireGuard, habilitar Cilium Mutual Authentication
(SPIRE) y escribir una `CiliumNetworkPolicy` que exija una mutual authentication exitosa entre
dos namespace.

## Infraestructura

| Componente | Finalidad |
| --- | --- |
| control-plane EC2 | clúster kubeadm sin kube-proxy y sin CNI en el momento de entregar el laboratorio |
| `ingress-115` | namespace del cliente, que debe pasar la mutual authentication |
| `app-115` | namespace del backend, protegido por una CiliumNetworkPolicy con `authentication.mode: required` |
| worker EC2 | los CLI `cilium`/`hubble`, el kubeconfig configurado |

## Tareas

---

|           **1**           | **Baseline: kube-proxy-free, sin CNI** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Qué hacemos       | • Confirma el estado actual del clúster antes de instalar nada |
| Criterios de aceptación | • El DaemonSet `kube-proxy` no existe<br/>• El `NotReady` inicial se observa antes de instalar Cilium<br/>• El Checker, tras completar todas las tareas, confirma la ausencia de kube-proxy y la disponibilidad de la API, y no el `NotReady` histórico |
|        Comprobación        | `kubectl -n kube-system get ds kube-proxy` -> `NotFound`. `kubectl get nodes` -> `NotReady` (no hay CNI). |

---

|           **2**           | **Instalación de Cilium como reemplazo de kube-proxy** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Qué hacemos       | • Instala el Cilium agent/chart versión `1.20.1` mediante el CLI `cilium` versión `v0.19.7` instalado en el worker, con `kubeProxyReplacement=true` y `k8sServiceHost`/`k8sServicePort` indicados explícitamente, que apunten al API server real (no al Service ClusterIP: sin kube-proxy el clúster no puede resolver `kubernetes.default` antes de que el propio Cilium arranque) |
| Criterios de aceptación | • `KubeProxyReplacement: True/Strict` (en `cilium-dbg status` del agente)<br/>• El Node pasa a `Ready`<br/>• El Service ClusterIP es alcanzable sin kube-proxy |
|        Comprobación        | `cilium status --wait`, `kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status \| grep KubeProxyReplacement`, luego `kubectl get nodes` -> `Ready`. Desde un Pod de prueba: `curl https://kubernetes.default.svc.cluster.local/` debe recibir una HTTP response (no un connection error). |

---

|           **3**           | **WireGuard transparent encryption** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Qué hacemos       | • Habilita `encryption.enabled=true`, `encryption.type=wireguard` sobre el Cilium ya instalado (`cilium upgrade`, no una reinstalación desde cero) |
| Criterios de aceptación | • `Encryption: Wireguard` en `cilium-dbg status` y `enable-wireguard: "true"` en el ConfigMap de Cilium<br/>• El camino de la tarea 2 no ha sufrido una regresión<br/>• El banco de pruebas de un solo nodo confirma la configuración de WireGuard habilitada, pero no demuestra tráfico cifrado entre nodos (Peers: 0) |
|        Comprobación        | `kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status \| grep Encryption`. Repite el curl de la tarea 2: debe volver a recibir una HTTP response. |

---

|           **4**           | **Cilium Mutual Authentication (SPIRE)** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Qué hacemos       | • Habilita la instalación integrada de SPIRE mediante el propio Helm chart de Cilium: `authentication.mutual.spire.enabled=true`, `authentication.mutual.spire.install.enabled=true` |
| Criterios de aceptación | • El StatefulSet `spire-server` y el DaemonSet `spire-agent` tienen todas las réplicas Ready solicitadas en el namespace `cilium-spire` |
|        Comprobación        | `kubectl get pods -A \| grep spire`: ambos tipos de Pod en estado `Running` y Ready. |

> **Particularidades del banco de pruebas.** En el clúster no hay StorageClass, por lo que el servidor SPIRE necesita
> un almacenamiento efímero (`authentication.mutual.spire.install.server.dataStorage.enabled=false`). La imagen
> `spire-server` funciona con uid 1000 y no puede crear un socket en el directorio hostPath `root:755`:
> ejecútala como root (`authentication.mutual.spire.install.server.securityContext.runAsUser=0`).
> Además, el chart exige `authentication.enabled=true`. Los detalles, en la solución de referencia.

---

|           **5**           | **CiliumNetworkPolicy con mutual authentication obligatoria** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       Qué hacemos       | • Crea `ingress-115` (client) y `app-115` (backend, label `app=backend`, Service `backend`)<br/>• Crea la `CiliumNetworkPolicy backend-auth-required` en `app-115`: `endpointSelector` sobre `app=backend`, ingress solo desde el namespace `ingress-115`, y `authentication.mode: required` en esta regla ingress |
| Criterios de aceptación | • La policy selecciona exactamente el backend, contiene una regla ingress desde `ingress-115` en TCP/80 con `authentication.mode: required`<br/>• No hay reglas ingress adicionales ni vías de elusión<br/>• En el banco de pruebas aislado del Lab 115 no hay otras network policies namespaced/globales que afecten al backend<br/>• El Service `backend` está dirigido al Pod `backend` Ready |
|        Comprobación        | `kubectl -n app-115 get ciliumnetworkpolicy backend-auth-required -o yaml`: comprueba `authentication.mode: required` dentro de `ingress[0]`. |

---

|           **6**           | **Positive/negative control: la authenticated identity está permitida, la ajena no** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Qué hacemos       | • Comprueba el efecto de la policy con tráfico en vivo: el cliente de `ingress-115` debe alcanzar `backend` (tras un handshake de mutual auth basado en SPIRE exitoso)<br/>• Un Pod aparte de un namespace "incorrecto" (`app-115`, no `ingress-115`; el tráfico del backend a sí mismo Cilium siempre lo deja pasar) debe ser bloqueado |
| Criterios de aceptación | • En el backend espejo aislado, el baseline permite a ambos clientes; tras aplicar una copia de la policy solo se permite `ingress-115`<br/>• El backend en funcionamiento responde al cliente permitido, rechaza a los clientes de `app-115` y de un nuevo namespace independiente<br/>• El Cilium BPF auth map contiene `spire` para la pareja exacta de identity del cliente/backend |
|        Comprobación        | `curl` desde el pod cliente en `ingress-115` a `http://backend.app-115.svc.cluster.local/` -> HTTP response. El mismo curl desde un Pod en `app-115` sin el label del cliente -> connection error. |

## Comprobación

```bash
check_result
```

El Checker **nunca retira la** `app-115/backend-auth-required` **en funcionamiento**. Para comprobar el baseline crea un backend espejo temporal y un Service en un namespace desechable `cks-115-*`, primero comprueba el tráfico permitido sin policy, luego aplica una copia de la CiliumNetworkPolicy comprobada solo al backend espejo. Por separado se comprueban el backend real, el EndpointSlice, las parejas exactas de SPIRE identities en el BPF auth map y la prohibición de clientes de namespace ajenos. Todos los Pod, Service, policy y el namespace temporal creados se eliminan con una comprobación de cleanup.

Solución de referencia: [worker/files/solutions/1_ES.MD](worker/files/solutions/1_ES.MD).

## Eliminación

```bash
TASK=115 make delete_cks_task
```
