[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 105 - リファレンス解答（ConfigMap、Secret、env）

## 課題 1. Secret + Secret から env を受け取る Pod（namespace `dev-db`）

```bash
kubectl create namespace dev-db
kubectl create secret generic dbpassword -n dev-db --from-literal=pwd=my-secret-pwd
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: db-pod
  namespace: dev-db
spec:
  containers:
  - name: db-pod
    image: mysql:8.0
    env:
    - name: MYSQL_ROOT_PASSWORD
      valueFrom:
        secretKeyRef:
          name: dbpassword
          key: pwd
```

## 課題 2. ConfigMap → 環境変数（namespace `app-cfg`）

```bash
kubectl create namespace app-cfg
kubectl create configmap app-config -n app-cfg --from-literal=COLOR=blue
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cfg-pod
  namespace: app-cfg
spec:
  containers:
  - name: cfg-pod
    image: viktoruj/ping_pong:latest
    envFrom:
    - configMapRef:
        name: app-config
```

## 課題 3. ファイルから作る ConfigMap → Deployment のボリューム（namespace `app-z`、`/appConfig`）

```bash
kubectl create namespace app-z
kubectl create configmap config -n app-z --from-file=/var/work/105/config.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-z
  namespace: app-z
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-z
  template:
    metadata:
      labels:
        app: app-z
    spec:
      containers:
      - name: app-z
        image: viktoruj/ping_pong:alpine
        volumeMounts:
        - name: config
          mountPath: /appConfig
      volumes:
      - name: config
        configMap:
          name: config
```

## 課題 4. Pod にマウントした Secret + ConfigMap（namespace `prod-apps`）

```bash
kubectl create namespace prod-apps
kubectl create secret generic prod-secret -n prod-apps --from-literal=var1=aaa --from-literal=var2=bbb
kubectl create configmap prod-config -n prod-apps --from-literal=config.yaml="test config"
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: prod-app
  namespace: prod-apps
spec:
  containers:
  - name: app1
    image: viktoruj/cks-lab:latest
    command: ["sleep", "60000"]
    volumeMounts:
    - name: config
      mountPath: /app/configs
  - name: app2
    image: viktoruj/cks-lab:latest
    command: ["sleep", "60000"]
    volumeMounts:
    - name: secret
      mountPath: /app/secrets
  volumes:
  - name: config
    configMap:
      name: prod-config
  - name: secret
    secret:
      secretName: prod-secret
```
