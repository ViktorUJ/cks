# Install istio

скачиваем и устанавливаем istioctl

```
version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/

istioctl version --remote=false 

```
```
client version: 1.29.1
```

установлиеваем istio в кластер с демо провилем и нодепортом
```
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
            nodePort: 32080   # <--- Ваш фиксированный HTTP порт
            name: http2
          - port: 443
            targetPort: 8443
            nodePort: 32443   # <--- Ваш фиксированный HTTPS порт
            name: https
EOF

istioctl install -f istio-kubeadm.yaml -y

```

проверяем что все установилось и работает
```
#  kubectl get pods -n istio-system

NAME                                    READY   STATUS    RESTARTS   AGE
istio-egressgateway-7f67df695d-z7jg5    1/1     Running   0          53s
istio-ingressgateway-76768cbcf6-l8rwt   1/1     Running   0          53s
istiod-76d6698857-wmvhs                 1/1     Running   0          61s


```
добавляем лейбл для автоматической инъекции sidecar в namespace default
````
kubectl label namespace default istio-injection=enabled
````
установливаем демо приложение bookinfo
```
cd istio-1.29.1

kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
```
проверяем что поды поднялись с сайдкаром
``` 
# kubectl get pods
NAME                              READY   STATUS    RESTARTS   AGE
details-v1-6cc9f5cc44-csr7h       2/2     Running   0          50s
productpage-v1-7f885b46fc-qqd29   2/2     Running   0          49s
ratings-v1-77b8b6df5b-kfdx8       2/2     Running   0          50s
reviews-v1-fdbf79cd8-zs7qf        2/2     Running   0          50s
reviews-v2-674c6d8b4-p5r65        2/2     Running   0          50s
reviews-v3-7b775c7568-m44z7       2/2     Running   0          50s


```

устанвливаем gateway для bookinfo
```
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```
проверяем что все работает
```
curl -s http://myapp.local:32080/productpage | grep -o "<title>.*</title>"
```