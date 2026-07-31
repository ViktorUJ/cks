[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 119 - 參考解答(速度訓練 + JSONPath)

本實驗的重點是把命令式指令與 `--dry-run` 練到夠快,同時訓練
`-o jsonpath`。答案檔案儲存在 `/home/ubuntu/answers/`。

加速用的設定(加入到你的工作階段中):

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
```

## 速度訓練

```bash
# 1. namespace
kubectl create namespace drill

# 2. deployment api,3 個副本
kubectl -n drill create deployment api --image=viktoruj/ping_pong:latest --replicas=3

# 3. 位於 80 埠、對應 api 的 ClusterIP service
kubectl -n drill expose deployment api --name=api-svc --port=80 --target-port=8080

# 4. configmap 與 secret
kubectl -n drill create configmap cfg --from-literal=APP_COLOR=blue
kubectl -n drill create secret generic sec --from-literal=PASSWORD=s3cr3t
```

## JSONPath

```bash
mkdir -p /home/ubuntu/answers

# 5. 所有節點的 kubelet 版本
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}' \
  > /home/ubuntu/answers/versions.txt

# 6. namespace drill 中所有 Pod 容器的映像
kubectl -n drill get pods -o jsonpath='{.items[*].spec.containers[*].image}' \
  > /home/ubuntu/answers/images.txt

# 7. service api-svc 的 ClusterIP
kubectl -n drill get svc api-svc -o jsonpath='{.spec.clusterIP}' \
  > /home/ubuntu/answers/api-ip.txt
```

考試中實用的 JSONPath 技巧:

```bash
# 排序後的輸出
kubectl get pods -A --sort-by=.metadata.creationTimestamp
# custom-columns
kubectl get pods -n drill -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[*].image
# jsonpath 中的 range
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.kubeletVersion}{"\n"}{end}'
```

文件:[JSONPath Support](https://kubernetes.io/docs/reference/kubectl/jsonpath/),
[kubectl Quick Reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/)。

## 檢查

```bash
check_result
```
