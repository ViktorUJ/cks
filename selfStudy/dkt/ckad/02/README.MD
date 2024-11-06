# 2 CKAD 

### [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)


### [реквесты, лимиты](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)


### [qos](https://kubernetes.io/docs/concepts/configuration/pod-priority-preemption/)


Создадим новый под в NS `default` c именем `pod2` и образом `viktoruj/ping_pong:alpine` и переменной окружения  `SRV_PORT`=`80`

[viktoruj/ping_pong:alpine](https://github.com/ViktorUJ/cks/tree/master/docker/ping_pong) - это образ с http сервером, который возвращает в ответе всю метаинформацию входящего запроса, включая IP-адрес отправителя, все параметры запроса и заголовки. Конфигурация сервера может быть изменена с помощью переменных окружения:
```
k run pod2 --image  viktoruj/ping_pong:alpine --env SRV_PORT=80

```
``` 
k get po pod2
```
``` 
NAME   READY   STATUS    RESTARTS   AGE
pod2   1/1     Running   0          53s

```

Расширенная информация о поде 
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


