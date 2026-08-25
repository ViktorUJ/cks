[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 35 - Referenzlösung (Multicluster-Mesh)

Zwei **leere** Cluster werden bereitgestellt (nichts ist vorinstalliert). Der Worker-PC verfügt über
kubeconfig-Kontexte für beide. Sie erstellen ein einzelnes **Multi-Primary-, Multi-Network**-Mesh:
gemeinsame CA -> Istio auf beiden -> East-West-Gateways -> Cluster-übergreifende Erkennung -> Überprüfung
des Cluster-übergreifenden Load Balancings.

Alle Befehle werden auf dem **Worker-PC** ausgeführt, sofern nicht anders angegeben. Istio `1.29.x`.

## Schritt 0. Variablen und istioctl

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

## Schritt 1. Gemeinsame CA (gemeinsame Stammzertifizierungsstelle) auf beiden Clustern

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

## Schritt 2. Istio auf beiden Clustern installieren (Multi-Primary, Multi-Network)

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

## Schritt 3. East-West-Gateway auf beiden Clustern (über die Node-IP erreichbar)

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

## Schritt 4. Cluster-übergreifende Erkennung (Remote-Secrets)

Jeder istiod benötigt API-Zugriff auf den jeweils anderen Cluster. Verwenden Sie die Node-IP als API-Adresse
(im VPC erreichbar):

```bash
istioctl create-remote-secret --context "$CTX1" --name cluster1 --server "https://$C1_IP:6443" \
  | kubectl apply --context "$CTX2" -f -
istioctl create-remote-secret --context "$CTX2" --name cluster2 --server "https://$C2_IP:6443" \
  | kubectl apply --context "$CTX1" -f -
```

## Schritt 5. Die Beispiel-App bereitstellen (helloworld v1 in c1, v2 in c2, sleep)

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

## Schritt 6. Cluster-übergreifendes Load Balancing überprüfen

```bash
kubectl --context "$CTX1" -n sample exec deploy/sleep -c sleep -- \
  sh -c 'for i in $(seq 10); do curl -s helloworld:5000/hello; done'
# responses alternate between:
#   Hello version: v1, instance: helloworld-v1-... (local, cluster1)
#   Hello version: v2, instance: helloworld-v2-... (remote, cluster2)
```

Wenn Sie **sowohl v1 als auch v2** sehen, beweist das, dass die beiden Cluster ein Mesh bilden: Der Client `sleep` in
cluster1 erreicht `helloworld`-Endpunkte in cluster2 über das East-West-Gateway.

## Warum das funktioniert

- **Gemeinsame CA** - beide Cluster installieren dieselben `cacerts` (gemeinsame Stammzertifizierungsstelle), sodass mTLS-
  Zertifikate, die von jedem istiod ausgestellt werden, auf eine Vertrauenswurzel zurückgehen. Ohne eine gemeinsame Stammzertifizierungsstelle gibt es
  kein Cluster-übergreifendes Vertrauen und kein Mesh.
- **Multi-Primary** - jeder Cluster verfügt über sein eigenes istiod, daher gibt es keinen einzelnen Ausfallpunkt der Control Plane.
- **Multi-Network + East-West-Gateway** - die Cluster sind getrennte Netzwerke (überlappende
  Pod-CIDRs, Overlay-CNI), daher läuft Cluster-übergreifender Datenverkehr über das East-West-Gateway mittels
  SNI (`AUTO_PASSTHROUGH`), wodurch Ende-zu-Ende-mTLS erhalten bleibt. `meshNetworks` teilt jedem istiod die
  Adresse des Peer-Gateways (Node-IP:15443) mit.
- **Remote-Secrets** - geben jedem istiod Lesezugriff auf die API des anderen Clusters, damit es
  Remote-Services/-Endpunkte erkennt und Endpunkte gleichnamiger Services zusammenführt.
- **Cluster-übergreifendes LB** - sobald Endpunkte aus beiden Clustern denselben `helloworld`
  Service bereitstellen, führt Envoy das Load Balancing über sie hinweg durch (lokalitätsbewusst; Failover über Cluster hinweg).
