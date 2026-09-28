[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 114 — Troubleshooting: reparamos recursos rotos

## Descripción

Práctica del dominio Troubleshooting (30% del CKA). En el clúster ya están desplegados
objetos **rotos**: tu tarea es encontrar y eliminar las causas aplicando una ruta de
depuración sistemática: `get` → `describe` (Events) → `logs` → reparación. Las tareas
imitan incidentes típicos: ImagePullBackOff, Endpoints vacíos por un selector incorrecto y
CreateContainerConfigError por un ConfigMap ausente.

Todas las tareas están redactadas en estilo de examen (como las preguntas reales de
CKA/CKAD) con verificación automática mediante el comando `check_result`.

## Objetivo

Consolidar el material de los capítulos del curso:

- [Capítulo 44. Depuración de fallos de aplicaciones](../../course/44/es.md) — la ruta `get` → `describe` → `logs`, análisis de los estados de los Pods
- [Capítulo 45. Depuración del control plane y de los nodos worker](../../course/45/es.md) — diagnóstico de nodos y componentes del sistema
- [Capítulo 46. Depuración de servicios y red](../../course/46/es.md) — la cadena Service ↔ Endpoints ↔ etiquetas

## Qué reparamos y para qué

En este laboratorio reparamos tres incidentes independientes: una imagen defectuosa, un
enlace roto entre el Service y los pods, y una configuración ausente. Cada avería ejercita
su propio tramo de la ruta de depuración:

| Avería | Síntoma | Causa | Qué enseña |
|--------|---------|-------|------------|
| **ReplicaSet `rs-app2223`** (namespace `rsapp`) | ImagePullBackOff | etiqueta de imagen incorrecta | análisis de problemas de imagen y recreación de los Pods del RS (capítulo 44) |
| **Service `svc-broken`** (namespace `tsvc`) | Endpoints vacíos | el selector no coincide con los label de los Pods | la cadena Service ↔ Endpoints ↔ etiquetas (capítulo 46) |
| **Deployment `capp`** (namespace `cfgapp`) | CreateContainerConfigError | falta el ConfigMap necesario | dependencias de configuración (capítulo 44) |

Panorama final de lo que quedará despliegado:

```mermaid
flowchart LR
    a["rs-app2223<br>ImagePullBackOff"] -->|"fix image"| a2["2 ready"]
    b["svc-broken<br>Endpoints vacíos"] -->|"fix selector"| b2["Endpoints presentes"]
    c["capp<br>CreateContainerConfigError"] -->|"create ConfigMap"| c2["Ready"]
    a2 ~~~ b
    b2 ~~~ c
    style a fill:#db4437,color:#fff
    style b fill:#db4437,color:#fff
    style c fill:#db4437,color:#fff
    style a2 fill:#0f9d58,color:#fff
    style b2 fill:#0f9d58,color:#fff
    style c2 fill:#0f9d58,color:#fff
```

## Infraestructura

El entorno se despliega en AWS (`eu-central-1`) mediante Terragrunt y consta de:

| Componente | Descripción                                                          |
|------------|----------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` con subredes públicas                             |
| `ssh-keys` | Claves SSH para el acceso a los nodos                                |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, de un solo nodo; al arrancar despliega los objetos rotos |
| `worker`   | Máquina de trabajo con `kubectl` y `check_result`                    |

Instancias: `t4g.medium` (master), Ubuntu `22.04`. El clúster es de un solo nodo: al master
se le ha quitado el taint `control-plane`, por lo que los pods se planifican directamente
en él.

## Despliegue

```bash
TASK=114 make run_cka_task
```

Tras la creación, conéctate por SSH a la máquina de trabajo (worker) y realiza las tareas
desde allí. `kubectl` ya está configurado con el contexto `cluster1-admin@cluster1`.

Comandos útiles en la máquina de trabajo:

```bash
time_left       # cuánto tiempo queda
check_result    # comprobar la solución
```

## Tareas

---
|        **1**        | **Reparar el ReplicaSet**                                   |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | En el namespace `rsapp` los Pods del ReplicaSet `rs-app2223` se quedan colgados en `ImagePullBackOff`. Recorre la ruta: `kubectl get po -n rsapp` (vemos el estado), `kubectl describe po -n rsapp <pod>` (en Events: la imagen `viktoruj/ping_pong:doesnotexist123` no se descarga). Corrige la imagen en la plantilla del RS por una que funcione (`viktoruj/ping_pong:latest`) con `kubectl edit rs rs-app2223 -n rsapp`. El RS no recrea los Pods al cambiar la plantilla: elimina los Pods antiguos (`kubectl delete po -n rsapp -l <label>`) para que el RS levante otros nuevos. Consigue `2` réplicas listas. |
| Criterios de aceptación | - ReplicaSet `rs-app2223` (namespace `rsapp`): `2` réplicas Ready. |
---
|        **2**        | **Reparar el Service (Endpoints vacíos)**                    |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | El Service `svc-broken` del namespace `tsvc` no entrega tráfico: tiene los Endpoints vacíos. Diagnóstico: `kubectl get endpoints svc-broken -n tsvc` (vacío), `kubectl describe svc svc-broken -n tsvc` (selector, por ejemplo `app=WRONG`), `kubectl get pods -n tsvc --show-labels` (los Pods tienen la etiqueta `app=web`). Ajusta el selector del Service a los label reales de los Pods (`kubectl patch svc svc-broken -n tsvc -p '{"spec":{"selector":{"app":"web"}}}'`) y asegúrate de que los Endpoints se han rellenado. |
| Criterios de aceptación | - Service `svc-broken` (namespace `tsvc`): los Endpoints no están vacíos (≥ 1 dirección). |
---
|        **3**        | **Reparar el Deployment (falta el ConfigMap)**               |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | El Deployment `capp` del namespace `cfgapp` falla con `CreateContainerConfigError`. La ruta: `kubectl get po -n cfgapp` (vemos el estado), `kubectl describe po -n cfgapp <pod>` (en Events: no se encuentra el ConfigMap `missing-config`). Crea el ConfigMap ausente (`kubectl create configmap missing-config -n cfgapp --from-literal=KEY=value`) y espera hasta que el despliegue esté listo (`kubectl rollout status deploy capp -n cfgapp`). |
| Criterios de aceptación | - Deployment `capp` (namespace `cfgapp`): ≥ 1 réplica Ready. |
---

## Comprobación del resultado

En la máquina de trabajo lanza la verificación automática:

```bash
check_result
```

El script ejecuta los tests y muestra cuántas tareas están completadas.

## Solución

Solución de referencia: [worker/files/solutions/1_ES.MD](worker/files/solutions/1_ES.MD)

## Cobertura de exámenes simulados

El laboratorio cubre las tareas de troubleshooting de los simulados: CKAD mock 01 (n.º 4 —
fix ReplicaSet); la habilidad general de troubleshooting de CKA mock 01/02 (análisis de
estados, Endpoints, configuración) y CKAD mock 02 (n.º 7/n.º 8 — fix ingress/netpol).

## Eliminación del clúster y los recursos

```bash
TASK=114 make delete_cka_task
```
