[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 35 - Эталонное решение (многокластерная mesh-сеть)

Подготавливаются два **пустых** кластера (ничего не установлено заранее). На рабочем ПК есть
контексты kubeconfig для обоих. Вы создаёте единую **multi-primary, multi-network** mesh-сеть:
общий ЦС -> Istio на обоих кластерах -> east-west-шлюзы -> межкластерное обнаружение -> проверка
межкластерной балансировки нагрузки.

Все команды выполняются с **рабочего ПК**, если не указано иное. Istio `1.29.x`.

## Шаг 0. Переменные и istioctl

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

## Шаг 1. Общий ЦС (общий корень) на обоих кластерах

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

## Шаг 2. Установка Istio (multi-primary, multi-network) на оба кластера

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

## Шаг 3. East-west-шлюз на обоих кластерах (доступен через IP-адрес узла)

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

## Шаг 4. Межкластерное обнаружение (удалённые секреты)

Каждому istiod необходим доступ к API другого кластера. Используйте IP-адрес узла в качестве адреса API
(доступного внутри VPC):

```bash
istioctl create-remote-secret --context "$CTX1" --name cluster1 --server "https://$C1_IP:6443" \
  | kubectl apply --context "$CTX2" -f -
istioctl create-remote-secret --context "$CTX2" --name cluster2 --server "https://$C2_IP:6443" \
  | kubectl apply --context "$CTX1" -f -
```

## Шаг 5. Развёртывание примера приложения (helloworld v1 в c1, v2 в c2, sleep)

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

## Шаг 6. Проверка межкластерной балансировки нагрузки

```bash
kubectl --context "$CTX1" -n sample exec deploy/sleep -c sleep -- \
  sh -c 'for i in $(seq 10); do curl -s helloworld:5000/hello; done'
# responses alternate between:
#   Hello version: v1, instance: helloworld-v1-... (local, cluster1)
#   Hello version: v2, instance: helloworld-v2-... (remote, cluster2)
```

Наличие **обеих v1 и v2** доказывает, что два кластера образуют одну mesh-сеть: клиент `sleep` в
cluster1 достигает конечных точек `helloworld` в cluster2 через east-west-шлюз.

## Почему это работает

- **Общий ЦС** - оба кластера устанавливают одни и те же `cacerts` (общий корень), поэтому сертификаты mTLS,
  выпущенные каждым istiod, образуют цепочку к одному корню доверия. Без общего корня нет
  межкластерного доверия и нет mesh-сети.
- **Multi-primary** - в каждом кластере есть собственный istiod, поэтому отсутствует единая точка
  отказа плоскости управления.
- **Multi-network + east-west-шлюз** - кластеры являются отдельными сетями (перекрывающиеся
  CIDR подов, overlay CNI), поэтому межкластерный трафик проходит через east-west-шлюз по
  SNI (`AUTO_PASSTHROUGH`), сохраняя сквозной mTLS. `meshNetworks` сообщает каждому istiod
  адрес шлюза однорангового кластера (IP-адрес узла:15443).
- **Удалённые секреты** - предоставляют каждому istiod доступ на чтение к API другого кластера, поэтому он
  обнаруживает удалённые сервисы и конечные точки и объединяет конечные точки одноимённых сервисов.
- **Межкластерная LB** - когда конечные точки из обоих кластеров обслуживают один и тот же сервис `helloworld`,
  Envoy балансирует нагрузку между ними (с учётом локальности; аварийное переключение между кластерами).
