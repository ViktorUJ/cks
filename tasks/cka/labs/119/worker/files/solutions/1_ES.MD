[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 119 — solución de referencia (ejercicios de velocidad + JSONPath)

El sentido del laboratorio es ganar velocidad con los comandos imperativos y `--dry-run`, y
además entrenar `-o jsonpath`. Los ficheros de respuesta se guardan en
`/home/ubuntu/answers/`.

Aceleradores (añádelos a tu sesión):

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
```

## Ejercicios

```bash
# 1. namespace
kubectl create namespace drill

# 2. deployment api, 3 réplicas
kubectl -n drill create deployment api --image=viktoruj/ping_pong:latest --replicas=3

# 3. service ClusterIP para api en el puerto 80
kubectl -n drill expose deployment api --name=api-svc --port=80 --target-port=8080

# 4. configmap y secret
kubectl -n drill create configmap cfg --from-literal=APP_COLOR=blue
kubectl -n drill create secret generic sec --from-literal=PASSWORD=s3cr3t
```

## JSONPath

```bash
mkdir -p /home/ubuntu/answers

# 5. versiones de kubelet de todos los nodos
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}' \
  > /home/ubuntu/answers/versions.txt

# 6. imágenes de todos los contenedores de los pods del namespace drill
kubectl -n drill get pods -o jsonpath='{.items[*].spec.containers[*].image}' \
  > /home/ubuntu/answers/images.txt

# 7. ClusterIP del servicio api-svc
kubectl -n drill get svc api-svc -o jsonpath='{.spec.clusterIP}' \
  > /home/ubuntu/answers/api-ip.txt
```

Trucos útiles de JSONPath para el examen:

```bash
# salida ordenada
kubectl get pods -A --sort-by=.metadata.creationTimestamp
# custom-columns
kubectl get pods -n drill -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[*].image
# range en jsonpath
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.kubeletVersion}{"\n"}{end}'
```

Documentación: [JSONPath Support](https://kubernetes.io/docs/reference/kubectl/jsonpath/),
[kubectl Quick Reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/).

## Comprobación

```bash
check_result
```
