[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 112 — solución de referencia (etcd: snapshots y restauración)

Todas las acciones con etcd se hacen en el nodo del control plane
(`ssh k8s1_controlPlane_1`, `sudo -i`). `etcdctl` ya está instalado; los certificados están
en `/etc/kubernetes/pki/etcd/`.

Conviene definir una sola vez los parámetros comunes de conexión a etcd:

```bash
# en el control plane, como root
export ETCDCTL_API=3
export EP="--endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key"
```

## Tarea 1. Tomar el snapshot S1 (estado base) y copiarlo al worker

```bash
# en el control plane
etcdctl $EP snapshot save /root/etcd-snapshot-1.db
etcdctl snapshot status /root/etcd-snapshot-1.db --write-out=table
```

Copiar el snapshot a la máquina de trabajo (para la verificación):

```bash
# desde worker PC
scp k8s1_controlPlane_1:/root/etcd-snapshot-1.db \
  /var/work/tests/artifacts/etcd/etcd-snapshot-1.db
```

(si `scp` no consigue tomar el fichero de `/root`, cópialo en el control plane a `/tmp` y
dale permisos: `cp /root/etcd-snapshot-1.db /tmp/ && chmod 644 /tmp/etcd-snapshot-1.db`, y
luego haz `scp` desde `/tmp`.)

## Tarea 2. Introducir cambios en el clúster

Creamos «recursos marcadores»: con ellos veremos luego la diferencia entre los snapshots.
Los comandos se ejecutan en la máquina de trabajo (allí está configurado `kubectl`).

```bash
# en worker PC
kubectl create namespace snapshot-demo
kubectl -n snapshot-demo create configmap demo-config --from-literal=app=v1
kubectl -n snapshot-demo create deployment demo-web \
  --image=viktoruj/ping_pong --replicas=2

kubectl get ns snapshot-demo
kubectl -n snapshot-demo get cm,deploy
```

## Tarea 3. Tomar el snapshot S2 (después de los cambios)

```bash
# en el control plane
etcdctl $EP snapshot save /root/etcd-snapshot-2.db
etcdctl snapshot status /root/etcd-snapshot-2.db --write-out=table
```

```bash
# desde worker PC
scp k8s1_controlPlane_1:/root/etcd-snapshot-2.db \
  /var/work/tests/artifacts/etcd/etcd-snapshot-2.db
```

La diferencia: `etcd-snapshot-1.db` se tomó **antes** de crear `snapshot-demo`, y
`etcd-snapshot-2.db` — **después**. Es decir, S2 contiene el namespace `snapshot-demo` y sus
recursos, y S1 no.

## Tarea 4. Restaurar S1 y comprobar que no hay recursos de más

Restauramos el primer snapshot: el clúster debe volver al estado **anterior** a la creación
de `snapshot-demo`.

Orden de la restauración (método «parar los pods estáticos → restaurar en `/var/lib/etcd` →
levantar los pods estáticos»):

```bash
# en el control plane, como root
# 1. ver el nombre del nodo y las direcciones del manifiesto actual de etcd: harán falta en el restore
grep -E -- '--name=|--initial-cluster=|--initial-advertise-peer-urls=' \
  /etc/kubernetes/manifests/etcd.yaml
# ejemplo de salida:
#   - --name=ip-10-10-1-17
#   - --initial-advertise-peer-urls=https://10.10.1.17:2380
#   - --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380

# 2. parar todos los pods estáticos del control plane (kubelet apagará sus contenedores)
mkdir -p /etc/kubernetes/manifests-stopped
mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
# esperar hasta que desaparezcan los contenedores de etcd/apiserver
crictl ps

# 3. retirar los datos actuales y restaurar el snapshot S1 en /var/lib/etcd
mv /var/lib/etcd /var/lib/etcd.bak
etcdctl snapshot restore /root/etcd-snapshot-1.db \
  --data-dir=/var/lib/etcd \
  --name=ip-10-10-1-17 \
  --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380 \
  --initial-advertise-peer-urls=https://10.10.1.17:2380

# 4. devolver los manifiestos: kubelet levantará el control plane con los datos restaurados
mv /etc/kubernetes/manifests-stopped/*.yaml /etc/kubernetes/manifests/
```

> **Importante sobre `--name` (etcd 3.6+).** En el restore hay que indicar `--name`,
> `--initial-cluster` y `--initial-advertise-peer-urls` **exactamente iguales** a los del
> manifiesto de etcd. Si no, el member restaurado no coincidirá con aquel con el que arranca
> el pod estático y etcd caerá con el pánico `member unknown`. Los valores se toman del
> paso 1.

Comprobamos que el clúster se ha levantado y que `snapshot-demo` **ha desaparecido**:

```bash
# desde worker PC (esperar ~1 minuto a que arranque la API)
kubectl get --raw='/healthz'          # ok
kubectl get ns snapshot-demo          # NotFound — no hay recursos de más
kubectl get pods -n kube-system
```

## Tarea 5. Restaurar el clúster desde S2

Ahora restauramos el segundo snapshot: `snapshot-demo` y sus recursos deben volver. El
procedimiento es el mismo, el snapshot es `/root/etcd-snapshot-2.db`.

```bash
# en el control plane, como root
mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
crictl ps                                    # esperar a que paren los contenedores

rm -rf /var/lib/etcd
etcdctl snapshot restore /root/etcd-snapshot-2.db \
  --data-dir=/var/lib/etcd \
  --name=ip-10-10-1-17 \
  --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380 \
  --initial-advertise-peer-urls=https://10.10.1.17:2380

mv /etc/kubernetes/manifests-stopped/*.yaml /etc/kubernetes/manifests/
```

Comprobamos que el clúster está sano y que `snapshot-demo` **ha vuelto**:

```bash
# desde worker PC
kubectl get --raw='/healthz'                 # ok
kubectl get ns snapshot-demo                 # Active
kubectl -n snapshot-demo get cm,deploy       # demo-config y demo-web están en su sitio
kubectl get pods -n kube-system
```

Conclusión: un snapshot es una imagen completa del estado del clúster en el momento de
tomarlo. La restauración desde S1 devuelve el clúster al estado «vacío», y desde S2 recupera
los recursos creados.
