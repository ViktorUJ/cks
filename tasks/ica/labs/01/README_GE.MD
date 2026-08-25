[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# ლაბორატორია 01 - Istio-ს ინსტალაცია Kubernetes-ის კლასტერში

> [საცნობარო გადაწყვეტა](worker/files/solutions/1_GE.MD)

## აღწერა

ლაბორატორიული სამუშაო Istio service mesh-ის Kubernetes-ის (kubeadm) კლასტერში ინსტალაციის, Bookinfo დემო-აპლიკაციის გაშლისა და sidecar-ინექციის მუშაობის შემოწმების შესახებ.

## ინფრასტრუქტურა

გარემო იშლება AWS-ში (`eu-central-1`) Terragrunt-ის მეშვეობით და შედგება შემდეგი კომპონენტებისგან:

| კომპონენტი | აღწერა                                         |
|-----------|--------------------------------------------------|
| `vpc` | VPC `10.10.0.0/16` საჯარო ქვექსელებით        |
| `ssh-keys` | SSH-გასაღებები კვანძებზე წვდომისთვის                    |
| `k8s-1` | Kubernetes `1.35.2` (kubeadm)                    |
| `worker` | სამუშაო მანქანა `kubectl`-ითა და კლასტერზე წვდომით |

ინსტანსები: `t3.medium` (master) Ubuntu `22.04`

## გაშლა

```bash
TASK=01 make run_ica_task
```

## შესრულების თანმიმდევრობა

### 1. istioctl-ის ინსტალაცია

ჩამოტვირთეთ და დააინსტალირეთ Istio-ს CLI-უტილიტა:

```bash
version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/
```

შეამოწმეთ ვერსია:

```bash
istioctl version --remote=false
```

```
client version: 1.29.1
```

### 2. Istio-ს ინსტალაცია კლასტერში

დააინსტალირეთ Istio `demo` პროფილითა და NodePort ტიპის Ingress Gateway-ით:

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
            nodePort: 32080   # ფიქსირებული HTTP პორტი
            name: http2
          - port: 443
            targetPort: 8443
            nodePort: 32443   # ფიქსირებული HTTPS პორტი
            name: https
EOF

istioctl install -f istio-kubeadm.yaml -y
```

შეამოწმეთ, რომ ყველა კომპონენტი გაშვებულია:

```bash
kubectl get pods -n istio-system
```

```
NAME                                    READY   STATUS    RESTARTS   AGE
istio-egressgateway-7f67df695d-z7jg5    1/1     Running   0          53s
istio-ingressgateway-76768cbcf6-l8rwt   1/1     Running   0          53s
istiod-76d6698857-wmvhs                 1/1     Running   0          61s
```

### 3. sidecar-ინექციის ჩართვა

დაამატეთ label `default` namespace-ს Envoy sidecar-პროქსის ავტომატური ინექციისთვის:

```bash
kubectl label namespace default istio-injection=enabled
```

### 4. Bookinfo აპლიკაციის გაშლა

```bash
cd istio-1.29.1
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
```

დარწმუნდით, რომ თითოეულ პოდს აქვს `2/2` კონტეინერი (აპლიკაცია + istio-proxy):

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

### 5. Gateway-ის კონფიგურაცია

გამოიყენეთ Gateway და VirtualService ტრაფიკის Ingress Gateway-ის გავლით მარშრუტიზაციისთვის:

```bash
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

შეამოწმეთ აპლიკაციის ხელმისაწვდომობა:

```bash
curl -s http://myapp.local:32080/productpage | grep -o "<title>.*</title>"
```
```
<title>Simple Bookstore App</title>

```

## კლასტერისა და რესურსების წაშლა:

```bash
TASK=01 make delete_ica_task
```