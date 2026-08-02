[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 121 — Drills: RBAC

## Descripción

Entrenamiento de velocidad sobre RBAC: tareas cortas e independientes de ServiceAccount,
Role/RoleBinding, ClusterRole/ClusterRoleBinding y comprobación de los permisos efectivos
con `kubectl auth can-i`. El namespace `rbac` está creado de antemano.

Las tareas están redactadas en estilo de examen con verificación automática mediante el
comando `check_result`. El objetivo del drill no es repasar la teoría, sino la velocidad y
la memoria muscular: «coger soltura» creando objetos de RBAC de forma imperativa y
mantener el ritmo del examen.

## Objetivo

Consolidar el material de los capítulos del curso:

- [Capítulo 21. ServiceAccount; autenticación, autorización, admission](../../course/21/es.md) — ServiceAccount, la cadena authn/authz/admission
- [Capítulo 38. RBAC: Role, ClusterRole y bindings](../../course/38/es.md) — Role/ClusterRole, RoleBinding/ClusterRoleBinding, comprobación de permisos con `auth can-i`

## Qué hacemos y para qué

| Bloque | Tareas | Habilidad |
|--------|--------|-----------|
| **RBAC con namespace** | ServiceAccount `app-sa`, Role `pod-reader`, RoleBinding `read-pods` | permisos dentro de un namespace mediante Role + binding (capítulo 38) |
| **RBAC a nivel de clúster** | ClusterRole `cr-viewer`, ClusterRoleBinding `crb-viewer` | acceso a recursos del clúster (nodes) mediante ClusterRole (capítulo 38) |
| **Comprobación de permisos** | `kubectl auth can-i` para `app-sa` | validación rápida de los permisos efectivos de un ServiceAccount (capítulo 21) |

## Infraestructura

El entorno se despliega en AWS (`eu-central-1`) mediante Terragrunt y consta de:

| Componente | Descripción                                                                     |
|------------|---------------------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` con subredes públicas                                        |
| `ssh-keys` | Claves SSH para el acceso a los nodos                                            |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, de un solo nodo; el namespace `rbac` está creado de antemano |
| `worker`   | Máquina de trabajo con `kubectl` y `check_result`                               |

Instancias: `t3.medium` (master), Ubuntu `22.04`. El clúster es de un solo nodo: al master
se le ha quitado el taint `control-plane`, por lo que los pods se planifican directamente
en él.

## Despliegue

```bash
TASK=121 make run_cka_task
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
|        **1**        | **ServiceAccount**                                          |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Crea el ServiceAccount `app-sa` en el namespace `rbac` (`kubectl -n rbac create serviceaccount app-sa`). |
| Criterios de aceptación | - el ServiceAccount `app-sa` existe en el namespace `rbac`. |
---
|        **2**        | **Role**                                                    |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Crea el Role `pod-reader` en el namespace `rbac` con los permisos `get,list,watch` sobre el recurso `pods` (`kubectl -n rbac create role pod-reader --verb=get,list,watch --resource=pods`). |
| Criterios de aceptación | - el Role `pod-reader` concede `get`/`list`/`watch` sobre `pods`. |
---
|        **3**        | **RoleBinding**                                             |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Crea el RoleBinding `read-pods` en el namespace `rbac`, enlazando el Role `pod-reader` con el sujeto ServiceAccount `app-sa` (`kubectl -n rbac create rolebinding read-pods --role=pod-reader --serviceaccount=rbac:app-sa`). |
| Criterios de aceptación | - el RoleBinding `read-pods` referencia el Role `pod-reader` y el sujeto `app-sa`. |
---
|        **4**        | **ClusterRole**                                             |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Crea el ClusterRole `cr-viewer` con los permisos `get,list` sobre el recurso de clúster `nodes` (`kubectl create clusterrole cr-viewer --verb=get,list --resource=nodes`). |
| Criterios de aceptación | - el ClusterRole `cr-viewer` concede `get`/`list` sobre `nodes`. |
---
|        **5**        | **ClusterRoleBinding**                                      |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Crea el ClusterRoleBinding `crb-viewer`, enlazando el ClusterRole `cr-viewer` con el sujeto ServiceAccount `app-sa` del namespace `rbac` (`kubectl create clusterrolebinding crb-viewer --clusterrole=cr-viewer --serviceaccount=rbac:app-sa`). |
| Criterios de aceptación | - el ClusterRoleBinding `crb-viewer` referencia el ClusterRole `cr-viewer` y el sujeto `rbac/app-sa`. |
---
|        **6**        | **Comprobación de permisos (auth can-i)**                   |
| :-----------------: | :----------------------------------------------------------- |
| Qué hacemos         | Comprueba los permisos efectivos de `app-sa` con `kubectl auth can-i ... --as=system:serviceaccount:rbac:app-sa`: `get pods` en `rbac`, `get nodes` y `delete pods` en `rbac`. Asegúrate de que los enlaces se han concedido correctamente. |
| Criterios de aceptación | - `get pods` en el namespace `rbac` = `yes`;<br/>- `get nodes` = `yes`;<br/>- `delete pods` en el namespace `rbac` = `no`. |
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

El dominio Cluster Architecture (RBAC) para CKA y Application Security para CKAD:
repetición de Role/ClusterRole y de los enlaces con un ServiceAccount.

## Eliminación del clúster y los recursos

```bash
TASK=121 make delete_cka_task
```
