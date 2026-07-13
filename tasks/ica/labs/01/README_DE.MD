[RU version](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD)

# Lab 01 - Installation von Istio in einem Kubernetes-Cluster

## Beschreibung

Praktische Übung zur Installation des Istio Service Mesh in einem Kubernetes-Cluster (kubeadm), zum Deployment der Demo-Anwendung Bookinfo und zur Überprüfung der Sidecar-Injektion.

## Infrastruktur

Die Umgebung wird in AWS (`eu-central-1`) über Terragrunt bereitgestellt und besteht aus:

| Komponente | Beschreibung                                     |
|-----------|--------------------------------------------------|
| `vpc` | VPC `10.10.0.0/16` mit öffentlichen Subnetzen        |
| `ssh-keys` | SSH-Schlüssel für den Zugriff auf die Nodes                    |
| `k8s-1` | Kubernetes `1.35.2` (kubeadm)                    |
| `worker` | Arbeitsmaschine mit `kubectl` und Zugriff auf den Cluster |

Instanzen: `t3.medium` (master) Ubuntu `22.04`

## Deployment

```bash
TASK=01 make run_ica_task
```

## Ablauf

### 1. Installation von istioctl

Wir laden das Istio-CLI-Werkzeug herunter und installieren es:

```bash
version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/
```

Wir überprüfen die Version:

```bash
istioctl version --remote=false
```

```
client version: 1.29.1
```

### 2. Installation von Istio im Cluster

Wir installieren Istio mit dem Profil `demo` und einem Ingress Gateway vom Typ NodePort:

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
            nodePort: 32080   # fester HTTP-Port
            name: http2
          - port: 443
            targetPort: 8443
            nodePort: 32443   # fester HTTPS-Port
            name: https
EOF

istioctl install -f istio-kubeadm.yaml -y
```

Wir überprüfen, dass alle Komponenten gestartet sind:

```bash
kubectl get pods -n istio-system
```

```
NAME                                    READY   STATUS    RESTARTS   AGE
istio-egressgateway-7f67df695d-z7jg5    1/1     Running   0          53s
istio-ingressgateway-76768cbcf6-l8rwt   1/1     Running   0          53s
istiod-76d6698857-wmvhs                 1/1     Running   0          61s
```

### 3. Aktivierung der Sidecar-Injektion

Wir fügen dem Namespace `default` ein Label hinzu, um die automatische Injektion des Sidecar-Proxys Envoy zu ermöglichen:

```bash
kubectl label namespace default istio-injection=enabled
```

### 4. Deployment der Anwendung Bookinfo

```bash
cd istio-1.29.1
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
```

Wir stellen sicher, dass jeder Pod `2/2` Container hat (Anwendung + istio-proxy):

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

### 5. Konfiguration des Gateways

Wir wenden Gateway und VirtualService an, um den Datenverkehr über das Ingress Gateway zu routen:

```bash
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

Wir überprüfen die Erreichbarkeit der Anwendung:

```bash
curl -s http://myapp.local:32080/productpage | grep -o "<title>.*</title>"
```
```
<title>Simple Bookstore App</title>

```

## Löschen des Clusters und der Ressourcen:

```bash
TASK=01 make delete_ica_task
```
