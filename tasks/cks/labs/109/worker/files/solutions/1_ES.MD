[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 109 - solución de referencia: encryption at rest para Secret

> Trabajamos como en el examen: los comandos `kubectl` se ejecutan en la máquina de trabajo, y las operaciones sobre el
> nodo (etcd, archivos y manifest del control-plane), en el propio control-plane: entra en él con
> `ssh control-plane`, ejecuta los comandos y sal (`exit`). Es **solo un clúster didáctico de
> un solo nodo**; en producción no se da a los usuarios acceso directo a etcd.

## Dónde encontrar ejemplos en la documentación

Todos los comandos de abajo están tomados de la documentación oficial de Kubernetes; en el examen hay que encontrarlos allí
mismo, y no recordarlos de memoria:

| Qué se necesita                                                                                                                                                                                                                                                                                                            | Página y sección                                                                                                                                                                                    |
| :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Leer el registro raw de etcd y ver el prefijo `k8s:enc:aescbc:v1:` (el comando `ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key get /registry/secrets/default/secret1 \| hexdump -C`) | [Encrypting Confidential Data at Rest - Verify that newly written data is encrypted](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#verifying-that-data-is-encrypted)                             |
| Un ejemplo de `EncryptionConfiguration` con `aescbc` e `identity`                                                                                                                                                                                                                                                       | [Encrypting Confidential Data at Rest - Write an encryption configuration file](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#write-an-encryption-configuration-file)                            |
| El flag `--encryption-provider-config` y el montaje del archivo en el static Pod de kube-apiserver                                                                                                                                                                                                                | [Encrypting Confidential Data at Rest - Use the new encryption configuration file](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#use-the-new-encryption-configuration-file)                      |
| Reescribir todos los Secret (`kubectl get secrets --all-namespaces -o json \| kubectl replace -f -`)                                                                                                                                                                                                             | [Encrypting Confidential Data at Rest - Ensure all relevant data are encrypted](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#ensure-all-secrets-are-encrypted)                                  |
| Rotación de la clave (pasos 1-7) y eliminación de la clave antigua                                                                                                                                                                                                                                       | [Encrypting Confidential Data at Rest - Rotate a decryption key](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#rotating-a-decryption-key)                                                        |
| Dónde obtener las rutas de los certificados de etcd, si no se recuerdan: «`trusted-ca-file`, `cert-file` y `key-file` se pueden obtener de la descripción del Pod de etcd» (`kubectl -n kube-system describe pod etcd-<node>` o `/etc/kubernetes/manifests/etcd.yaml`)       | [Operating etcd clusters for Kubernetes - Snapshot using etcdctl options](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/)                                                               |
| Role/RoleBinding y ServiceAccount (`automountServiceAccountToken`)                                                                                                                                                                                                                                                        | [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/), [Configure Service Accounts for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) |

Rutas de los certificados en un clúster kubeadm: `/etc/kubernetes/pki/etcd/ca.crt`,
`/etc/kubernetes/pki/etcd/server.crt`, `/etc/kubernetes/pki/etcd/server.key`; el endpoint por defecto es
`https://127.0.0.1:2379`, por lo que en el control-plane el flag `--endpoints` no hace falta.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
export NS=encryption-109
kubectl config use-context "$CTX"
```

## 1. Registrar la prueba de plaintext antes de habilitar el cifrado

`Secret.data` en la API está codificado en base64, y no cifrado. El bootstrap creó un
canary seguro antes de que apareciera la EncryptionConfiguration. Primero miramos el registro raw de etcd con el comando de la
documentación y luego guardamos la prueba en forma de cadena en el archivo `/tmp/plaintext-proof.txt`
en el control-plane y después la copiamos a la máquina de trabajo en
`/var/work/109/plaintext-proof.txt` (el directorio lo creó el bootstrap): la comprobación lee el archivo en la máquina de trabajo.

Entra en el control-plane y ejecuta en él (en este comando todo es de la documentación, salvo la clave en
etcd: `/registry/secrets/<namespace>/<name>`):

```bash
ssh control-plane
sudo -i
```

```bash
# en el control-plane: registro raw de etcd, la salida de hexdump -C muestra el plaintext
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret | hexdump -C

# guardar la prueba (solo el valor, mediante strings) - también en el control-plane
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret --print-value-only \
  | strings > /tmp/plaintext-proof.txt
cat /tmp/plaintext-proof.txt
# cks-109-legacy-plaintext
exit   # de root
exit   # del control-plane
```

```bash
# en la máquina de trabajo: copiar la prueba
scp control-plane:/tmp/plaintext-proof.txt /var/work/109/plaintext-proof.txt
cat /var/work/109/plaintext-proof.txt
```

En este paso en el archivo no hay `k8s:enc:`. Es la prueba del estado **anterior** a la configuración;
tras el re-encryption la nueva salida debe pasar a ser ciphertext y el marker desaparecerá.

## 2. Crear la EncryptionConfiguration

`aescbc` se ha elegido solo para la mecánica didáctica de CKS. Kubernetes considera AES-CBC débil por
el riesgo de ataques padding-oracle y no lo recomienda como default de producción. Para un key
manager externo usa KMS v2; elige un provider local solo con un threat model vigente
y un procedimiento de rotación.

Generamos una clave AES-256 de 32 bytes, la codificamos en base64 y creamos la configuración en el control-plane.
`aescbc` va el primero: con él se escribirán los nuevos Secret. Con `identity` en último lugar, el API
server puede leer el registro plaintext antiguo solo hasta la migración. Un ejemplo del archivo está en la página de la
documentación (enlace al principio de la solución).

```bash
ssh control-plane
sudo -i
```

```bash
# en el control-plane (root)
mkdir -m 700 /etc/kubernetes/enc
key=$(head -c 32 /dev/urandom | base64)
cat > /etc/kubernetes/enc/encryption-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: cks-109-aescbc
        secret: ${key}
  - identity: {}
EOF
chmod 600 /etc/kubernetes/enc/encryption-config.yaml
ls -ld /etc/kubernetes/enc; ls -l /etc/kubernetes/enc
exit   # de root
exit   # del control-plane
```

La clave real no se debe colocar en Git, en un ticket, en el log del terminal ni en el Terraform state.
Si se pierde la clave, el Secret cifrado de un snapshot queda ilegible.

## 3. Conectar la configuración al kube-apiserver static

Primero guardamos el manifest **fuera** del directorio `/etc/kubernetes/manifests/`: el kubelet lee como static
Pod cada archivo no oculto de este directorio, incluido `*.bak`. Una copia del manifest original dentro
del directorio es un segundo static Pod con el mismo nombre; el kubelet puede seguir ejecutando precisamente esa copia
(la configuración antigua sin `--encryption-provider-config`), y la edición del archivo principal silenciosamente no
tendrá efecto, y el cifrado seguirá desactivado con un API server aparentemente sano.
En el control-plane abre precisamente el manifest existente del static Pod
y añade **a los** `command`, `volumeMounts` y `volumes` existentes estos elementos;
no sustituyas todo el archivo por una plantilla.

```bash
ssh control-plane
sudo -i
```

```bash
# en el control-plane (root)
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak-109
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
# container name: kube-apiserver
command:
- kube-apiserver
- --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml
volumeMounts:
- name: encryption-config
  mountPath: /etc/kubernetes/enc
  readOnly: true

# spec.volumes
volumes:
- name: encryption-config
  hostPath:
    path: /etc/kubernetes/enc
    type: Directory
```

El kubelet notará el cambio y reiniciará el static Pod. Antes de continuar, espera al API
server; de lo contrario un error de YAML/ruta puede dejar el control-plane inaccesible.

```bash
# todavía en el control-plane: comprobar que el flag llegó al manifest en funcionamiento, luego salir
grep -n -- '--encryption-provider-config\|encryption-config' /etc/kubernetes/manifests/kube-apiserver.yaml
exit   # de root
exit   # del control-plane
```

```bash
# en la máquina de trabajo: el API server se reinicia durante aproximadamente un minuto; repite hasta que el comando
# devuelva "readyz check passed" (antes habrá "connection refused")
kubectl get --raw='/readyz?verbose'
```

## 4. Reescribir los Secret antiguos y comprobar el ciphertext

La configuración no cambia los registros ya guardados. Primero crearemos un Secret después de habilitar el
provider y luego reescribiremos todos los Secret existentes mediante la API. En producción antes de esto
se hace un snapshot protegido y se usa un procedimiento controlado con retry.

```bash
kubectl -n "$NS" create secret generic encrypted-secret \
  --from-literal=token='cks-109-fresh-ciphertext'
kubectl get secrets --all-namespaces -o json | kubectl replace -f -

kubectl -n "$NS" get secret legacy-secret -o jsonpath='{.data.token}' | base64 -d; echo
kubectl -n "$NS" get secret encrypted-secret -o jsonpath='{.data.token}' | base64 -d; echo
# cks-109-legacy-plaintext
# cks-109-fresh-ciphertext
```

Los registros raw los leemos en el control-plane, como en la tarea 1:

```bash
ssh control-plane
sudo -i
```

```bash
# en el control-plane (root)
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret | hexdump -C
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/encrypted-secret | hexdump -C
# ambos registros empiezan por k8s:enc:aescbc:v1:...
exit   # de root
exit   # del control-plane
```

La API devuelve el plaintext a un cliente autorizado: es normal y no demuestra el
cifrado at rest. Aquí la prueba es que raw etcd contiene `k8s:enc:aescbc:v1:` para el
registro antiguo y el nuevo y ya no contiene el legacy marker.

Ahora el migration fallback ya no hace falta. Eliminamos `identity`, reiniciamos a la fuerza el
kube-apiserver static mediante CRI y volvemos a comprobar la salud y la lectura. Hazlo solo
después de un snapshot y de confirmar el ciphertext de todos los tipos de recursos afectados.

```bash
ssh control-plane
sudo -i
```

```bash
# en el control-plane (root): quitar identity y reiniciar el kube-apiserver static
vim /etc/kubernetes/enc/encryption-config.yaml   # eliminar la línea "- identity: {}"
crictl stop $(crictl ps --name kube-apiserver -q)
exit   # de root
exit   # del control-plane
```

```bash
# en la máquina de trabajo
until kubectl get --raw=/readyz 2>/dev/null | grep -qx ok; do sleep 2; done
kubectl -n "$NS" get secret legacy-secret encrypted-secret
```

Estado final de este laboratorio: el provider de cifrado (`aescbc`) es el primero y el único, `identity`
está eliminado. El fallback temporal no se debe dejar como un «seguro» permanente.

## 5. Restringir el acceso a la API y desactivar el token automount

Encryption at rest no sustituye a RBAC: un sujeto con `get` de Secret verá el plaintext mediante la API.
Crearemos un ServiceAccount con acceso a exactamente un Secret, así como un Pod de diagnóstico sin
service-account token montado.

```yaml
# rbac-109.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secret-reader
  namespace: encryption-109
automountServiceAccountToken: false
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader-109
  namespace: encryption-109
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["encrypted-secret"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secret-reader-109
  namespace: encryption-109
subjects:
- kind: ServiceAccount
  name: secret-reader
  namespace: encryption-109
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: secret-reader-109
---
apiVersion: v1
kind: Pod
metadata:
  name: secret-reader-109
  namespace: encryption-109
spec:
  serviceAccountName: secret-reader
  automountServiceAccountToken: false
  containers:
  - name: pause
    image: registry.k8s.io/pause:3.10
```

```bash
kubectl apply -f rbac-109.yaml
kubectl wait -n "$NS" --for=condition=Ready pod/secret-reader-109 --timeout=120s
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader get secret/encrypted-secret -n "$NS"
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader list secrets -n "$NS"
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader get secret/legacy-secret -n "$NS"
# yes
# no
# no

check_result
```

`automountServiceAccountToken: false` reduce la credential surface disponible del Pod, pero no
limita el RBAC del propio ServiceAccount si la aplicación obtiene otras credentials.

## Adicionalmente: cómo es KMS v2 y la rotación completa de la clave

### KMS v2: envelope encryption sin una clave local en la config

`aescbc` de arriba solo sirve para la mecánica didáctica. En producción KMS v2 conecta
un KMS-plugin soportado mediante un Unix socket local en `EncryptionConfiguration`.
Para KMS v2 el API server usa un seed/DEK cifrado a nivel del API server y
deriva las claves de cifrado de registros individuales. El plugin protege el seed mediante un KEK externo;
en eso KMS v2 se diferencia de KMS v1 per-resource. Etcd guarda el ciphertext de los recursos y
los metadatos necesarios para el descifrado. El KEK permanece en el KMS externo, y no en etcd ni en Git. El esquema de
configuración depende de la versión de Kubernetes y del plugin, pero en esencia hacen falta el provider `kms`,
un nombre estable de key y el endpoint del socket. No copies el endpoint de ejemplo de un clúster ajeno:
contrasta el formato de KMS v2 y los requisitos de health/ACL con la documentación de tu versión de Kubernetes.

### Lifecycle completo de la rotación de la clave aescbc

La transición `identity -> aescbc` de la tarea 4 es una migration, y no una rotación de la clave para datos ya
cifrados. Antes de la rotación haz un snapshot cifrado de etcd y guarda la
clave antigua para el rollback. Añade la clave nueva **como primera** y deja temporalmente la antigua
como segunda: los providers se leen en orden, y los registros nuevos se escriben con la primera clave.

```yaml
- aescbc:
    keys:
    - name: cks-109-aescbc-2026-rotation
      secret: <base64-32-byte-new-key>
    - name: cks-109-aescbc
      secret: <base64-32-byte-old-key>
```

Tras reiniciar el API server, reescribe los recursos y comprueba precisamente el nombre de la nueva key en el ciphertext
raw, y no solo el prefix general `k8s:enc`:

```bash
# en la máquina de trabajo
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
ssh control-plane
sudo -i
```

```bash
# en el control-plane (root)
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret --print-value-only \
  | strings | grep -F 'k8s:enc:aescbc:v1:cks-109-aescbc-2026-rotation:'
exit   # de root
exit   # del control-plane
```

Cuando la migration de todos los Secret esté confirmada, el backup hecho, la API lea los datos y `/readyz`
devuelva `ok`, elimina la key antigua de la lista, reinicia el API server y repite las
comprobaciones. No elimines la key antigua antes: los registros no reescritos con el nuevo provider quedarán
ilegibles. Para KMS v2 el orden es el mismo: primero el nuevo KEK/plugin primary, luego el
re-encryption, la comprobación y solo después de la migración, la retirada de servicio del KEK antiguo.
