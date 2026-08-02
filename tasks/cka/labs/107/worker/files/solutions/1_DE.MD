[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 107 — Referenzlösung (Multi-Container, Images, Volumes)

## Aufgabe 1. Pod `multi-pod` mit zwei Containern

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

## Aufgabe 2. Sidecar-Logger: gemeinsames emptyDir, der zweite Container sammelt die Logs

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

Der Container `log` liest aus dem gemeinsamen Volume, was `app` dorthin schreibt, und gibt
es auf stdout aus — das klassische Pattern eines Log-sammelnden Sidecars.

## Aufgabe 3. Pod `redis-storage` mit emptyDir

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

## Aufgabe 4. Image-Bau mit podman + Export in ein oci-archive

```bash
cd /var/work/107
sudo podman build -t ckad:0.0.1 -f Dockerfile .
sudo podman save --format oci-archive -o /var/work/107/ckad.tar ckad:0.0.1
sudo podman images | grep ckad
ls -l /var/work/107/ckad.tar
```
