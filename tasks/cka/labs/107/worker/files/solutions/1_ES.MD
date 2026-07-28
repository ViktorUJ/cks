[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 107 — solución de referencia (multi-container, imágenes, volúmenes)

## Tarea 1. Pod `multi-pod` con dos contenedores

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-pod
spec:
  containers:
  - name: alpha
    image: viktoruj/ping_pong:latest
    env:
    - name: name
      value: alpha
  - name: beta
    image: viktoruj/ping_pong:alpine
    env:
    - name: name
      value: beta
```

## Tarea 2. Sidecar de logs: emptyDir compartido, el segundo contenedor recoge los logs

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: logger
spec:
  volumes:
  - name: logs
    emptyDir:
      sizeLimit: 500Mi
  containers:
  - name: app
    image: busybox
    command: ["/bin/sh","-c","while true; do echo hi >> /log/app.log; sleep 5; done"]
    volumeMounts:
    - name: logs
      mountPath: /log
  - name: log
    image: busybox
    command: ["/bin/sh","-c","tail -F /log/app.log"]
    volumeMounts:
    - name: logs
      mountPath: /log
```

El contenedor `log` lee del volumen compartido lo que escribe `app` y lo muestra en stdout:
el patrón clásico del sidecar recolector de logs.

## Tarea 3. Pod `redis-storage` con emptyDir

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: redis-storage
spec:
  containers:
  - name: redis-storage
    image: redis:alpine
    volumeMounts:
    - name: data
      mountPath: /data/redis
  volumes:
  - name: data
    emptyDir:
      sizeLimit: 500Mi
```

## Tarea 4. Construcción de la imagen con podman + exportación a oci-archive

```bash
cd /var/work/107
sudo podman build -t ckad:0.0.1 -f Dockerfile .
sudo podman save --format oci-archive -o /var/work/107/ckad.tar ckad:0.0.1
sudo podman images | grep ckad
ls -l /var/work/107/ckad.tar
```
