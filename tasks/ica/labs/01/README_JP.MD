[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 01 - Kubernetes クラスターへの Istio のインストール

> [リファレンス解答](worker/files/solutions/1_JP.MD)

## 概要

Kubernetes（kubeadm）クラスターへの Istio service mesh のインストール、デモアプリケーション Bookinfo のデプロイ、および sidecar インジェクションの動作確認を行うラボです。

## インフラストラクチャ

環境は Terragrunt を使用して AWS（`eu-central-1`）にデプロイされ、以下で構成されます。

| コンポーネント | 説明                                         |
|-----------|--------------------------------------------------|
| `vpc` | パブリックサブネットを持つ VPC `10.10.0.0/16`        |
| `ssh-keys` | ノードへアクセスするための SSH キー                    |
| `k8s-1` | Kubernetes `1.35.2`（kubeadm）                    |
| `worker` | `kubectl` とクラスターへのアクセスを備えた作業マシン |

インスタンス: `t3.medium`（master）Ubuntu `22.04`

## デプロイ

```bash
TASK=01 make run_ica_task
```

## 実施手順

### 1. istioctl のインストール

Istio の CLI ユーティリティをダウンロードしてインストールします。

```bash
version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/
```

バージョンを確認します。

```bash
istioctl version --remote=false
```

```
client version: 1.29.1
```

### 2. クラスターへの Istio のインストール

`demo` プロファイルおよび NodePort タイプの Ingress Gateway を使用して Istio をインストールします。

```bash
cat <<EOF > istio-kubeadm.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: demo
  components:
    ingressGateways:
    - name: istio-ingressgateway
      k8s:
        service:
          type: NodePort
          ports:
          - port: 80
            targetPort: 8080
            nodePort: 32080   # 固定 HTTP ポート
            name: http2
          - port: 443
            targetPort: 8443
            nodePort: 32443   # 固定 HTTPS ポート
            name: https
EOF

istioctl install -f istio-kubeadm.yaml -y
```

すべてのコンポーネントが起動していることを確認します。

```bash
kubectl get pods -n istio-system
```

```
NAME                                    READY   STATUS    RESTARTS   AGE
istio-egressgateway-7f67df695d-z7jg5    1/1     Running   0          53s
istio-ingressgateway-76768cbcf6-l8rwt   1/1     Running   0          53s
istiod-76d6698857-wmvhs                 1/1     Running   0          61s
```

### 3. sidecar インジェクションの有効化

Envoy sidecar プロキシを自動インジェクションするため、namespace `default` に label を追加します。

```bash
kubectl label namespace default istio-injection=enabled
```

### 4. Bookinfo アプリケーションのデプロイ

```bash
cd istio-1.29.1
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
```

各 pod に `2/2` のコンテナ（アプリケーション + istio-proxy）が含まれることを確認します。

```bash
kubectl get pods
```

```
NAME                              READY   STATUS    RESTARTS   AGE
details-v1-6cc9f5cc44-csr7h       2/2     Running   0          50s
productpage-v1-7f885b46fc-qqd29   2/2     Running   0          49s
ratings-v1-77b8b6df5b-kfdx8       2/2     Running   0          50s
reviews-v1-fdbf79cd8-zs7qf        2/2     Running   0          50s
reviews-v2-674c6d8b4-p5r65        2/2     Running   0          50s
reviews-v3-7b775c7568-m44z7       2/2     Running   0          50s
```

### 5. Gateway の設定

Ingress Gateway 経由でトラフィックをルーティングするため、Gateway と VirtualService を適用します。

```bash
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

アプリケーションにアクセスできることを確認します。

```bash
curl -s http://myapp.local:32080/productpage | grep -o "<title>.*</title>"
```
```
<title>Simple Bookstore App</title>

```

## クラスターとリソースの削除:

```bash
TASK=01 make delete_ica_task
```