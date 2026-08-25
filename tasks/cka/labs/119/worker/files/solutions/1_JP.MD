[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 119 - 参考解答（スピードドリル + JSONPath）

この実習の狙いは、命令型コマンドと `--dry-run` でスピードを鍛え、さらに
`-o jsonpath` を練習することです。解答ファイルは `/home/ubuntu/answers/` に保存します。

高速化のための小技（セッションに追加してください）：

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
```

## ドリル

```bash
# 1. namespace
kubectl create namespace drill

# 2. deployment api、3 レプリカ
kubectl -n drill create deployment api --image=viktoruj/ping_pong:latest --replicas=3

# 3. api 用の ClusterIP service（ポート 80）
kubectl -n drill expose deployment api --name=api-svc --port=80 --target-port=8080

# 4. configmap と secret
kubectl -n drill create configmap cfg --from-literal=APP_COLOR=blue
kubectl -n drill create secret generic sec --from-literal=PASSWORD=s3cr3t
```

## JSONPath

```bash
mkdir -p /home/ubuntu/answers

# 5. すべてのノードの kubelet バージョン
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}' \
  > /home/ubuntu/answers/versions.txt

# 6. namespace drill のすべての Pod のコンテナイメージ
kubectl -n drill get pods -o jsonpath='{.items[*].spec.containers[*].image}' \
  > /home/ubuntu/answers/images.txt

# 7. service api-svc の ClusterIP
kubectl -n drill get svc api-svc -o jsonpath='{.spec.clusterIP}' \
  > /home/ubuntu/answers/api-ip.txt
```

試験で役立つ JSONPath のテクニック：

```bash
# ソートされた出力
kubectl get pods -A --sort-by=.metadata.creationTimestamp
# custom-columns
kubectl get pods -n drill -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[*].image
# jsonpath の range
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.kubeletVersion}{"\n"}{end}'
```

ドキュメント：[JSONPath Support](https://kubernetes.io/docs/reference/kubectl/jsonpath/),
[kubectl Quick Reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/)。

## チェック

```bash
check_result
```
