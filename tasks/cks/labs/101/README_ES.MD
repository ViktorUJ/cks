[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 101 - NetworkPolicy: default-deny, aislamiento y EC2 IMDS

## Descripción

`NetworkPolicy` funciona como una allow-list: tras default-deny, los flujos necesarios se restablecen únicamente mediante reglas explícitas. La aplicación efectiva de las reglas corre a cargo de Calico. El worker de este laboratorio es una instancia EC2 gestionada por Terraform; su Instance Metadata Service (IMDS) está disponible en `http://169.254.169.254/`. Terraform habilita explícitamente el HTTP endpoint, deja permitido el GET de IMDSv1 para un probe seguro y establece el response hop limit en `2`, de modo que, antes de default-deny, un Pod normal pueda confirmar la alcanzabilidad de red hacia IMDS.

El laboratorio comprueba únicamente la alcanzabilidad de red del IMDS endpoint, sin leer metadata ni credentials. Cualquier HTTP status `1xx–5xx` realmente recibido significa que existe un camino TCP/HTTP hasta IMDS. El código `000` (`HTTP:000` en los comandos de la solución, `HTTPCODE:000` en la salida del checker) junto con un transport error/timeout significa que no hay respuesta HTTP. El HTTP status concreto depende de las EC2 metadata options: si el token usage es `required`, un GET sin un IMDSv2 token válido recibe `401`; si IMDSv1 está permitido, un GET tokenless se considera una petición IMDSv1 y puede recibir una HTTP response normal.

**Riesgo residual.** El worker EC2 tiene asociado un IAM instance profile, y un GET tokenless de IMDSv1 a `latest/meta-data/iam/security-credentials/<role>` devuelve realmente credentials temporales de AWS (AccessKeyId/SecretAccessKey/SessionToken): no es un riesgo hipotético, sino el comportamiento real del entorno actual. El propio rol está limitado a permisos prácticamente nulos (least privilege: ni siquiera puede leer su propio IAM role mediante `iam:GetRole`), por lo que el valor práctico de la fuga para un atacante es mínimo, pero el estudiante debe entender claramente que en producción, con la misma configuración (`HttpTokens=optional`, IMDSv1 permitido), este mismo comando devolvería credentials reales de un rol de producción con permisos reales. El laboratorio reproduce a propósito este anti-patrón del capítulo 02.1 (IMDSv1 allowed, response hop limit `2`) con fines de probe y para aprender a encontrar esta vulnerabilidad mediante NetworkPolicy; en producción usa `HttpTokens=required` (solo IMDSv2) y `HttpPutResponseHopLimit=1`.

## Despliegue

En la máquina de gestión, lanza el entorno:

```bash
TASK=101 make run_cks_task
```

Tras un despliegue correcto, Terraform mostrará el comando SSH para conectarse al worker. Tendrá este formato:

```
worker_pc_ssh = "ssh ubuntu@<IP> password=<PASSWORD>"
```

Por ejemplo:

```
18:53:06.019 STDOUT [worker] terraform: worker_pc_ssh = "ssh ubuntu@18.193.110.150 password= fq0J9RuZWN"
```

Para conectarte usa solo la dirección del comando:

```bash
ssh ubuntu@<IP>
```

Cuando SSH pida la contraseña, introduce el valor que Terraform mostró después de `password=`.

**Para las comprobaciones de runtime** usa un Pod de diagnóstico temporal con los mismos labels que la identity que se comprueba. Para las comprobaciones HTTP hace falta una imagen con curl (`curlimages/curl:8.11.1`); para DNS, una imagen con nslookup (`busybox:1.36.1`). Tras la comprobación, elimina los Pods temporales y las policies temporales.

Trabaja en el worker. Antes de empezar, asegúrate de que los namespaces estén limpios (por si acaso):

```bash
kubectl delete namespace cks-101 cks-101-legacy imds-control --ignore-not-found --wait=true
printf 'EC2 IMDS target: %s\n' 'http://169.254.169.254/'
time_left
```

Comprueba cada etapa por tu cuenta sobre tus propios recursos; lanza `check_result` después de completar las tareas y abre la solución de referencia solo después de un intento propio o si te atascas.

## Objetivo

Configurar una allow-list mínima de ingress/egress, fijar el image digest, demostrar la semántica AND del selector y el `ipBlock.except` exacto para IMDS, y después comparar un Pod normal con uno con `hostNetwork`, sin suponer de antemano un resultado universal.

## Infraestructura

| Componente | Finalidad |
| ------------------ | ---------------------------------------------------------------------------------------------------- |
| `cks-101`        | namespace de la aplicación y de sus `NetworkPolicy` |
| `cks-101-legacy` | namespace del escenario del cliente legacy |
| `imds-control`   | namespace independiente sin policy para el baseline y para el control probe repetido |
| worker EC2       | instancia EC2 gestionada por Terraform con IMDS `http://169.254.169.254/` |
| CNI                | Calico |

## Tareas

---

|           **1**           | **Aplicación** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       Qué hacemos       | Namespace `cks-101`; Deployments `frontend` y `backend` con `replicas: 1`, sin `hostNetwork`, con el mismo `viktoruj/ping_pong@sha256:<64hex>`; Service `backend` TCP/8080.<br/><br/>**Cómo obtener el digest actual:**<br/>1. Lanza temporalmente un Pod con la imagen `viktoruj/ping_pong:latest`.<br/>2. Espera al pull y a Ready.<br/>3. Ejecuta `digest=$(kubectl get pod <pod_name> -o yaml \| grep imageID \| cut -d'@' -f2)` y obtén `sha256:<64hex>`.<br/>4. Elimina el Pod temporal.<br/>5. Usa el digest obtenido para ambos Deployment: `viktoruj/ping_pong@sha256:<64hex>`. |
| Criterios de aceptación | Ambas replicas en Ready, las image references son idénticas, el Service tiene endpoint. |
|        Comprobación        | Ejecuta `kubectl -n cks-101 get deploy,svc,endpoints` y asegúrate de que:<br/>1. Ambos Deployment tienen `1/1 Ready`.<br/>2. El Service `backend` tiene endpoint.<br/><br/>Para comprobar la pinned image ejecuta:<br/>`kubectl -n cks-101 get deploy frontend backend -o yaml \| grep 'image:'`<br/>Ambos Deployment deben usar la misma imagen del tipo `viktoruj/ping_pong@sha256:<64hex>`. |

---

|           **2**           | **Baseline, default-deny y probe repetido** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Qué hacemos       | Crea el namespace `imds-control` y un curl Pod temporal. Crea el frontend probe en `cks-101`. **Antes de `default-deny`** confirma dos baselines: frontend → backend y frontend → IMDS son alcanzables; `imds-control` → IMDS también es alcanzable. Después crea `default-deny`. **Tras `default-deny`** repite los IMDS probes: frontend debe recibir `HTTP 000` y curl `7`/`28`, y `imds-control` debe seguir recibiendo un HTTP `1xx–5xx` real con exit `0`. El deny del backend se comprueba en Task 3, después de restablecer DNS. |
| Criterios de aceptación | Antes del deny, backend e IMDS son realmente alcanzables. Tras el deny, frontend → IMDS da `HTTP 000` + curl `7`/`28`; el `imds-control` independiente mantiene HTTP `1xx–5xx` + exit `0`. |
|        Comprobación        | 1. Antes de `default-deny`: curl desde el frontend probe a `http://backend:8080/` debe recibir una HTTP response + exit `0`.<br/>2. Antes de `default-deny`: frontend e `imds-control` deben recibir una HTTP response real de IMDS.<br/>3. Comprueba `default-deny`: `podSelector` vacío, `Ingress` + `Egress`, sin allow-rules.<br/>4. Tras `default-deny`: frontend → IMDS debe devolver `HTTP 000` + curl `7`/`28`; `imds-control` → IMDS debe seguir recibiendo HTTP `1xx–5xx` + exit `0`.<br/>5. No compruebes el deny del backend antes de restablecer DNS: se comprueba en Task 3. |

---

|           **3**           | **DNS** |
| :-----------------------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Qué hacemos       | Tras `default-deny`, con la primera allow-rule devuelve al frontend acceso únicamente a `kube-system/kube-dns` por exact UDP/53 y TCP/53, sin `endPort`. Para la comprobación, crea un `dns-probe` aparte con `busybox:1.36.1` y el label `app=frontend`. |
| Criterios de aceptación | El DNS allow-set es exactamente UDP/53 + TCP/53; `nslookup kubernetes.default.svc.cluster.local` funciona. En este momento el backend aún no debe ser alcanzable por TCP/8080. |
|        Comprobación        | 1. Comprueba `allow-frontend-dns` en el YAML: solo UDP/53 y TCP/53, sin `endPort` ni puertos adicionales.<br/>2. Ejecuta `nslookup kubernetes.default.svc.cluster.local` desde `dns-probe`.<br/>3. Tras un DNS correcto, ejecuta curl desde el frontend probe a `http://backend:8080/`: hasta Task 4 se espera `HTTP 000` + curl `7`/`28`. |

---

|           **4**           | **NetworkPolicy para la aplicación** |
| :-----------------------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Qué hacemos       | Crea `allow-frontend-egress-to-backend` y `allow-backend-ingress-from-frontend`. Después de esto, frontend debe recibir una HTTP response real de `http://backend:8080/`. |
| Criterios de aceptación | Frontend → backend:8080 está permitido; una foreign identity sigue bloqueada. |
|        Comprobación        | Positive: curl del frontend por el Service DNS. Negative: un foreign Pod con una egress policy temporal hacia backend no debe pasar el backend ingress. |

---

|           **5**           | **Comprobación final de IMDS** |
| :-----------------------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Qué hacemos       | Tras añadir las policies allow de DNS y de la aplicación, repite el mismo IMDS probe desde el Pod frontend y desde el `imds-control` independiente. El objetivo es demostrar que las nuevas policies allow no abrieron IMDS. No hace falta crear archivos de artifact auxiliares. |
| Criterios de aceptación | `imds-control`: HTTP `1xx–5xx` real + exit `0`; frontend: `HTTP 000` + curl `7`/`28`. |
|        Comprobación        | Ejecuta el mismo curl acotado (`-m 5`) desde ambos Pods y compara el resultado real. No uses `curl -f`: un HTTP `401/403/404/...` también significa alcanzabilidad de red. |

---

|           **6**           | **Legacy AND e IMDS except** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Qué hacemos       | Crea el namespace `cks-101-legacy` con el Deployment `legacy-client`: replicas=1, sin hostNetwork, imagen `curlimages/curl:8.11.1`, comando `sleep 3600`. Crea la NetworkPolicy `allow-backend-ingress-from-legacy` en el namespace `cks-101`: selecciona backend, contiene un único ingress peer con AND selector (namespaceSelector y podSelector en un mismo elemento `from`), TCP/8080. Crea la NetworkPolicy `allow-legacy-egress` en el namespace `cks-101-legacy`: selecciona app=legacy-client, contiene ipBlock cidr=0.0.0.0/0 con un único except 169.254.169.254/32, sin allow-rules adicionales. Comprueba: 1) IMDS desde legacy-client está bloqueado; 2) legacy-client puede alcanzar backend; 3) un Pod con otro label en el mismo namespace no pasa el ingress; 4) un Pod con label=legacy-client en el namespace cks-101 no pasa el ingress. Tras las comprobaciones, elimina los Pods temporales y las policies temporales. |
| Criterios de aceptación | IMDS bloqueado, el flujo real legacy-client → backend permitido, el Pod con un label incorrecto o de un namespace incorrecto bloqueado. |
|        Comprobación        | 1. Ejecuta `kubectl -n cks-101-legacy get networkpolicy allow-legacy-egress -o yaml` y asegúrate de que `ipBlock.cidr=0.0.0.0/0` y el único `except` es `169.254.169.254/32`.<br/>2. Ejecuta `kubectl -n cks-101 get networkpolicy allow-backend-ingress-from-legacy -o yaml` y asegúrate de que `namespaceSelector` y `podSelector` están en un mismo elemento `from`, puerto TCP/8080.<br/>3. Curl desde `legacy-client` a IMDS debe devolver `HTTP 000` y exit `7` o `28`.<br/>4. Curl desde `legacy-client` a backend debe recibir una HTTP response real.<br/>5. Un Pod con otro label en `cks-101-legacy` con un egress temporal hacia backend no debe pasar el backend ingress.<br/>6. Un Pod con `app=legacy-client` en el namespace `cks-101` con un egress temporal hacia backend tampoco debe pasar el backend ingress. |

---

|           **7**           | **Observación de hostNetwork** |
| :-----------------------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Qué hacemos       | Crea `hostnetwork-probe` con la imagen `curlimages/curl:8.11.1`, el label `app=frontend` y `spec.hostNetwork=true`. Ejecuta desde él el mismo curl a IMDS que usaste para el Pod frontend normal. Compara la observación real con Task 5. No hace falta crear archivos de artifact auxiliares. |
| Criterios de aceptación | Pod Ready, `hostNetwork=true`, IMDS probe real ejecutado. Para hostNetwork no se presupone un resultado esperado universal: el comportamiento depende del CNI y de la configuración del nodo. |
|        Comprobación        | Comprueba `hostNetwork: true`, después ejecuta un curl acotado (`-m 5`) a IMDS y `echo $?`. Compara la observación real con el Pod normal de Task 5. |

## Comprobación

```bash
check_result
```

El Checker crea y elimina sus propios namespace `imds-control` y probes: antes y después del deny en `cks-101` confirma que el IMDS real responde desde un namespace independiente sin policy. No confía en los recursos de control de un intento anterior y no sustituye las comprobaciones propias de baseline/runtime. Las policies adicionales que amplíen los flujos permitidos provocan un error.

Solución de referencia: [worker/files/solutions/1_ES.MD](worker/files/solutions/1_ES.MD).

## Eliminación

```bash
TASK=101 make delete_cks_task
```
