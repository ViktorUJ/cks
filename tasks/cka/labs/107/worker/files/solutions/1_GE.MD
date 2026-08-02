[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 107 — ეტალონური ამოხსნა (multi-container, image-ები, ტომები)

## დავალება 1. Pod `multi-pod` ორი კონტეინერით

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

## დავალება 2. Sidecar-ლოგერი: საერთო emptyDir, მეორე კონტეინერი აგროვებს ლოგებს

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

`log`-კონტეინერი საერთო ტომიდან კითხულობს იმას, რასაც `app` წერს, და გამოაქვს stdout-ში —
ლოგების შემგროვებელი sidecar-ის კლასიკური პატერნი.

## დავალება 3. Pod `redis-storage` emptyDir-ით

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

## დავალება 4. Image-ის აწყობა podman-ით + ექსპორტი oci-archive-ში

```bash
cd /var/work/107
sudo podman build -t ckad:0.0.1 -f Dockerfile .
sudo podman save --format oci-archive -o /var/work/107/ckad.tar ckad:0.0.1
sudo podman images | grep ckad
ls -l /var/work/107/ckad.tar
```
