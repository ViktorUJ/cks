<p align="center">
    <a href="https://github.com/ViktorUJ/cks/blob/dkt_ckad_01/selfStudy/dkt/ckad/01/README.MD"><img src="https://kubernetes.io/images/docs/components-of-kubernetes.svg" width="1900" height="1060" alt="SRE Learning Platform"/></a>
</p>

[components](https://kubernetes.io/docs/concepts/overview/components/)

[CNI plugins](https://kubernetes.io/docs/concepts/cluster-administration/networking/#cni)


## Примитивы Kubernetes

| Имя         | Что нужно для запуска                                      | Вопросы, решаемые на этом уровне                                               |
|-------------|------------------------------------------------------------|--------------------------------------------------------------------------------|
| Container   | image + cmd                                                 | отдельно запустить нельзя, логирование, супервайзинг                           |
| Pod         | 1 или несколько контейнеров + общая сеть + общие папки + Labels | автоматизация инфраструктуры, супервайзинг, Service Discovery                  |
| ReplicaSet  | несколько Pod + проверка, что запущено нужное количество    | супервайзинг, автоскейлинг                                                     |
| Deployment  | ReplicaSet + история обновлений + процесс деплоя            | CI/CD                                                                         |
| Job         | Pod                                                         | успешное выполнение                                                           |
| Cron Job    | Job + расписание                                            | выполнение задач по расписанию                                                |
| Volume      | Size + Access Type + Storage Class                          | управление хранилищем                                                          |
| StatefulSet |                                                            | поддержка состояния для Pod                                                   |
| Ingress     | набор правил для подключения внешних пользователей          | балансировка трафика, терминация SSL, виртуальный хостинг на основе имен       |
| DaemonSets  | развертывание системных демонов                             | системные демоны, такие как журналирование и мониторинг                        |
| ConfigMaps  | маленькая файловая система для хранения переменных          | монтируется к Pod во время запуска                                             |
| Secrets     | хранение сертификатов и приватных данных                    | монтируется к Pod в виде временного диска                                      |
