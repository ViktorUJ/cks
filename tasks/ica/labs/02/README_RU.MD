[Eng version](README.MD)

# Lab 01 — Установка Istio в Kubernetes-кластер

## Описание

Лабораторная работа по установке Istio service mesh в кластер Kubernetes (kubeadm), развёртыванию демо-приложения Bookinfo и проверке работы sidecar-инъекции.

## Инфраструктура

Окружение разворачивается в AWS (`eu-north-1`) через Terragrunt и состоит из:

| Компонент | Описание                                         |
|-----------|--------------------------------------------------|
| `vpc` | VPC `10.10.0.0/16` с публичными подсетями        |
| `ssh-keys` | SSH-ключи для доступа к нодам                    |
| `k8s-1` | Kubernetes `1.35.2` (kubeadm)                    |
| `worker` | Рабочая машина с `kubectl` и доступом к кластеру |

Инстансы: `t4g.medium` (master) Ubuntu `22.04`

## Развёртывание

```bash
TASK=01 make run_ica_task
```

## Порядок выполнения

### 1. Установка istioctl

Скачиваем и устанавливаем CLI-утилиту Istio:

```bash
version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/
```

Проверяем версию:

```bash
istioctl version --remote=false
```

```
client version: 1.29.1
```

### 2. Установка Istio в кластер

Устанавливаем Istio с профилем `demo` и Ingress Gateway типа NodePort:

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
            nodePort: 32080   # фиксированный HTTP порт
            name: http2
          - port: 443
            targetPort: 8443
            nodePort: 32443   # фиксированный HTTPS порт
            name: https
EOF

istioctl install -f istio-kubeadm.yaml -y
```

Проверяем, что все компоненты запущены:

```bash
kubectl get pods -n istio-system
```

```
NAME                                    READY   STATUS    RESTARTS   AGE
istio-egressgateway-7f67df695d-z7jg5    1/1     Running   0          53s
istio-ingressgateway-76768cbcf6-l8rwt   1/1     Running   0          53s
istiod-76d6698857-wmvhs                 1/1     Running   0          61s
```

### 3. Включение sidecar-инъекции

Добавляем label на namespace `default` для автоматической инъекции sidecar-прокси Envoy:

```bash
kubectl label namespace default istio-injection=enabled
```

### 4. Развёртывание приложения Bookinfo

```bash
cd istio-1.29.1
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
```

Убеждаемся, что у каждого пода `2/2` контейнера (приложение + istio-proxy):

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

### 5. Настройка Gateway

Применяем Gateway и VirtualService для маршрутизации трафика через Ingress Gateway:

```bash
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

Проверяем доступность приложения:

```bash
curl -s http://myapp.local:32080/productpage | grep -o "<title>.*</title>"
```
```
<title>Simple Bookstore App</title>

```

## Удаление кластера и ресурсов:

```bash
TASK=01 make delete_ica_task
```