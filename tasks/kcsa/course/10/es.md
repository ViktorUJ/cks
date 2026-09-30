[Русская версия](ru.md) · [Eng version](README.md) · [Version française](fr.md) · [Deutsche Version](de.md) · [ქართული ვერსია](ge.md) · [繁體中文版](tw.md) · [日本語版](jp.md)

# Capítulo 10. Autenticación y autorización

> **Qué sigue.** En los capítulos 07-09 protegimos los componentes del clúster, los nodos de trabajo, los `Pod` y los límites de red. Ahora examinaremos el recorrido de una solicitud a la API de Kubernetes: primero el clúster establece la identidad y luego decide si puede realizarse la acción. Este es el dominio KCSA **Kubernetes Security Fundamentals**, con un peso del 22%.

## 10.1 Quién accede a la API: usuarios y `ServiceAccount`

Cada solicitud a la API de Kubernetes pasa por autenticación, o authentication. Su tarea es responder la pregunta «¿quién es?». Tras una autenticación correcta, API Server pasa el nombre del usuario y los grupos a la siguiente etapa, la autorización.

Un usuario normal, por ejemplo un ingeniero o un sistema CI fuera del clúster, no es un objeto Kubernetes `User`. Kubernetes obtiene dicha identidad a través del mecanismo de autenticación configurado. `ServiceAccount` es un objeto de la API de Kubernetes destinado principalmente a procesos en `Pod`. Su nombre completo incluye el namespace: `system:serviceaccount:shop:catalog`.

| Método | Cuándo se usa | Restricción importante |
|---|---|---|
| Certificado TLS de cliente | Administrador, componente del clúster o automatización | Hay que proteger la clave privada y la fecha de expiración del certificado. |
| Bearer token | Automatización o integración | El token transmite los privilegios de su propietario, no debe incluirse en código ni registros. |
| Token de `ServiceAccount` | Un proceso dentro de un `Pod` accede a la API | Los permisos los determina RBAC, no el mero hecho de disponer del token. |
| OIDC | Proveedor externo de identidad, por ejemplo SSO corporativo | API Server debe confiar en el issuer y comprobar los claims del token. |
| Authentication webhook | Un servicio externo confirma la credential del cliente | Es una authentication integration, no un admission webhook ni un authorizer. |
| Bootstrap token | Token con propósito limitado para la incorporación inicial de un nodo | Se necesita para bootstrap/TLS bootstrap, no como application identity de larga duración. |

Una solicitud anónima con la autenticación anónima habilitada se convierte en el usuario `system:anonymous` y el grupo `system:unauthenticated`. No es un modo conveniente para el acceso normal a la API. En una configuración protegida, se deshabilita el acceso anónimo o se le conceden solo endpoints seguros y abiertos de forma intencionada.

La autenticación no concede acceso por sí sola. Un certificado, token o identidad OIDC solo nombra al sujeto. La autorización determina qué puede hacer ese sujeto.

## 10.2 Tokens de `ServiceAccount` y el riesgo de la cuenta `default`

Cada `Namespace` contiene un `ServiceAccount` llamado `default`. Si la especificación de un `Pod` no indica `serviceAccountName`, Kubernetes asigna este. Esto no significa que `default` tenga automáticamente permisos amplios: el riesgo surge cuando se le otorga un `RoleBinding` o `ClusterRoleBinding` por comodidad.

Kubernetes moderno, incluido v1.36, normalmente entrega a un `Pod` un bound token proyectado mediante el mecanismo TokenRequest. Este token está vinculado al `ServiceAccount` y al `Pod` concreto, tiene una duración limitada y kubelet lo renueva automáticamente. No se debe crear un Secret de larga duración con un token de `ServiceAccount` sin una razón justificada.

Si una aplicación no requiere la API de Kubernetes, no necesita el token. Su montaje se deshabilita en el `Pod` o en el propio `ServiceAccount`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: web
  namespace: shop
automountServiceAccountToken: false
---
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: shop
spec:
  serviceAccountName: web
  automountServiceAccountToken: false
  containers:
    - name: web
      image: nginx:1.30.4
```

Cuando un contenedor queda comprometido, el token montado puede leerse y utilizarse fuera del clúster mientras sea válido. Por tanto, para cada `Pod` se elige un `ServiceAccount` independiente con permisos mínimos, y `default` no se usa como cuenta común de aplicaciones. Deshabilitar automount no revoca RBAC, pero elimina el secreto del sistema de archivos del pod que no necesita la API.

## 10.3 Autorización: RBAC y otros authorizer

La autorización responde la pregunta «¿puede el sujeto ya autenticado realizar esta acción?». API Server evalúa la combinación de usuario o grupo, `verb`, recurso, namespace y, a veces, el nombre del objeto y la ruta de la API.

En Kubernetes se pueden habilitar varios authorizer. Se comprueban en el orden configurado: el primero que devuelve `Allow` o `Deny` finaliza inmediatamente la decisión; solo si todos devuelven `NoOpinion`, la solicitud se deniega de forma predeterminada. El mecanismo principal y recomendado para la mayoría de los clústeres es RBAC.

| Mecanismo | Propósito | Significado práctico |
|---|---|---|
| RBAC | Reglas en `Role`, `ClusterRole` y enlaces | La opción habitual para un acceso gestionado y auditable. |
| Node | Limita las acciones de kubelet en nombre del nodo | Se usa para identidades de nodo, no en lugar de RBAC para usuarios. |
| Webhook | Consulta un servicio externo de autorización | Adecuado cuando la decisión depende de un sistema externo. |
| ABAC | Compara la solicitud con un archivo estático de políticas | Un enfoque obsoleto para proyectos nuevos, difícil de auditar y mantener. |

No confunda RBAC con authentication. `RoleBinding` no confirma una identidad ni crea un token. Vincula un sujeto ya conocido a un conjunto de permisos. De forma similar, `NetworkPolicy` limita las conexiones de red, pero no reemplaza la decisión de API Server sobre los permisos de un recurso.

### Node authorizer y `NodeRestriction`: capas cercanas, pero diferentes

**Node authorizer** es un authorizer especial para la kubelet/node identity `system:node:<nodeName>` del grupo `system:nodes`. Limita qué operaciones de API puede realizar kubelet para su nodo y los `Pod` que se le asignaron, incluidos los `Secret`, `ConfigMap` y datos de volúmenes que necesita. Esto es **authorization**.

**`NodeRestriction`** es un validating admission plugin. Además limita qué objetos `Node` y `Pod` asociados puede modificar kubelet: un kubelet correctamente identificado no debe modificar el Node/Pod de otro ni establecer por su cuenta labels protegidos. Esto es **admission**, no un authorizer.

> **No confundir.** Node authorizer responde «¿la node identity tiene permitido realizar esta acción de API?». `NodeRestriction` responde «incluso después de la autorización, ¿es admisible esta modificación del objeto?». Ambos mecanismos son importantes para el least privilege de kubelet, pero no reemplazan el RBAC de usuarios, TLS ni la protección del nodo.

## 10.4 RBAC: roles, enlaces y privilegios mínimos

`Role` describe reglas solo en un `Namespace`. `ClusterRole` describe reglas para todo el clúster o puede vincularse a un único namespace mediante un `RoleBinding`. `RoleBinding` actúa en su propio namespace y `ClusterRoleBinding` actúa en todo el clúster.

Los permisos RBAC son aditivos: se suman varios enlaces y no hay una regla independiente para «denegar». Por tanto, el principio de mínimo privilegio implica conceder solo los `apiGroups`, `resources` y `verbs` necesarios, así como elegir el alcance más reducido.

A continuación, `Role` permite a la aplicación leer solo un `ConfigMap` en el namespace `shop`. Es un ejemplo de regla estricta, no una plantilla para todas las tareas.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: read-site-config
  namespace: shop
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["site-config"]
    verbs: ["get"]
```

Puede comprobarse el permiso esperado con el comando `kubectl auth can-i`. Por ejemplo, un administrador puede comprobar una acción para una cuenta específica:

```bash
kubectl auth can-i get configmap/site-config -n shop \
  --as=system:serviceaccount:shop:web
```

El comando es útil para comprobar, pero no reemplaza la revisión de manifiestos ni de los enlaces efectivos. Requieren especial atención los permisos `get`, `list` y `watch` sobre `secrets`, así como `create`, `update`, `patch` y `delete` para cargas de trabajo. El acceso a recursos RBAC, `bind`, `escalate` e `impersonate` puede permitir conceder o utilizar permisos adicionales. `cluster-admin`, `verbs: ["*"]` y `resources: ["*"]` no son una opción inicial segura.

Estos authorization checks especiales resuelven tareas diferentes:

- `bind` se refiere a la creación o modificación de `RoleBinding` / `ClusterRoleBinding`. Normalmente, el caller ya debe poseer los permissions incluidos en el `Role`/`ClusterRole` que se vincula, en el scope correspondiente. Un permiso explícito `bind` para un rol concreto permite realizar el binding incluso sin poseer el conjunto propio de todos esos permissions.

- `escalate` no se refiere al binding, sino a la creación o modificación de `Role` / `ClusterRole`. Normalmente, el caller no puede escribir en un rol permissions que no posee por sí mismo. Un permiso explícito `escalate` es una excepción a esta protección.

- el `impersonate` classic permite enviar solicitudes en nombre del user/group/ServiceAccount indicado u otro identity attribute compatible. Es una capacidad independiente y no debe confundirse con `bind` ni `escalate`.

En Kubernetes v1.36 también está disponible el mecanismo beta `ConstrainedImpersonation`, enabled by default. Añade verbs más específicos de las familias `impersonate:*` e `impersonate-on:*` para limitar no solo la identity, sino también las acciones realizadas en su nombre. Las reglas RBAC existentes con `impersonate` classic siguen funcionando; API Server puede utilizar constrained checks y, si es necesario, fallback a `impersonate` classic.

El permiso `create` sobre `pods` merece atención aparte: la propia posibilidad de crear un `Pod` puede ser un paso para aumentar la influencia de un sujeto, incluso si este no tiene acceso directo a los datos objetivo. La cadena de razonamiento es la siguiente: el sujeto tiene derecho a crear un `Pod` → el nuevo `Pod` puede indicar el `serviceAccountName` de cualquier `ServiceAccount` disponible en el namespace, si no se configura una denegación explícita por separado → mediante el `ServiceAccount` elegido o mediante los `Secret`/`ConfigMap`/volúmenes montados, este `Pod` puede obtener acceso a datos o permisos de API que el sujeto original no poseía directamente. El alcance final depende de qué `ServiceAccount` y volúmenes están realmente disponibles en el namespace, y de los controls restrictivos independientes (por ejemplo, `automountServiceAccountToken: false`, PSA/PSS, enlaces RBAC restringidos para los `ServiceAccount` existentes). El derecho a crear una workload no debe interpretarse como una vía incondicional a cualquier `Secret` o cualquier `ServiceAccount` del clúster: amplía la influencia potencial exactamente en la medida que permita el resto de la configuración del namespace.

## 10.5 Cómo se aplica en la práctica

El equipo de plataforma separa las identidades humanas de las de máquina. Los empleados inician sesión mediante OIDC corporativo, la automatización obtiene credenciales independientes y cada componente en un `Namespace` utiliza un `ServiceAccount` independiente.

Para un servicio HTTP de aplicación que no llama a la API de Kubernetes, se establece `automountServiceAccountToken: false`. A un controlador que necesita la API se le otorgan un `ServiceAccount` independiente y un `Role` con recursos y verb específicos. Antes de publicar un cambio, se comprueba `kubectl auth can-i` y después se revisan `RoleBinding` y `ClusterRoleBinding`.

Se buscan regularmente enlaces a `default` y `ClusterRoleBinding` amplios. Cuando un empleado deja la empresa, se filtra un token o se pierde una clave de certificado, las credenciales se revocan o sustituyen, y se revisan los permisos asociados. Así, la filtración de un token no se convierte en acceso permanente a todo el clúster.

## 10.6 Exam vocabulary / Miniglosario

| Término | Significado |
|---|---|
| authentication | Establecimiento de la identidad del remitente de una solicitud a la API. |
| authorization | Decisión sobre si esa identidad tiene permitido realizar una acción específica. |
| `ServiceAccount` | Identidad de Kubernetes para procesos que normalmente se ejecutan en un `Pod`. |
| bearer token | Token cuyo portador obtiene los privilegios asociados a él. |
| OIDC | Protocolo para conectar Kubernetes con un proveedor externo de identidad. |
| RBAC | Control de acceso mediante roles y enlaces de roles. |
| `Role` / `ClusterRole` | Conjunto de reglas en un namespace / a nivel de clúster. |
| `RoleBinding` / `ClusterRoleBinding` | Enlace de un rol a un usuario, grupo o `ServiceAccount`. |
| `bind` | Permiso RBAC especial para vincular Role/ClusterRole sin tener que poseer todos los permissions del rol que se vincula. |
| `escalate` | Permiso RBAC especial para crear/modificar Role/ClusterRole con permissions superiores a los permissions propios del caller. |
| `impersonate` | Permission classic de Kubernetes para la impersonation de otra identity; en v1.36 también existe ConstrainedImpersonation beta con verbs más específicos. |

## 10.7 Exam Essentials / Resumen del capítulo

- Los usuarios normales se autentican mediante mecanismos externos, mientras que `ServiceAccount` es un objeto Kubernetes para procesos en un `Pod`.
- Los certificados de cliente, bearer tokens, tokens de `ServiceAccount` y OIDC establecen la identidad, pero no conceden permisos sin autorización.
- `default` no tiene permisos amplios automáticamente, pero vincularlo hace que todos los pods que lo usan implícitamente sean posibles portadores de dichos permisos.
- El token de `ServiceAccount` que una aplicación no necesita no se monta mediante `automountServiceAccountToken: false`.
- RBAC es el authorizer principal; `Role` y `RoleBinding` normalmente reducen el alcance de acceso frente a las variantes de clúster.
- Los permisos se acumulan, por lo que los verb peligrosos y las reglas wildcard amplias aumentan las consecuencias de una vulneración.

## 10.8 No confundir y cómo aparece en el examen

En MCQ (multiple choice question, pregunta de opción múltiple) normalmente debe distinguirse authentication de authorization y elegir el acceso seguro más limitado. Trampas frecuentes:

- creer que un `ServiceAccount` o un token por sí solo otorga permisos; los permisos los determinan los enlaces RBAC;
- confundir `RoleBinding` con `ClusterRoleBinding`: el primero está limitado a su namespace;
- considerar que `default` es incondicionalmente peligroso: el riesgo depende de los permisos concedidos y del montaje del token;
- tomar OIDC por un método de autorización: OIDC confirma una identidad externa y el authorizer toma la decisión de acceso;
- elegir `cluster-admin` o wildcard en lugar de un rol independiente con un conjunto preciso de recursos y verb.

Primero determine de qué trata la pregunta: quién realiza la solicitud, cómo se estableció la identidad o qué acción está permitida. Después, compruebe el alcance: un namespace o todo el clúster.

## 10.9 Preguntas de autoevaluación

### 1. ¿Qué afirmación sobre `ServiceAccount` es correcta?

   - a. Obtiene automáticamente `cluster-admin` en su namespace.

   - b. Es una identidad Kubernetes para procesos en un `Pod`; sus permisos los definen los enlaces RBAC.

   - c. Sustituye a `NetworkPolicy` para el acceso de red.

   - d. Es un usuario externo que siempre se autentica mediante OIDC.

<details>
<summary>Respuesta y explicación</summary>

**Respuesta correcta: b.** Los procesos en pods suelen usar `ServiceAccount`, y sus capacidades las determinan los roles y los enlaces. OIDC, `cluster-admin` y las reglas de red no se derivan de la mera creación de `ServiceAccount`.

</details>

### 2. ¿Qué reduce el riesgo para un `Pod` que no necesita la API de Kubernetes?

   - a. Habilitar la autenticación anónima de API Server.

   - b. Añadir `verbs: ["*"]` a `ClusterRole`.

   - c. Asignar a `default` `ServiceAccount` con `cluster-admin`.

   - d. Establecer `automountServiceAccountToken: false`.

<details>
<summary>Respuesta y explicación</summary>

**Respuesta correcta: d.** Así Kubernetes no monta el token de `ServiceAccount` en el pod. Las otras opciones amplían el acceso o crean una superficie de ataque innecesaria.

</details>

### 3. ¿Qué objeto define permisos limitados a un `Namespace`?

   - a. `Role`

   - b. `ClusterRoleBinding`

   - c. `NetworkPolicy`

   - d. `ServiceAccount`

<details>
<summary>Respuesta y explicación</summary>

**Respuesta correcta: a.** `Role` define reglas limitadas por namespace (qué verbs están permitidos para qué recursos), pero no concede por sí mismo esos permisos a un sujeto: para concederlos realmente se usa un `RoleBinding` en el mismo namespace, que vincula `Role` con subjects específicos.

</details>

### 4. ¿Qué mecanismo de Kubernetes es la opción principal para gestionar los permisos de usuarios y `ServiceAccount`?

   - a. Node authorizer

   - b. ABAC

   - c. RBAC

   - d. OIDC

<details>
<summary>Respuesta y explicación</summary>

**Respuesta correcta: c.** RBAC define reglas de acceso auditables mediante roles y enlaces. OIDC corresponde a la autenticación, Node authorizer sirve a identidades de nodo y ABAC se basa en políticas estáticas.

</details>

### 5. ¿Por qué el permiso `get` sobre `secrets` requiere especial precaución?

   - a. Puede revelar credentials, claves y tokens que luego dan acceso a Kubernetes o a sistemas externos.
   - b. Devuelve solo metadata de Secret y nunca permite al cliente de API obtener el valor almacenado.
   - c. Concede automáticamente al sujeto el derecho a crear un `Pod`, incluso si RBAC no contiene el permiso correspondiente.
   - d. Obliga a API Server a volver a cifrar Secret en cada lectura y por tanto aumenta los permisos del cliente.

<details>
<summary>Respuesta y explicación</summary>

**Respuesta correcta: a.** `Secret` suele contener datos que dan acceso a otros recursos. Por tanto, `get`, y especialmente los más amplios `list/watch`, deben concederse con least privilege. Leer un Secret no crea otros permisos RBAC automáticamente.

</details>

> **Adónde seguir.** Profundice sus habilidades prácticas en el capítulo 10 de CKS: RBAC y minimización de acceso, el capítulo 11 de CKS: ServiceAccounts y tokens, y el capítulo 12 de CKS: restricción del acceso a la API de Kubernetes. La sintaxis básica de roles también está en el capítulo 38 de CKA: RBAC, y la cadena de `ServiceAccount` y admission, en el capítulo 21 de CKA. En KCSA, continúe con el [capítulo 11](../11/es.md) sobre Pod Security Standards y Pod Security Admission.

[Índice](../README_ES.md) · [Capítulo 09](../09/es.md) · [Capítulo 11](../11/es.md)
