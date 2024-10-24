**Kubernetes**  - система оркестрации контейнерами . Сейчас самая популярная система оркестрации контейнерами.
альтернатива : , AWS -ECS ,  docker-Swarm, mesos , Nomad (hashicorp),


<p align="center">
    <a href="https://github.com/ViktorUJ/cks/blob/dkt_ckad_01/selfStudy/dkt/ckad/01/README.MD"><img src="https://kubernetes.io/images/docs/components-of-kubernetes.svg" width="1200" height="1200" alt="SRE Learning Platform"/></a>
</p>

[components](https://kubernetes.io/docs/concepts/overview/components/)

[CNI plugins](https://kubernetes.io/docs/concepts/cluster-administration/networking/#cni)

## Основные компоненты  Kubernetes

| **Компонент**      | **Что решает**                                                     | **Как найти**                                                                                      |
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

| **Имя**     | **Что нужно для запуска**                                       | **Вопросы, решаемые на этом уровне**                                     |
|-------------|-----------------------------------------------------------------|--------------------------------------------------------------------------|
| Container   | image + cmd                                                     | отдельно запустить нельзя, логирование, супервайзинг                     |
| Pod         | 1 или несколько контейнеров + общая сеть + общие папки + Labels | автоматизация инфраструктуры, супервайзинг, Service Discovery            |
| ReplicaSet  | несколько Pod + проверка, что запущено нужное количество        | супервайзинг, автоскейлинг                                               |
| Deployment  | ReplicaSet + история обновлений + процесс деплоя                | CI/CD                                                                    |
| Job         | Pod                                                             | успешное выполнение                                                      |
| Cron Job    | Job + расписание                                                | выполнение задач по расписанию                                           |
| Volume      | Size + Access Type + Storage Class                              | управление хранилищем                                                    |
| StatefulSet | набор pods  c фиксированными именами ,                          | поддержка состояния для Pod                                              |
| Ingress     | набор правил для подключения внешних пользователей              | балансировка трафика, терминация SSL, виртуальный хостинг на основе имен |
| DaemonSets  | развертывание системных демонов                                 | системные демоны, такие как журналирование и мониторинг                  |
| ConfigMaps  | маленькая файловая система для хранения переменных              | монтируется к Pod во время запуска                                       |
| Secrets     | хранение сертификатов и приватных данных                        | монтируется к Pod в виде временного диска                                |


## Варианты установки Kubernetes

| Название                                               | Сложность           | Стоимость               | Применение                        |
|--------------------------------------------------------|---------------------|-------------------------|-----------------------------------|
| [Minikube](https://minikube.sigs.k8s.io/docs/)         | Низкая              | Бесплатно               | Обучение, тестирование на локальных машинах |
| [kind (Kubernetes in Docker)](https://kind.sigs.k8s.io/) | Низкая              | Бесплатно               | Обучение, разработка, тестирование |
| [k3s](https://k3s.io/)                                 | Низкая              | Бесплатно               | Легковесные кластеры, IoT, edge устройства |
| [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/) | Средняя             | Бесплатно               | Продакшен, ручная настройка      |
| [MicroK8s](https://microk8s.io/)                       | Низкая              | Бесплатно               | Обучение, разработка, малые кластеры |
| [Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine) | Низкая              | Платная, зависит от ресурсов | Продакшен, облачные решения       |
| [Amazon EKS](https://aws.amazon.com/eks/)              | Средняя             | Платная, зависит от ресурсов | Продакшен, облачные решения       |
| [Azure Kubernetes Service (AKS)](https://azure.microsoft.com/en-us/services/kubernetes-service/) | Низкая              | Платная, зависит от ресурсов | Продакшен, облачные решения       |
| [OpenShift](https://www.openshift.com/)                | Высокая             | Платная                 | Продакшен, корпоративные решения |
| [Rancher](https://rancher.com/)                        | Средняя             | Платная (базовый функционал бесплатно) | Продакшен, многокластерные решения |
| Kubernetes на собственных серверах                     | Высокая             | Варьируется (зависит от инфраструктуры) | Продакшен, корпоративные решения |


## Свой кластер для обучения Kubernetes

## Варианты установки Kubernetes для обучения

| Название                              | Запускается                          | Сложность           | Стоимость               | Область применения                                                             |
|---------------------------------------|--------------------------------------|---------------------|-------------------------|--------------------------------------------------------------------------------|
| [Minikube](https://minikube.sigs.k8s.io/docs/) | Локальные машины                     | Низкая              | Бесплатно               | CKAD                                                                           |
| [k3s](https://k3s.io/)                | Локальные машины, виртуальные машины | Низкая              | Бесплатно               | CKAD                                                                           |
| [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/) | Виртуальные машины, локальные машины | Средняя             | Бесплатно               | CKAD ,CKA,CKS(при запуске  паблик клауде )                                     |
| [Killercoda](https://killercoda.com/) | Как сервис (облако)                  | Низкая              | Бесплатно (для учебных сценариев) | Обучение в интерактивных сценариях для CKAD ,CKA,CKS . только готовые сценапии |
| [SRE Learning Platform](https://github.com/ViktorUJ/cks)   | AWS, ec2                             | Низкая             | Низкая              | CKAD ,CKA,CKS . лабораторные работы , моки экзаменов , свои сценарии.          |


## Подключение к кластеру 

###  (http запросы api серверу)[https://kubernetes.io/docs/tasks/administer-cluster/access-cluster-api/]

###  (kubectl)[https://kubernetes.io/docs/reference/kubectl/overview/]

