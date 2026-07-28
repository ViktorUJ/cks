[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD)

# Lab 120 — Drills: servicios y red

## Descripción

Entrenador de velocidad para el dominio Services & Networking. Tareas cortas e
independientes sobre la creación de Services (ClusterIP, NodePort, headless), Ingress y
NetworkPolicy, más un bloque de JSONPath.

Las tareas están redactadas en estilo de examen con verificación automática mediante el
comando `check_result`. El objetivo del drill no es repasar teoría, sino la velocidad y la
memoria muscular: coger soltura y ajustarse al ritmo del examen. Los ficheros de respuesta
de las tareas de JSONPath se guardan en `/home/ubuntu/answers/`.

## Objetivo

Consolidar el material de los capítulos del curso:

- [Capítulo 7. Services: ClusterIP, NodePort, LoadBalancer, Endpoints](../../course/07/ru.md) — tipos de Service, publicación con `expose`, Endpoints
- [Capítulo 31. El Service por dentro, DNS y CoreDNS](../../course/31/ru.md) — Service headless (`clusterIP: None`), nombres DNS
- [Capítulo 32. Ingress y controladores de Ingress](../../course/32/ru.md) — enrutado por host y ruta hacia el Service de backend
- [Capítulo 34. NetworkPolicy](../../course/34/ru.md) — default-deny, podSelector, policyTypes

## Qué hacemos y para qué

| Bloque | Tareas | Habilidad |
|--------|--------|-----------|
| **Services** | Deployment `web`, ClusterIP, NodePort, headless | publicar rápido una carga con distintos tipos de Service (capítulos 7, 31) |
| **Enrutado y aislamiento** | Ingress `web-ing`, NetworkPolicy `deny-all` | reglas de Ingress por host y default-deny del tráfico (capítulos 32, 34) |
| **JSONPath** | nodePort del Service `web-np` → a un fichero | extracción de datos con `-o jsonpath` contra el reloj (capítulo 47) |

## Infraestructura

El entorno se despliega en AWS (`eu-central-1`) mediante Terragrunt y consta de:

| Componente | Descripción                                                          |
|------------|----------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` con subredes públicas                             |
| `ssh-keys` | Claves SSH para el acceso a los nodos                                |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, un solo nodo |
| `worker`   | Máquina de trabajo con `kubectl` y `check_result`                    |

Instancias: `t3.medium` (master), Ubuntu `22.04`. El clúster es de un solo nodo: al master
se le ha quitado el taint `control-plane`, por lo que los pods se planifican directamente
en él.

## Despliegue

```bash
TASK=120 make run_cka_task
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
|        **1**        | **Deployment**                                              |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Crea el namespace (espacio de nombres) `net` y, dentro de él, un Deployment `web` con la imagen `viktoruj/ping_pong:latest` y 2 réplicas (`kubectl create ns net`, `kubectl -n net create deployment web --image=viktoruj/ping_pong:latest --replicas=2`). |
| Criterios de aceptación | - Deployment `web` (ns `net`): 2 réplicas listas. |
---
|        **2**        | **ClusterIP**                                               |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Publica el Deployment `web` como Service (servicio) de tipo ClusterIP con el nombre `web-svc` en el puerto 80 (`kubectl -n net expose deployment web --name=web-svc --port=80 --target-port=8080`). |
| Criterios de aceptación | - Service `web-svc` (ns `net`): los Endpoints no están vacíos. |
---
|        **3**        | **NodePort**                                                |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Crea un Service `web-np` de tipo NodePort para `web` con el `nodePort: 30080` fijo (`kubectl -n net create service nodeport web-np --tcp=80:8080 --node-port=30080`). |
| Criterios de aceptación | - Service `web-np`: tipo `NodePort`, `nodePort` 30080. |
---
|        **4**        | **Service headless**                                        |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Crea un Service headless `web-h` con `clusterIP: None` para los Pods de `web` (selector `app=web`). Un Service headless reparte registros DNS directamente a los Pods, sin pasar por la IP virtual. |
| Criterios de aceptación | - Service `web-h`: `clusterIP` = `None`. |
---
|        **5**        | **Ingress**                                                 |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Crea un Ingress `web-ing` en el namespace `net`: el host `web.local`, la ruta `/` dirige al Service de backend `web-svc` puerto 80 (`kubectl -n net create ingress web-ing --rule="web.local/*=web-svc:80"`). |
| Criterios de aceptación | - Regla del host `web.local` → backend Service `web-svc`, puerto 80. |
---
|        **6**        | **NetworkPolicy (default-deny)**                            |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Crea una NetworkPolicy `deny-all` en el namespace `net` con un `podSelector: {}` vacío (se aplica a todos los Pods) y `policyTypes: [Ingress]`: la política prohíbe todo el tráfico entrante. |
| Criterios de aceptación | - NetworkPolicy `deny-all`: `policyTypes` contiene `Ingress`, `podSelector` está vacío. |
---
|        **7**        | **JSONPath**                                                |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Extrae el `nodePort` del Service `web-np` con `-o jsonpath` y guárdalo en `/home/ubuntu/answers/nodeport.txt` (ruta `{.spec.ports[0].nodePort}`). |
| Criterios de aceptación | - El valor de `nodeport.txt` coincide con `.spec.ports[0].nodePort` del Service `web-np`. |
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

Dominio Services & Networking (20% CKA / 20% CKAD): repasos básicos de Services, Ingress y
NetworkPolicy.

## Eliminación del clúster y los recursos

```bash
TASK=120 make delete_cka_task
```
