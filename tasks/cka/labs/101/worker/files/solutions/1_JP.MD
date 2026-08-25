[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 101 - 参考解答（基礎：Pod、Deployment、namespace、Service）

## 課題 1。Namespace `ckad-101`

```bash
kubectl create namespace ckad-101
```

## 課題 2。`ckad-101` 内の Pod `web`（viktoruj/ping_pong、label `tier=frontend`）

```bash
kubectl run web --image=viktoruj/ping_pong:latest --labels="tier=frontend" -n ckad-101
```

確認：

```bash
kubectl get po web -n ckad-101 --show-labels
```

## 課題 3。`ckad-101` 内の Deployment `api`（viktoruj/ping_pong、4 レプリカ）

まず 3 レプリカで作成し、その後 4 にスケールします（または最初から `--replicas=4`）：

```bash
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=3 -n ckad-101
kubectl scale deployment api --replicas=4 -n ckad-101
```

確認（Ready になるまで待つ）：

```bash
kubectl get deploy api -n ckad-101 -w
```

## 課題 4。Deployment `api` 用の Service `api-svc`（ClusterIP、ポート 80 → targetPort 8080）

```bash
kubectl expose deployment api --name=api-svc --port=80 --target-port=8080 -n ckad-101
```

Service が Pod に紐づいたことの確認（Endpoints が空でない）：

```bash
kubectl get svc api-svc -n ckad-101
kubectl get endpoints api-svc -n ckad-101
```

## 課題 5。Service `web-np`（NodePort、ポート 80 → targetPort 8080、nodePort 30101）

```bash
kubectl expose deployment api --name=web-np --type=NodePort --port=80 --target-port=8080 -n ckad-101
# 特定の nodePort を指定する（デフォルトではランダムに割り当てられる）
kubectl patch svc web-np -n ckad-101 -p '{"spec":{"ports":[{"port":80,"targetPort":8080,"nodePort":30101}]}}'
```

確認：

```bash
kubectl get svc web-np -n ckad-101
```

## 課題 6。JSONPath：Pod の名前をファイルへ

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl get pods -n ckad-101 -o jsonpath='{.items[*].metadata.name}' \
  > /var/work/tests/artifacts/6/pods.txt
cat /var/work/tests/artifacts/6/pods.txt
```

## マニフェスト生成による素早い自己チェック（スピード練習用）

```bash
export do="--dry-run=client -o yaml"
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=4 $do -n ckad-101 > api.yaml
kubectl apply -f api.yaml
```
