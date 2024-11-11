# 2 CKAD 

### [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)


### [реквесты, лимиты](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)


### [qos](https://kubernetes.io/docs/concepts/configuration/pod-priority-preemption/)


### [PriorityClass](https://kubernetes.io/docs/concepts/configuration/pod-priority-preemption/)


### [Ephemeral containers](https://kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/)


### [Twelve-Factor App](https://12factor.net/ru/)


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

###  реквесты лимиты

Создадим под в NS `default` c именем `pod2` и образом `viktoruj/ping_pong:alpine` и переменными окружения: 

`ENABLE_LOAD_MEMORY`=`true` 
`ENABLE_LOAD_CPU`=`true` 
`MEMORY_USAGE_PROFILE`=`5=10 7=60`
`CPU_USAGE_PROFILE`=`5=10 7=60`












```
k get po pod2 -o wide
```

```` 
NAME   READY   STATUS    RESTARTS   AGE     IP             NODE             NOMINATED NODE   READINESS GATES
pod2   1/1     Running   0          2m47s   10.0.111.195   ip-10-2-15-227   <none>           <none>
````

``` 
k describe po pod2

```

``` 
 k describe po pod2
Name:             pod2
Namespace:        default
Priority:         0
Service Account:  default
Node:             ip-10-2-15-227/10.2.15.227
Start Time:       Mon, 04 Nov 2024 05:35:23 +0000
Labels:           run=pod2
Annotations:      cni.projectcalico.org/containerID: 938bac44763cbf5ad711ab1cdc6d9544a5abc907811387          853bd0ac0418a94608
                  cni.projectcalico.org/podIP: 10.0.111.195/32
                  cni.projectcalico.org/podIPs: 10.0.111.195/32
Status:           Running
IP:               10.0.111.195
IPs:
  IP:  10.0.111.195
Containers:
  pod2:
    Container ID:   containerd://57fccf9cc76814c4fd3b38318547c063a09c8cbf742710e7750d4905614522c9
    Image:          viktoruj/ping_pong:alpine
    Image ID:       docker.io/viktoruj/ping_pong@sha256:f9281278ca76bd1c61c50b6a0ac1ffbd290a3bdd49f          7caae19cb5dda1335d345
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Mon, 04 Nov 2024 05:35:30 +0000
    Ready:          True
    Restart Count:  0
    Environment:
      SRV_PORT:  80
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-rv9rp (ro)
Conditions:
  Type                        Status
  PodReadyToStartContainers   True
  Initialized                 True
  Ready                       True
  ContainersReady             True
  PodScheduled                True
Volumes:
  kube-api-access-rv9rp:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  14m   default-scheduler  Successfully assigned default/pod2 to ip-10-2-15-227
  Normal  Pulling    14m   kubelet            Pulling image "viktoruj/ping_pong:alpine"
  Normal  Pulled     14m   kubelet            Successfully pulled image "viktoruj/ping_pong:alpine"           in 6.592s (6.592s including waiting). Image size: 66793744 bytes.
  Normal  Created    14m   kubelet            Created container pod2
  Normal  Started    14m   kubelet            Started container pod2

```
Давайте посмотрим на Events пода.


Давайте пересоздаим под с ошибочной командой и посмотри что мы увидим в Events
```
k delete po pod2 

k run pod2 --image  viktoruj/ping_pong:alpine --env SRV_PORT=80 --command leknrf

k get po pod2
```
``` 
NAME   READY   STATUS             RESTARTS      AGE
pod2   0/1     CrashLoopBackOff   4 (58s ago)   2m32s

```

посмотрим describe пода
``` 
k describe po pod2
```

``` 
```


