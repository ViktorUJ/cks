[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 105 — solution de référence (ConfigMap, Secret, env)

## Tâche 1. Secret + pod avec env issu du secret (namespace `dev-db`)

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

## Tâche 2. ConfigMap → variable d'environnement (namespace `app-cfg`)

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

## Tâche 3. ConfigMap depuis un fichier → volume dans le deployment (namespace `app-z`, `/appConfig`)

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

## Tâche 4. Secret + ConfigMap montés dans le pod (namespace `prod-apps`)

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
