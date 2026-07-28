[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD)

# Lab 122 — Ejercicios: planificación de pods

## Descripción

Un entrenador de velocidad para el dominio Workloads & Scheduling: tareas cortas e
independientes sobre nodeSelector, nodeAffinity, requests/limits, PriorityClass y
taints/tolerations. El clúster es de un solo nodo: las labels (etiquetas) y los taints se
ponen en el único nodo.

Las tareas están redactadas en estilo de examen con verificación automática mediante el
comando `check_result`. El objetivo del ejercicio no es repasar la teoría, sino la velocidad
y la memoria muscular: coger soltura con la gestión de la planificación de los Pods y
ajustarse al ritmo del examen.

> **Importante:** haz la tarea 6 (taint) en último lugar — el taint `NoSchedule` impide
> planificar Pods sin toleration.

## Objetivo

Consolidar el material de los capítulos del curso:

- [Capítulo 12. Planificación de pods: nodeName, nodeSelector, affinity](../../course/12/ru.md) — fijar Pods a nodos mediante nodeSelector y nodeAffinity
- [Capítulo 13. Taints y tolerations](../../course/13/ru.md) — repeler Pods con taints y admitirlos con tolerations
- [Capítulo 14. Recursos: requests, limits, LimitRange, ResourceQuota](../../course/14/ru.md) — requests y limits de CPU/memoria por contenedor
- [Capítulo 15. Static Pods, PriorityClass, varios planificadores](../../course/15/ru.md) — prioridad de los Pods mediante PriorityClass

## Qué hacemos y para qué

| Bloque | Tareas | Habilidad |
|--------|--------|-----------|
| **Fijación a un nodo** | label `disk=ssd`, Pod `sel` (nodeSelector), Pod `aff` (nodeAffinity) | dirigir los Pods a los nodos adecuados (capítulo 12) |
| **Recursos y prioridad** | Pod `res` (requests/limits), PriorityClass `high-prio` + Pod `prio` | requests/limits y prioridad de planificación (capítulos 14, 15) |
| **Taints y tolerations** | taint `dedicated=special:NoSchedule` + Pod `tol` | aislar un nodo con un taint y admitir Pods mediante toleration (capítulo 13) |

## Infraestructura

El entorno se despliega en AWS (`eu-central-1`) mediante Terragrunt y consta de:

| Componente | Descripción                                                                     |
|------------|---------------------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` con subredes públicas                                        |
| `ssh-keys` | Claves SSH para el acceso a los nodos                                            |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, de un nodo; el namespace `sched` se crea con antelación |
| `worker`   | Máquina de trabajo con `kubectl` y `check_result`                               |

Instancias: `t3.medium` (master), Ubuntu `22.04`. El clúster es de un solo nodo: al master
se le ha quitado el taint `control-plane`, por lo que los pods se planifican directamente
en él.

## Despliegue

```bash
TASK=122 make run_cka_task
```

Tras la creación, conéctate por SSH a la máquina de trabajo (worker) y realiza las tareas
desde allí. `kubectl` ya está configurado con el contexto `cluster1-admin@cluster1`.

Comandos útiles en la máquina de trabajo:

```bash
time_left       # cuánto tiempo queda
check_result    # comprobar la solución
```

## Tareas

Conviene guardar el nombre del único nodo en una variable:
`NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')`.

---
|        **1**        | **Etiqueta en el nodo**                                     |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Pon en el nodo la label (etiqueta) `disk=ssd` (`kubectl label node $NODE disk=ssd`). |
| Criterios de aceptación | - el nodo tiene la label `disk=ssd`. |
---
|        **2**        | **nodeSelector**                                            |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Crea el Pod `sel` (ns `sched`, imagen `viktoruj/ping_pong:latest`) con `nodeSelector: disk=ssd`: el Pod solo se planifica en un nodo con esa label. |
| Criterios de aceptación | - el Pod `sel` está en estado `Running`, `nodeSelector` `disk=ssd`. |
---
|        **3**        | **nodeAffinity**                                            |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Crea el Pod `aff` (ns `sched`, imagen `viktoruj/ping_pong:latest`) con nodeAffinity required: clave `disk`, operador `In`, valores `[ssd]` (`requiredDuringSchedulingIgnoredDuringExecution`). |
| Criterios de aceptación | - el Pod `aff` está en estado `Running`, nodeAffinity está definido. |
---
|        **4**        | **requests / limits**                                       |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Crea el Pod `res` (ns `sched`, imagen `viktoruj/ping_pong:latest`) con requests `cpu=100m`, `memory=64Mi` y limits `cpu=200m`, `memory=128Mi` en el contenedor. |
| Criterios de aceptación | - el Pod `res` está en estado `Running`, los limits de `cpu` y `memory` están definidos. |
---
|        **5**        | **PriorityClass**                                           |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Crea la PriorityClass `high-prio` con el valor `value: 1000` (`kubectl create priorityclass high-prio --value=1000`) y luego el Pod `prio` (ns `sched`, imagen `viktoruj/ping_pong:latest`) con `priorityClassName: high-prio`. |
| Criterios de aceptación | - PriorityClass `high-prio` `value=1000`;<br/>- el Pod `prio` está en estado `Running` con `priorityClassName: high-prio`. |
---
|        **6**        | **Taint + toleration** (en último lugar)                    |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Pon en el nodo el taint `dedicated=special:NoSchedule` (`kubectl taint node $NODE dedicated=special:NoSchedule`) y después crea el Pod `tol` (ns `sched`, imagen `viktoruj/ping_pong:latest`) con la toleration correspondiente (`key=dedicated`, `operator=Equal`, `value=special`, `effect=NoSchedule`). **Haz esta tarea en último lugar**: el taint impedirá planificar los demás Pods. |
| Criterios de aceptación | - el nodo tiene el taint `dedicated=special:NoSchedule`;<br/>- el Pod `tol` está en estado `Running`. |
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

El dominio Workloads & Scheduling (15% CKA) — repeticiones de nodeSelector/affinity,
recursos, PriorityClass, taints/tolerations.

## Eliminación del clúster y los recursos

```bash
TASK=122 make delete_cka_task
```
