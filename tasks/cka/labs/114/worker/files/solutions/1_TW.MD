[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# 實驗 114 - 參考解答(troubleshooting)

診斷路線只有一條:`get` → `describe`(Events)→ `logs` → 修復。

## 任務 1。ReplicaSet rs-app2223(ImagePullBackOff)

```bash
kubectl get po -n rsapp                 # STATUS: ImagePullBackOff
kubectl describe po -n rsapp <pod>      # Events: 無法拉取映像 viktoruj/ping_pong:doesnotexist123
# 修復 RS 範本中的映像
kubectl edit rs rs-app2223 -n rsapp     # image: viktoruj/ping_pong:doesnotexist123 -> viktoruj/ping_pong:latest
# RS 在範本變更時不會自己重建 Pods - 刪除舊的 Pods
kubectl delete po -n rsapp -l app=rsapp
kubectl get rs rs-app2223 -n rsapp      # READY 2
```

## 任務 2。Service svc-broken(空的 Endpoints)

```bash
kubectl get endpoints svc-broken -n tsvc   # 空的
kubectl describe svc svc-broken -n tsvc    # selector app=WRONG
kubectl get pods -n tsvc --show-labels     # Pods 帶有 label app=web
# 修復 Service 的 selector
kubectl patch svc svc-broken -n tsvc -p '{"spec":{"selector":{"app":"web"}}}'
kubectl get endpoints svc-broken -n tsvc   # 位址已出現
```

## 任務 3。Deployment capp(CreateContainerConfigError)

```bash
kubectl get po -n cfgapp                  # CreateContainerConfigError
kubectl describe po -n cfgapp <pod>       # 找不到 configMap missing-config
# 建立缺少的 ConfigMap
kubectl create configmap missing-config -n cfgapp --from-literal=KEY=value
kubectl rollout status deploy capp -n cfgapp
```
