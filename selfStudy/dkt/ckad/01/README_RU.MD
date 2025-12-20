[README_ENG](README.MD)

## [video](https://www.youtube.com/watch?v=4WXSijgYbVw)

## [presentation](https://www.canva.com/design/DAGUf_wVLzU/3loTtTVLbmVJULPuzeI5VA/edit)


**Kubernetes**  - система оркестрации контейнерами . Сейчас самая популярная система оркестрации контейнерами.
альтернатива : , AWS -ECS ,  docker-Swarm, mesos , Nomad (hashicorp),


<p align="center">
    <a href="https://github.com/ViktorUJ/cks/blob/dkt_ckad_01/selfStudy/dkt/ckad/01/README.MD"><img src="https://kubernetes.io/images/docs/components-of-kubernetes.svg" width="1900" height="600" alt="SRE Learning Platform"/></a>
</p>

[components](https://kubernetes.io/docs/concepts/overview/components/)

[CNI plugins](https://kubernetes.io/docs/concepts/cluster-administration/networking/#cni)


## Основные компоненты  Kubernetes

| **Компонент**      | **назначение**                                                    | **Как найти**                                                                                      |
|--------------------|--------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| API Server         | Управляет запросами к кластеру                                     | Статический под. Манифест находится в `/etc/kubernetes/manifests/kube-apiserver.yaml`              |
| etcd               | Хранение всей информации о состоянии кластера                      | Статический под. Манифест находится в `/etc/kubernetes/manifests/etcd.yaml`                        |
| Scheduler          | Планирует запуск подов на нодах                                    | Статический под. Манифест находится в `/etc/kubernetes/manifests/kube-scheduler.yaml`              |
| Controller-Manager | Управляет контроллерами для поддержания работоспособности кластера | Статический под. Манифест находится в `/etc/kubernetes/manifests/kube-controller-manager.yaml`     |
| Kubelet            | Управляет подами на конкретных нодах                               | Установлен в виде сервиса на нодах. Проверка: `systemctl status kubelet`                           |
| kube-proxy         | Управляет сетевыми правилами (iptables)                            | Демонсет. Проверка: `kubectl get daemonset kube-proxy --namespace=kube-system`                     |
| CNI                | Обеспечивает сетевое взаимодействие между подами                   | Установлен в виде плагинов. Проверка: `kubectl get pods --namespace=kube-system`                   |
| DNS                | Обеспечивает разрешение имен сервисов в кластере                   | Развернут как сервис и под (CoreDNS). Проверка: `kubectl get svc kube-dns --namespace=kube-system` |



## Примитивы Kubernetes


| **Имя**                  | **назначение**                                                            | **описание**                                                             |
|--------------------------|---------------------------------------------------------------------------|--------------------------------------------------------------------------|
| Container                | часть конфигурации pod                                                    | отдельно запустить нельзя                                                |
| Pod                      | запуск 1 или нескольких контейнеров с общей сетью  + общие папки + Labels | изменить нельзя, нужно пересоздавать                                     |
| ReplicaSet               | держит нужное количество pod                                              | изменяется только  число pod , применяется  как часть  deployment        |
| Deployment               | основной примитив для приложений. ( ReplicaSet + история обновлений)      | поддержка состояния , обновление параметров pod                          |
| DaemonSets               | развертывание системных демонов                                           | системные демоны, такие как журналирование и мониторинг                  |
| StatefulSet              | набор pods  c фиксированными именами                                      | поддержка состояния для Pod                                              |
| Service                  | балансировщик внутри кластера                                             | может быть внешним                                                       |
| Job                      | разовые задачи                                                            | pod + результат выполнения                                               |
| Cron Job                 | Job + расписание                                                          | выполнение задач по расписанию                                           |
| Persistent volume  (PV)  | постоянная файловая система для pod                                       | Size + Access Type + Storage Class                                       |
| Persistent Volume Claims | шаблон для создания Persistent volume                                     | проверяет  создан ли PV ,если нужно создает                              |
| Ingress                  | подключение к приложению из внешнего мира                                 | балансировка трафика, терминация SSL, виртуальный хостинг на основе имен |
| ConfigMaps               | хранение конфигураций приложения                                          | монтируется в Pod как ридонли файловая система во время запуска          |
| Secrets                  | хранение сертификатов и приватных данных                                  | монтируется в Pod как ридонли файловая система или переменных окружения  |
| Namespace                | Логическое разделение приложений                                          | в них создаются pod , deployment , service  , etc                        |


## Варианты установки Kubernetes


| Название                                                                                         | Сложность           | Стоимость                               | Применение                                  |
|--------------------------------------------------------------------------------------------------|---------------------|-----------------------------------------|---------------------------------------------|
| [Minikube](https://minikube.sigs.k8s.io/docs/)                                                   | Низкая              | Бесплатно                               | Обучение, тестирование на локальных машинах |
| [kind (Kubernetes in Docker)](https://kind.sigs.k8s.io/)                                         | Низкая              | Бесплатно                               | Обучение, разработка, тестирование          |
| [k3s](https://k3s.io/)                                                                           | Низкая              | Бесплатно                               | Легковесные кластеры, IoT, edge устройства  |
| [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)                | Средняя             | Бесплатно                               | Продакшен, ручная настройка                 |
| [MicroK8s](https://microk8s.io/)                                                                 | Низкая              | Бесплатно                               | Обучение, разработка, малые кластеры        |
| [Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine)                     | Низкая              | Платная, зависит от ресурсов            | Продакшен, облачные решения                 |
| [Amazon EKS](https://aws.amazon.com/eks/)                                                        | Низкая             | Платная, зависит от ресурсов            | Продакшен, облачные решения                 |
| [Azure Kubernetes Service (AKS)](https://azure.microsoft.com/en-us/services/kubernetes-service/) | Низкая              | Платная, зависит от ресурсов            | Продакшен, облачные решения                 |
| [OpenShift](https://www.openshift.com/)                                                          | Высокая             | Платная                                 | Продакшен, корпоративные решения            |
| [Rancher](https://rancher.com/)                                                                  | Средняя             | Платная (базовый функционал бесплатно)  | Продакшен, многокластерные решения          |
| Kubernetes на собственных серверах                                                               | Высокая             | Варьируется (зависит от инфраструктуры) | Продакшен, корпоративные решения            |


## Варианты Kubernetes для обучения


| Название                              | Запускается                            | Сложность           | Стоимость               | Область применения                                                             |
|---------------------------------------|----------------------------------------|---------------------|-------------------------|--------------------------------------------------------------------------------|
| [Minikube](https://minikube.sigs.k8s.io/docs/) | Локальные машины                       | Низкая              | Бесплатно               | CKAD                                                                           |
| [k3s](https://k3s.io/)                | Локальные машины, виртуальные машины   | Низкая              | Бесплатно               | CKAD                                                                           |
| [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/) | Виртуальные машины, локальные машины   | Средняя             | Бесплатно               | CKAD ,CKA,CKS(при запуске  паблик клауде )                                     |
| [Killercoda](https://killercoda.com/) | Как сервис (облако)                    | Низкая              | Бесплатно (для учебных сценариев) | Обучение в интерактивных сценариях для CKAD ,CKA,CKS . только готовые сценарии |
| [SRE Learning Platform](https://github.com/ViktorUJ/cks)   | AWS, ec2                               | Низкая             | Низкая              | CKAD ,CKA,CKS . лабораторные работы , моки экзаменов , свои сценарии.          |


### Запуск сценария на нашей платформе 

[видео](https://www.youtube.com/watch?v=Xh6sWzafBmw)


[инструкция](https://github.com/ViktorUJ/cks/blob/master/docs%2Frun_from_docker.MD)


[DKT64](https://www.youtube.com/watch?v=QuMUzflHsS4)

``` 

TASK=01  make run_ckad_mock_clean

```



## Подключение к кластеру 


###  [http запросы api серверу](https://kubernetes.io/docs/tasks/administer-cluster/access-cluster-api/)


### [kubernetes lens](https://k8slens.dev/)


###  [kubectl - основной инструмент  ](https://kubernetes.io/docs/reference/kubectl/overview/)


### конфигурация 
```
~/.kube/config

```
Можно изменить путь к конфигурации 

``` 
export KUBECONFIG=/etc/kubernetes/admin.conf

```

``` 
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://<cluster-api-server-url>:6443
    certificate-authority-data: <base64-encoded-ca-cert>
  name: kubernetes
users:
- name: kubernetes-admin
  user:
    client-certificate-data: <base64-encoded-client-cert>
    client-key-data: <base64-encoded-client-key>
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
    namespace: default
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes

```


``` 
# информация о кластере 
k version 


# список нод 

k get no

# информация по конкретной ноде

k describe no ip-10-2-14-14 

k get no ip-10-2-14-14 -o yaml
 

# список namespace

k get ns

```

``` 
# создание pod

k run nginx --image=nginx 


# удаление pod

k delete po nginx

```


```
# генерация манифеста pod  и  создание pod  из манифеста
 
k run nginx --image=nginx -o yaml --dry-run=client > pod.yaml


k apply -f pod.yaml


# удаление pod через манифест

k delete -f pod.yaml

```

``` 
# создание pod с переменными окружения 

k run nginx --image=nginx --env="key1=value1" --env="key2=value2"

```


### Изменения существующего pod 


``` 
# получеем манифест pod
k get po nginx -o yaml > pod.yaml

# удаляем существующий pod

# изменяем манифест
vim pod.yaml

# применяем манифест
k apply -f pod.yaml

```

### Создание pod с командой


```
k run nginx --image=nginx --command -- sleep 1000

```

###  Быстрое удаление pod (полезно на экзамене )

```
k delete po nginx --force --grace-period=0

```

### Просмотр namespace
``` 
k get ns

```
### Создание namespace

```
k create ns my-namespace

```

### Удаление namespace

```
k delete ns my-namespace
```

### Создание pod в namespace

```
k create ns my-namespace

k run nginx --image=nginx --namespace=my-namespace
``` 

### [Пример экзаменационного задания 1](https://github.com/ViktorUJ/cks/tree/master/tasks/ckad/mock/01) 


|        **1**        | **Deploy a pod named webhttpd**                                                |
| :-----------------: | :----------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                             |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                |
| Acceptance criteria | - Name: `webhttpd` <br/>- Image: `httpd:alpine`<br/>- Namespace: `apx-z993845` |

```
k get ns  apx-z993845
k create ns apx-z993845

k run webhttpd --image httpd:alpine -n apx-z993845
k get po -n  apx-z993845


check_result 

``` 


### [Пример экзаменационного задания 6](https://github.com/ViktorUJ/cks/tree/master/tasks/ckad/mock/01) 


|        **6**        | **Update the environment variable on the pod text-printer.**                                                 |
| :-----------------: | :----------------------------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                                           |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                              |
| Acceptance criteria | - Change the value of the environment variable to `GREEN`<br/>- Ensure that the logs of the pod was updated. |


```
k get pod text-printer -o yaml > 6.yaml

k delete pod text-printer

``` 
``` 
# vim 6.yaml
...
  env:
    - name: COLOR
      value: GREEN
...
```

```
k apply -f 6.yaml

check_result 
```

[Настройка автодобивики команд, аллиасов](https://kubernetes.io/ru/docs/reference/kubectl/cheatsheet/)

**На экзамене обязательно используем аллиасы  , автодобивку команд и генерацию манифестов**
