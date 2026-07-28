[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD)

# Lab 119 — Ejercicios de velocidad y JSONPath

## Descripción

Un entrenador de velocidad para CKA/CKAD: tareas cortas y repetitivas de creación
imperativa de objetos (Pod, Deployment, Service, ConfigMap, Secret) y un bloque aparte
dedicado a `-o jsonpath`: extraer datos de los objetos del clúster a ficheros.

Las tareas están redactadas en estilo de examen con verificación automática mediante el
comando `check_result`. El objetivo del ejercicio no es repasar la teoría, sino la velocidad
y la memoria muscular: coger soltura con los comandos imperativos y ajustarse al ritmo del
examen (~6-8 minutos por tarea). Los ficheros de respuesta de las tareas de JSONPath se
guardan en `/home/ubuntu/answers/`.

## Objetivo

Consolidar el material de los capítulos del curso:

- [Capítulo 3. Trabajar con kubectl: enfoques imperativo y declarativo](../../course/03/ru.md) — comandos imperativos rápidos, `--dry-run=client -o yaml`, generadores de objetos
- [Capítulo 47. Examen CKAD: JSONPath y productividad con kubectl](../../course/47/ru.md) — extracción de datos con `-o jsonpath`, custom-columns, `--sort-by`
- [Capítulo 48. Examen CKA: gestión del tiempo y estrategia](../../course/48/ru.md) — reparto del tiempo y orden de resolución de las tareas

## Qué hacemos y para qué

| Bloque | Tareas | Habilidad |
|--------|--------|-----------|
| **Ejercicios** | namespace, Deployment, Service, ConfigMap, Secret | velocidad con los comandos imperativos, `--dry-run` (capítulo 3) |
| **JSONPath** | versiones de los nodos, imágenes de los Pods, ClusterIP del Service → a ficheros | `-o jsonpath`, extracción de datos contra el reloj (capítulo 47) |

## Infraestructura

El entorno se despliega en AWS (`eu-central-1`) mediante Terragrunt y consta de:

| Componente | Descripción                                                          |
|------------|----------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` con subredes públicas                             |
| `ssh-keys` | Claves SSH para el acceso a los nodos                                |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, de un nodo |
| `worker`   | Máquina de trabajo con `kubectl` y `check_result`                    |

Instancias: `t3.medium` (master), Ubuntu `22.04`. El clúster es de un solo nodo: al master
se le ha quitado el taint `control-plane`, por lo que los pods se planifican directamente
en él.

## Despliegue

```bash
TASK=119 make run_cka_task
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
|        **1**        | **Namespace**                                                |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Crea el namespace (espacio de nombres) `drill`: en él vivirán los objetos de las demás tareas (`kubectl create namespace drill`). |
| Criterios de aceptación | - el namespace `drill` existe. |
---
|        **2**        | **Deployment**                                              |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | En el namespace `drill` crea un Deployment `api` con la imagen `viktoruj/ping_pong:latest` y 3 réplicas (`kubectl -n drill create deployment api --image=viktoruj/ping_pong:latest --replicas=3`). |
| Criterios de aceptación | - Deployment `api` en `drill`: 3 réplicas listas. |
---
|        **3**        | **Service**                                                 |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Publica el Deployment `api` como un Service (servicio) de tipo ClusterIP con el nombre `api-svc` en el puerto 80 (`kubectl -n drill expose deployment api --name=api-svc --port=80 --target-port=8080`). |
| Criterios de aceptación | - Service `api-svc` (ns `drill`): los Endpoints no están vacíos. |
---
|        **4**        | **ConfigMap y Secret**                                      |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | En el namespace `drill` crea un ConfigMap `cfg` con la clave `APP_COLOR=blue` y un Secret `sec` con la clave `PASSWORD` (cualquier valor). Usa `--from-literal`. |
| Criterios de aceptación | - `cfg.data.APP_COLOR=blue`;<br/>- el Secret `sec` tiene la clave `PASSWORD`. |
---
|        **5**        | **JSONPath: versiones de los nodos**                        |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Extrae el `kubeletVersion` de todos los nodos con `-o jsonpath` y guarda el resultado en el fichero `/home/ubuntu/answers/versions.txt` (ruta `{.items[*].status.nodeInfo.kubeletVersion}`). |
| Criterios de aceptación | - El contenido de `versions.txt` coincide con la salida de `jsonpath` para los nodos. |
---
|        **6**        | **JSONPath: imágenes de los Pods**                          |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Extrae las imágenes de los contenedores de todos los Pods del namespace `drill` con `-o jsonpath` y guárdalas en `/home/ubuntu/answers/images.txt` (ruta `{.items[*].spec.containers[*].image}`). |
| Criterios de aceptación | - El conjunto de imágenes de `images.txt` coincide con la salida de `jsonpath` para los Pods de `drill`. |
---
|        **7**        | **JSONPath: ClusterIP del Service**                         |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Extrae el ClusterIP del Service `api-svc` con `-o jsonpath` y guárdalo en `/home/ubuntu/answers/api-ip.txt` (ruta `{.spec.clusterIP}`). |
| Criterios de aceptación | - El valor de `api-ip.txt` coincide con `.spec.clusterIP` del Service `api-svc`. |
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

Habilidades básicas de velocidad y JSONPath, demandadas en todos los exámenes simulados de
CKA y CKAD.

## Eliminación del clúster y los recursos

```bash
TASK=119 make delete_cka_task
```
