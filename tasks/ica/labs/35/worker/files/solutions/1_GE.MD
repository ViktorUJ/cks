[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 35 - საცნობარო გადაწყვეტა (მრავალკლასტერული mesh)

მომზადებულია ორი **ცარიელი** კლასტერი (წინასწარ არაფერია დაყენებული). worker PC-ზე
ორივე კლასტერის kubeconfig კონტექსტებია. თქვენ ქმნით ერთიან **multi-primary, multi-network** mesh-ს:
საერთო CA -> Istio ორივეზე -> east-west gateway-ები -> კლასტერებს შორის აღმოჩენა ->
კლასტერებს შორის დატვირთვის დაბალანსების შემოწმება.

ყველა ბრძანება სრულდება **worker PC**-დან, თუ სხვა რამ არ არის მითითებული. Istio `1.29.x`.

## ნაბიჯი 0. ცვლადები და istioctl

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

## ნაბიჯი 1. საერთო CA (საერთო root) ორივე კლასტერზე

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

## ნაბიჯი 2. Istio-ს დაყენება (multi-primary, multi-network) ორივეზე

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

## ნაბიჯი 3. East-west gateway ორივეზე (ხელმისაწვდომია node IP-ის მეშვეობით)

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

## ნაბიჯი 4. კლასტერებს შორის აღმოჩენა (remote secret-ები)

თითოეულ istiod-ს მეორე კლასტერის API-ზე წვდომა სჭირდება. API-ის მისამართად გამოიყენეთ node IP
(VPC-ის შიგნიდან ხელმისაწვდომი):

```bash
istioctl create-remote-secret --context "$CTX1" --name cluster1 --server "https://$C1_IP:6443" \
  | kubectl apply --context "$CTX2" -f -
istioctl create-remote-secret --context "$CTX2" --name cluster2 --server "https://$C2_IP:6443" \
  | kubectl apply --context "$CTX1" -f -
```

## ნაბიჯი 5. ნიმუშის აპლიკაციის გაშლა (helloworld v1 c1-ში, v2 c2-ში, sleep)

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

## ნაბიჯი 6. კლასტერებს შორის დატვირთვის დაბალანსების შემოწმება

```bash
kubectl --context "$CTX1" -n sample exec deploy/sleep -c sleep -- \
  sh -c 'for i in $(seq 10); do curl -s helloworld:5000/hello; done'
# responses alternate between:
#   Hello version: v1, instance: helloworld-v1-... (local, cluster1)
#   Hello version: v2, instance: helloworld-v2-... (remote, cluster2)
```

**როგორც v1-ის, ისე v2-ის** დანახვა ადასტურებს, რომ ორი კლასტერი ერთ mesh-ს ქმნის: `sleep` კლიენტი
cluster1-ში east-west gateway-ის გავლით cluster2-ში არსებულ `helloworld` endpoint-ებს უკავშირდება.

## რატომ მუშაობს ეს

- **საერთო CA** - ორივე კლასტერი აყენებს *ერთსა და იმავე* `cacerts`-ს (საერთო root), ამიტომ თითოეული istiod-ის
  მიერ გაცემული mTLS სერტიფიკატების ჯაჭვი ერთ ნდობის root-მდე მიდის. საერთო root-ის გარეშე
  კლასტერებს შორის ნდობა და mesh არ იარსებებს.
- **Multi-primary** - თითოეულ კლასტერს საკუთარი istiod აქვს, ამიტომ control plane-ში
  მარცხის ერთადერთი წერტილი არ არსებობს.
- **Multi-network + east-west gateway** - კლასტერები ცალკეულ ქსელებშია (გადაფარული
  pod CIDR-ები, overlay CNI), ამიტომ კლასტერებს შორის ტრაფიკი east-west gateway-ის გავლით
  SNI-ის (`AUTO_PASSTHROUGH`) გამოყენებით გადაადგილდება და end-to-end mTLS ნარჩუნდება. `meshNetworks` თითოეულ istiod-ს
  peer gateway-ის მისამართს (node IP:15443) აწვდის.
- **Remote secret-ები** - თითოეულ istiod-ს მეორე კლასტერის API-ზე წაკითხვის წვდომას აძლევს, რის შედეგადაც ის
  remote service-ებს/endpoint-ებს აღმოაჩენს და ერთნაირი სახელის მქონე service-ების endpoint-ებს აერთიანებს.
- **კლასტერებს შორის LB** - როცა ორივე კლასტერის endpoint-ები ერთსა და იმავე `helloworld`
  Service-ს ემსახურება, Envoy მათ შორის დატვირთვას აბალანსებს (locality-aware; კლასტერებს შორის failover).
