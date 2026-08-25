[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 35 - リファレンスソリューション（マルチクラスターメッシュ）

2 つの**ベア**クラスターがプロビジョニングされています（事前インストールされたものはありません）。ワーカー PC には
両方の kubeconfig コンテキストがあります。単一の**マルチプライマリ、マルチネットワーク**メッシュを構築します。
共有 CA -> 両方に Istio -> east-west ゲートウェイ -> クラスター間ディスカバリー ->
クラスター間ロードバランシングを検証します。

特記がない限り、すべてのコマンドは**ワーカー PC**から実行します。Istio `1.29.x`。

## ステップ 0. 変数と istioctl

```bash
CTX1=$(kubectl config get-contexts -o name | grep -m1 cluster1)
CTX2=$(kubectl config get-contexts -o name | grep -m1 cluster2)

# node IPs (single-node clusters); used for east-west gateway + API address
C1_IP=$(kubectl --context "$CTX1" get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
C2_IP=$(kubectl --context "$CTX2" get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "cluster1=$CTX1 $C1_IP ; cluster2=$CTX2 $C2_IP"

# istioctl on the worker PC
export ISTIO_VERSION=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
sudo install istio-$ISTIO_VERSION/bin/istioctl /usr/local/bin/
```

## ステップ 1. 両方のクラスターの共有 CA（共通ルート）

```bash
mkdir -p ~/certs && cd ~/certs
# root CA
openssl genrsa -out root-key.pem 4096
openssl req -x509 -new -nodes -key root-key.pem -sha256 -days 3650 \
  -subj "/O=Istio/CN=Root CA" -out root-cert.pem
# shared intermediate CA
openssl genrsa -out ca-key.pem 4096
openssl req -new -key ca-key.pem -subj "/O=Istio/CN=Intermediate CA" -out ca.csr
cat > ext.cnf <<'EOF'
basicConstraints=critical,CA:TRUE,pathlen:0
keyUsage=critical,digitalSignature,keyCertSign,cRLSign
subjectAltName=DNS:istiod.istio-system.svc
EOF
openssl x509 -req -in ca.csr -CA root-cert.pem -CAkey root-key.pem -CAcreateserial \
  -days 3650 -sha256 -extfile ext.cnf -out ca-cert.pem
cat ca-cert.pem root-cert.pem > cert-chain.pem

# install the SAME cacerts on both clusters (this is what gives shared trust)
for CTX in "$CTX1" "$CTX2"; do
  kubectl --context "$CTX" create namespace istio-system 2>/dev/null || true
  kubectl --context "$CTX" -n istio-system create secret generic cacerts \
    --from-file=root-cert.pem --from-file=ca-cert.pem \
    --from-file=ca-key.pem --from-file=cert-chain.pem
done
cd ~
```

## ステップ 2. 両方に Istio をインストール（マルチプライマリ、マルチネットワーク）

```bash
kubectl --context "$CTX1" label namespace istio-system topology.istio.io/network=network1 --overwrite
kubectl --context "$CTX2" label namespace istio-system topology.istio.io/network=network2 --overwrite

# cluster1
istioctl install --context "$CTX1" -y -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: cluster1
      network: network1
      meshNetworks:
        network1:
          endpoints: [{fromRegistry: cluster1}]
          gateways: [{address: $C1_IP, port: 15443}]
        network2:
          endpoints: [{fromRegistry: cluster2}]
          gateways: [{address: $C2_IP, port: 15443}]
EOF

# cluster2
istioctl install --context "$CTX2" -y -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: cluster2
      network: network2
      meshNetworks:
        network1:
          endpoints: [{fromRegistry: cluster1}]
          gateways: [{address: $C1_IP, port: 15443}]
        network2:
          endpoints: [{fromRegistry: cluster2}]
          gateways: [{address: $C2_IP, port: 15443}]
EOF
```

## ステップ 3. 両方の east-west ゲートウェイ（ノード IP 経由で到達可能）

```bash
# cluster1 EW gateway
istioctl install --context "$CTX1" -y -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: eastwest
spec:
  profile: empty
  components:
    ingressGateways:
      - name: istio-eastwestgateway
        label:
          istio: eastwestgateway
          topology.istio.io/network: network1
        enabled: true
        k8s:
          env:
            - name: ISTIO_META_REQUESTED_NETWORK_VIEW
              value: network1
          service:
            type: NodePort
            ports:
              - name: tls
                port: 15443
                targetPort: 15443
                nodePort: 32443
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: cluster1
      network: network1
EOF
# make it reachable at C1_IP:15443 for the peer cluster
kubectl --context "$CTX1" -n istio-system patch svc istio-eastwestgateway \
  -p "{\"spec\":{\"externalIPs\":[\"$C1_IP\"]}}"

# cluster2 EW gateway (network2)
istioctl install --context "$CTX2" -y -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: eastwest
spec:
  profile: empty
  components:
    ingressGateways:
      - name: istio-eastwestgateway
        label:
          istio: eastwestgateway
          topology.istio.io/network: network2
        enabled: true
        k8s:
          env:
            - name: ISTIO_META_REQUESTED_NETWORK_VIEW
              value: network2
          service:
            type: NodePort
            ports:
              - name: tls
                port: 15443
                targetPort: 15443
                nodePort: 32443
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: cluster2
      network: network2
EOF
kubectl --context "$CTX2" -n istio-system patch svc istio-eastwestgateway \
  -p "{\"spec\":{\"externalIPs\":[\"$C2_IP\"]}}"

# expose all mesh services (*.local) through the EW gateway on both clusters
for CTX in "$CTX1" "$CTX2"; do
kubectl --context "$CTX" -n istio-system apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: cross-network-gateway
spec:
  selector:
    istio: eastwestgateway
  servers:
    - port:
        number: 15443
        name: tls
        protocol: TLS
      tls:
        mode: AUTO_PASSTHROUGH
      hosts:
        - "*.local"
EOF
done
```

## ステップ 4. クラスター間ディスカバリー（リモートシークレット）

各 istiod には、もう一方のクラスターの API へのアクセスが必要です。API アドレスとしてノード IP を使用します
（VPC 内から到達可能です）。

```bash
istioctl create-remote-secret --context "$CTX1" --name cluster1 --server "https://$C1_IP:6443" \
  | kubectl apply --context "$CTX2" -f -
istioctl create-remote-secret --context "$CTX2" --name cluster2 --server "https://$C2_IP:6443" \
  | kubectl apply --context "$CTX1" -f -
```

## ステップ 5. サンプルアプリをデプロイ（c1 に helloworld v1、c2 に v2、sleep）

```bash
BASE=https://raw.githubusercontent.com/istio/istio/release-1.29/samples

for CTX in "$CTX1" "$CTX2"; do
  kubectl --context "$CTX" create namespace sample 2>/dev/null || true
  kubectl --context "$CTX" label namespace sample istio-injection=enabled --overwrite
  # the Service (same in both clusters -> endpoints get merged across clusters)
  kubectl --context "$CTX" -n sample apply -f "$BASE/helloworld/helloworld.yaml" -l service=helloworld
  # sleep client
  kubectl --context "$CTX" -n sample apply -f "$BASE/sleep/sleep.yaml"
done
# v1 only in cluster1, v2 only in cluster2
kubectl --context "$CTX1" -n sample apply -f "$BASE/helloworld/helloworld.yaml" -l version=v1
kubectl --context "$CTX2" -n sample apply -f "$BASE/helloworld/helloworld.yaml" -l version=v2
```

## ステップ 6. クラスター間ロードバランシングを検証

```bash
kubectl --context "$CTX1" -n sample exec deploy/sleep -c sleep -- \
  sh -c 'for i in $(seq 10); do curl -s helloworld:5000/hello; done'
# responses alternate between:
#   Hello version: v1, instance: helloworld-v1-... (local, cluster1)
#   Hello version: v2, instance: helloworld-v2-... (remote, cluster2)
```

**v1 と v2 の両方**が表示されれば、2 つのクラスターが 1 つのメッシュを形成していることが証明されます。cluster1 の
`sleep` クライアントは、east-west ゲートウェイを介して cluster2 の `helloworld` エンドポイントに到達します。

## これが機能する理由

- **共有 CA** - 両方のクラスターは*同一の* `cacerts`（共通ルート）をインストールするため、各 istiod が発行する mTLS
  証明書は 1 つの信頼ルートに連鎖します。共有ルートがなければ、クラスター間の信頼もメッシュもありません。
- **マルチプライマリ** - 各クラスターには独自の istiod があるため、コントロールプレーンに単一障害点はありません。
- **マルチネットワーク + east-west ゲートウェイ** - クラスターは別々のネットワークです（重複する
  Pod CIDR、オーバーレイ CNI）。そのため、クラスター間トラフィックは east-west ゲートウェイを経由し、SNI
  （`AUTO_PASSTHROUGH`）によりエンドツーエンドの mTLS を維持します。`meshNetworks` は、各 istiod に
  ピアゲートウェイのアドレス（ノード IP:15443）を伝えます。
- **リモートシークレット** - 各 istiod にもう一方のクラスターの API への読み取りアクセスを与えるため、リモートの
  サービスとエンドポイントを検出し、同名サービスのエンドポイントをマージします。
- **クラスター間 LB** - 両方のクラスターのエンドポイントが同じ `helloworld` Service をバックエンドとすると、
  Envoy はそれらに負荷分散します（ローカリティ認識、クラスター間フェイルオーバー）。
