[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 107 - 參考解答(multi-container、映像、卷)

## 任務 1。含兩個容器的 Pod `multi-pod`

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

## 任務 2。Sidecar 日誌收集器:共用 emptyDir,第二個容器收集日誌

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

`log` 容器從共用卷讀取 `app` 寫進去的內容,並輸出到 stdout -
這就是經典的 sidecar 日誌收集模式。

## 任務 3。含 emptyDir 的 Pod `redis-storage`

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

## 任務 4。用 podman 建置映像 + 匯出成 oci-archive

```bash
cd /var/work/107
sudo podman build -t ckad:0.0.1 -f Dockerfile .
sudo podman save --format oci-archive -o /var/work/107/ckad.tar ckad:0.0.1
sudo podman images | grep ckad
ls -l /var/work/107/ckad.tar
```
