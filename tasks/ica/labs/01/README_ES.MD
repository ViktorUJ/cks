[RU version](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD)

# Lab 01 - Instalación de Istio en un clúster de Kubernetes

## Descripción

Laboratorio de instalación de la malla de servicios Istio en un clúster de Kubernetes (kubeadm), despliegue de la aplicación de demostración Bookinfo y verificación de la inyección de sidecar.

## Infraestructura

El entorno se despliega en AWS (`eu-central-1`) mediante Terragrunt y consta de:

| Componente | Descripción                                      |
|-----------|--------------------------------------------------|
| `vpc` | VPC `10.10.0.0/16` con subredes públicas        |
| `ssh-keys` | Claves SSH para el acceso a los nodos                    |
| `k8s-1` | Kubernetes `1.35.2` (kubeadm)                    |
| `worker` | Máquina de trabajo con `kubectl` y acceso al clúster |

Instancias: `t3.medium` (master) Ubuntu `22.04`

## Despliegue

```bash
TASK=01 make run_ica_task
```

## Orden de ejecución

### 1. Instalación de istioctl

Descargamos e instalamos la utilidad CLI de Istio:

```bash
version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/
```

Verificamos la versión:

```bash
istioctl version --remote=false
```

```
client version: 1.29.1
```

### 2. Instalación de Istio en el clúster

Instalamos Istio con el perfil `demo` y un Ingress Gateway de tipo NodePort:

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
            nodePort: 32080   # puerto HTTP fijo
            name: http2
          - port: 443
            targetPort: 8443
            nodePort: 32443   # puerto HTTPS fijo
            name: https
EOF

istioctl install -f istio-kubeadm.yaml -y
```

Verificamos que todos los componentes estén en ejecución:

```bash
kubectl get pods -n istio-system
```

```
NAME                                    READY   STATUS    RESTARTS   AGE
istio-egressgateway-7f67df695d-z7jg5    1/1     Running   0          53s
istio-ingressgateway-76768cbcf6-l8rwt   1/1     Running   0          53s
istiod-76d6698857-wmvhs                 1/1     Running   0          61s
```

### 3. Activación de la inyección de sidecar

Añadimos una label al namespace `default` para la inyección automática del sidecar proxy Envoy:

```bash
kubectl label namespace default istio-injection=enabled
```

### 4. Despliegue de la aplicación Bookinfo

```bash
cd istio-1.29.1
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
```

Nos aseguramos de que cada pod tenga `2/2` contenedores (aplicación + istio-proxy):

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

### 5. Configuración del Gateway

Aplicamos el Gateway y el VirtualService para enrutar el tráfico a través del Ingress Gateway:

```bash
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

Verificamos la disponibilidad de la aplicación:

```bash
curl -s http://myapp.local:32080/productpage | grep -o "<title>.*</title>"
```
```
<title>Simple Bookstore App</title>

```

## Eliminación del clúster y los recursos:

```bash
TASK=01 make delete_ica_task
```
