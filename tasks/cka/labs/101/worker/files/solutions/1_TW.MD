[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 101 - 參考解答(基礎:Pod、Deployment、namespace、Service)

## 任務 1。Namespace `ckad-101`

```bash
kubectl create namespace ckad-101
```

## 任務 2。在 `ckad-101` 中的 Pod `web`(viktoruj/ping_pong,label `tier=frontend`)

```bash
kubectl run web --image=viktoruj/ping_pong:latest --labels="tier=frontend" -n ckad-101
```

檢查:

```bash
kubectl get po web -n ckad-101 --show-labels
```

## 任務 3。在 `ckad-101` 中的 Deployment `api`(viktoruj/ping_pong,4 個副本)

先用 3 個副本建立,再擴充到 4 個(或直接使用 `--replicas=4`):

```bash
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=3 -n ckad-101
kubectl scale deployment api --replicas=4 -n ckad-101
```

檢查(等到就緒為止):

```bash
kubectl get deploy api -n ckad-101 -w
```

## 任務 4。為 Deployment `api` 建立 Service `api-svc`(ClusterIP,埠 80 → targetPort 8080)

```bash
kubectl expose deployment api --name=api-svc --port=80 --target-port=8080 -n ckad-101
```

檢查 Service 是否已與 Pod 綁定(Endpoints 不為空):

```bash
kubectl get svc api-svc -n ckad-101
kubectl get endpoints api-svc -n ckad-101
```

## 任務 5。Service `web-np`(NodePort,埠 80 → targetPort 8080,nodePort 30101)

```bash
kubectl expose deployment api --name=web-np --type=NodePort --port=80 --target-port=8080 -n ckad-101
# 指定特定的 nodePort(預設會隨機指派)
kubectl patch svc web-np -n ckad-101 -p '{"spec":{"ports":[{"port":80,"targetPort":8080,"nodePort":30101}]}}'
```

檢查:

```bash
kubectl get svc web-np -n ckad-101
```

## 任務 6。JSONPath:把 Pod 名稱寫入檔案

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl get pods -n ckad-101 -o jsonpath='{.items[*].metadata.name}' \
  > /var/work/tests/artifacts/6/pods.txt
cat /var/work/tests/artifacts/6/pods.txt
```

## 透過產生資源清單快速自我檢查(用來訓練速度)

```bash
export do="--dry-run=client -o yaml"
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=4 $do -n ckad-101 > api.yaml
kubectl apply -f api.yaml
```
