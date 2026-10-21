[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 109 - Cifrado de Secret en etcd y acceso mínimo

## Objetivo

En este laboratorio de CKS demostrarás que un Secret de Kubernetes sin encryption at rest se almacena en
etcd como bytes legibles (base64 no es cifrado), habilitarás `aescbc` mediante
`EncryptionConfiguration`, lo conectarás al `kube-apiserver` static, reescribirás los antiguos
Secret y restringirás el acceso a los datos con RBAC y `automountServiceAccountToken`.

`aescbc` se ha elegido aquí solo para practicar la mecánica de examen de
`EncryptionConfiguration` y de re-encryption. La documentación actual de Kubernetes considera
AES-CBC débil y no lo recomienda por el riesgo de ataques padding-oracle; `aesgcm` también exige
una rotación automatizada de la clave. Para producción elige el provider según la documentación
vigente y el threat model; con un key manager externo es preferible KMS v2
(consulta el [capítulo 21](../../course/21/es.md)).

## Threat model

Encryption at rest protege frente a un storage compromise: supongamos que un atacante obtuvo acceso read-only a un snapshot de etcd o a la capa de almacenamiento, por ejemplo mediante un backup o un volume snapshot, pero no tiene acceso autorizado a la API. La tarea 1 demuestra precisamente ese riesgo inicial mediante lectura raw de etcd.

Tras habilitar encryption at rest, las tareas 2–4 reducen el blast radius de ese acceso: los datos leídos directamente no deben revelar el Secret. No es una protección universal ni un sustituto del control de acceso a la API.

Si el atacante tiene un acceso legítimo a la API con permisos de lectura de Secret, encryption at rest no protege frente a esa amenaza: la API devolverá el valor tras descifrarlo. Por eso la tarea 5 restringe aparte RBAC y automount, reduciendo el blast radius de la identity de un workload con esos permisos.

## Compruébate antes de empezar

<details>
<summary>1. ¿Por qué base64 en `Secret.data` no es cifrado?</summary>

base64 es solo una codificación, reversible sin clave: cualquiera que tenga acceso a los propios bytes (por ejemplo, mediante lectura raw de etcd) puede decodificar el valor al instante, sin ninguna operación criptográfica. El cifrado requiere una clave para la transformación inversa; base64 no tiene esa propiedad en absoluto.
</details>

<details>
<summary>2. ¿Por qué el provider `identity` debe ir el ÚLTIMO en la lista de providers y no el primero?</summary>

Los providers en `EncryptionConfiguration` se prueban en orden para LEER los registros existentes, y el primer provider se usa para ESCRIBIR datos nuevos. Si `identity` (es decir, "sin cifrado") va el primero, todos los nuevos registros se escribirán SIN cifrar, a pesar de la presencia de `aescbc` en la lista. Con `identity` el último se pueden leer los registros plaintext antiguos (aún no migrados), pero se garantiza que todos los registros nuevos los cifre el primer provider.
</details>

<details>
<summary>3. ¿Por qué no se puede simplemente eliminar la clave de cifrado antigua inmediatamente después de añadir la nueva?</summary>

Los registros existentes en etcd siguen cifrados con la clave ANTIGUA hasta que se reescriban explícitamente (re-encryption). Si quitas la clave antigua del `EncryptionConfiguration` activo antes de que todos los registros se hayan reescrito con la nueva, el API server no podrá descifrar los registros antiguos restantes mediante la provider chain actual: quedarán ilegibles hasta que la clave antigua se devuelva a la configuración. Eliminar la clave de la configuración no destruye físicamente el key material: si la clave antigua guardada se vuelve a añadir a la provider chain, el acceso se restablece. La pérdida irreversible de datos solo se produce si el propio key material realmente se pierde o se destruye (por ejemplo, la clave no se guardó en ningún sitio antes de eliminarla). El orden: añadir la nueva clave la primera → reescribir todos los Secret → confirmar que todos los registros usan la nueva clave → guardar la clave antigua en un lugar fiable para el rollback → solo después quitarla de la configuración.
</details>

## Infraestructura

El entorno se despliega con Terragrunt en AWS `eu-central-1`:

| Componente | Finalidad |
|---|---|
| `vpc` | VPC `10.10.0.0/16` con subredes públicas |
| `ssh-keys` | claves SSH para el worker y el control-plane |
| `k8s-1` | control-plane kubeadm de un solo nodo: Kubernetes **1.36.0**, containerd, **Calico** |
| `worker` | máquina de trabajo con `kubectl`; en el control-plane (`ssh control-plane`) está instalado el `etcdctl` 3.6.0 estándar, como en el examen |

El control-plane admite deliberadamente Pods normales: no se crea un worker de Kubernetes aparte.
Antes de las tareas, el bootstrap crea el namespace `encryption-109` y un `legacy-secret`
inofensivo. Este Secret se creó **antes** de la EncryptionConfiguration, por lo que sirve
como prueba controlada del estado plaintext.

Las operaciones sobre el nodo se realizan en el propio control-plane, como en el examen: entra en él
(`ssh control-plane`), trabaja allí y sal (`exit`); `kubectl`, desde la máquina de trabajo. El registro raw
de etcd se lee con el `etcdctl` estándar de la documentación de Kubernetes con los certificados de kubeadm de
`/etc/kubernetes/pki/etcd/` (`ca.crt`, `server.crt`, `server.key`). Los ejemplos de comandos ya hechos están
en la sección «Dónde encontrar ejemplos en la documentación» de la solución de referencia.

## Despliegue

```bash
TASK=109 make run_cks_task
```

Conéctate a la máquina de trabajo. El contexto `cluster1-admin@cluster1` ya está configurado.

```bash
time_left
check_result
```

## Tareas

---
| **1** | **Demostrar el Secret plaintext inicial** |
| :---: | :--- |
| Qué hacemos | • Antes de habilitar el cifrado, solicita el registro raw `/registry/secrets/encryption-109/legacy-secret` con el `etcdctl get ... --print-value-only` estándar<br/>• Entra en el control-plane (`ssh control-plane`) y trabaja en él, como en el examen: pasa la salida por `strings` y guarda el resultado en un archivo en el control-plane (`/tmp/plaintext-proof.txt`), luego cópialo a la máquina de trabajo con el comando `scp` a `/var/work/109/plaintext-proof.txt` |
| Criterios de aceptación | • El archivo contiene la salida completa de `strings` del registro raw original (coincide con el snapshot del bootstrap, incluido el marker `cks-109-legacy-plaintext`) y no contiene `k8s:enc:`<br/>• Una cadena escrita a mano no se acepta<br/>• Es la prueba del estado inicial: `Secret.data` es base64, no encryption at rest |

<details>
<summary>💡 Pista para la tarea 1</summary>

Esta tarea hay que hacerla PRIMERO, antes de la tarea 2: en cuanto habilites EncryptionConfiguration y reescribas el Secret, la prueba plaintext desaparecerá y no podrás registrarla post-hoc. El comando `etcdctl` con los flags `--cacert/--cert/--key` se toma de la documentación oficial de Kubernetes (la sección «Verify that newly written data is encrypted» de la página Encrypting Confidential Data at Rest); las rutas de los certificados de kubeadm: `/etc/kubernetes/pki/etcd/ca.crt`, `server.crt`, `server.key`. Los enlaces exactos están en la sección «Dónde encontrar ejemplos en la documentación» de la solución de referencia.
</details>

---
| **2** | **Crear la EncryptionConfiguration para Secret** |
| :---: | :--- |
| Qué hacemos | • En el control-plane crea `/etc/kubernetes/enc/encryption-config.yaml`, owner `root:root`, mode `0600`<br/>• Formato: `apiserver.config.k8s.io/v1`, `EncryptionConfiguration`<br/>• Para `secrets` establece como primer provider `aescbc` con una clave base64 con nombre de **32 bytes aleatorios**, y después `identity: {}` |
| Criterios de aceptación | • Archivo `root:root` mode `0600` en un directorio `root:root` mode `0700`<br/>• El provider activo principal para `secrets` — el **primer** `aescbc` con una named base64 key correcta de 32 bytes<br/>• `identity` es admisible solo como último fallback temporal para el plaintext legacy<br/>• Un symlink al archivo/directorio está prohibido |

<details>
<summary>💡 Pista para la tarea 2</summary>

Genera la clave mediante `head -c 32 /dev/urandom | base64`: precisamente 32 BYTES (no 32 caracteres de la cadena base64, que será más larga por la codificación). Compruébalo: `echo -n "<tu-clave-base64>" | base64 -d | wc -c` debe devolver exactamente `32`.
</details>

---
| **3** | **Conectar la config al kube-apiserver static** |
| :---: | :--- |
| Qué hacemos | • Modifica con cuidado `/etc/kubernetes/manifests/kube-apiserver.yaml`: añade el flag `--encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml`, un `volumeMount` read-only `/etc/kubernetes/enc` y el correspondiente volume `hostPath` `/etc/kubernetes/enc`<br/>• Guarda un backup del manifest antes de editarlo |
| Criterios de aceptación | • El manifest en funcionamiento contiene el flag, el mount y el hostPath<br/>• Tras el restart del static Pod, `kubectl get --raw='/readyz'` devuelve `ok` |

<details>
<summary>💡 Pista para la tarea 3</summary>

Hacen falta tres cambios separados a la vez: el propio flag `--encryption-provider-config`, `volumeMounts` (dentro del contenedor) Y `volumes` (hostPath a nivel del Pod spec); olvidar cualquiera de los tres provocará o bien un CrashLoopBackOff (el flag apunta a un archivo que el contenedor no ve), o bien que el flag simplemente no se pase. Guarda el backup **fuera** de `/etc/kubernetes/manifests`, por ejemplo `sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak-109`. El kubelet lee del directorio de static manifests los archivos adicionales no ocultos; un `kube-apiserver.yaml.bak` vecino puede interpretarse como un segundo static Pod y bloquear la aplicación de la nueva configuración.
</details>

---
| **4** | **Re-encrypt y demostrar el ciphertext** |
| :---: | :--- |
| Qué hacemos | • Cuando el API server esté listo, crea en `encryption-109` el Secret `encrypted-secret` con el literal `token=cks-109-fresh-ciphertext`<br/>• Reescribe todos los Secret existentes anteriormente mediante la API (`kubectl get secrets --all-namespaces -o json | kubectl replace -f -`)<br/>• Comprueba ambos Secret mediante la API y raw etcd<br/>• Solo después de esta comprobación elimina el fallback temporal `identity`, reinicia el kube-apiserver static y vuelve a comprobar `/readyz` y la lectura de ambos Secret |
| Criterios de aceptación | • `legacy-secret` y `encrypted-secret` se leen mediante la API con los valores originales<br/>• El raw value de cada uno empieza por `k8s:enc:aescbc:v1:`<br/>• El legacy marker ya no se ve en raw etcd<br/>• Los payload/UID originales de todo el bootstrap Secret corpus se conservan, todos los registros están cifrados con la primera clave activa<br/>• La clave del archivo final es capaz de descifrar el ciphertext de ambos canary Secret<br/>• En la configuración final no hay `identity`, API healthy |

<details>
<summary>💡 Pista para la tarea 4</summary>

El orden es crítico: crear `encrypted-secret` → reescribir TODOS los Secret existentes mediante `kubectl replace` → comprobar raw etcd para AMBOS (legacy y encrypted) → SOLO DESPUÉS quitar `identity` de la configuración. Si quitas `identity` antes de que `legacy-secret` se haya reescrito, el API server ya no podrá leer el registro plaintext antiguo mediante la provider chain, y `legacy-secret` quedará inaccesible.
</details>

---
| **5** | **Minimizar RBAC y desactivar automount** |
| :---: | :--- |
| Qué hacemos | • Crea un ServiceAccount `secret-reader` en `encryption-109` con `automountServiceAccountToken: false`<br/>• El Role `secret-reader-109` debe dar solo `get` solo del Secret `encrypted-secret`<br/>• Vincúlalo con un RoleBinding del mismo nombre<br/>• Crea un Pod `secret-reader-109` con ese ServiceAccount, `automountServiceAccountToken: false`, con la imagen `registry.k8s.io/pause:3.10` |
| Criterios de aceptación | • El RBAC efectivo del ServiceAccount con sus grupos estándar permite `get encrypted-secret` en `encryption-109` y prohíbe otras operaciones sobre Secret, incluido el acceso a Secret de otros namespace<br/>• Role/RoleBinding exactos<br/>• Pod Running con un solo `pause:3.10`, sin ServiceAccount token montado ni automática ni manualmente y sin otras credential-bearing sources (volumes Secret/hostPath/CSI/PVC, env/envFrom de Secret)<br/>• Los volumes emptyDir/ConfigMap inofensivos son admisibles<br/>• `automountServiceAccountToken: false` en el Pod y en el ServiceAccount |

<details>
<summary>💡 Pista para la tarea 5</summary>

Usa `resourceNames: ["encrypted-secret"]` en el Role: sin este campo, `get`/`list` sobre el recurso `secrets` daría acceso a TODOS los Secret del namespace, incluido `legacy-secret`, lo que infringe el requisito de least-privilege. `pause:3.10` es una imagen de relleno que no necesita la Kubernetes API en absoluto, por lo que el automount se desactiva en dos niveles (SA y Pod) sin consecuencias funcionales.
</details>

## Comprobación

```bash
check_result
```

La comprobación contiene Init y cinco tests obligatorios. El test 4 comprueba no solo la presencia del
archivo de configuración, sino el ciphertext real `k8s:enc:aescbc:v1:` para el registro nuevo y el anterior de
etcd y la ausencia del `identity` migration-only en la configuración final. Antes de un re-encryption masivo en un entorno real hace falta un snapshot, un plan de
rotación de claves y una ventana controlada; este laboratorio no es un runbook de producción.

## Solución

Solución de referencia: [worker/files/solutions/1_ES.MD](worker/files/solutions/1_ES.MD)

## Eliminación

```bash
TASK=109 make delete_cks_task
```

## Adicionalmente: KMS v2 y el ciclo de vida completo de la rotación

**KMS v2 (walkthrough opcional).** Un KMS-plugin externo se conecta al API server como
provider `kms` en `EncryptionConfiguration`; su endpoint es un Unix socket local, y la clave
del provider recibe un nombre estable, por ejemplo `kms-v2-primary`. En KMS v2 el API server obtiene mediante el plugin un seed cifrado (wrapped bajo el
**KEK** externo) y a partir de él deriva las claves para cifrar objetos individuales. KMS v2
usa el seed/DEK a nivel del API server, y no una llamada aparte a KMS para cada Secret.
En etcd se guardan el ciphertext del Secret y los datos necesarios para restablecer la clave. Así, el KEK no está en etcd; la availability, las ACL y el backup de KMS pasan a ser
parte del modelo de seguridad. Un provider mínimo **ilustrativo** (el endpoint debe
corresponder al plugin instalado) es así:

```yaml
resources:
- resources: [secrets]
  providers:
  - kms:
      apiVersion: v2
      name: kms-v2-primary
      endpoint: unix:///var/run/kms-plugin/socket.sock
```

Añade el provider el primero para los registros nuevos, monta el socket en el `kube-apiserver` static
y espera a la health del plugin antes del re-encryption. Para una configuración real usa
un plugin soportado y el formato actual de `kms` v2 de la documentación de la versión
de Kubernetes que uses; este laboratorio no levanta un KMS-plugin ni entrega un socket operativo.

**Rotación completa de la clave del provider.** La migración de plaintext a la primera clave
`aescbc` realizada en la tarea 4 no es una rotación completa de la clave. Para ella: (1) haz un snapshot protegido de etcd y
comprueba que la clave antigua está guardada y disponible para el rollback; (2) añade la nueva clave
la primera en `aescbc.keys`, dejando la antigua la segunda, y luego reinicia el API server; (3)
reescribe los Secret existentes mediante la API, para que se cifren con la nueva primera clave;
(4) para los registros raw de etcd, primero seleccionados y luego todos, confirma el prefijo
`k8s:enc:aescbc:v1:<nombre-de-la-nueva-clave>:`; (5) solo después de la migración completa, del backup y de
la comprobación de lectura, elimina la clave antigua, reinicia el API server y vuelve a comprobar `/readyz`
y los Secret. Para KMS v2, de forma equivalente, primero se cambia el KEK/plugin primary, se realiza el
re-encryption y solo después se retira el KEK antiguo del uso según el procedimiento de KMS.
