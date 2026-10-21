[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 114 - Kubeconfig contexts, client certificates y API exposure

## Descripción

El kubeconfig que se entrega al estudiante contiene varios contexts: el operativo `cluster1-admin@cluster1`
y dos deliberadamente inoperativos (`staging-admin@staging`, `legacy-admin@legacy`), que apuntan a API server
inexistentes. `current-context` justo después del login está establecido en el inoperativo `staging-admin@staging`: esto
reproduce a propósito una situación real del examen, en la que al candidato se le entrega un kubeconfig con varios
context y tiene que entender por sí mismo cuál de ellos es el operativo.

Aparte, en el mismo kubeconfig hay un usuario `cluster9-admin` con un client certificate completo, realmente generado,
autofirmado (`client-certificate-data`/`client-key-data`). Este certificado no da
ningún permiso en el clúster (su CA no es de confianza para el apiserver): la tarea enseña a leer y analizar un
client certificate de un kubeconfig, y no a autenticarse con él.

Además, el laboratorio cubre el escenario clásico de reducción de la superficie de ataque de un Service: primero creas
deliberadamente un Service `NodePort` (accesible externamente en la IP del nodo control-plane), y luego lo reduces a
`ClusterIP`, demostrando el efecto en vivo en ambos sentidos.

## Despliegue

En la máquina de gestión, lanza el entorno:

```bash
TASK=114 make run_cks_task
```

Tras un despliegue correcto, Terraform mostrará el comando SSH para conectarse al worker:

```
worker_pc_ssh = "ssh ubuntu@<IP> password=<PASSWORD>"
```

Conéctate solo a la dirección de la salida de Terraform:

```bash
ssh ubuntu@<IP>
```

Trabaja en el worker. Comprueba por tu cuenta cada etapa; lanza `check_result` después de completar
las tareas, y abre la solución de referencia solo después de un intento propio o si te atascas.

## Objetivo

Aprender a trabajar de forma segura con un kubeconfig que contiene varios contextos, a extraer y comprobar un
client certificate sin usarlo para la autenticación, y a gestionar de forma consciente el exposure de un Service
mediante el cambio `NodePort` -> `ClusterIP`.

## Infraestructura

| Componente | Finalidad |
| --- | --- |
| kubeconfig (`~/.kube/config`) | 4 context: 1 operativo (`cluster1-admin@cluster1`), 2 decoy (`staging-admin@staging`, `legacy-admin@legacy`), 1 con un client certificate real (`cluster9-admin@cluster1`) |
| `cks-114` | namespace de tu aplicación backend y del Service |
| control-plane EC2 | clúster kubeadm de un solo nodo, CNI Calico |

## Tareas

---

|           **1**           | **Kubeconfig context inventory** |
| :-----------------------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Qué hacemos       | • Ejecuta `kubectl config get-contexts`, determina el `current-context` actual (inoperativo).<br/>• Encuentra el context realmente operativo y cambia a él: `kubectl config use-context <name>`. |
| Criterios de aceptación | • `current-context` == `cluster1-admin@cluster1`.<br/>• Desde este context realmente pasa una petición al API server (no que simplemente exista en el archivo). |
|        Comprobación        | `kubectl config current-context`, luego `kubectl get nodes`: debe devolver una lista real de nodos, y no un connection error. |

---

|           **2**           | **Client certificate extraction** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       Qué hacemos       | • Extrae el `client-certificate-data` del usuario `cluster9-admin` del kubeconfig, decodifica el base64 y analiza el certificado mediante `openssl x509`.<br/>• Guarda el resultado en `/var/work/tests/artifacts/task2-cert.txt` en formato `KEY=VALUE`, un valor por línea: `SHA256_FP`, `SUBJECT`, `ISSUER`, `NOTBEFORE`, `NOTAFTER`. |
| Criterios de aceptación | • Los cinco valores del artefacto coinciden con lo que se extrae del certificado bootstrap original de `cluster9-admin`.<br/>• El Checker contrasta el fingerprint original, la inmutabilidad del certificado en el kubeconfig y los cinco campos. |
|        Comprobación        | ```bash<br/>cert=$(kubectl config view --raw -o jsonpath='{.users[?(@.name=="cluster9-admin")].user.client-certificate-data}' \| base64 -d)<br/>echo "$cert" \| openssl x509 -noout -fingerprint -sha256 -subject -issuer -startdate -enddate<br/>```<br/>`-fingerprint -sha256` imprime `sha256 Fingerprint=AA:BB:...`: en el artefacto escribe el hex sin dos puntos (las mayúsculas/minúsculas no importan). |

---

|           **3**           | **Baseline: NodePort exposure** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Qué hacemos       | • Crea el namespace `cks-114`.<br/>• Crea un Deployment `backend` (por ejemplo `viktoruj/ping_pong:alpine` con `SRV_PORT=80`, label `app=backend`).<br/>• Crea un Service `kubernetes-public` de tipo `NodePort` en el puerto 80, con un `nodePort: 30114` explícito.<br/>• **No toques** el Service `default/kubernetes`. |
| Criterios de aceptación | • El backend es realmente alcanzable tanto desde el propio nodo por `<node-internal-ip>:30114`, como dentro del clúster por `kubernetes-public.cks-114.svc.cluster.local`.<br/>• `default/kubernetes` sigue siendo `ClusterIP`.<br/>• La tarea 4 después convierte este mismo Service en `ClusterIP`, por lo que al final del laboratorio el estado NodePort ya no se observa: la fase histórica de NodePort se confirma con dos probes HTTP 200 (desde el worker y por DNS desde un Pod), con la comprobación del backend/EndpointSlice y con un monitor que conserva el UID del Service y del Deployment.<br/>• Primero completa la tarea 3 por completo y espera al archivo `/var/lib/cks-lab114-checker/nodeport-phase-seen`, que crea el monitor tras ambos live-probes exitosos; solo después realiza la tarea 4. El archivo es la confirmación de la fase histórica para el mismo Service/Deployment. |
|        Comprobación        | Desde el worker (fuera del clúster): `curl http://<node-internal-ip>:30114/` -> HTTP 200.<br/>Desde dentro del clúster (un Pod temporal con curl): `curl http://kubernetes-public.cks-114.svc.cluster.local/` -> HTTP 200. La IP del nodo: `kubectl get nodes -o wide`. |

---

|           **4**           | **Reduce exposure: NodePort -> ClusterIP** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       Qué hacemos       | • Cambia `kubernetes-public` al tipo `ClusterIP`.<br/>• Recuerda: el API server no permitirá dejar `nodePort` con el tipo `ClusterIP`: el campo hay que quitarlo explícitamente (`kubectl edit svc kubernetes-public` y elimina la línea `nodePort`, o `kubectl patch` con `$patch: replace` sobre el array `ports`). |
| Criterios de aceptación | • La ruta externa `<node-internal-ip>:30114` ahora está bloqueada a nivel de transporte (connection refused/timeout).<br/>• La ruta dentro del clúster sigue funcionando.<br/>• El Backend Pod sigue Ready. |
|        Comprobación        | Desde el worker: `curl -m5 http://<node-internal-ip>:30114/` -> error de conexión (no un código HTTP).<br/>Desde dentro del clúster: `curl http://kubernetes-public.cks-114.svc.cluster.local/` -> HTTP 200 como antes.<br/>`kubectl -n cks-114 get svc kubernetes-public -o yaml` -> `type: ClusterIP`, ningún puerto tiene `nodePort`. |

## Comprobación

```bash
check_result
```

El Checker comprueba `current-context` y una petición en vivo a la API a través de él, extrae y analiza de forma independiente
el certificado `cluster9-admin`, lo comprueba respecto del fingerprint bootstrap original y lo compara con tu artefacto, y también ejecuta un probe HTTP 200 externo y dentro del clúster, comprueba el Deployment, el EndpointSlice y la inmutabilidad de `default/kubernetes`. La fase histórica de NodePort la confirma un monitor root-owned con dos live-probes antes del cambio del Service; en el estado ClusterIP el checker comprueba el DNS en vivo y la denegación de transporte de NodePort.

Solución de referencia: [worker/files/solutions/1_ES.MD](worker/files/solutions/1_ES.MD).

## Eliminación

```bash
TASK=114 make delete_cks_task
```
