[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 01 - 在 Kubernetes 叢集安裝 Istio

> [參考解答](worker/files/solutions/1_TW.MD)

## 說明

在 Kubernetes（kubeadm）叢集中安裝 Istio service mesh、部署 Bookinfo 示範應用程式，以及驗證 sidecar 注入運作的實驗。

## 基礎設施

環境透過 Terragrunt 在 AWS（`eu-central-1`）中部署，由以下項目組成：

| 元件 | 說明                                         |
|-----------|--------------------------------------------------|
| `vpc` | 具有公有子網路的 VPC `10.10.0.0/16`        |
| `ssh-keys` | 用於存取節點的 SSH 金鑰                    |
| `k8s-1` | Kubernetes `1.35.2`（kubeadm）                    |
| `worker` | 安裝 `kubectl` 並可存取叢集的工作機器 |

執行個體：`t3.medium`（master）Ubuntu `22.04`

## 部署

```bash
TASK=01 make run_ica_task
```

## 執行步驟

### 1. 安裝 istioctl

下載並安裝 Istio CLI 工具：

```bash
version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/
```

驗證版本：

```bash
istioctl version --remote=false
```

```
client version: 1.29.1
```

### 2. 在叢集安裝 Istio

使用 `demo` 設定檔和 NodePort 類型的 Ingress Gateway 安裝 Istio：

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
            nodePort: 32080   # 固定的 HTTP 連接埠
            name: http2
          - port: 443
            targetPort: 8443
            nodePort: 32443   # 固定的 HTTPS 連接埠
            name: https
EOF

istioctl install -f istio-kubeadm.yaml -y
```

確認所有元件皆已啟動：

```bash
kubectl get pods -n istio-system
```

```
NAME                                    READY   STATUS    RESTARTS   AGE
istio-egressgateway-7f67df695d-z7jg5    1/1     Running   0          53s
istio-ingressgateway-76768cbcf6-l8rwt   1/1     Running   0          53s
istiod-76d6698857-wmvhs                 1/1     Running   0          61s
```

### 3. 啟用 sidecar 注入

為 `default` namespace 新增 label，以自動注入 Envoy sidecar 代理：

```bash
kubectl label namespace default istio-injection=enabled
```

### 4. 部署 Bookinfo 應用程式

```bash
cd istio-1.29.1
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
```

確認每個 pod 都有 `2/2` 個容器（應用程式 + istio-proxy）：

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

### 5. 設定 Gateway

套用 Gateway 與 VirtualService，以透過 Ingress Gateway 路由流量：

```bash
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

驗證應用程式是否可存取：

```bash
curl -s http://myapp.local:32080/productpage | grep -o "<title>.*</title>"
```
```
<title>Simple Bookstore App</title>

```

## 刪除叢集與資源：

```bash
TASK=01 make delete_ica_task
```