[RU version](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD)

# Lab 01 - Installation d'Istio dans un cluster Kubernetes

## Description

Travail pratique sur l'installation du maillage de services Istio dans un cluster Kubernetes (kubeadm), le déploiement de l'application de démonstration Bookinfo et la vérification du fonctionnement de l'injection de sidecar.

## Infrastructure

L'environnement est déployé dans AWS (`eu-central-1`) via Terragrunt et se compose de :

| Composant | Description                                         |
|-----------|--------------------------------------------------|
| `vpc` | VPC `10.10.0.0/16` avec des sous-réseaux publics        |
| `ssh-keys` | Clés SSH pour l'accès aux nœuds                    |
| `k8s-1` | Kubernetes `1.35.2` (kubeadm)                    |
| `worker` | Machine de travail avec `kubectl` et accès au cluster |

Instances : `t3.medium` (master) Ubuntu `22.04`

## Déploiement

```bash
TASK=01 make run_ica_task
```

## Déroulement

### 1. Installation d'istioctl

On télécharge et on installe l'utilitaire CLI d'Istio :

```bash
version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/
```

On vérifie la version :

```bash
istioctl version --remote=false
```

```
client version: 1.29.1
```

### 2. Installation d'Istio dans le cluster

On installe Istio avec le profil `demo` et un Ingress Gateway de type NodePort :

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
            nodePort: 32080   # port HTTP fixe
            name: http2
          - port: 443
            targetPort: 8443
            nodePort: 32443   # port HTTPS fixe
            name: https
EOF

istioctl install -f istio-kubeadm.yaml -y
```

On vérifie que tous les composants sont démarrés :

```bash
kubectl get pods -n istio-system
```

```
NAME                                    READY   STATUS    RESTARTS   AGE
istio-egressgateway-7f67df695d-z7jg5    1/1     Running   0          53s
istio-ingressgateway-76768cbcf6-l8rwt   1/1     Running   0          53s
istiod-76d6698857-wmvhs                 1/1     Running   0          61s
```

### 3. Activation de l'injection de sidecar

On ajoute un label sur le namespace `default` pour l'injection automatique du sidecar proxy Envoy :

```bash
kubectl label namespace default istio-injection=enabled
```

### 4. Déploiement de l'application Bookinfo

```bash
cd istio-1.29.1
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
```

On s'assure que chaque pod a `2/2` conteneurs (application + istio-proxy) :

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

### 5. Configuration du Gateway

On applique le Gateway et le VirtualService pour router le trafic via l'Ingress Gateway :

```bash
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

On vérifie la disponibilité de l'application :

```bash
curl -s http://myapp.local:32080/productpage | grep -o "<title>.*</title>"
```
```
<title>Simple Bookstore App</title>

```

## Suppression du cluster et des ressources :

```bash
TASK=01 make delete_ica_task
```
