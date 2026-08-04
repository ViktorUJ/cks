# Amazon EKS: практический самоучитель по продакшн-эксплуатации

Практический курс по Amazon EKS с привязкой к лабораторным работам в
`tasks/eks/labs`. Курс рассчитан на инженеров, которые **уже прошли CKA** (или
уверенно владеют Kubernetes на уровне администратора) и переходят к управляемому
кластеру в AWS.

Отдельной сертификации по EKS не существует, поэтому курс построен не под экзамен,
а под реальную эксплуатацию: то, за что отвечает инженер, когда control plane
обслуживает AWS, а ноды, сеть, доступы, стоимость и обновления остаются на вас.

> **Что предполагается известным.** Поды, Deployment, Service, Ingress, RBAC,
> PV/PVC, probes, kubectl, отладка нагрузок - это база курса CKA, и здесь она не
> повторяется. Если этих тем ещё нет в активе, начните с
> [курса CKA + CKAD](../../cka/course/README_RU.md).

> **Версии.** Курс ориентирован на актуальные версии EKS (Kubernetes `1.33` -
> `1.36`). У EKS свой жизненный цикл версий: 14 месяцев standard support плюс
> 12 месяцев extended support (26 месяцев на минорную версию), поэтому глава об
> обновлениях привязана не к конкретному номеру, а к процессу. Лабы курса
> разворачиваются на версии из `env.hcl` каждой лабы.

## Как устроен курс

Каждая тема - папка с номером. Внутри лежат локализованные файлы. Основной язык -
русский (`ru.md`), с него будут сделаны переводы (как в курсах CKA и Istio).
Переключатель языков появится в первой строке каждого файла после первого
перевода.

Курс требует **своего аккаунта AWS**: почти все темы проверяются только на живом
кластере, а часть из них (спот-прерывания, NAT и трафик, обновления, стоимость)
в локальном kind воспроизвести нельзя. Лабы разворачиваются через Terragrunt и
удаляются одной командой, чтобы не жечь деньги.

## Содержание

### Часть 0. AWS-фундамент (необязательная)

Подготовительная часть для тех, кто пришёл с сильным Kubernetes и слабым AWS.
Если IAM, VPC и EC2 - привычные инструменты, переходите сразу к Части 1.
Отдельных лаб у этой части нет: она нужна, чтобы остальные главы читались без
пробелов.

- 0.1. [AWS для инженера Kubernetes: аккаунты, регионы, AZ, квоты, теги, биллинг](00-1-aws/ru.md)
- 0.2. [IAM с нуля: политики, роли, доверие, STS и временные ключи](00-2-iam/ru.md)
- 0.3. [VPC с нуля: подсети, маршрутизация, IGW и NAT, security groups, VPC endpoints](00-3-vpc/ru.md)
- 0.4. [EC2 и модели оплаты: типы инстансов, AMI, on-demand, spot, Savings Plans](00-4-ec2/ru.md)
- 0.5. [Инструменты: aws cli, eksctl, terraform и terragrunt, helm, полезные плагины](00-5-tools/ru.md)

### Часть 1. Архитектура и создание кластера

1. [Введение: что берёт на себя EKS и что остаётся на вас](01/ru.md)
2. [Control plane EKS: endpoint public и private, platform versions, SLA, логи](02/ru.md)
3. [Жизненный цикл версий: standard и extended support, стратегия обновлений](03/ru.md)
4. [Создание кластера: eksctl, Terraform и Terragrunt, CloudFormation](04/ru.md)
5. [Доступ к кластеру: IAM и RBAC, access entries, миграция с aws-auth](05/ru.md)
6. [Сеть кластера: VPC CNI, ENI и IP-адреса, планирование CIDR](06/ru.md)
7. [Масштаб адресного плана: prefix delegation, secondary CIDR, custom networking](07/ru.md)
8. [Альтернативы VPC CNI: Cilium, режимы сети, когда менять CNI](08/ru.md)

### Часть 2. Ноды и вычислительные ресурсы

9. [Типы вычислений: managed node groups, self-managed, Fargate, Auto Mode](09/ru.md)
10. [AMI и bootstrap: AL2023, Bottlerocket, launch templates, kubelet и user data](10/ru.md)
11. [Cluster Autoscaler и Karpenter: два подхода к масштабированию нод](11/ru.md)
12. [Karpenter: NodePool, EC2NodeClass, disruption, consolidation, drift](12/ru.md) 🧪
13. [Spot-инстансы: прерывания, диверсификация, обработка событий](13/ru.md)
14. [Плотность и сайзинг: pods per node, лимиты ENI, requests и limits в облаке](14/ru.md)
15. [Fargate: профили, ограничения, стоимость, сценарии применения](15/ru.md)

### Часть 3. Идентичность и безопасность

16. [IRSA: OIDC-провайдер, trust policy, аннотации ServiceAccount](16/ru.md)
17. [EKS Pod Identity: агент, ассоциации, миграция с IRSA](17/ru.md)
18. [Секреты: шифрование KMS, Secrets Manager и SSM через External Secrets и CSI](18/ru.md)
19. [Харденинг: IMDSv2 и hop limit, Pod Security Admission, приватный кластер](19/ru.md)
20. [Образы и supply chain: ECR, сканирование, подписи, pull through cache](20/ru.md)
21. [Аудит и детект: логи control plane, CloudTrail, GuardDuty, runtime-мониторинг](21/ru.md)
22. [Политики и мультитенантность: Kyverno и Gatekeeper, изоляция команд](22/ru.md)

### Часть 4. Хранение данных

23. [EBS CSI: gp3, StorageClass, расширение, снапшоты, привязка к AZ](23/ru.md)
24. [EFS и FSx: shared storage для нагрузок между AZ](24/ru.md)
25. [S3 в приложениях: Mountpoint for Amazon S3 CSI и паттерны доступа](25/ru.md)

### Часть 5. Сеть и трафик

26. [AWS Load Balancer Controller и Service типа LoadBalancer: NLB](26/ru.md)
27. [Ingress через ALB: target-type, аннотации, TLS и ACM, WAF](27/ru.md)
28. [Gateway API в AWS: ALB Gateway API и VPC Lattice](28/ru.md)
29. [DNS и сертификаты: external-dns, Route 53, cert-manager](29/ru.md)
30. [NetworkPolicy в EKS: VPC CNI network policy и Cilium](30/ru.md)
31. [Egress и стоимость трафика: NAT, VPC endpoints, PrivateLink](31/ru.md)
32. [Мультикластер и мультиаккаунт: связность, общие ресурсы, шаблоны](32/ru.md)

### Часть 6. Наблюдаемость

33. [Метрики: Container Insights, Managed Prometheus и Grafana, kube-prometheus-stack](33/ru.md)
34. [Логи: Fluent Bit, CloudWatch Logs, OpenSearch, контроль расходов](34/ru.md)
35. [Автомасштабирование приложений: HPA, внешние метрики, KEDA](35/ru.md) 🧪
36. [Трейсинг и профилирование: ADOT и X-Ray](36/ru.md)

### Часть 7. Эксплуатация

37. [Аддоны EKS: managed addons против Helm, версии и порядок обновления](37/ru.md)
38. [Обновление кластера: in-place по версиям, blue/green кластеры, устаревшие API](38/ru.md)
39. [Откат версии кластера: rollback readiness insights, окно 7 дней, порядок отката](39/ru.md)
40. [Надёжность: multi-AZ, PDB, topology spread, корректное выключение нод](40/ru.md)
41. [Бэкап кластера через AWS Backup: состояние кластера, постоянные тома, composite recovery point](41/ru.md)
42. [Восстановление и DR: restore в существующий и новый кластер, namespace-restore, Velero](42/ru.md)
43. [Стоимость: OpenCost и Kubecost, right-sizing, Savings Plans, спот-микс, трафик](43/ru.md)
44. [GitOps и доставка: Argo CD и Flux, управление парком кластеров](44/ru.md)

### Часть 8. Troubleshooting

45. [Нода не присоединилась к кластеру: IAM, SG, user data, bootstrap, kubelet](45/ru.md)
46. [Сетевые сбои: ENI exhausted, SG и NACL, DNS, unhealthy targets в балансировщике](46/ru.md)
47. [Доступ и IAM: access entries, IRSA и Pod Identity, webhook, kubeconfig](47/ru.md)

### Часть 9. Итог

48. [Продакшн-чеклист EKS и что читать дальше](48/ru.md)

## Практика

Лабы разворачиваются в вашем аккаунте AWS через Terragrunt, проверяются
автоматически через `check_result` и удаляются одной командой:

- 🧪 [Лабораторные работы EKS](../../../docs/labs.MD#eks-labs) - список лаб и команды запуска

Готовые лабы курса:

- Глава 12 - 🧪 [Karpenter Basics](../labs/02/README_RUS.MD)
- Глава 35 - 🧪 [Автомасштабирование приложений с KEDA и Prometheus](../labs/03/README_RUS.MD)

Значок 🧪 в оглавлении означает, что у главы есть своя лаба. Остальные лабы курса
в работе: они делаются под конкретные главы, в том же формате (Terragrunt-стек,
задания с автопроверкой, эталонные решения) и с отдельной нумерацией `101+`, чтобы
не смешиваться со старыми лабами EKS.

## Что читать дальше

- [Документация Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/) -
  первоисточник по версиям, аддонам и лимитам.
- [EKS Best Practices Guides](https://docs.aws.amazon.com/eks/latest/best-practices/) -
  официальные рекомендации по сети, безопасности, надёжности и стоимости.
- [EKS Workshop](https://www.eksworkshop.com/) - бесплатные интерактивные модули от AWS.
- [AWS Backup: бэкап и восстановление EKS](https://docs.aws.amazon.com/aws-backup/latest/devguide/eks-backups.html) -
  документация по бэкапу состояния кластера и постоянных томов.
- [От Spot.io к Karpenter](../../../docs/articles/from_spot_io_to_karpenter/readme_RU.MD) -
  наш разбор миграции управления нодами в продакшене.
