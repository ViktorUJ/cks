[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 114 - 参考解答（troubleshooting）

診断の手順は 1 つだけです：`get` → `describe`（Events）→ `logs` → 修正。

## 課題 1。ReplicaSet rs-app2223（ImagePullBackOff）

```bash
kubectl get po -n rsapp                 # STATUS: ImagePullBackOff
kubectl describe po -n rsapp <pod>      # Events: イメージ viktoruj/ping_pong:doesnotexist123 が取得できない
# RS のテンプレートのイメージを直す
kubectl edit rs rs-app2223 -n rsapp     # image: viktoruj/ping_pong:doesnotexist123 -> viktoruj/ping_pong:latest
# RS はテンプレートを変えても自分で Pod を作り直さない - 古い Pod を削除する
kubectl delete po -n rsapp -l app=rsapp
kubectl get rs rs-app2223 -n rsapp      # READY 2
```

## 課題 2。Service svc-broken（Endpoints が空）

```bash
kubectl get endpoints svc-broken -n tsvc   # 空
kubectl describe svc svc-broken -n tsvc    # selector app=WRONG
kubectl get pods -n tsvc --show-labels     # Pod には label app=web が付いている
# Service の selector を直す
kubectl patch svc svc-broken -n tsvc -p '{"spec":{"selector":{"app":"web"}}}'
kubectl get endpoints svc-broken -n tsvc   # アドレスが現れた
```

## 課題 3。Deployment capp（CreateContainerConfigError）

```bash
kubectl get po -n cfgapp                  # CreateContainerConfigError
kubectl describe po -n cfgapp <pod>       # configMap missing-config が見つからない
# 足りない ConfigMap を作成する
kubectl create configmap missing-config -n cfgapp --from-literal=KEY=value
kubectl rollout status deploy capp -n cfgapp
```
