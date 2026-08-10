# Глоссарий курса EKS

[Оглавление курса](README_RU.md)

Единый алфавитный справочник терминов курса. Термин оставлен на английском там,
где он английский в AWS и Kubernetes, описание - на русском. В колонке «Главы» -
где термин разбирается, со ссылками на главы. Поиск по странице - Ctrl+F.

| Термин | Описание | Главы |
|--------|----------|-------|
| **ABAC / RBAC** | доступ по тегам через `aws:PrincipalTag` против доступа по ролям и политикам с конкретными действиями и ресурсами. | [0.2](00-2-iam/ru.md) |
| **Access entry** | запись в конфигурации доступа кластера, связывающая один IAM-принципал с `username` и `kubernetesGroups`; тип `STANDARD` для людей и сервисов, `EC2_LINUX`, `EC2_WINDOWS`, `FARGATE_LINUX`, `HYBRID_LINUX`, `EC2` для нод. | [01](01/ru.md), [05](05/ru.md), [47](47/ru.md) |
| **access entry типа `EC2_LINUX`** | запись, авторизующая ARN роли ноды в кластере. | [45](45/ru.md) |
| **access point** | вход в подкаталог EFS со своими правами и POSIX-идентичностью; основа динамического провижининга и изоляции каталогов. | [24](24/ru.md) |
| **Access policy** | управляемая AWS политика прав уровня Kubernetes, ассоциируемая с access entry; содержит verbs и resources, а не IAM-права, и не редактируется. | [05](05/ru.md), [47](47/ru.md) |
| **Access scope** | область действия access policy: `cluster` или `namespace` со списком. | [05](05/ru.md) |
| **ACM (AWS Certificate Manager)** | сертификаты, живущие на балансировщике; ключ не экспортируется, продление автоматическое. | [27](27/ru.md), [29](29/ru.md) |
| **actions / conditions** | аннотации кастомных действий (redirect, fixed-response, weighted forward) и дополнительных условий роутинга (заголовки, метод, query, source IP). | [27](27/ru.md) |
| **Admission webhook** | внешний обработчик, который apiserver зовёт до записи объекта в etcd; mutating меняет объект, validating только пропускает или отклоняет. | [22](22/ru.md) |
| **ADOT** | AWS Distro for OpenTelemetry: дистрибутив OTel от AWS (SDK, агенты, Collector). | [36](36/ru.md) |
| **ALIAS** | запись Route 53 на ресурс AWS (например ELB), работает на apex домена, где CNAME запрещён, и не тарифицируется как отдельный запрос. | [29](29/ru.md) |
| **Allocatable** | то, что осталось подам после `kube-reserved`, `system-reserved` и порога вытеснения; на это смотрит планировщик. | [14](14/ru.md) |
| **`allowVolumeExpansion`** | флаг StorageClass, разрешающий увеличивать том через рост PVC. | [23](23/ru.md) |
| **Amazon EKS** | управляемый Kubernetes в AWS: control plane обслуживает AWS, ноды и обвязка на вас. | [01](01/ru.md) |
| **Amazon Managed Grafana (AMG)** | управляемый Grafana; подключает AMP как data source, доступ пользователей через IAM Identity Center. | [33](33/ru.md) |
| **Amazon Managed Service for Prometheus (AMP)** | управляемый Prometheus-совместимый бэкенд; workspace, remote-write, PromQL, retention на стороне AWS. | [33](33/ru.md) |
| **amazon-cloudwatch-observability** | управляемый аддон EKS, ставящий CloudWatch agent и включающий Container Insights with enhanced observability. | [33](33/ru.md) |
| **AMI (Amazon Machine Image)** | шаблон диска инстанса: ядро, ФС, софт; для нод берут EKS-оптимизированный, где уже согласованы `kubelet`, `containerd` и bootstrap-логика. | [0.4](00-4-ec2/ru.md), [10](10/ru.md) |
| **API Priority and Fairness** | механизм Kubernetes, распределяющий квоту одновременных запросов между их типами; при исчерпании клиент получает `429`. | [02](02/ru.md) |
| **app-of-apps** | родительское `Application`, разворачивающее набор дочерних. | [44](44/ru.md) |
| **Application** | CRD Argo CD: связка «источник в Git + целевой кластер и namespace». | [44](44/ru.md) |
| **Application Load Balancer (ALB)** | балансировщик L7 (HTTP/HTTPS) с роутингом по host и path, терминацией TLS, WAF и аутентификацией; в EKS создаётся LBC из Ingress. | [27](27/ru.md) |
| **ApplicationSet** | контроллер Argo CD, генерирующий `Application` по шаблону; cluster generator создаёт по одному на каждый подключённый кластер, git generator - по каталогам или файлам в Git, matrix generator перемножает два генератора (cluster + git). | [44](44/ru.md) |
| **ARN** | `arn:partition:service:region:account-id:resource`, адрес ресурса. | [0.1](00-1-aws/ru.md) |
| **`AssumeRoleWithWebIdentity`** | операция STS, обменивающая web identity token на временные креды IAM-роли. | [16](16/ru.md) |
| **auditID** | уникальный идентификатор запроса в audit-логе; одинаков для всех stage одной операции. Общего ID с CloudTrail нет - между источниками сшивают по принципалу, IP и времени. | [21](21/ru.md) |
| **`authenticationMode`** | режим аутентификации кластера: `CONFIG_MAP`, `API_AND_CONFIG_MAP`, `API`; движение только в сторону `API`. | [04](04/ru.md), [05](05/ru.md), [47](47/ru.md) |
| **`authenticationSource`** | источник учётных данных тома: `driver` (общая роль драйвера) или `pod` (роль сервис-аккаунта пода). | [25](25/ru.md) |
| **Availability Zone (AZ)** | изолированный набор дата-центров региона; базовый домен отказа, по которому раскладывают реплики. | [0.1](00-1-aws/ru.md), [40](40/ru.md) |
| **AWS Backup** | централизованный сервис резервного копирования AWS; бэкапит EKS, EBS, EFS, S3 и другие ресурсы по единым планам и хранилищам. | [41](41/ru.md) |
| **aws cli v2** | основная CLI для AWS; конфигурация в `~/.aws/config`, доступ выбирается через `--profile` или `AWS_PROFILE`. | [0.5](00-5-tools/ru.md) |
| **AWS Control Tower** | готовая landing zone от AWS: controls (preventive, detective, proactive), обнаружение дрейфа и account factory. | [0.1](00-1-aws/ru.md) |
| **`aws eks get-token`** | `exec`-плагин в kubeconfig, формирующий presigned STS-токен для входа в кластер. | [47](47/ru.md) |
| **AWS Gateway API Controller** | контроллер `aws-application-networking-k8s`, GatewayClass `amazon-vpc-lattice`, транслирует Gateway API в объекты VPC Lattice. | [28](28/ru.md) |
| **AWS Load Balancer Controller (Gateway API)** | реализация с `controllerName` `gateway.k8s.aws/alb` (ALB, L7) и `gateway.k8s.aws/nlb` (NLB, L4). | [28](28/ru.md) |
| **AWS Load Balancer Controller (LBC)** | контроллер в кластере, создающий NLB для Service типа LoadBalancer и ALB для Ingress; ставится через Helm, требует IAM-роли. | [26](26/ru.md) |
| **AWS Organizations** | сервис управления несколькими аккаунтами: иерархия OU, общие политики (SCP), консолидированный биллинг. | [0.1](00-1-aws/ru.md), [32](32/ru.md) |
| **AWS PrivateLink** | механизм приватного доступа к сервисам AWS и к сервисам в других аккаунтах через interface endpoint. | [31](31/ru.md) |
| **AWS RAM (Resource Access Manager)** | сервис шаринга ресурсов (subnets, Transit Gateway, VPC Lattice service network, Route 53 Resolver rules) с другими аккаунтами и организацией. | [0.1](00-1-aws/ru.md), [32](32/ru.md) |
| **`aws sts get-caller-identity`** | команда «кто я»: аккаунт, ARN, userId. | [0.5](00-5-tools/ru.md) |
| **AWS X-Ray** | управляемый бэкенд трейсов: хранение, service map, разбивка задержки, поиск трейсов. | [36](36/ru.md) |
| **`aws-auth` ConfigMap** | legacy-механизм отображения через объект в `kube-system` с полями `mapRoles` и `mapUsers`. | [05](05/ru.md), [45](45/ru.md), [47](47/ru.md) |
| **aws-for-fluent-bit** | собранный AWS образ Fluent Bit со встроенными плагинами вывода в сервисы AWS. | [34](34/ru.md) |
| **`aws-vault`** | хранение кредов в keychain и запуск команд во временной сессии. | [0.5](00-5-tools/ru.md) |
| **`AWS_VPC_K8S_CNI_EXTERNALSNAT`** | снимает узловой SNAT egress подов (`true`), чтобы внешняя сторона видела реальный адрес пода; тогда выход в интернет идёт только через NAT gateway. | [07](07/ru.md) |
| **`AWSTraceHeader`** | системный атрибут сообщения SQS под заголовок трейса X-Ray; способ пронести контекст через асинхронную границу, где заголовков нет. | [36](36/ru.md) |
| **backend-protocol-version** | application protocol таргет-группы: `HTTP1`, `HTTP2` или `GRPC`; нужен, чтобы ALB проксировал gRPC и HTTP/2 к подам, а не по HTTP/1.1. | [27](27/ru.md) |
| **backup plan** | план бэкапа: расписание, retention, lifecycle (переход в cold storage) и привязка ресурсов. | [41](41/ru.md) |
| **backup vault** | хранилище recovery points с ключом KMS и политикой доступа; на нём включается Vault Lock. | [41](41/ru.md) |
| **BackupStorageLocation (BSL)** | место хранения бэкапов Velero (S3-бакет). | [42](42/ru.md) |
| **bake period** | пауза между апгрейдом control plane и нод: ноды остаются на N-1 и откат доступен без их возврата. | [39](39/ru.md) |
| **Basic / Enhanced scanning** | режимы поиска CVE в ECR: basic - ОС-пакеты нативно; enhanced - ОС и пакеты языков через Amazon Inspector, непрерывно. | [20](20/ru.md) |
| **behavior / stabilizationWindowSeconds** | секция HPA, сглаживающая скорость и колебания масштабирования через окна стабилизации и policies. | [35](35/ru.md) |
| **bin packing** | укладка подов по нодам по их requests. | [14](14/ru.md) |
| **blue/green кластер** | новый кластер на целевой версии рядом со старым, с миграцией нагрузок и переключением трафика. | [03](03/ru.md), [38](38/ru.md) |
| **bootstrap.sh** | скрипт настройки kubelet на AL2 из user data. | [45](45/ru.md) |
| **`bootstrapClusterCreatorAdminPermissions`** | поле конфигурации доступа при создании; при `true` (по умолчанию) создатель кластера получает права администратора в нём. | [04](04/ru.md), [05](05/ru.md) |
| **Bottlerocket** | минимальная ОС под контейнеры: read-only корень, обновление целым образом, управление через API, control- и admin-контейнеры вместо открытого SSH. | [10](10/ru.md) |
| **Burstable (T-серия)** | базовая доля CPU плюс CPU credits; для prod-нод не годится. | [0.4](00-4-ec2/ru.md) |
| **Capacity** | полная ёмкость инстанса по CPU, памяти и подам. | [14](14/ru.md) |
| **Capacity Blocks** | бронь GPU/Trainium-ёмкости под обучение. | [0.4](00-4-ec2/ru.md) |
| **capacity type** | тип ёмкости ноды (`spot`/`on-demand`); метки `karpenter.sh/capacity-type` и `eks.amazonaws.com/capacityType`. | [13](13/ru.md) |
| **CapacityProvisioned** | аннотация пода с реально выданной комбинацией vCPU и памяти после округления; именно она определяет стоимость. | [15](15/ru.md) |
| **cert-manager** | контроллер выпуска сертификатов внутри кластера в виде `Secret`; источник задают ClusterIssuer или Issuer. | [29](29/ru.md) |
| **CFS throttling** | замедление контейнера при превышении CPU limit. | [14](14/ru.md) |
| **chargeback** | стоимость реально относят на бюджет команды. | [43](43/ru.md) |
| **`CiliumNetworkPolicy` / `CiliumClusterwideNetworkPolicy`** | CRD Cilium с L7- и FQDN-правилами и кластерной областью действия. | [08](08/ru.md), [30](30/ru.md) |
| **CloudTrail** | журнал вызовов API AWS; для EKS фиксирует операции над кластером как ресурсом AWS (management events), не события внутри Kubernetes. | [21](21/ru.md) |
| **CloudWatch Application Signals** | APM поверх OTel (SLO, задержка, ошибки), включается аддоном `amazon-cloudwatch-observability`. | [36](36/ru.md) |
| **CloudWatch Logs** | хранилище логов AWS; log groups и log streams, запросы через Logs Insights, оплата за ingestion и storage. | [34](34/ru.md) |
| **CloudWatch Logs Insights** | язык запросов по логам (`fields`, `filter`, `sort`, `stats`); основной инструмент разбора audit-лога. | [21](21/ru.md) |
| **Cluster Autoscaler (CA)** | автоскейлер нод, работающий поверх Auto Scaling group: меняет `desiredSize` групп по неразмещённым подам и недозагрузке. Типы инстансов фиксированы launch template групп. | [11](11/ru.md) |
| **cluster creator admin** | IAM principal, создавший кластер, получает админский доступ автоматически. | [47](47/ru.md) |
| **Cluster endpoint** | адрес Kubernetes API кластера. Public endpoint доступен из интернета и ограничивается только списком CIDR; private endpoint доступен из VPC и ограничивается cluster security group. | [01](01/ru.md), [02](02/ru.md) |
| **Cluster insights** | автоматические проверки кластера от EKS; `UPGRADE_READINESS` про готовность к апгрейду, `ROLLBACK_READINESS` про возможность откатиться, доступна 7 дней. | [03](03/ru.md), [38](38/ru.md) |
| **Cluster security group** | группа, автоматически создаваемая для кластера и навешиваемая на эти интерфейсы и на ноды managed node groups. | [02](02/ru.md), [45](45/ru.md) |
| **cluster version rollback** | откат control plane EKS на предыдущий минор после in-place апгрейда, в окне 7 дней, с сохранением etcd, нагрузок и томов. | [03](03/ru.md), [39](39/ru.md) |
| **ClusterIssuer / Issuer** | объекты cert-manager, описывающие источник сертификатов на весь кластер или на namespace. | [29](29/ru.md) |
| **ClusterMesh** | объединение Pod Network нескольких кластеров Cilium через `clustermesh-apiserver`; нужны уникальные `cluster-id` и непересекающиеся PodCIDR. | [08](08/ru.md) |
| **CMK (customer managed key)** | ваш ключ KMS: даёт контроль над политикой ключа и аудит расшифровки в CloudTrail, в отличие от AWS owned key по умолчанию. | [18](18/ru.md) |
| **CNI chaining** | режим, где VPC CNI выдаёт адреса и настраивает интерфейс, а Cilium добавляет поверх политики и наблюдаемость; `aws-node` остаётся. | [08](08/ru.md), [30](30/ru.md) |
| **`cni-metrics-helper`** | компонент: скрейпит `awscni_*` с подов `aws-node` и шлёт агрегаты в CloudWatch. | [06](06/ru.md) |
| **composite recovery point** | составная точка для EKS, группирующая состояние кластера и бэкапы томов как одну единицу. | [41](41/ru.md) |
| **Compute Savings Plans** | обязательство по расходу в час на 1-3 года в обмен на скидку, гибкое по семействам инстансов, региону и Fargate/Lambda; коммит часовой, между часами не переносится и на Spot не распространяется, а его расход видно в отчётах Savings Plans utilization (израсходовано) и coverage (покрыто) в Cost Explorer. | [43](43/ru.md) |
| **Compute SP / EC2 Instance SP** | гибкий план (EC2, Fargate, Lambda) / более глубокий, но на одно семейство в регионе. | [0.4](00-4-ec2/ru.md) |
| **configurationValues** | поле аддона для декларативной настройки без ручной правки манифестов. | [37](37/ru.md) |
| **connection draining** | слив активных соединений при дерегистрации target; `deregistration_delay.timeout_seconds` (по умолчанию 300). | [40](40/ru.md) |
| **conntrack** | таблица соединений ядра ноды; при переполнении дропаются новые соединения. | [46](46/ru.md) |
| **Consolidated billing** | общий счёт организации; объёмные скидки и Savings Plans действуют на все аккаунты. | [0.1](00-1-aws/ru.md) |
| **Consolidation** | добровольное уплотнение ради стоимости; политики `WhenEmpty` и `WhenEmptyOrUnderutilized`, методы empty/single/multi-node, параметр `consolidateAfter`. | [11](11/ru.md), [12](12/ru.md) |
| **Container Insights** | мониторинг EKS средствами CloudWatch: агент собирает метрики нод и подов, дашборды и алармы в CloudWatch. | [33](33/ru.md) |
| **ContainerResource** | тип метрики HPA, считающий утилизацию по одному контейнеру пода, а не по сумме всех; нужен там, где sidecar размывает метрику приложения. | [35](35/ru.md) |
| **context propagation** | передача `trace id` между сервисами через заголовки (W3C Trace Context), чтобы трейс не разрывался. | [36](36/ru.md) |
| **continuous profiling** | непрерывный сбор hotspot'ов CPU и памяти в коде; в AWS - Amazon CodeGuru Profiler, из eBPF-профайлеров - Pyroscope и Parca. | [36](36/ru.md) |
| **Control plane** | API-сервер, scheduler, controller manager и etcd; в EKS живут в аккаунте AWS, вне вашего VPC, и не видны в `kubectl get pods -n kube-system`. | [01](01/ru.md) |
| **control plane logging** | доставка логов управляющего слоя EKS (`api`, `audit`, `authenticator`, `controllerManager`, `scheduler`) в CloudWatch Logs. | [34](34/ru.md) |
| **core-аддоны** | `vpc-cni`, `kube-proxy`, `coredns`: обязательное ядро, ставится для каждого кластера. | [37](37/ru.md) |
| **cost allocation (аллокация)** | распределение стоимости ресурсов AWS на объекты Kubernetes (namespace, Deployment, label) по потреблению или requests. | [43](43/ru.md) |
| **cost allocation tags** | теги AWS для разбивки счёта; user-defined теги надо активировать в консоли Billing. | [43](43/ru.md) |
| **Cost and Usage Report** | детальный биллинг AWS в S3; чтение через Athena даёт OpenCost/Kubecost сверять аллокацию с фактическим счётом со скидками. | [43](43/ru.md) |
| **Cost Anomaly Detection** | сервис AWS, ML-детекция аномального роста трат с алертами в email или SNS (Slack/Teams через AWS Chatbot). | [43](43/ru.md) |
| **crash-consistent / application-consistent** | снимок без остановки записи против снимка с согласованием на уровне приложения; у AWS Backup для EKS доступен только первый. | [41](41/ru.md) |
| **Cross-account ENI** | сетевые интерфейсы, которые EKS создаёт в ваших подсетях для связи control plane с нодами, kubelet API, webhooks и OIDC. | [02](02/ru.md) |
| **cross-AZ трафик** | передача данных между зонами доступности; тарифицируется за передачу, обычно в обе стороны. | [31](31/ru.md) |
| **cross-zone load balancing** | режим балансировщика, раскидывающий трафик по целям всех зон; ровнее нагрузка, но больше cross-AZ. | [31](31/ru.md) |
| **Custom networking** | режим, где secondary ENI и адреса подов берутся из подсети и security groups объекта `ENIConfig`, по одному на AZ, с выбором по метке из `ENI_CONFIG_LABEL_DEF`. | [07](07/ru.md) |
| **custom.metrics.k8s.io** | API кастомных метрик объектов кластера для HPA (Pods, Object). | [35](35/ru.md) |
| **Data Firehose** | управляемый буфер и маршрутизатор потоков в S3, OpenSearch и другие назначения. | [34](34/ru.md) |
| **Data plane** | ваши ноды и всё, что на них запускается. | [01](01/ru.md) |
| **Delegated administrator** | аккаунт организации, управляющий GuardDuty/Security Hub на всю организацию и видящий findings всех членов; назначается регионально. | [0.1](00-1-aws/ru.md), [21](21/ru.md) |
| **`deletionProtection`** | флаг, запрещающий удаление кластера. | [04](04/ru.md) |
| **deprecated / removed API** | `apiVersion` объявлен устаревшим, затем удалён; после удаления манифесты с ним не применяются. | [38](38/ru.md) |
| **describe-addon-versions** | операция EKS API: версии аддона, их совместимость с минором Kubernetes и `defaultVersion`. | [37](37/ru.md) |
| **`describe-target-health`** | команда, показывающая состояние и причину для таргетов target group. | [46](46/ru.md) |
| **Digest** | `sha256`-хеш содержимого образа, неизменяемый идентификатор; деплой по digest гарантирует запуск ровно собранного артефакта, в отличие от подвижного тега. | [20](20/ru.md) |
| **Disruption budget** | лимит темпа добровольных прерываний: доля/число нод, окна по `schedule` и `duration`, привязка к `reasons`. | [12](12/ru.md) |
| **DNS-01** | способ ACME-проверки владения доменом через TXT-запись; в Route 53 её создаёт cert-manager. | [29](29/ru.md) |
| **Drift** | расхождение ноды с желаемым состоянием (новый AMI, изменённые селекторы или `requirements`); выполняется раньше consolidation. | [12](12/ru.md) |
| **Dual-stack** | VPC и подсети с IPv4 и IPv6 (`/56` и `/64`); режим IPv6 снимает нехватку адресов под поды. | [0.3](00-3-vpc/ru.md) |
| **EBS / instance store** | сетевой том в одной AZ / эфемерный локальный NVMe. | [0.4](00-4-ec2/ru.md) |
| **EBS CSI-драйвер** | `aws-ebs-csi-driver`, managed addon с провизионером `ebs.csi.aws.com`; управляет жизненным циклом томов EBS. | [23](23/ru.md) |
| **EC2NodeClass** | CRD (`karpenter.k8s.aws/v1`) с AWS-настройками: AMI, IAM-роль, подсети и SG, диски, IMDS. | [12](12/ru.md) |
| **ECR** | управляемый реестр OCI-образов AWS; приватный registry на аккаунт-регион с адресом `<account-id>.dkr.ecr.<region>.amazonaws.com` и публичный `public.ecr.aws`. | [20](20/ru.md) |
| **EFS** | Amazon Elastic File System, управляемый региональный NFS с эластичной ёмкостью и режимом ReadWriteMany. | [24](24/ru.md) |
| **EFS CSI-драйвер** | `aws-efs-csi-driver`, managed addon с провизионером `efs.csi.aws.com`; работает поверх заранее созданной файловой системы. | [24](24/ru.md) |
| **EKS audit log** | тип логов control plane (`audit`), JSON-события Kubernetes audit: кто, какой verb, над каким ресурсом, откуда и с каким результатом; пишется в CloudWatch Logs. | [21](21/ru.md) |
| **EKS authenticator** | webhook на control plane, который проверяет presigned STS-токен и сопоставляет IAM identity с Kubernetes-субъектом. | [47](47/ru.md) |
| **EKS Auto Mode** | режим, где AWS управляет нодами-appliance (Bottlerocket, read-only root, без SSH и SSM, 21 день жизни), масштабированием на Karpenter и встроенными сетью, DNS, EBS CSI, ELB. | [01](01/ru.md), [09](09/ru.md) |
| **EKS Cluster State** | манифесты объектов Kubernetes (Secret, ConfigMap, StatefulSet, PVC, RBAC, CRD и т.п.) плюс конфигурация кластера. | [41](41/ru.md) |
| **EKS Pod Identity** | механизм выдачи IAM-роли поду через агент на ноде и API EKS, без OIDC-провайдера кластера и без trust policy, привязанной к конкретному кластеру. | [17](17/ru.md), [47](47/ru.md) |
| **EKS Pod Identity Agent** | аддон `eks-pod-identity-agent`, работающий `DaemonSet` на нодах и раздающий подам временные креды через локальный endpoint. | [17](17/ru.md) |
| **EKS-оптимизированный AMI** | образ от AWS с компонентами ноды нужных версий; семейства AL2023, Bottlerocket, Windows и устаревающий AL2. | [10](10/ru.md) |
| **eksctl** | официальная CLI для EKS, работает через CloudFormation, императивна. | [0.5](00-5-tools/ru.md) |
| **enableNetworkPolicy** | параметр managed addon VPC CNI, включающий enforcement стандартного NetworkPolicy. | [30](30/ru.md) |
| **Encryption at rest** | шифрование слоёв в ECR: по умолчанию SSE-S3 (AES-256), опционально SSE-KMS ключом `aws/ecr` или своим customer managed key; задаётся на создании и неизменно. | [20](20/ru.md) |
| **endpoint service** | публикация собственного сервиса (за NLB) как цели PrivateLink для потребителей из других VPC и аккаунтов. | [31](31/ru.md) |
| **`endpointPublicAccess` / `endpointPrivateAccess`** | булевы флаги режима доступа; по умолчанию `true` и `false`. | [02](02/ru.md) |
| **enforcer** | компонент CNI, превращающий NetworkPolicy в реальные фильтры трафика; в EKS по умолчанию отсутствует, пока не включён. | [30](30/ru.md) |
| **Enhanced subnet discovery** | подсети с тегом `kubernetes.io/role/cni=1` без `ENIConfig`. | [07](07/ru.md) |
| **ENI** | elastic network interface; число ENI на инстанс и адресов IPv4 на ENI зависит от типа инстанса. | [0.3](00-3-vpc/ru.md), [06](06/ru.md) |
| **Envelope encryption** | шифрование в два ключа: DEK шифрует данные, KEK (ключ KMS) шифрует DEK. EKS применяет его к секретам etcd через Kubernetes KMS provider v2. | [18](18/ru.md) |
| **ephemeral ports** | высокий диапазон `1024-65535`, куда идёт обратный трафик; на NACL его разрешают вручную. | [46](46/ru.md) |
| **eviction threshold** | буфер памяти, ниже которого kubelet вытесняет поды. | [14](14/ru.md) |
| **exec-плагин kubeconfig** | секция `exec`, вызывающая `aws eks get-token`; долгоживущего токена в файле нет, а полученные креды `client-go` кэширует до `status.expirationTimestamp`. | [0.5](00-5-tools/ru.md) |
| **Expander** | стратегия Cluster Autoscaler для выбора node group, когда под подходит в несколько: `least-waste` (дефолт), `priority`, `most-pods`, `random`. | [11](11/ru.md) |
| **Extended support** | фаза после standard (~12 месяцев): версия ещё поддерживается, но за повышенную плату за час кластера; включена по умолчанию. | [03](03/ru.md), [38](38/ru.md) |
| **External Secrets Operator (ESO)** | контроллер, читающий секрет из AWS и создающий из него нативный `Secret`; объекты `SecretStore`/`ClusterSecretStore` и `ExternalSecret`. | [18](18/ru.md) |
| **external-dns** | контроллер, синхронизирующий DNS-записи в провайдере с объектами Kubernetes (Ingress, Service); в AWS работает с Route 53. | [29](29/ru.md) |
| **external.metrics.k8s.io** | API внешних метрик (очереди, топики) для HPA (тип External). | [35](35/ru.md) |
| **externalTrafficPolicy** | политика Service: `Cluster` (пересылка на любую ноду, SNAT) или `Local` (только локальные поды, сохранение client IP). | [26](26/ru.md) |
| **`failed to assign an IP address to container`** | VPC CNI не смог выдать поду IP: кончились адреса на ноде или в подсети. | [46](46/ru.md) |
| **failurePolicy** | реакция на недоступный webhook: `Fail` останавливает admission, `Ignore` пропускает объект мимо проверки. | [22](22/ru.md) |
| **Fargate** | запуск пода на выделенной микро-VM без нод; без DaemonSet, привилегий, `HostNetwork`, GPU и доступа к ноде. Плата за vCPU и память пода. | [09](09/ru.md) |
| **fargate-scheduler** | планировщик EKS, работающий рядом с kube-scheduler и направляющий подходящие под профиль поды на Fargate. | [15](15/ru.md) |
| **Fargate-профиль** | объект уровня кластера с селекторами (namespace плюс опционально labels), pod execution role и приватными подсетями; определяет, какие поды идут на Fargate. Изменить нельзя, только пересоздать. | [15](15/ru.md) |
| **Finding** | находка GuardDuty; уходит в Security Hub и EventBridge для алертинга и реакции. | [21](21/ru.md) |
| **Fluent Bit** | лёгкий форвардер логов на C, запускается DaemonSet'ом на каждой ноде; читает файлы логов, обогащает и отправляет в назначения. | [34](34/ru.md) |
| **Forbidden (403)** | провал авторизации: RBAC не даёт прав на действие. | [47](47/ru.md) |
| **game day** | учения, на которых DR и инцидент-сценарии проверяют на деле. | [48](48/ru.md) |
| **Gatekeeper** | policy engine поверх OPA; правила на Rego, модель `ConstraintTemplate` (шаблон + схема) плюс `Constraint` (экземпляр). | [22](22/ru.md) |
| **Gateway** | точка входа со слушателями (протокол, порт, TLS); владелец - платформенная команда. В VPC Lattice отображается в Service Network. | [28](28/ru.md) |
| **Gateway API** | стандарт Kubernetes для управления трафиком, преемник Ingress: набор типизированных ресурсов с разделением ролей. | [28](28/ru.md) |
| **gateway endpoint** | тип VPC endpoint для S3 и DynamoDB через запись в route table; бесплатен. | [25](25/ru.md), [31](31/ru.md) |
| **GatewayClass** | шаблон реализации с полем `controllerName`; определяет, какой контроллер обработает Gateway (аналог IngressClass). | [28](28/ru.md) |
| **GitOps** | модель, где желаемое состояние описано в Git, а агент непрерывно приводит к нему кластер (принципы формулирует OpenGitOps, проект CNCF). | [44](44/ru.md) |
| **GitOps Toolkit** | набор контроллеров Flux (source, kustomize, helm, image и другие). | [44](44/ru.md) |
| **Golden image** | воспроизводимый кастомный образ, собранный поверх оптимизированного AMI через image builder. | [10](10/ru.md) |
| **graceful node shutdown** | функция kubelet, гасящая поды с grace period при остановке ОС. | [40](40/ru.md) |
| **Grafana Loki** | хранилище логов, индексирующее только метки потока; логи сжаты в чанки в объектном хранилище, запросы на LogQL. Метки должны быть низкокардинальными, для высокой кардинальности есть structured metadata; родной агент - Grafana Alloy (Promtail влит в него). | [34](34/ru.md) |
| **`granted` (`assume`)** | быстрое переключение SSO-профилей и вход в консоль. | [0.5](00-5-tools/ru.md) |
| **Graviton** | процессоры AWS на arm64 (суффикс `g`), требуют multi-arch образов. | [0.4](00-4-ec2/ru.md) |
| **GuardDuty EKS Protection** | анализ EKS audit logs на угрозы через собственный независимый поток GuardDuty, без обязательного включения control plane logging. | [21](21/ru.md) |
| **GuardDuty Runtime Monitoring** | наблюдение за поведением на нодах через агент `aws-guardduty-agent` (eBPF): процессы, сеть, файлы; не поддерживает Fargate и Hybrid Nodes. | [21](21/ru.md) |
| **Hard multi-tenancy** | арендаторы в отдельных кластерах/аккаунтах; жёсткая граница ценой сложности. | [22](22/ru.md) |
| **HashiCorp Vault** | внешнее хранилище секретов не от AWS, занимающее то же место, что Secrets Manager: аутентификация пода через Kubernetes, JWT/OIDC или AWS IAM auth; доставка через Vault Agent Injector, Vault Secrets Operator, ESO или CSI Driver с провайдером Vault. | [18](18/ru.md) |
| **head-based и tail-based sampling** | решение о записи на входе, до исхода запроса, против решения на шлюзе после сборки трейса (политики по ошибкам и задержке). Tail-based требует, чтобы все спаны трейса пришли в один экземпляр коллектора. | [36](36/ru.md) |
| **helmfile** | декларативное описание набора helm-релизов с версиями и values в одном файле. | [0.5](00-5-tools/ru.md) |
| **hop limit (`httpPutResponseHopLimit`)** | число сетевых прыжков ответа IMDS; при 1 под до IMDS не дотягивается, а узел работает. | [19](19/ru.md) |
| **hosted zone** | контейнер DNS-записей домена в Route 53; бывает public (интернет) и private (привязана к VPC). | [29](29/ru.md) |
| **HPA (HorizontalPodAutoscaler)** | контроллер, меняющий число реплик Deployment по метрике. | [35](35/ru.md) |
| **HTTPRoute** | правила маршрутизации по host, path, заголовкам на backend; ссылается на Gateway через `parentRefs`. В VPC Lattice отображается в VPC Lattice Service. | [28](28/ru.md) |
| **hub-and-spoke** | топология с центральным Transit Gateway (хаб) и подключёнными к нему VPC команд (spokes). | [32](32/ru.md) |
| **Hubble** | подсистема наблюдаемости Cilium: карта потоков и per-flow verdict, чего в VPC CNI network policy нет. | [08](08/ru.md), [30](30/ru.md) |
| **IAM Access Analyzer** | находит внешние доверенные сущности (external access) в resource-based политиках и trust policy. | [0.2](00-2-iam/ru.md) |
| **IAM auth policy** | политика в формате IAM для авторизации трафика между сервисами; в контроллере - ресурс `IAMAuthPolicy`. | [28](28/ru.md) |
| **IAM database authentication** | вход в RDS или Aurora по временному токену (`aws rds generate-db-auth-token`, по умолчанию 15 минут) вместо пароля; ротировать нечего. | [18](18/ru.md) |
| **IAM Identity Center** | единый вход и выдача доступа permission set'ами. | [0.1](00-1-aws/ru.md) |
| **IAM OIDC identity provider** | объект IAM, регистрирующий issuer URL кластера; на него ссылаются trust policy ролей. Заводится один раз на кластер. | [16](16/ru.md) |
| **IAM role** | identity без постоянных ключей, которую принимают на время. | [0.2](00-2-iam/ru.md) |
| **IAM user / group** | долгоживущая identity и набор таких identity; в проде избегаются. | [0.2](00-2-iam/ru.md) |
| **idle-ёмкость** | разница между оплаченной ёмкостью нод и реально потреблённым; маркер завышенных requests и плохого bin-packing. | [43](43/ru.md) |
| **image automation** | контроллеры Flux, коммитящие новые теги образов обратно в Git. | [44](44/ru.md) |
| **IMDS** | Instance Metadata Service на `169.254.169.254`; источник метаданных и кредов роли ноды. IMDSv1 - без токена, IMDSv2 - session-based (`PUT`+токен). | [0.2](00-2-iam/ru.md), [0.4](00-4-ec2/ru.md), [19](19/ru.md) |
| **Immutable-параметр** | параметр кластера, который нельзя изменить после создания: `ipFamily`, кастомный `serviceIpv4Cidr`, VPC, имя и роль IAM кластера. | [04](04/ru.md) |
| **In-place upgrade** | обновление того же кластера на следующий минор: control plane, потом аддоны, потом ноды. | [03](03/ru.md), [38](38/ru.md) |
| **in-tree cloud provider** | встроенный в компоненты Kubernetes код AWS, по умолчанию создающий Classic Load Balancer для Service типа LoadBalancer. | [26](26/ru.md) |
| **in-tree провизионер** | встроенный `kubernetes.io/aws-ebs`, deprecated, без `gp3` и снапшотов; дефолтный `gp2` в EKS всё ещё на нём. | [23](23/ru.md) |
| **IngressClass alb** | класс с контроллером `ingress.k8s.aws/alb`; Ingress с `ingressClassName: alb` обрабатывает AWS Load Balancer Controller. | [27](27/ru.md) |
| **IngressGroup** | объединение нескольких Ingress по `group.name` в один общий ALB; `group.order` задаёт приоритет правил. | [27](27/ru.md) |
| **INPUT / FILTER / OUTPUT** | три вида секций конвейера Fluent Bit: чтение, обработка, отправка. | [34](34/ru.md) |
| **`InsufficientCidrBlocks`** | ошибка EC2 API про отсутствие непрерывных блоков при формально свободных адресах. | [07](07/ru.md) |
| **Interface endpoint** | тип VPC endpoint на базе PrivateLink: ENI в подсети, почасовая плата плюс плата за данные. | [31](31/ru.md) |
| **Internet Gateway** | бесплатный шлюз в интернет для публичных адресов. | [0.3](00-3-vpc/ru.md) |
| **involuntary disruption** | неконтролируемое: отказ ноды/AZ, OOM, spot-прерывание; защищается раскладкой, а не PDB. | [40](40/ru.md) |
| **ipamd** | демон внутри `aws-node`, управляющий пулом адресов ноды: привязывает вторичные адреса и создаёт ENI через EC2 API. | [06](06/ru.md) |
| **`ipFamily`** | семейство адресов кластера, задаётся только при создании. | [07](07/ru.md) |
| **IRSA** | IAM Roles for Service Accounts: выдача IAM-роли поду через привязанный `ServiceAccount` на основе OIDC federation. | [0.2](00-2-iam/ru.md), [16](16/ru.md), [47](47/ru.md) |
| **Karpenter** | автоскейлер нод, создающий EC2-инстансы напрямую под конкретные неразмещённые поды и сам подбирающий тип из разрешённого диапазона. | [11](11/ru.md) |
| **KEDA** | надстройка событийного автомасштабирования: ставит метрики в HPA и управляет им. | [35](35/ru.md) |
| **`kms:CreateGrant`** | право, без которого драйвер создаст том со своим CMK, но не примонтирует его: шифрование EBS идёт через гранты, разрешение нужно и в политике ключа. | [23](23/ru.md) |
| **krew** | менеджер плагинов: индекс, `search`, `install`, `upgrade`; поддерживает свои индексы. | [0.5](00-5-tools/ru.md) |
| **kube-prometheus-stack** | Helm-чарт с Prometheus Operator, Prometheus, Grafana, Alertmanager, node-exporter и kube-state-metrics. | [33](33/ru.md) |
| **`kube-reserved` / `system-reserved`** | ресурсы, зарезервированные kubelet под Kubernetes и под ОС. | [14](14/ru.md) |
| **kube-state-metrics** | компонент, отдающий состояние объектов Kubernetes (Pending, реплики, рестарты) в виде метрик. | [33](33/ru.md) |
| **Kubecost** | продукт на базе OpenCost с UI, отчётами и рекомендациями; на EKS есть EKS-optimized bundle (add-on или Helm). | [43](43/ru.md) |
| **`kubectl plugin list`** | что kubectl видит в `PATH`. | [0.5](00-5-tools/ru.md) |
| **`kubeProxyReplacement`** | режим Cilium, где Service/NodePort балансирует eBPF вместо kube-proxy; `true` включает замену. Требует свежего ядра и владения балансировкой. | [08](08/ru.md) |
| **Kustomization / HelmRelease** | CRD Flux: что и куда применять из источника. | [44](44/ru.md) |
| **Kyverno** | policy engine, где политика это YAML-ресурс (`ClusterPolicy`/`Policy`) с правилами validate/mutate/generate/verifyImages; реакция - `Enforce`/`Audit`. | [22](22/ru.md) |
| **Landing zone** | преднастроенная многоаккаунтная структура (management, shared services, среды, команды); разворачивается в том числе через AWS Control Tower. | [0.1](00-1-aws/ru.md), [32](32/ru.md) |
| **Launch template** | версионируемый шаблон инстанса (AMI, тип, диск, SG, user data, IMDS); managed node group всегда разворачивается через него. | [10](10/ru.md) |
| **Launch template / Auto Scaling group** | версионируемый шаблон запуска / группа инстансов с `min`, `desired`, `max` по подсетям AZ. | [0.4](00-4-ec2/ru.md) |
| **Lifecycle policy** | правила автоудаления образов по возрасту или количеству. | [20](20/ru.md) |
| **limits** | верхний предел потребления контейнера. | [14](14/ru.md) |
| **log group / log stream** | группа (обычно на приложение) и поток внутри неё (обычно на под) в CloudWatch Logs. | [34](34/ru.md) |
| **Managed / inline policy** | переиспользуемая версионируемая политика / встроенная в роль. | [0.2](00-2-iam/ru.md) |
| **Managed addon (EKS managed addon)** | курируемый AWS компонент кластера (VPC CNI, CoreDNS, kube-proxy, CSI), версией которого управляет EKS через свой API. | [0.5](00-5-tools/ru.md), [01](01/ru.md), [37](37/ru.md) |
| **managed collector (scraper)** | управляемый агентless-сборщик AMP, скрейпит метрики EKS и пишет в workspace через remote-write. | [33](33/ru.md) |
| **managed fields / server-side apply** | механизм, которым аддон объявляет и применяет свои поля; на нём основано разрешение конфликтов. | [37](37/ru.md) |
| **Managed node group** | группа EC2 под управлением EKS: ASG и launch template ведёт AWS, обновление с drain по команде, но ОС и содержимое ноды на вас. | [01](01/ru.md), [09](09/ru.md) |
| **Management account** | корневой аккаунт-плательщик, нагрузки в нём не держат. | [0.1](00-1-aws/ru.md) |
| **`matchLabelKeys`** | ключи меток пода, добавляемые к `labelSelector` ограничения раскладки; с `pod-template-hash` перекос считается внутри одной ревизии Deployment. | [40](40/ru.md) |
| **max-pods** | лимит подов на ноде: `ENI * (IP на ENI - 1) + 2`, у managed node groups ограничен сверху (110 или 250). | [0.4](00-4-ec2/ru.md), [06](06/ru.md), [46](46/ru.md) |
| **maxSkew** | допустимый перекос числа подов между самым полным и самым пустым доменом. | [40](40/ru.md) |
| **`memory_limiter`** | процессор Collector, ограничивающий расход памяти: на пороге он отказывает в приёме данных вместо того, чтобы уйти в `OOMKilled`; ставится первым. | [36](36/ru.md) |
| **metric_relabel_configs** | секция scrape config (в ServiceMonitor - `metricRelabelings`), отбрасывающая высококардинальные метрики (`drop` по `__name__`) и лейблы (`labeldrop`) до записи и remote-write; инструмент контроля объёма и стоимости. | [33](33/ru.md) |
| **Metrics API (`metrics.k8s.io`)** | Kubernetes API текущих метрик ресурсов, источник для `kubectl top` и HPA по resource metrics. | [33](33/ru.md), [35](35/ru.md) |
| **metrics-server** | компонент, собирающий CPU и память с kubelet и отдающий их через Metrics API для `kubectl top` и HPA; без истории и хранения. | [33](33/ru.md) |
| **mount target** | сетевой интерфейс EFS в подсети конкретной AZ; точка входа для нод этой зоны, по одному на зону доступности. | [24](24/ru.md) |
| **Mountpoint for Amazon S3** | клиент, отдающий объекты бакета через файловый интерфейс; основа CSI-драйвера. | [25](25/ru.md) |
| **Mountpoint S3 CSI-драйвер** | `aws-mountpoint-s3-csi-driver`, managed addon с провизионером `s3.csi.aws.com`; только статический провижининг. | [25](25/ru.md) |
| **must have** | пункт, без которого выход в прод опасен и должен быть заблокирован. | [48](48/ru.md) |
| **NACL** | stateless-фильтр на уровне подсети; входящие и исходящие правила независимы. | [46](46/ru.md) |
| **namespace restore** | точечное восстановление до 5 namespace в существующий кластер без cluster-scoped ресурсов (кроме связанных PV). | [42](42/ru.md) |
| **NAT Gateway** | управляемый AWS сервис трансляции адресов, дающий приватным подсетям исходящий доступ в интернет; тарифицируется почасово и за обработанные гигабайты. | [0.3](00-3-vpc/ru.md), [31](31/ru.md) |
| **`ndots:5`** | настройка resolv.conf подов, из-за которой имена перебирают search-домены. | [46](46/ru.md) |
| **nested (child) recovery point** | вложенная точка внутри composite: состояние кластера или отдельный том. | [41](41/ru.md) |
| **Network ACL** | stateless фильтр на подсети, allow и deny по номерам правил. | [0.3](00-3-vpc/ru.md) |
| **`NETWORK_POLICY_ENFORCING_MODE`** | режим применения политик при старте пода: `standard` (default allow, есть окно без политик) или `strict` (default deny). | [08](08/ru.md), [30](30/ru.md) |
| **NetworkPolicy** | стандартный объект Kubernetes, декларирующий разрешённый ingress и egress для подов; сам по себе ничего не блокирует без enforcer'а. | [30](30/ru.md) |
| **nice to have** | пункт, повышающий зрелость, который допустимо доводить уже в проде. | [48](48/ru.md) |
| **NLB (Network Load Balancer)** | балансировщик L4 (TCP/UDP), высокая производительность, статические IP; создаётся LBC из Service типа LoadBalancer. | [26](26/ru.md) |
| **node instance role** | IAM-роль, которую принимает EC2-нода; с неё kubelet ходит в AWS API. | [45](45/ru.md) |
| **Node Termination Handler (NTH)** | компонент AWS для обработки прерываний на managed и self-managed нодах без Karpenter; режимы IMDS и Queue Processor. | [13](13/ru.md) |
| **nodeadm** | инициализатор ноды на AL2023 и Bottlerocket; вход - YAML-манифест `NodeConfig` (`apiVersion: node.eks.aws/v1alpha1`), замена скрипту `bootstrap.sh`. | [10](10/ru.md), [45](45/ru.md) |
| **NodeClaim** | заявка Karpenter на конкретную ноду; связывает `NodePool` и реальный `Node`. | [12](12/ru.md) |
| **NodeCreationFailure** | health issue managed node group: ноды не подключились к кластеру за 15 минут после запуска. | [45](45/ru.md) |
| **NodeLocal DNSCache** | локальный кэширующий DNS на ноде, снимает нагрузку с CoreDNS и per-ENI троттлинг. | [46](46/ru.md) |
| **NodePool** | CRD (`karpenter.sh/v1`), задающий границы нод: `requirements`, `limits`, `weight`, labels/taints, политику disruption. | [12](12/ru.md) |
| **NodePool и NodeClass** | объекты, описывающие, какие ноды и как поднимать; в Auto Mode дефолтные неизменяемы, свои добавлять можно. | [09](09/ru.md) |
| **non-destructive restore** | режим, при котором существующие объекты не перезаписываются, а пропускаются (пропуски видны через SNS). | [42](42/ru.md) |
| **NotReady при живом kubelet** | обычно CNI не готов, подам не выдаются IP. | [45](45/ru.md) |
| **OIDC issuer URL** | публичный OIDC-endpoint кластера (`oidc.eks.<region>.amazonaws.com/id/`) с публичными ключами подписи projected-токенов. | [16](16/ru.md) |
| **On-demand / Spot** | оплата по факту / мощности со скидкой и прерыванием за две минуты. | [0.4](00-4-ec2/ru.md) |
| **OOMKilled** | убийство контейнера ядром при превышении memory limit. | [14](14/ru.md) |
| **OpenCost** | открытый вендонейтральный стандарт и движок аллокации стоимости, проект CNCF; берёт потребление из Prometheus и цены ресурсов AWS. | [43](43/ru.md) |
| **OpenSearch Service** | управляемый OpenSearch для полнотекстового поиска и дашбордов; оплата за кластер (ноды). | [34](34/ru.md) |
| **OpenTelemetry (OTel)** | стандарт CNCF: единые API, SDK и протокол; разделяет инструментирование и бэкенд. | [36](36/ru.md) |
| **OpenTelemetry Collector** | сборщик: receivers принимают, processors обрабатывают, exporters выгружают телеметрию в бэкенды. | [36](36/ru.md) |
| **OpenTelemetry Operator** | оператор, делающий авто-инструментирование инъекцией агента в под. | [36](36/ru.md) |
| **OpenTofu** | открытый форк terraform, совместимый с модулями курса; выбирается атрибутом `terraform_binary = "tofu"`. | [0.5](00-5-tools/ru.md) |
| **OTLP** | протокол передачи телеметрии от приложения к collector и между collector'ами. | [36](36/ru.md) |
| **OU** | группа аккаунтов, к которой применяют политики. | [0.1](00-1-aws/ru.md) |
| **ownership** | закреплённая ответственность за домен или пункт чеклиста. | [48](48/ru.md) |
| **Permissions boundary** | потолок прав для роли или пользователя, права не выдаёт. | [0.2](00-2-iam/ru.md) |
| **Placement group** | управление размещением инстансов: `cluster` (рядом, минимальная задержка, одна AZ), `partition` (разные стойки по партициям, до 7 на AZ), `spread` (каждый на своём железе, не больше 7 работающих на AZ). | [0.4](00-4-ec2/ru.md) |
| **`placementGroupSelector`** | поле своего `NodeClass`, выбирающее placement group по имени или id. Группу создают заранее сами; принадлежность пода к группе задают `nodeSelector` по метке `eks.amazonaws.com/placement-group-id`. | [09](09/ru.md), [12](12/ru.md) |
| **Platform version** | patch-уровень и набор возможностей control plane EKS внутри минорной версии Kubernetes, формат `eks.<n>`, обновляется AWS автоматически. | [01](01/ru.md), [02](02/ru.md) |
| **pluto / kube-no-trouble (kubent)** | инструменты поиска устаревших API: pluto в Git и Helm, kubent в живом кластере. | [38](38/ru.md) |
| **Pod execution role** | IAM-роль, с которой `kubelet` на подложке Fargate регистрируется в кластере и тянет образы из ECR; задаётся при создании профиля. От неё же встроенный log router пишет логи в приёмник, поэтому права на запись логов нужны именно ей. | [15](15/ru.md) |
| **Pod Identity association** | запись в API EKS, связывающая `кластер + namespace + ServiceAccount` с IAM-ролью; создаётся `aws eks create-pod-identity-association`. | [17](17/ru.md), [37](37/ru.md) |
| **pod readiness gate** | дополнительное условие готовности пода; AWS Load Balancer Controller держит `target-health.elbv2.k8s.aws` ложным, пока target не станет `healthy`. | [40](40/ru.md) |
| **Pod Security Admission (PSA)** | встроенный admission-контроллер, применяющий Pod Security Standards на namespace через лейблы; заменил Pod Security Policies. | [19](19/ru.md) |
| **Pod Security Standards** | профили privileged, baseline, restricted (строгий, для прода). | [19](19/ru.md) |
| **`POD_SECURITY_GROUP_ENFORCING_MODE`** | `strict` без source NAT против `standard`, где за VPC трафик идёт с primary ENI под правилами SG ноды. | [46](46/ru.md) |
| **PodDisruptionBudget (PDB)** | объект, ограничивающий число одновременно выселяемых подов при добровольных нарушениях (`minAvailable`/`maxUnavailable`). | [40](40/ru.md) |
| **`pods.eks.amazonaws.com`** | принципал сервиса в trust policy роли Pod Identity; общий для всех кластеров и аккаунтов. Креды роли выдаёт EKS Auth API по `AssumeRoleForPodIdentity`. | [17](17/ru.md) |
| **Policy** | JSON с `Version`, `Statement`, `Effect`, `Action`, `Resource`, `Condition`; бывает identity-based (на принципале) и resource-based (на самом ресурсе). | [0.2](00-2-iam/ru.md) |
| **Policy engine** | admission webhook с вашими правилами (Kyverno, Gatekeeper); проверяет и при необходимости меняет объекты по правилам до записи в etcd. | [22](22/ru.md) |
| **`pollingInterval` и `cooldownPeriod`** | период опроса источника KEDA (по умолчанию 30 с) и ожидание перед уходом в ноль (по умолчанию 300 с); второй действует только для scale-to-zero. | [35](35/ru.md) |
| **Prefix delegation** | режим, где слот на ENI занимает префикс `/28` (16 адресов); включается `ENABLE_PREFIX_DELEGATION`, требует Nitro. | [07](07/ru.md), [46](46/ru.md) |
| **preserve_client_ip** | атрибут target group NLB, управляющий сохранением исходного IP клиента в режиме `ip`. | [26](26/ru.md) |
| **preStop** | hook, выполняемый до SIGTERM; используется для паузы перед остановкой. | [40](40/ru.md) |
| **Principal** | тот, кто выполняет запрос: пользователь, роль, сервис AWS. | [0.2](00-2-iam/ru.md) |
| **private / public endpoint** | режим доступа к API-серверу кластера. | [45](45/ru.md) |
| **Private hosted zone** | зона Route 53, которую EKS создаёт и связывает с вашим VPC, чтобы имя endpoint разрешалось в приватный адрес. | [02](02/ru.md) |
| **Projected service account token** | OIDC-совместимый JWT с идентичностью SA, audience `sts.amazonaws.com` и сроком жизни; монтируется в под и обменивается в STS на креды. | [16](16/ru.md) |
| **prometheus-adapter** | адаптер, публикующий метрики Prometheus в custom/external API. | [35](35/ru.md) |
| **provisioningMode: efs-ap** | режим StorageClass, при котором драйвер создаёт access point на каждый PVC. | [24](24/ru.md) |
| **`publicAccessCidrs`** | список CIDR, которым разрешён публичный endpoint; по умолчанию `0.0.0.0/0`. | [02](02/ru.md) |
| **Pull through cache** | правило ECR, кэширующее образы внешнего реестра (Docker Hub, Quay, `registry.k8s.io` и др.) в вашем приватном ECR по запросу. | [20](20/ru.md) |
| **pull-модель** | агент внутри кластера сам тянет из Git; push - внешний пайплайн. | [44](44/ru.md) |
| **QoS-класс** | `Guaranteed`, `Burstable` или `BestEffort`; задаёт порядок вытеснения при нехватке памяти. | [14](14/ru.md) |
| **ReadWriteMany (RWX)** | access mode: том монтируется на запись многими подами на многих нодах одновременно. | [24](24/ru.md) |
| **Rebalance recommendation** | ранний сигнал о повышенном риске изъятия, приходящий раньше двухминутного уведомления; даёт время увести нагрузку заранее. | [13](13/ru.md) |
| **recovery point** | точка восстановления, результат успешного backup job. | [41](41/ru.md) |
| **ReferenceGrant** | ресурс Gateway API в namespace целевого ресурса; разрешает кросс-namespace ссылки (`backendRefs`, `certificateRefs`) из перечисленных namespace. | [28](28/ru.md) |
| **Replication configuration** | правила ECR, копирующие образы в другие регионы и аккаунты; для cross-account аккаунт-получатель разрешает источнику `ecr:CreateRepository` и `ecr:ReplicateImage` в своей registry policy. | [20](20/ru.md) |
| **Repository creation template** | шаблон настроек (шифрование, lifecycle, immutability, policy) для репозиториев, которые ECR создаёт сам под pull through cache по префиксу; без него кэш-репозиторий получает дефолты (`MUTABLE`, SSE-S3, без политик). | [20](20/ru.md) |
| **Repository policy / registry policy** | resource-based политики на один репозиторий и на весь registry аккаунта; в них работает `aws:PrincipalOrgID`, поэтому pull выдаётся сразу всей организации. | [20](20/ru.md), [32](32/ru.md) |
| **requests** | объём ресурсов, по которому идут упаковка и решение автоскейлера; резерв за подом. | [14](14/ru.md) |
| **resolveConflicts** | как аддон поступает при конфликте полей: `NONE`, `OVERWRITE`, `PRESERVE`. | [37](37/ru.md) |
| **Resource Modifiers** | ConfigMap Velero с JSON-патчами к объектам на момент restore (`--resource-modifier-configmap`); чем снимают несовместимые с целевым кластером поля. | [42](42/ru.md) |
| **ResourceQuota / LimitRange** | лимит суммарного потребления namespace и дефолты/границы на отдельный контейнер соответственно. | [22](22/ru.md) |
| **restore hook** | init-контейнер или exec-команда, запускаемая Velero при restore пода. | [42](42/ru.md) |
| **restore job** | задача восстановления в AWS Backup; запускается `start-restore-job`, отслеживается `list-restore-jobs`/`describe-restore-job`. | [42](42/ru.md) |
| **retention policy** | срок хранения логов в log group, по истечении которого записи удаляются; по умолчанию логи не истекают. | [34](34/ru.md) |
| **right-sizing** | приведение requests/limits к реальному потреблению для уплотнения нод. | [14](14/ru.md), [43](43/ru.md) |
| **rollback readiness** | готовность к откату версии: известны окно и порядок. | [48](48/ru.md) |
| **rollback readiness insights** | тип cluster insights в категории `ROLLBACK_READINESS`, проверяющий готовность к откату; статусы PASSING/WARNING/ERROR/UNKNOWN. | [39](39/ru.md) |
| **Root-пользователь** | владелец аккаунта с неограниченными правами, нужен только при первичной настройке. | [0.1](00-1-aws/ru.md) |
| **Route 53 Resolver** | встроенный DNS VPC по адресу «CIDR плюс 2», upstream для CoreDNS. | [0.3](00-3-vpc/ru.md) |
| **Route table** | таблица маршрутов подсети; публичная и приватная подсеть отличаются только маршрутом по умолчанию. | [0.3](00-3-vpc/ru.md) |
| **RPO** | допустимый объём потери данных; задаётся частотой бэкапа. | [42](42/ru.md) |
| **RTO** | целевое время восстановления сервиса после аварии. | [42](42/ru.md) |
| **S3 Express One Zone** | зональный класс хранения (directory buckets) с низкой задержкой и высоким IOPS в одной AZ; в отличие от general purpose бакетов поддерживает `append`. | [25](25/ru.md) |
| **S3 Object Lock** | WORM-защита S3-бакета: неизменяемость версий объектов на срок retention (Governance/Compliance), защищает бэкапы Velero от удаления и шифрования. | [42](42/ru.md) |
| **sampling** | запись не всех трейсов, а доли, для контроля объёма и стоимости. | [36](36/ru.md) |
| **sampling rules** | правила X-Ray, задающие долю записываемых запросов через reservoir и fixed rate. | [36](36/ru.md) |
| **Savings Plans / RI** | скидка 30-70% за обязательство на 1 или 3 года. | [0.4](00-4-ec2/ru.md) |
| **scale-to-zero** | опускание Deployment до нуля реплик в простое; умеет KEDA, HPA нет. | [35](35/ru.md) |
| **ScaledJob** | CRD KEDA для масштабирования числа параллельных Job под порции работы. | [35](35/ru.md) |
| **ScaledObject** | CRD KEDA, описывающий цель масштабирования и триггеры для Deployment. | [35](35/ru.md) |
| **scaler** | источник метрики KEDA: `aws-sqs-queue`, `aws-cloudwatch`, `prometheus`, `kafka`, `cron` и десятки других. | [35](35/ru.md) |
| **Schedule** | объект Velero для периодического backup по cron; задаёт RPO. | [42](42/ru.md) |
| **SCP (Service Control Policy)** | политика-ограничитель на OU или аккаунт: задаёт максимум прав и сама ничего не разрешает. | [0.1](00-1-aws/ru.md), [0.2](00-2-iam/ru.md) |
| **Secondary CIDR** | дополнительный блок IPv4 у VPC; для EKS обычно из `100.64.0.0/10` (RFC 6598). | [07](07/ru.md) |
| **Secrets Store CSI Driver + AWS provider (ASCP)** | драйвер, монтирующий секрет из AWS как файлы в томе на ноде; объект `SecretProviderClass`, опциональный sync в `Secret`. | [18](18/ru.md) |
| **Security group** | stateful firewall на ENI, только allow, источником может быть другая SG. | [0.3](00-3-vpc/ru.md), [46](46/ru.md) |
| **`SecurityGroupPolicy`** | ресурс, привязывающий SG к подам по селектору (security groups for pods); под с branch ENI перестаёт наследовать правила SG ноды. | [46](46/ru.md) |
| **self-heal** | автоматический откат дрейфа к состоянию из Git. | [44](44/ru.md) |
| **self-managed addon** | компонент, установленный Helm-ом или манифестом; жизненный цикл и совместимость целиком на инженере. | [37](37/ru.md) |
| **Self-managed node** | EC2-инстанс, который вы сами поднимаете и присоединяете (access entry типа `EC2_LINUX`); весь жизненный цикл ноды на вас. | [09](09/ru.md) |
| **service map** | карта сервисов и связей с задержкой и долей ошибок на рёбрах. | [36](36/ru.md) |
| **Service Network** | граница VPC Lattice для набора сервисов; VPC клиентов ассоциируют с ней для доступа к сервисам. | [28](28/ru.md) |
| **Service Quotas** | лимиты сервисов на аккаунт и регион, повышаются по запросу. | [0.1](00-1-aws/ru.md) |
| **`serviceIpv4Cidr`** | диапазон адресов Service, виртуальный и не связанный с VPC. | [06](06/ru.md) |
| **ServiceMonitor, PodMonitor** | CRD Prometheus Operator, декларативно описывающие, какие эндпоинты скрейпить. | [33](33/ru.md) |
| **Session tags** | теги сессии (кластер, namespace, SA), которые Pod Identity добавляет в запрос к STS и на которых строят ABAC; в политиках - `aws:PrincipalTag/kubernetes-namespace` и `aws:PrincipalTag/eks-cluster-name`; требуют `sts:TagSession` в trust policy. | [17](17/ru.md) |
| **shared costs** | общие затраты кластера (control plane, системные namespace, idle), разносимые на команды по правилу или показываемые отдельно. | [43](43/ru.md) |
| **Shared responsibility** | AWS отвечает за безопасность облака, вы - в облаке. | [0.1](00-1-aws/ru.md), [01](01/ru.md) |
| **shared services account** | аккаунт с общими ресурсами (ECR, приватные зоны DNS, наблюдаемость), которыми пользуются остальные аккаунты. | [32](32/ru.md) |
| **shared VPC** | модель, где владелец шарит subnets через RAM, а другие аккаунты запускают в них свои ресурсы, включая ноды EKS. | [32](32/ru.md) |
| **showback** | командам показывают их стоимость без движения денег. | [43](43/ru.md) |
| **SNAT** | подмена адреса источника на адрес ноды для исходящего трафика подов, выключается переменной `AWS_VPC_K8S_CNI_EXTERNALSNAT`. | [06](06/ru.md) |
| **Soft multi-tenancy** | арендаторы в одном кластере (namespace, RBAC, ResourceQuota, LimitRange, NetworkPolicy, политики); общий control plane и ядро. | [22](22/ru.md) |
| **span** | отдельная операция внутри трейса (обработка, вызов, запрос в базу) со временем и атрибутами; из span складывается дерево трейса. | [36](36/ru.md) |
| **split-horizon DNS** | одно имя с разными ответами снаружи и изнутри VPC через пару public и private зон. | [29](29/ru.md) |
| **Spot interruption notice** | уведомление о прерывании за две минуты до остановки или завершения инстанса; жёсткая рамка на корректное завершение. | [13](13/ru.md) |
| **Spot-инстанс** | свободная ёмкость EC2 со скидкой, которую AWS может отозвать в любой момент, когда она понадобится под on-demand-спрос. | [13](13/ru.md) |
| **Spot-пул** | связка «тип инстанса + зона доступности»; ёмкость отзывается пулами. | [13](13/ru.md) |
| **ssl-redirect** | аннотация, включающая редирект HTTP на HTTPS на указанный порт listener'а. | [27](27/ru.md) |
| **SSM Session Manager** | доступ на инстанс без SSH через агента SSM. | [45](45/ru.md) |
| **Staging labels** | метки версий секрета в Secrets Manager: `AWSCURRENT` читается по умолчанию, `AWSPENDING` - значение на проверке при ротации, `AWSPREVIOUS` - предыдущее. | [18](18/ru.md) |
| **Stakater Reloader** | контроллер, делающий rolling restart Deployment по аннотации при изменении примонтированных `Secret` или `ConfigMap`, чтобы под подхватил новое значение. | [18](18/ru.md) |
| **Standard support** | фаза поддержки минорной версии в EKS (~14 месяцев), обычная работа без доплаты за версию. | [03](03/ru.md), [38](38/ru.md), [48](48/ru.md) |
| **State** | файл соответствия между кодом Terraform и реальными ресурсами; хранится в S3 с версионированием и блокировкой записи. | [0.5](00-5-tools/ru.md), [04](04/ru.md) |
| **stdout/stderr** | стандартные потоки вывода контейнера; по конвенции Kubernetes приложение пишет логи туда, а не в файлы внутри контейнера. | [34](34/ru.md) |
| **STS** | сервис временных ключей; `sts:AssumeRole`, `sts:AssumeRoleWithWebIdentity`. | [0.2](00-2-iam/ru.md) |
| **Subnet CIDR reservation** | резервирование непрерывного блока внутри подсети под префиксы. | [07](07/ru.md) |
| **subnet IP exhaustion** | в подсети не осталось свободных адресов под ENI и поды. | [46](46/ru.md) |
| **sync waves** | порядок применения ресурсов в Argo CD по волнам внутри фаз sync. | [44](44/ru.md) |
| **Tag immutability** | режим репозитория `IMMUTABLE`, запрещающий перезапись тега другим образом; `MUTABLE` (по умолчанию) перезапись разрешает. | [20](20/ru.md) |
| **target EKS cluster** | существующий кластер, в который идёт restore; либо создаётся AWS Backup в рамках restore (`newCluster=true`). | [42](42/ru.md) |
| **target-type** | тип таргета NLB: `instance` (через `NodePort` ноды) или `ip` (прямо на IP пода, нужен VPC CNI, обязателен на Fargate). | [26](26/ru.md), [27](27/ru.md) |
| **`terminationGracePeriod`** | предел дренажа ноды; при его наличии drift идёт даже через блокирующие PDB и `do-not-disrupt`. | [12](12/ru.md) |
| **terminationGracePeriodSeconds** | время между SIGTERM и SIGKILL для завершения пода (по умолчанию 30). | [40](40/ru.md) |
| **terragrunt** | обёртка над terraform: общий backend, `env.hcl`, `dependency`, `run-all`, DRY-модули без копипасты. | [0.5](00-5-tools/ru.md) |
| **Thanos** | набор компонентов, добавляющий Prometheus долгое хранение в объектном хранилище: `sidecar` выгружает блоки в S3, `store gateway` читает их обратно, `compactor` компактит, делает downsampling и применяет retention, `querier` даёт единый PromQL и дедупликацию HA-пар, `ruler` считает правила по истории. | [33](33/ru.md) |
| **throughput mode** | режим пропускной способности EFS: Elastic, Bursting или Provisioned. | [24](24/ru.md) |
| **topology aware routing** | предпочтение endpoint'ов в зоне клиента; включается полем `trafficDistribution: PreferClose` в Service. | [31](31/ru.md) |
| **topologySpreadConstraints** | поле пода для равномерной раскладки реплик по доменам (`maxSkew`, `topologyKey`, `whenUnsatisfiable`, `minDomains`). | [40](40/ru.md) |
| **trace** | весь путь одного запроса через сервисы, с общим `trace id`. | [36](36/ru.md) |
| **Transit Gateway** | региональный маршрутизатор-хаб с транзитивной маршрутизацией между подключёнными VPC, VPN и Direct Connect; шарится через RAM. | [32](32/ru.md) |
| **TriggerAuthentication** | CRD KEDA с параметрами доступа триггера, для AWS - провайдер `aws` через IRSA или Pod Identity. | [35](35/ru.md) |
| **Trust policy** | политика доверия роли: `Federated`-принципал (ARN OIDC-провайдера), `Action` `sts:AssumeRoleWithWebIdentity` и условия `StringEquals` на `sub` и `aud`. | [0.2](00-2-iam/ru.md), [16](16/ru.md), [47](47/ru.md) |
| **TXT-реестр** | механизм external-dns, помечающий свои записи TXT-маркером; владельца задаёт `--txt-owner-id`. | [29](29/ru.md) |
| **Unauthorized (401)** | провал аутентификации: identity не доказана или не замаплена. | [47](47/ru.md) |
| **`unhealthyPodEvictionPolicy`** | поле PDB: `IfHealthyBudget` (по умолчанию) не даёт выселять нездоровые поды при уже нарушенном приложении, `AlwaysAllow` разрешает всегда. | [40](40/ru.md) |
| **upgrade insights** | тип insights, флагующий готовность к апгрейду и удаляемые API. | [38](38/ru.md) |
| **Upgrade policy (`supportType`)** | поле конфигурации кластера со значениями `STANDARD` и `EXTENDED`, определяющее поведение в конце стандартной поддержки. Extended support включён по умолчанию; выйти из него переключением политики нельзя, только апгрейдом. | [03](03/ru.md) |
| **`useCachedMetrics` и `fallback`** | кэширование значения в пределах интервала опроса и число реплик на случай недоступного источника; вместе снижают риск троттлинга API и `<unknown>` в `TARGETS`. | [35](35/ru.md) |
| **User data** | скрипт или конфиг, выполняемый при первом старте инстанса; запускает bootstrap и настраивает `kubelet`. | [0.4](00-4-ec2/ru.md), [10](10/ru.md) |
| **ValidatingAdmissionPolicy** | встроенная в apiserver валидация на CEL (Kubernetes 1.30+), без внешнего webhook; пара с `ValidatingAdmissionPolicyBinding` (к чему применить и реакция `Deny`/`Warn`/`Audit`). | [22](22/ru.md) |
| **Vault Lock** | WORM-защита vault от удаления бэкапов; governance mode (снимается по IAM) и compliance mode (неизменяем после grace time). | [41](41/ru.md) |
| **Velero** | Kubernetes-native backup/restore; объекты в S3 (BackupStorageLocation), тома через CSI snapshots или File System Backup. | [42](42/ru.md) |
| **velero-plugin-for-aws** | официальный плагин Velero для AWS: object store для S3 (BSL) и volume snapshotter для снапшотов EBS. | [42](42/ru.md) |
| **Version skew** | допустимое upstream-политикой отставание kubelet от API-сервера; причина порядка «сначала control plane, потом ноды». | [03](03/ru.md), [37](37/ru.md) |
| **version skew policy** | правило Kubernetes: ноды не новее control plane; диктует порядок отката (сначала ноды, потом control plane). | [38](38/ru.md), [39](39/ru.md) |
| **VersionRollback** | тип обновления в ответе `update-cluster-version` при откате. | [39](39/ru.md) |
| **VictoriaLogs** | беззависимостная база логов без схемы и настройки индексов; колоночное хранение на диске, запросы на LogsQL, приём по протоколам Elasticsearch bulk, Loki push, OTLP и syslog; есть кластерный вариант (`vlinsert`, `vlstorage`, `vlselect`). | [34](34/ru.md) |
| **VictoriaMetrics** | замена хранилища метрик, а не надстройка: `vmagent` для сбора, `vmsingle` или кластер `vminsert`/`vmstorage`/`vmselect`, `vmalert` для правил, срок хранения флагом `-retentionPeriod`, язык MetricsQL как расширение PromQL. | [33](33/ru.md) |
| **volume node affinity conflict** | событие планировщика, когда `nodeAffinity` тома указывает на зону без подходящей ноды. | [23](23/ru.md) |
| **`volumeBindingMode`** | когда провизионится том: `Immediate` (при появлении PVC) или `WaitForFirstConsumer` (при планировании пода). | [23](23/ru.md) |
| **VolumeSnapshot / Content / Class** | объекты CSI-снапшотов: запрос, снапшот в AWS, класс. | [23](23/ru.md) |
| **voluntary disruption** | осознанное выселение подов: drain, апгрейд нод, консолидация; защищается PDB. | [40](40/ru.md) |
| **VPC** | изолированная сеть в регионе; основной CIDR (`/16` ... `/28`) неизменяем, расширяется только secondary CIDR. | [0.3](00-3-vpc/ru.md) |
| **VPC CNI** | плагин сети от AWS, назначающий подам реальные приватные адреса из подсетей VPC; DaemonSet `aws-node` в `kube-system`. | [06](06/ru.md) |
| **VPC CNI network policy** | встроенная реализация `NetworkPolicy` на eBPF: контроллер в control plane плюс агент `aws-network-policy-agent` в `aws-node`; включается параметром аддона `enableNetworkPolicy`. | [08](08/ru.md), [30](30/ru.md) |
| **VPC endpoint** | приватный доступ к сервису AWS: gateway (S3, DynamoDB) или interface (PrivateLink). | [0.3](00-3-vpc/ru.md), [31](31/ru.md) |
| **VPC endpoint (PrivateLink)** | приватная точка входа к сервису AWS внутри VPC; для приватного узла данных обязательна для ECR, S3, STS, EKS и других. | [19](19/ru.md) |
| **VPC Flow Logs** | запись принятых и отклонённых потоков; фильтр `action = REJECT` в CloudWatch Logs Insights - инструмент SecOps и диагностики. | [0.3](00-3-vpc/ru.md) |
| **VPC Lattice** | управляемый сервис прикладной сети для east-west связи между VPC и аккаунтами без сайдкаров и пиринга. | [28](28/ru.md) |
| **VPC peering** | прямое соединение двух VPC один-к-одному; не транзитивно, требует непересекающихся CIDR. | [32](32/ru.md) |
| **wafv2-acl-arn** | аннотация привязки Web ACL из AWS WAF v2 к ALB для фильтрации запросов. | [27](27/ru.md) |
| **warm-пул** | запас заранее выданных адресов IPv4 на ноде ради быстрого запуска подов. | [06](06/ru.md) |
| **`WARM_PREFIX_TARGET`** | запас префиксов на ноде, `WARM_IP_TARGET` и `MINIMUM_IP_TARGET` имеют над ним приоритет. | [07](07/ru.md) |
| **workspace** | изолированное хранилище метрик в AMP с собственным remote-write endpoint и Prometheus-совместимым API. | [33](33/ru.md) |
| **X-Amzn-Trace-Id** | заголовок X-Ray с полями `Root`, `Parent`, `Sampled`; ADOT X-Ray propagator сопоставляет его с W3C `traceparent`, сохраняя сквозной `trace id`. | [36](36/ru.md) |
| **ZoneId (`euc1-az1`)** | стабильное имя зоны доступности, одинаковое во всех аккаунтах. | [0.1](00-1-aws/ru.md) |
| **аддон `adot`** | управляемый аддон EKS, разворачивающий ADOT Operator для управления collector'ами. | [36](36/ru.md) |
| **Аккаунт** | изолированное пространство ресурсов и единица биллинга; 12-значный номер участвует в ARN и trust policy. | [0.1](00-1-aws/ru.md) |
| **Вторичный приватный адрес** | дополнительный адрес IPv4 на ENI ноды, который выдаётся поду. | [06](06/ru.md) |
| **Диверсификация** | множество типов инстансов в нескольких AZ, чтобы изъятие одного пула не выбивало критичную долю нод. | [13](13/ru.md) |
| **Домен готовности** | одна ось эксплуатации (control plane, ноды, безопасность, сеть, хранение, наблюдаемость, эксплуатация, инциденты), проверяемая отдельно. | [48](48/ru.md) |
| **Дрейф (drift)** | расхождение фактического состояния с описанным в коде или в Git. | [04](04/ru.md), [44](44/ru.md) |
| **зависимость между стеками** | передача выходов одного стека во входы другого (в Terragrunt блок `dependency`). | [04](04/ru.md) |
| **Инстанс EC2** | виртуальная машина; для EKS это нода с containerd и kubelet. | [0.4](00-4-ec2/ru.md) |
| **локальный кэш** | кэш данных Mountpoint на томе ноды (`cache: emptyDir`/`ephemeral`), ускоряющий повторное чтение; кэш метаданных задаётся `metadata-ttl`. | [25](25/ru.md) |
| **Масштабирование нод против масштабирования подов** | разные уровни: ноды масштабируют CA и Karpenter, поды - HPA, VPA, KEDA. | [11](11/ru.md) |
| **Микро-VM** | выделенная виртуальная машина под один под со своим ядром, CPU, памятью и сетевым интерфейсом; граница изоляции Fargate. | [15](15/ru.md) |
| **Объектное хранилище** | модель ключ-значение: объект (байты плюс метаданные) под строкой-ключом, неизменяемый, обновляется целиком через `PutObject`. | [25](25/ru.md) |
| **окно отката (7 дней)** | период после апгрейда, в течение которого откат доступен; по истечении откат и его insights недоступны. | [39](39/ru.md) |
| **Плагин kubectl** | файл `kubectl-<имя>` в `PATH`, доступный как `kubectl <имя>`. | [0.5](00-5-tools/ru.md) |
| **Подсеть** | часть CIDR VPC в одной AZ. | [0.3](00-3-vpc/ru.md) |
| **Полная замена** | `aws-node` удалён, Cilium - единственный CNI со своим IPAM: ENI IPAM (реальные адреса VPC) или cluster-pool (overlay/VXLAN, виртуальные адреса). | [08](08/ru.md) |
| **префикс** | часть ключа до `/`, из которой Mountpoint эмулирует каталог; настоящих каталогов в S3 нет. | [25](25/ru.md) |
| **принудительный upgrade** | автоматический подъём версии по истечении extended support; такой кластер откатить нельзя. | [38](38/ru.md) |
| **Провайдер** | плагин terraform (`aws`, `kubernetes`, `helm`). | [0.5](00-5-tools/ru.md) |
| **прогрессивная доставка** | canary/blue-green деплой приложений (Argo Rollouts, Flagger). | [44](44/ru.md) |
| **Продакшн-чеклист** | систематический список проверок готовности по доменам, где каждый пункт либо закрыт, либо помечен как известный риск. | [48](48/ru.md) |
| **Профиль** | именованный набор параметров: регион, роль, SSO. | [0.5](00-5-tools/ru.md) |
| **Регион** | географическая площадка (`eu-central-1`), к которой привязаны ресурсы. | [0.1](00-1-aws/ru.md) |
| **режим external** | значение аннотации `aws-load-balancer-type`, отдающее реконсиляцию Service внешнему контроллеру LBC вместо in-tree провайдера. | [26](26/ru.md) |
| **Режимы доступа EBS** | `ReadWriteOnce` (одна нода) и `ReadWriteOncePod` (ровно один под); `ReadWriteMany` возможен лишь как Multi-Attach `io2` в режиме `volumeMode: Block` в одной AZ и без файловой системы. Общий файловый доступ - EFS или FSx. | [23](23/ru.md) |
| **реконсиляция** | непрерывный цикл сверки желаемого (Git) с фактическим (кластер). | [44](44/ru.md) |
| **статический провижининг** | PV описывается вручную с `bucketName`; динамического и создания бакетов у драйвера нет. | [25](25/ru.md) |
| **Стек** | независимо применяемая единица инфраструктуры со своим state. | [0.5](00-5-tools/ru.md), [04](04/ru.md) |
| **Стратегия ротации** | `single user` (меняется пароль одного пользователя, есть короткое окно риска отказов, закрывается повторами с задержкой) или `alternating users` (два пользователя по очереди, валидные креды в любой момент, нужен секрет с правами superuser). | [18](18/ru.md) |
| **Стратегия спота** | как выбирается пул: `capacity-optimized(-prioritized)` против `lowest-price`; capacity-ориентированные реже прерываются. | [0.4](00-4-ec2/ru.md) |
| **Тег** | пара ключ/значение; по тегам контроллеры EKS находят ресурсы, а активированный cost allocation tag используется в биллинге для разбивки счёта. | [0.1](00-1-aws/ru.md) |
| **Тип инстанса** | `семейство + поколение + суффикс . размер`, например `m7g.xlarge`. | [0.4](00-4-ec2/ru.md) |
| **Типы логов control plane** | `api`, `audit`, `authenticator`, `controllerManager`, `scheduler`; пишутся в CloudWatch Logs только после включения. | [02](02/ru.md) |
| **управляемая возможность EKS для Argo CD** | Argo CD как EKS Capability: контроллеры в control plane AWS, цели - только кластеры EKS по ARN, доступ в них через EKS access entries. | [44](44/ru.md) |
| **фильтр kubernetes** | FILTER Fluent Bit, добавляющий к записям namespace, pod, контейнер, labels и annotations. | [34](34/ru.md) |
| **шардирование Argo CD** | раздача подключённых кластеров репликам application-controller. | [44](44/ru.md) |
| **--force** | флаг, обходящий проверки insights (ERROR/WARNING/UNKNOWN), но не предусловия (окно, один минор, создан-на-версии, совместимость фич). | [39](39/ru.md) |
| **/var/log/containers** | каталог на ноде со ссылками на файлы логов контейнеров; точка, из которой сборщик забирает логи. | [34](34/ru.md) |
