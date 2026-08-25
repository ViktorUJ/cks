[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 107 - 参考解答（multi-container、イメージ、ボリューム）

## 課題 1。2 つのコンテナを持つ Pod `multi-pod`

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

## 課題 2。sidecar ロガー：共有の emptyDir、2 つ目のコンテナがログを収集する

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

`log` コンテナは共有ボリュームから `app` が書き込んだ内容を読み取り、stdout に出力します -
古典的な sidecar ログ収集パターンです。

## 課題 3。emptyDir を持つ Pod `redis-storage`

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

## 課題 4。podman でのイメージのビルド + oci-archive へのエクスポート

```bash
cd /var/work/107
sudo podman build -t ckad:0.0.1 -f Dockerfile .
sudo podman save --format oci-archive -o /var/work/107/ckad.tar ckad:0.0.1
sudo podman images | grep ckad
ls -l /var/work/107/ckad.tar
```
