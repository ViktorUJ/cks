[Eng version](RUNBOOK.md) · [Versión en español](RUNBOOK_ES.md) · [Version française](RUNBOOK_FR.md) · [Deutsche Version](RUNBOOK_DE.md) · [ქართული ვერსია](RUNBOOK_GE.md) · [繁體中文版](RUNBOOK_TW.md) · [日本語版](RUNBOOK_JP.md)

# Диагностический справочник EKS: симптом, причина, проверка

[Оглавление курса](README_RU.md) · [Глоссарий](GLOSSARY_RU.md)

## Как этим пользоваться

Это сводка разделов «Порядок диагностики и инструменты» глав 45, 46 и 47, собранная в один
файл для дежурства: на инциденте листать три главы неудобно.
Работает так: сначала опознайте КЛАСС симптома по таблице «Быстрый вход по симптому», потом
идите в свой слой и проходите его сверху вниз. Классификация важнее инструмента: под в
`ContainerCreating` и 503 от балансировщика лечатся разными командами.
Здесь только порядок прохода, чеклисты и команды. Разбор причин, механика и объяснения
остались в главах 45-47, ссылки на них стоят в каждой строке навигатора.

## Быстрый вход по симптому

| Что видно | Класс | Куда идти |
|---|---|---|
| `kubectl get nodes` пустой, нод нет | нода не присоединилась | [нода](#нода-не-присоединилась-к-кластеру), [глава 45](45/ru.md) |
| `NodeCreationFailure`, `Instances failed to join the kubernetes cluster` | нода не присоединилась | [нода](#нода-не-присоединилась-к-кластеру), [глава 45](45/ru.md) |
| node group в `CREATE_FAILED` или `DEGRADED` | нода не присоединилась | [нода](#нода-не-присоединилась-к-кластеру), [глава 45](45/ru.md) |
| в логе kubelet `node "" not found` | нода: DNS и private DNS name | [нода](#нода-не-присоединилась-к-кластеру), [глава 45](45/ru.md) |
| нода видна, но `NotReady` | CNI не готов, другой слой | [нода](#нода-не-присоединилась-к-кластеру), [глава 45](45/ru.md), глава 8 |
| под в `ContainerCreating`, `failed to assign an IP address to container` | сеть: IP и ENI | [сеть](#сетевые-сбои-в-работающем-кластере), [глава 46](46/ru.md) |
| под-под или под-RDS `connection timed out`, DNS резолвится | сеть: security group | [сеть](#сетевые-сбои-в-работающем-кластере), [глава 46](46/ru.md) |
| запрос уходит, но соединение зависает | сеть: NACL и ephemeral ports | [сеть](#сетевые-сбои-в-работающем-кластере), [глава 46](46/ru.md) |
| под не резолвит имена и не проходит readiness | сеть: своя SG у пода | [сеть](#сетевые-сбои-в-работающем-кластере), [глава 46](46/ru.md) |
| DNS работает через раз, плавающие таймауты | сеть: DNS | [сеть](#сетевые-сбои-в-работающем-кластере), [глава 46](46/ru.md) |
| лишняя DNS-нагрузка на внешние имена | сеть: эффект `ndots:5` | [сеть](#сетевые-сбои-в-работающем-кластере), [глава 46](46/ru.md) |
| таргеты в target group `unhealthy`, 502 `Bad gateway` | сеть: балансировщик | [сеть](#сетевые-сбои-в-работающем-кластере), [глава 46](46/ru.md) |
| 503 `Service unavailable` от сервиса за LB | сеть: здоровых таргетов нет | [сеть](#сетевые-сбои-в-работающем-кластере), [глава 46](46/ru.md) |
| `You must be logged in to the server (Unauthorized)` | доступ: аутентификация | [доступ](#отказ-доступа-человек-и-под), [глава 47](47/ru.md) |
| `couldn't get current server API group list: Unauthorized` | доступ: kubeconfig или регион | [доступ](#отказ-доступа-человек-и-под), [глава 47](47/ru.md) |
| `Forbidden: cannot <verb> resource` | доступ: RBAC | [доступ](#отказ-доступа-человек-и-под), [глава 47](47/ru.md) |
| под падает с `AccessDenied` на вызове AWS | доступ пода: STS и роль | [доступ](#отказ-доступа-человек-и-под), [глава 47](47/ru.md) |
| под падает с `WebIdentityErr: failed to retrieve credentials` | доступ пода: IRSA | [доступ](#отказ-доступа-человек-и-под), [глава 47](47/ru.md) |

## Нода не присоединилась к кластеру

Глава 45. Симптом один - пустой `kubectl get nodes` и `NodeCreationFailure`, - а причины лежат
на разных слоях. Порядок прохода сверху вниз:

1. Слой IAM: права node instance role и авторизация роли в кластере (раздел 45.2).
2. Слой сети: путь до endpoint API-сервера на 443, тип endpoint, DNS (раздел 45.3).
3. Слой user data и bootstrap: `bootstrap.sh` на AL2, `nodeadm`/`NodeConfig` на AL2023 (45.4).
4. Слой kubelet: демон запущен, kubeconfig и сертификат целы, регистрация прошла (45.5).

Логика: сначала спросить EKS через `describe-nodegroup`, затем проверить авторизацию роли
(дёшево и чаще всего виновата она), потом сеть до endpoint, и только затем лезть на ноду за
логами cloud-init и kubelet. Различайте «нод нет» и `NotReady`: второе при живом kubelet -
почти всегда CNI, это глава 8.

| Симптом | Вероятная причина | Что проверить |
|---|---|---|
| `NodeCreationFailure`, нод нет | роль ноды не авторизована | `aws eks list-access-entries`, `aws-auth` |
| нод нет, IAM в порядке | нет пути до API на 443 | SG, маршрут NAT/IGW, тип endpoint |
| нод нет, приватный кластер | не резолвится endpoint | DNS, DHCP options set в VPC |
| нод нет, кастомный AMI | bootstrap не отработал | `/var/log/cloud-init-output.log` |
| нод нет, kubelet падает | битый kubeconfig/сертификат | `journalctl -u kubelet` |
| нода есть, но `NotReady` | CNI не готов, нет IP подам | под `aws-node`, события ноды (глава 8) |
| в логе `node "" not found` | нет private DNS name | DHCP options, DNS в VPC |

```bash
# 1. что говорит сам EKS про node group
aws eks describe-nodegroup --cluster-name prod --nodegroup-name ng-1 \
  --query 'nodegroup.health.issues'
# 2. видит ли кластер ноды
kubectl get nodes
# 3. авторизована ли роль ноды
aws eks list-access-entries --cluster-name prod
# устаревший путь: маппинги в aws-auth
kubectl -n kube-system get configmap aws-auth -o yaml
# 4. на ноде через SSM Session Manager: лог bootstrap/cloud-init
sudo cat /var/log/cloud-init-output.log
# 5. на ноде: статус и логи kubelet
systemctl status kubelet
journalctl -u kubelet -n 200 --no-pager
```

Доступ на ноду без SSH берут через SSM Session Manager: нужен SSM agent и права. Если SSM
недоступен, остаётся консольный вывод инстанса (system log) и `/var/log`.

## Сетевые сбои в работающем кластере

Глава 46. Кластер работает, ноды `Ready`, но сеть подводит по-разному. Сначала классифицируйте
симптом: нет IP, обрыв связности, DNS, 5xx от балансировщика. Класс задаёт слой и команду.
`describe pod` и `get pods -o wide` дёшевы и первыми отсекают IP-проблемы,
`describe-target-health` мгновенно локализует сбой балансировщика, VPC Flow Logs - последний
рубеж для обрывов, которые не объясняются ни IP, ни health check. Помните разницу слоёв:
security group stateful и работает на уровне ENI, NACL stateless и работает на уровне подсети,
поэтому обратный трафик на ephemeral ports в NACL разрешают вручную.

| Симптом | Вероятная причина | Что проверить |
|---|---|---|
| `failed to assign an IP address` | нет свободных IP на ноде или в подсети | `describe pod`, `AvailableIpAddressCount` |
| под-под или под-RDS timeout | SG не разрешает трафик | `describe-network-interfaces` Groups, SG RDS |
| обрыв, но запрос уходит | NACL режет ephemeral ports | NACL правила in/out, VPC Flow Logs |
| DNS с перемежающимися таймаутами | CoreDNS, conntrack, per-ENI троттлинг | метрики CoreDNS (глава 33), conntrack, PPS |
| лишняя DNS-нагрузка на внешние имена | эффект `ndots:5` | search-домены, FQDN с точкой |
| 502 или 503 от сервиса за LB | таргеты `unhealthy` | `describe-target-health`, health check, SG |
| таргеты `unhealthy`, под жив | health check путь/порт или SG | путь и порт проверки, SG балансировщика |
| под без DNS и без readiness | своя SG у пода вместо SG ноды | `SecurityGroupPolicy` у пода, 53 TCP/UDP, вход от SG нод |

```bash
# 1. события пода: причина ContainerCreating и выдачи IP
kubectl describe pod <pod>
# 2. где под и на какой ноде
kubectl get pods -o wide
# 3. ENI, IP и SG на конкретном адресе
aws ec2 describe-network-interfaces \
  --filters "Name=private-ip-address,Values=<ip>" --query 'NetworkInterfaces[0]'
# 4. свободные адреса в подсети
aws ec2 describe-subnets --subnet-ids <subnet> \
  --query 'Subnets[0].AvailableIpAddressCount'
# 5. здоровье таргетов балансировщика
aws elbv2 describe-target-health --target-group-arn "$TG_ARN"
# есть ли готовые endpoints за сервисом
kubectl get endpointslices -l kubernetes.io/service-name=<svc>
# 6. проверка резолвинга из пода
kubectl run dnstest --image=busybox:1.36 --rm -it --restart=Never -- nslookup <name>
# своя SG у пода: режим применения и поиск ошибки в id SG
kubectl describe daemonset aws-node -n kube-system | grep -iE 'SECURITY_GROUP|DEMUX'
kubectl describe pod <pod> | grep -i InvalidSecurityGroupID
# 7. на ноде: собрать дамп сети VPC CNI (логи ipamd/plugin, ENI, eni-configs)
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids <instance-id> \
  --parameters 'commands=["/opt/cni/bin/aws-cni-support.sh"]'
```

Состояние ipamd видно и напрямую через его локальный endpoint: `/v1/enis` показывает выданные
ENI и IP, `/v1/pods` - привязку адресов к подам.

## Отказ доступа: человек и под

Глава 47. Сбои доступа делятся на две независимые оси, и первый вопрос дежурного - какая из них
сломана: человек или CI не входит в кластер, или под получает `AccessDenied` на вызове AWS.
Дальше классификацию доканчивает код отказа. `Unauthorized` (401) - это провал аутентификации:
нет токена, он протух, identity не замаплена; чинят в kubeconfig, креденшелах и маппинге
(access entry или aws-auth). `Forbidden` (403) - это провал авторизации: identity уже известна,
но RBAC не даёт прав; чинят в Role, ClusterRole и биндингах. `AccessDenied` из пода ведёт в
IRSA или Pod Identity. Быстрая развилка «кластер или я»: если `aws sts get-caller-identity`
показывает не ту identity, проблема локальная - профиль, регион или креденшелы.

| Симптом | Вероятная причина | Что проверить |
|---|---|---|
| `Unauthorized`, `must be logged in` | не та identity или не замаплена | `sts get-caller-identity`, `list-access-entries` |
| `Unauthorized` сразу после `edit aws-auth` | снесён свой маппинг | `get cm aws-auth`, восстановить через access entry |
| `Forbidden: cannot <verb>` | RBAC не даёт прав | `kubectl auth can-i`, Role и биндинги |
| `couldn't get server API group` | битый kubeconfig или регион | `update-kubeconfig`, `current-context`, профиль |
| под `AccessDenied` при IRSA | trust policy, OIDC, аннотация SA | OIDC provider, `sub`/`aud`, аннотация `role-arn` |
| под `WebIdentityErr` | токен не смонтирован, роль не та | пересоздать под, проверить trust policy |
| под `AccessDenied` при Pod Identity | нет association, агента или токена | `list-pod-identity-associations`, агент, токен в поде |

```bash
# кто я на самом деле в глазах AWS
aws sts get-caller-identity
# режим аутентификации и accessConfig кластера
aws eks describe-cluster --name <cluster> --query 'cluster.accessConfig'
# кто замаплен через access entries
aws eks list-access-entries --cluster-name <cluster>
# что в aws-auth (если режим ещё его использует)
kubectl -n kube-system get cm aws-auth -o yaml
# authz: что мне вообще можно
kubectl auth can-i --list
kubectl auth can-i get pods -n <ns>
# перегенерировать kubeconfig и проверить контекст
aws eks update-kubeconfig --name <cluster> --region <region> --profile <profile>
kubectl config current-context
# ось пода: аннотация роли на ServiceAccount (IRSA)
kubectl get sa <sa> -n <ns> -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
# ассоциации Pod Identity
aws eks list-pod-identity-associations --cluster-name <cluster>
# запущен ли агент Pod Identity
kubectl -n kube-system get pods -l app.kubernetes.io/name=eks-pod-identity-agent
# смонтирован ли токен Pod Identity в самом поде (нет файла - агент/association не сработали)
kubectl exec <pod> -n <ns> -- ls /var/run/secrets/pods.eks.amazonaws.com/serviceaccount/
```

Залоченный кластер восстанавливают через EKS API: `update-cluster-config` с
`authenticationMode=API_AND_CONFIG_MAP`, затем `create-access-entry` и
`associate-access-policy` с `AmazonEKSClusterAdminPolicy` (раздел 47.4). Обратный переход к
`CONFIG_MAP` невозможен.

## Что смотреть, когда ничего не сходится

- **VPC Flow Logs** пишут, `ACCEPT` или `REJECT` получил пакет на уровне ENI или подсети.
  `REJECT` указывает на SG или NACL, а отсутствие ответных пакетов при ушедшем запросе - на
  stateless NACL и ephemeral ports.
- **Логи control plane** (api, audit, authenticator) включают заранее, а не постфактум: логи
  authenticator показывают, замаплена ли пришедшая identity (главы 21 и 34).
- **`aws-cni-support.sh` через SSM** собирает логи ipamd и plugin вместе с состоянием ENI/IP и
  конфигурацией в архив `/var/log/eks_<instance-id>_<...>.tar.gz`, без SSH на ноду.
- **Логи `/var/log/aws-routed-eni`** (`ipamd.log`, `plugin.log`) читают на ноде, когда под
  висит с `failed to assign an IP address`, а неясно, кончились IP или не поднялась ENI.

## Чего здесь нет

Это не замена главам: объяснений причин, механики слоёв и разбора, почему симптом выглядит
именно так, тут нет - они в главах 45, 46 и 47. Здесь только порядок прохода и команды.
Troubleshooting-лабы курса (119, 120, 121, а также 126 про security groups for pods) в этом
файле не дублируются: их проходят по своим заданиям.
