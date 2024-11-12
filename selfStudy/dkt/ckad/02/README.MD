# 2 CKAD 

### [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)


### [реквесты, лимиты](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)


### [qos](https://kubernetes.io/docs/concepts/configuration/pod-priority-preemption/)


### [PriorityClass](https://kubernetes.io/docs/concepts/configuration/pod-priority-preemption/)


### [Twelve-Factor App](https://12factor.net/ru/)

### [Ephemeral containers](https://kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/)


### [logs](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/)


# Практика

### Типы проб

| **Тип пробы**          | **Когда применяется**                               | **Что происходит, если проба не проходит**                                                                                                                                  | **Взаимодействие с другими пробами**                                                                                                                                                    |
|------------------------|----------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Liveness Probe**     | Регулярно во время жизненного цикла контейнера     | Контейнер **перезапускается**, если не проходит `liveness`-проверку. Это предотвращает зависания контейнера и поддерживает его в рабочем состоянии.                         | Начинает действовать только после успешного завершения `startup`-проверки, если она настроена.                                                                                           |
| **Readiness Probe**    | После запуска контейнера и в течение его работы    | Контейнер **исключается из балансировки**, пока не пройдет `readiness`-проверку. Kubernetes не будет отправлять трафик на контейнер, пока он не готов обрабатывать запросы. | Начинает действовать только после успешного завершения `startup`-проверки, если она настроена.                                                                                           |
| **Startup Probe**      | Только во время начальной загрузки контейнера      | Если контейнер не проходит `startup`-проверку в указанный период, Kubernetes считает, что он не может инициализироваться, и перезапускает контейнер.                        | Блокирует выполнение `liveness` и `readiness`-проверок до успешного завершения `startup`-проверки. Помогает избежать преждевременных проверок при долгой инициализации контейнера. |


### Типы проверок в пробах

| **Тип проверки**       | **Описание**                                                                                                                        |
|------------------------|-------------------------------------------------------------------------------------------------------------------------------------|
| **httpGet**            | Отправляет HTTP-запрос на указанный порт и путь. Ожидает успешный HTTP-код (например, 200) для успешного прохождения проверки.     |
| **tcpSocket**          | Пытается установить TCP-соединение на указанный порт. Если соединение установлено, проверка считается успешной.                    |
| **exec**               | Выполняет команду внутри контейнера. Проверка считается успешной, если команда завершается с кодом 0.                              |





###  За пробы отвечает kubelet (проверяет пробы без участия API сервера)





### Настройка эндпоинтов для Kubernetes проб

Для подготовки эндпоинтов, которые будут использованы в Kubernetes пробах, можно реализовать **Readiness** и **Liveness** эндпоинты с разным функционалом:

1. **Эндпоинт для Readiness Probe** (`/ready`):
   - Проверяет готовность приложения к обработке запросов, включая установленные соединения с базами данных, кэшами и внешними сервисами.
   - Возвращает HTTP статус **200 OK** при полной готовности и **503 Service Unavailable** в случае, если соединения с базами данных или другими внешними сервисами не установлены.

2. **Эндпоинт для Liveness Probe** (`/health`):
   - Простой эндпоинт, проверяющий, что приложение запущено и не зависло.
   - Возвращает HTTP статус **200 OK** при успешной работе приложения.



Создадим под в NS `default` c именем `pod1` и образом `viktoruj/ping_pong:alpine` и переменной окружения  `SRV_PORT`=`80`




[viktoruj/ping_pong:alpine](https://github.com/ViktorUJ/cks/tree/master/docker/ping_pong) - это образ с http сервером, который возвращает в ответе всю метаинформацию входящего запроса, включая IP-адрес отправителя, все параметры запроса и заголовки. Конфигурация сервера может быть изменена с помощью переменных окружения:



```
k run pod2 --image  viktoruj/ping_pong:alpine --env SRV_PORT=80 -o yaml --dry-run=client > 1.yaml

```

``` 
# vim 1.yaml

apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod2
  name: pod2
spec:
  containers:
  - env:
    - name: SRV_PORT
      value: "80"
    image: viktoruj/ping_pong:alpine
    name: pod2
    livenessProbe:                        # add it                тип пробы
      httpGet:                            # add it                тип проверки
        path: /healthz                    # add it 
        port: 80                          # add it 
        httpHeaders:                      # add it                устанавливает заголовки HTTP запроса , если они нужны
        - name: Custom-Header             # add it 
          value: Awesome                  # add it 
      initialDelaySeconds: 3              # add it                время ожидания перед первой проверкой
      periodSeconds: 3                    # add it                периодичность проверок
      failureThreshold: 5                 # add it                количество неудачных проверок, после которых контейнер будет перезапущен

    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}


``` 
``` 
k apply -f 1.yaml

```
Посмотрим лог пода, чтобы убедиться, как работает проба
```
k logs  pod2 
```
``` 
Server Name: ping_pong_server                   
URL: http://10.0.130.194:80/healthz
Client IP: 10.2.13.62                           #   ip address ноды на которой запущен под  , т.к. kubelet проверяет пробы только своих подов
Method: GET
Protocol: HTTP/1.1
Headers:
User-Agent: kube-probe/1.30
Accept: */*
Custom-Header: Awesome                          #   заголовок который мы установили в пробе
Connection: close
```


Сэмулируем ситуацию, когда **livenessProbe** проба не проходит

``` 
k delete -f 1.yaml
vim 1.yaml
```


``` 
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod2
  name: pod2
spec:
  containers:
  - env:
    - name: SRV_PORT
      value: "9111"                       # add it   изменяем порт http сервера
    image: viktoruj/ping_pong:alpine
    name: pod2
    livenessProbe:                        # add it                тип пробы
      httpGet:                            # add it                тип проверки
        path: /healthz                    # add it 
        port: 80                          # add it 
        httpHeaders:                      # add it                устанавливает заголовки HTTP запроса , если они нужны
        - name: Custom-Header             # add it 
          value: Awesome                  # add it 
      initialDelaySeconds: 3              # add it                время ожидания перед первой проверкой
      periodSeconds: 3                    # add it                периодичность проверок
      failureThreshold: 5                 # add it                количество неудачных проверок, после которых контейнер будет перезапущен

    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

```


``` 
k apply -f 1.yaml

```

``` 
k get po pod2
```
``` 
NAME   READY   STATUS    RESTARTS      AGE
pod2   1/1     Running   1 (15s ago)   33s      # произошло т.к. проба не прошла 5 раз  через 3 секунды  и кубелет перезапустил под . 
                                                # но так как мы не установливали Readiness   под сразу попал в балансировку 
```
Изменим порт http сервера на **80** и добавим **Readiness** пробу на порт **9111**,  а **Liveness** пробу на порт 80. 


Сэмулируем ситуацию, когда **Readiness** проба не проходит . 
В таком случае под не будет принудительно рестартовать и просто не будет включен в балансировку, пока не пройдет **Readiness** проба. 

``` 
k delete -f 1.yaml
vim 1.yaml
```


``` 
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod2
  name: pod2
spec:
  containers:
  - env:
    - name: SRV_PORT
      value: "80"                       # add it   изменяем порт http сервера
    image: viktoruj/ping_pong:alpine
    name: pod2
    livenessProbe:                        # add it                тип пробы
      httpGet:                            # add it                тип проверки
        path: /healthz                    # add it 
        port: 80                          # add it 
      initialDelaySeconds: 3              # add it                время ожидания перед первой проверкой
      periodSeconds: 3                    # add it                периодичность проверок
      failureThreshold: 3                 # add it                количество неудачных проверок, после которых контейнер будет перезапущен
    readinessProbe:                       # add it                тип пробы
      httpGet:                            # add it                тип проверки
        path: /readiness                  # add it 
        port: 9111                        # add it 
      initialDelaySeconds: 9              # add it                время ожидания перед первой проверкой
      periodSeconds: 5                    # add it                периодичность проверок
      failureThreshold: 1                 # add it                количество неудачных проверок, после которых контейнер будет перезапущен      
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

```


``` 
k apply -f 1.yaml

```




``` 
k get po pod2
```

``` 

NAME   READY   STATUS    RESTARTS   AGE
pod2   0/1     Running   0          22s   # под не включен в балансировку, пока не пройдет Readiness проба , но рестартовать не будет.

```



### Типичные ошибки при настройке проб


| **Ошибка**                                           | **К чему приводит**                                                                                                                                                                                                             |
|------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Нет **Liveness Probe**                               | Kubernetes не перезапустит контейнер при его зависании или остановке, что может привести к длительной недоступности приложения.                                                                                                 |
| Нет **Readiness Probe**                              | Kubernetes начнет отправлять трафик на контейнер до того, как приложение будет полностью готово обрабатывать запросы. Или  будет отпралять запросы когда приложение не может их обработать(пропала связи сбазой данных и т.д.). |
| **Liveness** и **Readiness** пробы ведут на один и тот же эндпоинт | Временные проблемы с внешними зависимостями (например, базой данных) могут вызвать перезапуск контейнера, хотя он мог бы восстановиться сам.                                                                                    |
| Нет **Startup Probe** для медленно стартующих приложений | **Liveness** и **Readiness** пробы могут начать проверки до завершения полной загрузки приложения, что приведет к преждевременным перезапускам.                                                                                 |



``` 
k delete -f 1.yaml
```

### [Пример экзаменационного задания 12](https://github.com/ViktorUJ/cks/tree/master/tasks/ckad/mock/01) 

---
|       **12**        | **Create a new pod called `nginx1233` in the `web-ns` namespace with the image `nginx`. Add a livenessProbe to the container to restart it if the command `ls /var/www/html/` probe fails. This check should start after a delay of 10 seconds and run every 60 seconds.** |
| :-----------------: |:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 2%                                                                                                                                                                                                                                                                         |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                            |
| Acceptance criteria | - You may delete and recreate the object. Ignore the warnings from the probe.<br/>- Pod: `nginx1233`, namespace: `web-ns`, image `nginx`,  livenessProbe?                                                                                                                  |
---

``` 
k create ns web-ns

k run nginx1233 --namespace web-ns --image nginx --dry-run=client -o yaml > 12.yaml
```


```
# vim 12.yaml

apiVersion: v1
kind: Pod
metadata:
  labels:
    run: nginx1233
  name: nginx1233
  namespace: web-ns
spec:
  containers:
  - image: nginx
    name: nginx1233
    livenessProbe:
      exec:
        command:
        - ls
        - /var/www/html/
      initialDelaySeconds: 10
      periodSeconds: 60
```
```
k apply -f 12.yaml
```
```
check_result

```

```
-----
 ✓ 12.1 Create a new pod nginx1233 in the web-ns namespace.command
 ✓ 12.2 Create a new pod nginx1233 in the web-ns namespace.delay and period
 
-----


```

###  реквесты лимиты

Создадим под в NS `default` c именем `pod2` и образом `viktoruj/ping_pong:alpine` и переменными окружения: 

`ENABLE_LOAD_MEMORY`=`true` 
`ENABLE_LOAD_CPU`=`true` 
`MEMORY_USAGE_PROFILE`=`5=10 7=60`
`CPU_USAGE_PROFILE`=`5=10 7=60`


``` 
 k run pod2 --image viktoruj/ping_pong:alpine --env ENABLE_LOAD_MEMORY=true --env ENABLE_LOAD_CPU=true --env MEMORY_USAGE_PROFILE="5=10 7=60" --env CPU_USAGE_PROFILE="5=10 7=60" -o yaml --dry-run=client > 2.yaml
```

``` 
k apply -f 2.yaml

k get  po pod2 
```
``` 
NAME   READY   STATUS    RESTARTS   AGE
pod2   1/1     Running   0          22s

```

Для работы  **kubectl top**, нужен Metrics Server . Проверим его наличие
``` 
kubectl get deployment metrics-server -n kube-system

NAME             READY   UP-TO-DATE   AVAILABLE   AGE
metrics-server   1/1     1            1           115m

```


Посмотрим потребление нашего пода


``` 
k top po pod2 
```
``` 
NAME   CPU(cores)   MEMORY(bytes)
pod2   997m         9Mi

```

Посмотрим qos нашего пода

``` 
k describe po pod2
```

```
------

QoS Class:                   BestEffort

------


```

BestEffort - это самый низкий уровень QoS, который назначается по умолчанию, если не указаны ресурсы. Поды с этим классом QoS не имеют гарантированного доступа к ресурсам и могут быть убиты, если на узле не хватает ресурсов.

Добавим реквесты и лимиты равными, + 30% к нашему потреблению.


``` 
k delete -f 2.yaml

vim 2.yaml
```

```
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod2
  name: pod2
spec:
  containers:
  - env:
    - name: ENABLE_LOAD_MEMORY
      value: "true"
    - name: ENABLE_LOAD_CPU
      value: "true"
    - name: MEMORY_USAGE_PROFILE
      value: 5=10 7=60
    - name: CPU_USAGE_PROFILE
      value: 5=10 7=60
    image: viktoruj/ping_pong:alpine
    name: pod2
    resources:
      requests:
        memory: "10Mi"
        cpu: "1300m"
      limits:
        memory: "10Mi"
        cpu: "1300m"
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}



```

```
k apply -f 2.yaml

k describe   po pod2 
```
```

QoS Class:                   Guaranteed


```

Создадим ситуацию, когда наш под превышает лимиты по памяти.



``` 
k delete -f 2.yaml

vim 2.yaml
```

```
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod2
  name: pod2
spec:
  containers:
  - env:
    - name: ENABLE_LOAD_MEMORY
      value: "true"
    - name: ENABLE_LOAD_CPU
      value: "true"
    - name: MEMORY_USAGE_PROFILE
      value: 5=10 70=60                     # update  it
    - name: CPU_USAGE_PROFILE
      value: 5=10 7=60
    image: viktoruj/ping_pong:alpine
    name: pod2
    resources:
      requests:
        memory: "10Mi"
        cpu: "1000m"                         # update  it
      limits:
        memory: "10Mi"
        cpu: "1300m"
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}



```

```
k apply -f 2.yaml

k describe   po pod2 
```

``` 
QoS Class:                   Burstable     # так как лимиты не равны реквестам

```

``` 
ubuntu@worker:~> k get po pod2
NAME   READY   STATUS    RESTARTS      AGE
pod2   1/1     Running   2 (16s ago)   77s


```
``` 
k describe   po pod2
```
``` 
------
    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137
      Started:      Mon, 11 Nov 2024 06:20:04 +0000
      Finished:     Mon, 11 Nov 2024 06:20:34 +0000
    Ready:          False
------

```
Это произошло, так как наш под превысил лимиты по памяти и был убит kubelet

Похожую ситуацию можно наблюдать, когда у нас превышается объем доступной памяти , тогда kubelet убивает поды в зависимости от PriorityClass и qos . 



Когда привышаются лимиты по CPU, то kubelet не убивает поды, а просто включает throttling, что приводит к замедлению работы пода.

У нас есть [лабораторная работа](https://github.com/ViktorUJ/cks/blob/master/docs/..%2Ftasks%2Fcka%2Flabs%2F07%2FREADME.MD), где мы можем попробовать это на практике. [solution](https://github.com/ViktorUJ/cks/blob/master/tasks/cka/labs/07/worker/files/solutions/1.MD)



# PriorityClass

Получим существующие PriorityClass

```
k get priorityclasses

```

``` 
NAME                      VALUE        GLOBAL-DEFAULT   AGE
system-cluster-critical   2000000000   false            18m
system-node-critical      2000001000   false            18m

```

Создадим PriorityClass с именем `high-priority` и значением `1000000000`

```
k create priorityclass high-priority --value 1000000000 

k get priorityclasses

 
```
Создадим манифест пода, и добавим в него PriorityClass `high-priority`

``` 
k run pod3 --image viktoruj/ping_pong:alpine   -o yaml --dry-run=client > 3.yaml

vim 3.yaml
``` 

```
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod3
  name: pod3
spec:
  containers:
  - image: viktoruj/ping_pong:alpine
    name: pod3
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
  priorityClassName: high-priority                  # add it
status: {}

 
```
``` 
k apply -f 3.yaml
k describe po pod3
```
``` 
Name:                 pod3
Namespace:            default
Priority:             1000000000
Priority Class Name:  high-priority

-------

```

Более детально можно потренировать в [лабораторной работе](https://github.com/ViktorUJ/cks/blob/master/docs/..%2Ftasks%2Fcka%2Flabs%2F05%2FREADME.MD) . Решение можно посмотреть  [тут](https://github.com/ViktorUJ/cks/blob/master/tasks/cka/labs/05/worker/files/solutions/1.MD)


# Ephemeral containers

- нужны для отладки и диагностики , если имаджи собраны правильно  , то они не будут содержать ничего лишнего , кроме исполняемых файлов и библиотек. В идеале будет использоваться **Scratch** образ , который весит 0 байт.

| Возможности Ephemeral containers | Описание |
|-----------------------------------|----------|
| Работает без перезапуска пода     | Временный контейнер можно запустить без необходимости перезагрузки всего пода. |
| Может подключаться к любому контейнеру в поде | Временный контейнер позволяет подключиться к любому контейнеру внутри пода. |
| Может подключаться к подам с CrashLoop | Временный контейнер может подключаться даже к подам, находящимся в состоянии CrashLoop. |
| Имеет возможность отслеживать процессы в любом контейнере | Можно отслеживать процессы внутри любого контейнера в поде с помощью временного контейнера. |
| Имеет доступ к файловой системе любого контейнера | Временный контейнер может работать с файловой системой любого контейнера в поде. |
| Имеет ту же сеть, что и любой контейнер в поде | Временный контейнер имеет общий сетевой интерфейс с остальными контейнерами в поде. |
| Можно использовать любой образ Docker для временного контейнера | Вы можете запускать временный контейнер с использованием любого Docker-образа. |


``` 
kubectl   debug  -it   {pod_name} --image {ephemeral_container_image}    -n {k8s_name_space} --target {container_name_in_pod}
```


Создадим под в NS `default` c именем `pod4` и образом `viktoruj/ping_pong` . Данный образ не имеет утилиты `bash , sh , etc ` , поэтому мы не сможем подключиться к нему через `kubectl exec`  ли выполнить любые команды внутри пода.

``` 

k run pod4 --image viktoruj/ping_pong

k get po pod4
```

Подключимся к поду через `kubectl exec` (должны получить ошибку)

```
k exec -ti  pod4 -- sh
error: Internal error occurred: Internal error occurred: error executing command in container: failed to exec in container: failed to start exec "f1ba06eb91523589c2bae6c098e3140024e88e89d54debee4004e0fc0fe37686": OCI runtime exec failed: exec failed: unable to start container process: exec: "sh": executable file not found in $PATH: unknown

```

Подключимся к поду через `kubectl debug` 

```
kubectl   debug  -it   pod4  --image ubuntu --target pod4 
 
```
Получим pid запущенных процессов внутри контейнера
``` 
ps -aux

USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.1 1233220 5284 ?        Ssl  19:15   0:00 /app         # PID 1 это наш http сервер
root          20  0.0  0.0   4296  3128 pts/0    Ss   19:16   0:00 /bin/bash
root        2950  0.0  0.0   7628  3604 pts/0    R+   19:22   0:00 ps -aux


```
Получим список файлов нашего основного контейнера
``` 
ls /proc/1/root/
app  dev  etc  proc  sys  var

```
###  logs , мультиконтейнеры , label

Создадим под в NS `default` c именем `pod5` и двумя контейнерами : 
- `app` с образом `viktoruj/ping_pong`  и envs  `SRV_PORT=8080` `SERVER_NAME=app` 
- `side-car` c образом `viktoruj/ping_pong` и envs  `SRV_PORT=8081` `SERVER_NAME=side-car`  

```
k run pod5 --image viktoruj/ping_pong --env SRV_PORT=8080 --env SERVER_NAME=app --dry-run=client -o yaml > 5.yaml

``` 


```
# vim 5.yaml

apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod5
  name: pod5
spec:
  containers:
  - env:
    - name: SRV_PORT
      value: "8080"
    - name: SERVER_NAME
      value: app
    image: viktoruj/ping_pong
    name: app
    resources: {}

  - env:
    - name: SRV_PORT
      value: "8081"
    - name: SERVER_NAME
      value: side-car
    image: viktoruj/ping_pong
    name: side-car
    resources: {}

  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}


```

``` 
k apply -f 5.yaml
k get po pod5

```
``` 
NAME   READY   STATUS    RESTARTS   AGE
pod5   2/2     Running   0          4m16s

```

Получим логи контейнера `app` в поде `pod5`

```
k logs pod5 -c app
```
``` 
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOSTNAME=pod5
SERVER_NAME=app                              
SRV_PORT=8080
KUBERNETES_PORT_443_TCP_PORT=443
KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
KUBERNETES_SERVICE_HOST=10.96.0.1
KUBERNETES_SERVICE_PORT=443
KUBERNETES_SERVICE_PORT_HTTPS=443
KUBERNETES_PORT=tcp://10.96.0.1:443
KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
KUBERNETES_PORT_443_TCP_PROTO=tcp
HOME=/
enableLoadCpu: false, cpuMaxProc: 1

```

Получим логи контейнера `side-car` в поде `pod5`

```
k logs pod5 -c side-car
```

``` 
k logs pod5 -c side-car -f   # получать логи в реальном времени

```

Добавим Label к нашему поду  `app=http-server`

```
k delete -f 5.yaml
vim 5.yaml
```
``` 
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod5
    app: http-server
  name: pod5
spec:
  containers:
  - env:
    - name: SRV_PORT
      value: "8080"
    - name: SERVER_NAME
      value: app
    image: viktoruj/ping_pong
    name: app
    resources: {}

  - env:
    - name: SRV_PORT
      value: "8081"
    - name: SERVER_NAME
      value: side-car
    image: viktoruj/ping_pong
    name: side-car
    resources: {}

  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

```
Создадим под pod6 такой же, как pod5

```
cp 5.yaml 6.yaml
vim 6.yaml
```

``` 
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod6
    app: http-server
  name: pod6
spec:
  containers:
  - env:
    - name: SRV_PORT
      value: "8080"
    - name: SERVER_NAME
      value: app
    image: viktoruj/ping_pong
    name: app
    resources: {}

  - env:
    - name: SRV_PORT
      value: "8081"
    - name: SERVER_NAME
      value: side-car
    image: viktoruj/ping_pong
    name: side-car
    resources: {}

  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

```

``` 
k apply -f 6.yaml


```
Получим все поды с label app=http-server
``` 
# k get po -l app=http-server 

NAME   READY   STATUS    RESTARTS   AGE
pod5   2/2     Running   0          2m40s
pod6   2/2     Running   0          7s

```

Получим логи всех подов с **label** `app=http-server` и контейнера **app**

```
k logs  -c app -l  app=http-server
```

Покажет логи с префиксом источника 
``` 
k logs  -c app --prefix  -l  app=http-server
```

```  
 k logs  -c app --prefix  -l  app=http-server
[pod/pod5/app] KUBERNETES_SERVICE_HOST=10.96.0.1
[pod/pod5/app] KUBERNETES_SERVICE_PORT=443
[pod/pod5/app] KUBERNETES_SERVICE_PORT_HTTPS=443
[pod/pod5/app] KUBERNETES_PORT=tcp://10.96.0.1:443
[pod/pod5/app] KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
[pod/pod5/app] KUBERNETES_PORT_443_TCP_PROTO=tcp
[pod/pod5/app] KUBERNETES_PORT_443_TCP_PORT=443
[pod/pod5/app] KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
[pod/pod5/app] HOME=/
[pod/pod5/app] enableLoadCpu: false, cpuMaxProc: 1
[pod/pod6/app] KUBERNETES_SERVICE_HOST=10.96.0.1
[pod/pod6/app] KUBERNETES_SERVICE_PORT=443
[pod/pod6/app] KUBERNETES_SERVICE_PORT_HTTPS=443
[pod/pod6/app] KUBERNETES_PORT=tcp://10.96.0.1:443
[pod/pod6/app] KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
[pod/pod6/app] KUBERNETES_PORT_443_TCP_PROTO=tcp
[pod/pod6/app] KUBERNETES_PORT_443_TCP_PORT=443
[pod/pod6/app] KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
[pod/pod6/app] HOME=/
[pod/pod6/app] enableLoadCpu: false, cpuMaxProc: 1

```
Покажет логи от всех контейнеров в подах с **label** `app=http-server` и перфиксом источника

```
k logs   --prefix  --all-containers   -l  app=http-server 
``` 
``` 
[pod/pod5/app] KUBERNETES_SERVICE_HOST=10.96.0.1
[pod/pod5/app] KUBERNETES_SERVICE_PORT=443
[pod/pod5/app] KUBERNETES_SERVICE_PORT_HTTPS=443
[pod/pod5/app] KUBERNETES_PORT=tcp://10.96.0.1:443
[pod/pod5/app] KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
[pod/pod5/app] KUBERNETES_PORT_443_TCP_PROTO=tcp
[pod/pod5/app] KUBERNETES_PORT_443_TCP_PORT=443
[pod/pod5/app] KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
[pod/pod5/app] HOME=/
[pod/pod5/app] enableLoadCpu: false, cpuMaxProc: 1
[pod/pod5/side-car] KUBERNETES_SERVICE_PORT_HTTPS=443
[pod/pod5/side-car] KUBERNETES_PORT=tcp://10.96.0.1:443
[pod/pod5/side-car] KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
[pod/pod5/side-car] KUBERNETES_PORT_443_TCP_PROTO=tcp
[pod/pod5/side-car] KUBERNETES_PORT_443_TCP_PORT=443
[pod/pod5/side-car] KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
[pod/pod5/side-car] KUBERNETES_SERVICE_HOST=10.96.0.1
[pod/pod5/side-car] KUBERNETES_SERVICE_PORT=443
[pod/pod5/side-car] HOME=/
[pod/pod5/side-car] enableLoadCpu: false, cpuMaxProc: 1
[pod/pod6/app] KUBERNETES_SERVICE_HOST=10.96.0.1
[pod/pod6/app] KUBERNETES_SERVICE_PORT=443
[pod/pod6/app] KUBERNETES_SERVICE_PORT_HTTPS=443
[pod/pod6/app] KUBERNETES_PORT=tcp://10.96.0.1:443
[pod/pod6/app] KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
[pod/pod6/app] KUBERNETES_PORT_443_TCP_PROTO=tcp
[pod/pod6/app] KUBERNETES_PORT_443_TCP_PORT=443
[pod/pod6/app] KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
[pod/pod6/app] HOME=/
[pod/pod6/app] enableLoadCpu: false, cpuMaxProc: 1
[pod/pod6/side-car] KUBERNETES_PORT_443_TCP_PORT=443
[pod/pod6/side-car] KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
[pod/pod6/side-car] KUBERNETES_SERVICE_HOST=10.96.0.1
[pod/pod6/side-car] KUBERNETES_SERVICE_PORT=443
[pod/pod6/side-car] KUBERNETES_SERVICE_PORT_HTTPS=443
[pod/pod6/side-car] KUBERNETES_PORT=tcp://10.96.0.1:443
[pod/pod6/side-car] KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
[pod/pod6/side-car] KUBERNETES_PORT_443_TCP_PROTO=tcp
[pod/pod6/side-car] HOME=/
[pod/pod6/side-car] enableLoadCpu: false, cpuMaxProc: 1

```

Если контейнер рестартовал, то можно посмотреть логи с предыдущего контейнера с флагом `--previous`

```
