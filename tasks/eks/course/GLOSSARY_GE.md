[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Versión en español](GLOSSARY_ES.md) · [Version française](GLOSSARY_FR.md) · [Deutsche Version](GLOSSARY_DE.md) · [繁體中文版](GLOSSARY_TW.md) · [日本語版](GLOSSARY_JP.md)

# EKS კურსის ტერმინთა ლექსიკონი

[კურსის სარჩევი](README_GE.md)

კურსში გამოყენებული ტერმინების ერთიანი ანბანური ცნობარი. AWS-სა და Kubernetes-ში
ინგლისურად გამოყენებული ტერმინები ინგლისურად არის დატოვებული, აღწერილობები კი ქართულადაა.
სვეტში „თავები“ მოცემულია თავები, სადაც ტერმინი განიხილება, შესაბამისი ბმულებით.
გვერდზე ძიება: Ctrl+F.

| ტერმინი | აღწერა | თავები |
|--------|----------|-------|
| **ABAC / RBAC** | ტეგებით წვდომა `aws:PrincipalTag`-ის მეშვეობით, როლებითა და კონკრეტული მოქმედებებისა და რესურსების შემცველი პოლიტიკებით წვდომის საპირისპიროდ. | [0.2](00-2-iam/ge.md) |
| **Access entry** | კლასტერის წვდომის კონფიგურაციის ჩანაწერი, რომელიც ერთ IAM principal-ს `username`-სა და `kubernetesGroups`-ს უკავშირებს; ტიპი `STANDARD` ადამიანებისა და სერვისებისთვის, ხოლო `EC2_LINUX`, `EC2_WINDOWS`, `FARGATE_LINUX`, `HYBRID_LINUX`, `EC2` ნოდებისთვის. | [01](01/ge.md), [05](05/ge.md), [47](47/ge.md) |
| **`EC2_LINUX` ტიპის access entry** | ჩანაწერი, რომელიც კლასტერში ნოდის როლის ARN-ს ავტორიზაციას ანიჭებს. | [45](45/ge.md) |
| **access point** | EFS-ის ქვეკატალოგში შესასვლელი საკუთარი უფლებებითა და POSIX identity-ით; დინამიკური provisioning-ისა და კატალოგების იზოლაციის საფუძველი. | [24](24/ge.md) |
| **Access policy** | Kubernetes-ის დონის უფლებების AWS-ის მიერ მართული პოლიტიკა, რომელიც access entry-ს უკავშირდება; შეიცავს verbs-სა და resources-ს და არა IAM უფლებებს, და მისი რედაქტირება შეუძლებელია. | [05](05/ge.md), [47](47/ge.md) |
| **Access scope** | access policy-ის მოქმედების არე: `cluster` ან `namespace` სიით. | [05](05/ge.md) |
| **ACM (AWS Certificate Manager)** | load balancer-ზე განთავსებული სერტიფიკატები; გასაღები არ ექსპორტირდება, განახლება ავტომატურია. | [27](27/ge.md), [29](29/ge.md) |
| **actions / conditions** | custom action-ების (redirect, fixed-response, weighted forward) და routing-ის დამატებითი პირობების (headers, method, query, source IP) ანოტაციები. | [27](27/ge.md) |
| **Admission webhook** | გარე დამმუშავებელი, რომელსაც apiserver ობიექტის etcd-ში ჩაწერამდე იძახებს; mutating ობიექტს ცვლის, validating კი მხოლოდ ატარებს ან უარყოფს. | [22](22/ge.md) |
| **ADOT** | AWS Distro for OpenTelemetry: AWS-ის OTel დისტრიბუცია (SDK, აგენტები, Collector). | [36](36/ge.md) |
| **ALIAS** | Route 53-ის ჩანაწერი AWS რესურსზე, მაგალითად ELB-ზე; მუშაობს დომენის apex-ზე, სადაც CNAME აკრძალულია, და ცალკე მოთხოვნად არ ფასდება. | [29](29/ge.md) |
| **Allocatable** | რესურსი, რომელიც პოდებისთვის `kube-reserved`, `system-reserved` და eviction threshold-ის გამოკლების შემდეგ რჩება; scheduler სწორედ მას ითვალისწინებს. | [14](14/ge.md) |
| **`allowVolumeExpansion`** | StorageClass-ის ალამი, რომელიც PVC-ის გაზრდით volume-ის გაფართოებას რთავს. | [23](23/ge.md) |
| **Amazon EKS** | AWS-ში მართული Kubernetes: control plane-ს AWS ემსახურება, ნოდები და დანარჩენი ინფრასტრუქტურა კი თქვენზეა. | [01](01/ge.md) |
| **Amazon Managed Grafana (AMG)** | მართული Grafana; AMP-ს data source-ად აერთებს, მომხმარებლების წვდომა IAM Identity Center-ით ხდება. | [33](33/ge.md) |
| **Amazon Managed Service for Prometheus (AMP)** | მართული Prometheus-compatible backend; workspace, remote-write, PromQL და AWS-ის მხარეს retention. | [33](33/ge.md) |
| **amazon-cloudwatch-observability** | EKS managed addon, რომელიც CloudWatch agent-ს აყენებს და Container Insights with enhanced observability-ს რთავს. | [33](33/ge.md) |
| **AMI (Amazon Machine Image)** | instance-ის დისკის შაბლონი: kernel, filesystem და პროგრამული უზრუნველყოფა; ნოდებისთვის იყენებენ EKS-optimized AMI-ს, სადაც `kubelet`, `containerd` და bootstrap ლოგიკა უკვე შეთანხმებულია. | [0.4](00-4-ec2/ge.md), [10](10/ge.md) |
| **API Priority and Fairness** | Kubernetes-ის მექანიზმი, რომელიც ერთდროული მოთხოვნების კვოტას მათ ტიპებს შორის ანაწილებს; ამოწურვისას კლიენტი იღებს `429`-ს. | [02](02/ge.md) |
| **app-of-apps** | მშობელი `Application`, რომელიც შვილობილთა ნაკრებს შლის. | [44](44/ge.md) |
| **Application** | Argo CD-ის CRD: „წყარო Git-ში + სამიზნე კლასტერი და namespace“ კავშირი. | [44](44/ge.md) |
| **Application Load Balancer (ALB)** | L7 load balancer (HTTP/HTTPS) host-ითა და path-ით routing-ის, TLS termination-ის, WAF-ისა და authentication-ის მხარდაჭერით; EKS-ში LBC მას Ingress-იდან ქმნის. | [27](27/ge.md) |
| **ApplicationSet** | Argo CD controller, რომელიც შაბლონით `Application`-ებს ქმნის; cluster generator თითო დაკავშირებულ კლასტერზე ერთს ქმნის, git generator Git-ის კატალოგებისა ან ფაილების მიხედვით, matrix generator კი ორ generator-ს (cluster + git) აერთიანებს. | [44](44/ge.md) |
| **ARN** | `arn:partition:service:region:account-id:resource`, რესურსის მისამართი. | [0.1](00-1-aws/ge.md) |
| **`AssumeRoleWithWebIdentity`** | STS ოპერაცია, რომელიც web identity token-ს IAM role-ის დროებით credentials-ში ცვლის. | [16](16/ge.md) |
| **auditID** | audit log-ში მოთხოვნის უნიკალური იდენტიფიკატორი; ერთი ოპერაციის ყველა stage-სთვის ერთნაირია. CloudTrail-თან საერთო ID არ არსებობს, ამიტომ წყაროებს principal-ის, IP-ისა და დროის მიხედვით აკავშირებენ. | [21](21/ge.md) |
| **`authenticationMode`** | კლასტერის authentication რეჟიმი: `CONFIG_MAP`, `API_AND_CONFIG_MAP`, `API`; ცვლილება მხოლოდ `API`-ს მიმართულებით შეიძლება. | [04](04/ge.md), [05](05/ge.md), [47](47/ge.md) |
| **`authenticationSource`** | volume-ის credentials-ის წყარო: `driver` (driver-ის საერთო როლი) ან `pod` (პოდის service account-ის როლი). | [25](25/ge.md) |
| **Availability Zone (AZ)** | რეგიონის იზოლირებული data center-ების ნაკრები; failure-ის საბაზისო domain, რომლის მიხედვითაც replicas ნაწილდება. | [0.1](00-1-aws/ge.md), [40](40/ge.md) |
| **AWS Backup** | AWS-ის ცენტრალიზებული backup სერვისი; EKS-ს, EBS-ს, EFS-ს, S3-სა და სხვა რესურსებს საერთო გეგმებითა და vault-ებით აბექაფებს. | [41](41/ge.md) |
| **aws cli v2** | AWS-ის ძირითადი CLI; კონფიგურაცია `~/.aws/config`-შია, წვდომა აირჩევა `--profile`-ით ან `AWS_PROFILE`-ით. | [0.5](00-5-tools/ge.md) |
| **AWS Control Tower** | AWS-ის მზა landing zone: controls (preventive, detective, proactive), drift detection და account factory. | [0.1](00-1-aws/ge.md) |
| **`aws eks get-token`** | kubeconfig-ის `exec` plugin, რომელიც კლასტერში შესასვლელად presigned STS token-ს ქმნის. | [47](47/ge.md) |
| **AWS Gateway API Controller** | `aws-application-networking-k8s` controller, GatewayClass `amazon-vpc-lattice`, რომელიც Gateway API-ს VPC Lattice ობიექტებად გარდაქმნის. | [28](28/ge.md) |
| **AWS Load Balancer Controller (Gateway API)** | იმპლემენტაცია `controllerName`-ებით `gateway.k8s.aws/alb` (ALB, L7) და `gateway.k8s.aws/nlb` (NLB, L4). | [28](28/ge.md) |
| **AWS Load Balancer Controller (LBC)** | კლასტერში controller, რომელიც LoadBalancer ტიპის Service-სთვის NLB-ს, Ingress-ისთვის კი ALB-ს ქმნის; ინსტალირდება Helm-ით და IAM role სჭირდება. | [26](26/ge.md) |
| **AWS Organizations** | მრავალი account-ის მართვის სერვისი: OU hierarchy, საერთო policies (SCP) და consolidated billing. | [0.1](00-1-aws/ge.md), [32](32/ge.md) |
| **AWS PrivateLink** | AWS სერვისებსა და სხვა account-ებში არსებულ სერვისებზე interface endpoint-ით private access-ის მექანიზმი. | [31](31/ge.md) |
| **AWS RAM (Resource Access Manager)** | რესურსების (subnets, Transit Gateway, VPC Lattice service network, Route 53 Resolver rules) სხვა account-ებსა და organization-თან გაზიარების სერვისი. | [0.1](00-1-aws/ge.md), [32](32/ge.md) |
| **`aws sts get-caller-identity`** | ბრძანება „ვინ ვარ მე“: account, ARN, userId. | [0.5](00-5-tools/ge.md) |
| **AWS X-Ray** | მართული trace backend: შენახვა, service map, latency breakdown და trace search. | [36](36/ge.md) |
| **`aws-auth` ConfigMap** | legacy mapping მექანიზმი `kube-system`-ში არსებული ობიექტის მეშვეობით, `mapRoles` და `mapUsers` ველებით. | [05](05/ge.md), [45](45/ge.md), [47](47/ge.md) |
| **aws-for-fluent-bit** | AWS-ის მიერ აწყობილი Fluent Bit image, AWS სერვისებში output-ის ჩაშენებული plugins-ით. | [34](34/ge.md) |
| **`aws-vault`** | credentials-ის keychain-ში შენახვა და ბრძანებების დროებით session-ში გაშვება. | [0.5](00-5-tools/ge.md) |
| **`AWS_VPC_K8S_CNI_EXTERNALSNAT`** | პოდების egress-ზე ნოდის SNAT-ს თიშავს (`true`), რათა გარე მხარემ პოდის რეალური მისამართი დაინახოს; ამ შემთხვევაში ინტერნეტში გასვლა მხოლოდ NAT gateway-ით ხდება. | [07](07/ge.md) |
| **`AWSTraceHeader`** | X-Ray trace header-ისთვის განკუთვნილი SQS message system attribute; context-ის async boundary-ზე გადატანის გზა, სადაც headers არ არის. | [36](36/ge.md) |
| **backend-protocol-version** | target group-ის application protocol: `HTTP1`, `HTTP2` ან `GRPC`; საჭიროა, რომ ALB-მ gRPC და HTTP/2 პოდებამდე HTTP/1.1-ის ნაცვლად შესაბამისი protocol-ით გაატაროს. | [27](27/ge.md) |
| **backup plan** | backup-ის გეგმა: schedule, retention, lifecycle (cold storage-ში გადასვლა) და რესურსების მიბმა. | [41](41/ge.md) |
| **backup vault** | recovery point-ების საცავი KMS key-ითა და access policy-ით; მასზე ირთვება Vault Lock. | [41](41/ge.md) |
| **BackupStorageLocation (BSL)** | Velero backup-ების შენახვის ადგილი (S3 bucket). | [42](42/ge.md) |
| **bake period** | პაუზა control plane-ისა და ნოდების upgrade-ებს შორის: ნოდები N-1-ზე რჩება და rollback მათი დაბრუნების გარეშეა შესაძლებელი. | [39](39/ge.md) |
| **Basic / Enhanced scanning** | ECR-ში CVE ძიების რეჟიმები: basic ნატიურად ამოწმებს OS packages-ს; enhanced Amazon Inspector-ით უწყვეტად ამოწმებს OS-სა და language packages-ს. | [20](20/ge.md) |
| **behavior / stabilizationWindowSeconds** | HPA section, რომელიც stabilization windows-ითა და policies-ით scaling-ის სიჩქარესა და რყევებს არბილებს. | [35](35/ge.md) |
| **bin packing** | პოდების ნოდებზე მათი requests-ის მიხედვით განლაგება. | [14](14/ge.md) |
| **blue/green კლასტერი** | ძველის გვერდით target version-ზე შექმნილი ახალი კლასტერი, workloads-ის migration-ითა და traffic switch-ით. | [03](03/ge.md), [38](38/ge.md) |
| **bootstrap.sh** | AL2-ზე user data-დან kubelet-ის კონფიგურაციის script. | [45](45/ge.md) |
| **`bootstrapClusterCreatorAdminPermissions`** | შექმნისას access configuration-ის ველი; `true`-ისას (default) cluster creator მასში admin უფლებებს იღებს. | [04](04/ge.md), [05](05/ge.md) |
| **Bottlerocket** | მინიმალური container OS: read-only root, მთლიანი image-ით update, API-ით მართვა და ღია SSH-ის ნაცვლად control და admin containers. | [10](10/ge.md) |
| **Burstable (T-series)** | CPU-ის საბაზისო წილი და CPU credits; production nodes-ისთვის გამოუსადეგარია. | [0.4](00-4-ec2/ge.md) |
| **Capacity** | instance-ის სრული capacity CPU-ის, memory-ისა და pods-ის მიხედვით. | [14](14/ge.md) |
| **Capacity Blocks** | training-ისთვის GPU/Trainium capacity-ის reservation. | [0.4](00-4-ec2/ge.md) |
| **capacity type** | node capacity-ის ტიპი (`spot`/`on-demand`); labels `karpenter.sh/capacity-type` და `eks.amazonaws.com/capacityType`. | [13](13/ge.md) |
| **CapacityProvisioned** | პოდის annotation რეალურად გამოყოფილი vCPU-სა და memory-ის დამრგვალებული კომბინაციით; ღირებულებას სწორედ ის განსაზღვრავს. | [15](15/ge.md) |
| **cert-manager** | კლასტერში სერტიფიკატების `Secret`-ების სახით გაცემის controller; წყაროს ClusterIssuer ან Issuer განსაზღვრავს. | [29](29/ge.md) |
| **CFS throttling** | CPU limit-ის გადაჭარბებისას container-ის შენელება. | [14](14/ge.md) |
| **chargeback** | რეალური ღირებულების გუნდის ბიუჯეტზე მიკუთვნება. | [43](43/ge.md) |
| **`CiliumNetworkPolicy` / `CiliumClusterwideNetworkPolicy`** | Cilium CRD-ები L7 და FQDN rules-ით და cluster-wide scope-ით. | [08](08/ge.md), [30](30/ge.md) |
| **CloudTrail** | AWS API calls-ის ჟურნალი; EKS-ისთვის აფიქსირებს operations-ს კლასტერზე, როგორც AWS resource-ზე (management events), და არა Kubernetes-ის შიდა events-ს. | [21](21/ge.md) |
| **CloudWatch Application Signals** | OTel-ზე აგებული APM (SLO, latency, errors), რომელიც `amazon-cloudwatch-observability` addon-ით ირთვება. | [36](36/ge.md) |
| **CloudWatch Logs** | AWS log storage; log groups და log streams, Logs Insights-ით queries, საფასური ingestion-სა და storage-ზე. | [34](34/ge.md) |
| **CloudWatch Logs Insights** | logs query language (`fields`, `filter`, `sort`, `stats`); audit log-ის ანალიზის მთავარი ინსტრუმენტი. | [21](21/ge.md) |
| **Cluster Autoscaler (CA)** | node autoscaler, რომელიც Auto Scaling group-ის ზემოთ მუშაობს: unscheduled pods-ისა და underutilization-ის მიხედვით groups-ის `desiredSize`-ს ცვლის. Instance types group launch template-ში ფიქსირებულია. | [11](11/ge.md) |
| **cluster creator admin** | IAM principal, რომელმაც კლასტერი შექმნა, admin access-ს ავტომატურად იღებს. | [47](47/ge.md) |
| **Cluster endpoint** | კლასტერის Kubernetes API address. Public endpoint ინტერნეტიდან ხელმისაწვდომია და მხოლოდ CIDR list-ით იზღუდება; private endpoint VPC-დანაა ხელმისაწვდომი და cluster security group-ით იზღუდება. | [01](01/ge.md), [02](02/ge.md) |
| **Cluster insights** | EKS-ის automatic cluster checks; `UPGRADE_READINESS` ამოწმებს upgrade readiness-ს, `ROLLBACK_READINESS` rollback-ის შესაძლებლობას და 7 დღეა ხელმისაწვდომი. | [03](03/ge.md), [38](38/ge.md) |
| **Cluster security group** | group, რომელსაც EKS ავტომატურად ქმნის კლასტერისთვის და ამ interfaces-სა და managed node groups-ის ნოდებს ანიჭებს. | [02](02/ge.md), [45](45/ge.md) |
| **cluster version rollback** | in-place upgrade-ის შემდეგ EKS control plane-ის წინა minor-ზე დაბრუნება 7-დღიან window-ში, etcd-ის, workloads-ისა და volumes-ის შენარჩუნებით. | [03](03/ge.md), [39](39/ge.md) |
| **ClusterIssuer / Issuer** | cert-manager objects, რომლებიც მთელი cluster-ისთვის ან namespace-ისთვის certificate source-ს აღწერს. | [29](29/ge.md) |
| **ClusterMesh** | Cilium-ის რამდენიმე cluster-ის Pod Network-ის გაერთიანება `clustermesh-apiserver`-ით; საჭიროა უნიკალური `cluster-id` და არაგადამკვეთი PodCIDR-ები. | [08](08/ge.md) |
| **CMK (customer managed key)** | თქვენი KMS key: default AWS owned key-ისგან განსხვავებით, გაძლევთ key policy-ის კონტროლსა და CloudTrail-ში decrypt audit-ს. | [18](18/ge.md) |
| **CNI chaining** | რეჟიმი, სადაც VPC CNI მისამართებს გასცემს და interface-ს აწყობს, Cilium კი ზემოდან policies-სა და observability-ს ამატებს; `aws-node` რჩება. | [08](08/ge.md), [30](30/ge.md) |
| **`cni-metrics-helper`** | component, რომელიც `aws-node` pods-იდან `awscni_*`-ს scrape-ს აკეთებს და aggregates-ს CloudWatch-ში აგზავნის. | [06](06/ge.md) |
| **composite recovery point** | EKS-ის შედგენილი point, რომელიც cluster state-სა და volume backups-ს ერთ ერთეულად აჯგუფებს. | [41](41/ge.md) |
| **Compute Savings Plans** | 1-3 წლით საათობრივ ხარჯვაზე ვალდებულება ფასდაკლების სანაცვლოდ, მოქნილი instance families-ის, region-ისა და Fargate/Lambda-ს მიმართ; hourly commitment საათებს შორის არ გადადის და Spot-ზე არ ვრცელდება, გამოყენება კი Cost Explorer-ის Savings Plans utilization და coverage reports-ში ჩანს. | [43](43/ge.md) |
| **Compute SP / EC2 Instance SP** | მოქნილი plan (EC2, Fargate, Lambda) / უფრო დიდი ფასდაკლება, მაგრამ region-ში ერთ family-ზე. | [0.4](00-4-ec2/ge.md) |
| **configurationValues** | addon field declarative configuration-ისთვის, manifests-ის ხელით შეცვლის გარეშე. | [37](37/ge.md) |
| **connection draining** | target-ის deregistration-ისას active connections-ის დაცლა; `deregistration_delay.timeout_seconds` (default 300). | [40](40/ge.md) |
| **conntrack** | node kernel-ის connection table; გადავსებისას ახალი connections იკარგება. | [46](46/ge.md) |
| **Consolidated billing** | organization-ის ერთიანი ანგარიში; volume discounts და Savings Plans ყველა account-ზე მოქმედებს. | [0.1](00-1-aws/ge.md) |
| **Consolidation** | ღირებულების შესამცირებლად ნებაყოფლობითი შეკუმშვა; policies `WhenEmpty` და `WhenEmptyOrUnderutilized`, methods empty/single/multi-node და parameter `consolidateAfter`. | [11](11/ge.md), [12](12/ge.md) |
| **Container Insights** | CloudWatch-ით EKS monitoring: agent აგროვებს node და pod metrics-ს, dashboards და alarms CloudWatch-შია. | [33](33/ge.md) |
| **ContainerResource** | HPA metric type, რომელიც utilization-ს პოდის ერთი container-ის მიხედვით ითვლის და არა ყველას ჯამით; საჭიროა, როცა sidecar application metric-ს აზავებს. | [35](35/ge.md) |
| **context propagation** | `trace id`-ის services-ს შორის headers-ით (W3C Trace Context) გადაცემა, რათა trace არ გაწყდეს. | [36](36/ge.md) |
| **continuous profiling** | code-ში CPU და memory hotspots-ის უწყვეტი შეგროვება; AWS-ში Amazon CodeGuru Profiler, eBPF profilers-დან Pyroscope და Parca. | [36](36/ge.md) |
| **Control plane** | API server, scheduler, controller manager და etcd; EKS-ში AWS account-ში, თქვენი VPC-ის გარეთ ცხოვრობს და `kubectl get pods -n kube-system`-ში არ ჩანს. | [01](01/ge.md) |
| **control plane logging** | EKS control plane logs-ის (`api`, `audit`, `authenticator`, `controllerManager`, `scheduler`) CloudWatch Logs-ში მიწოდება. | [34](34/ge.md) |
| **core addons** | `vpc-cni`, `kube-proxy`, `coredns`: აუცილებელი ბირთვი, რომელიც ყველა cluster-ში ყენდება. | [37](37/ge.md) |
| **cost allocation** | AWS რესურსების ღირებულების Kubernetes objects-ზე (namespace, Deployment, label) consumption-ის ან requests-ის მიხედვით განაწილება. | [43](43/ge.md) |
| **cost allocation tags** | AWS tags bill-ის დასაყოფად; user-defined tags Billing console-ში უნდა გააქტიურდეს. | [43](43/ge.md) |
| **Cost and Usage Report** | AWS-ის დეტალური billing data S3-ში; Athena-ით კითხვა OpenCost/Kubecost-ს allocation-ის რეალურ, discounts-ის შემცველ bill-თან შედარების საშუალებას აძლევს. | [43](43/ge.md) |
| **Cost Anomaly Detection** | AWS service, რომელიც spending-ის უჩვეულო ზრდას ML-ით პოულობს და email ან SNS alerts-ს აგზავნის (Slack/Teams AWS Chatbot-ით). | [43](43/ge.md) |
| **crash-consistent / application-consistent** | snapshot writes-ის შეჩერების გარეშე, application-level consistency-ით snapshot-ის საპირისპიროდ; AWS Backup-ში EKS-ისთვის მხოლოდ პირველი არსებობს. | [41](41/ge.md) |
| **Cross-account ENI** | network interfaces, რომლებსაც EKS თქვენს subnets-ში control plane-ის nodes-თან, kubelet API-სთან, webhooks-სა და OIDC-სთან კავშირისთვის ქმნის. | [02](02/ge.md) |
| **cross-AZ traffic** | data transfer availability zones-ს შორის; ჩვეულებრივ ორივე მიმართულებით ფასდება. | [31](31/ge.md) |
| **cross-zone load balancing** | load balancer რეჟიმი, რომელიც traffic-ს ყველა zone-ის targets-ზე ანაწილებს; load უფრო თანაბარია, მაგრამ cross-AZ მეტია. | [31](31/ge.md) |
| **Custom networking** | რეჟიმი, სადაც secondary ENI-ები და pod addresses `ENIConfig` object-ის subnet-იდან და security groups-იდან, თითო AZ-ზე ერთიდან, `ENI_CONFIG_LABEL_DEF` label-ით არჩევით მიიღება. | [07](07/ge.md) |
| **custom.metrics.k8s.io** | cluster objects-ის custom metrics API HPA-სთვის (Pods, Object). | [35](35/ge.md) |
| **Data Firehose** | managed buffer და stream router S3-ში, OpenSearch-სა და სხვა destinations-ში. | [34](34/ge.md) |
| **Data plane** | თქვენი nodes და ყველაფერი, რაც მათზე ეშვება. | [01](01/ge.md) |
| **Delegated administrator** | organization account, რომელიც GuardDuty/Security Hub-ს მთელი organization-ისთვის მართავს და ყველა member-ის findings-ს ხედავს; ინიშნება region-ის მიხედვით. | [0.1](00-1-aws/ge.md), [21](21/ge.md) |
| **`deletionProtection`** | flag, რომელიც cluster deletion-ს კრძალავს. | [04](04/ge.md) |
| **deprecated / removed API** | `apiVersion` ჯერ deprecated-ად ცხადდება, შემდეგ იშლება; წაშლის შემდეგ მისი manifests აღარ გამოიყენება. | [38](38/ge.md) |
| **describe-addon-versions** | EKS API operation: addon versions, მათი Kubernetes minor-თან compatibility და `defaultVersion`. | [37](37/ge.md) |
| **`describe-target-health`** | command, რომელიც target group-ის targets-ის state-სა და reason-ს აჩვენებს. | [46](46/ge.md) |
| **Digest** | image content-ის `sha256` hash, immutable identifier; მოძრავი tag-ისგან განსხვავებით, digest-ით deploy ზუსტად აგებული artifact-ის გაშვებას უზრუნველყოფს. | [20](20/ge.md) |
| **Disruption budget** | voluntary disruptions-ის ტემპის limit: nodes-ის proportion/count, windows `schedule`-ითა და `duration`-ით, `reasons`-თან binding. | [12](12/ge.md) |
| **DNS-01** | domain ownership-ის ACME check TXT record-ით; Route 53-ში მას cert-manager ქმნის. | [29](29/ge.md) |
| **Drift** | node-ის desired state-თან განსხვავება (ახალი AMI, შეცვლილი selectors ან `requirements`); consolidation-მდე სრულდება. | [12](12/ge.md) |
| **Dual-stack** | VPC და subnets IPv4-ითა და IPv6-ით (`/56` და `/64`); IPv6 რეჟიმი pod addresses-ის დეფიციტს ხსნის. | [0.3](00-3-vpc/ge.md) |
| **EBS / instance store** | network volume ერთ AZ-ში / ephemeral local NVMe. | [0.4](00-4-ec2/ge.md) |
| **EBS CSI driver** | `aws-ebs-csi-driver`, managed addon provisioner-ით `ebs.csi.aws.com`; მართავს EBS volumes-ის lifecycle-ს. | [23](23/ge.md) |
| **EC2NodeClass** | CRD (`karpenter.k8s.aws/v1`) AWS settings-ით: AMI, IAM role, subnets და SG, disks, IMDS. | [12](12/ge.md) |
| **ECR** | AWS-ის managed OCI image registry; private registry თითო account-region-ზე მისამართით `<account-id>.dkr.ecr.<region>.amazonaws.com` და public `public.ecr.aws`. | [20](20/ge.md) |
| **EFS** | Amazon Elastic File System, managed regional NFS elastic capacity-ითა და ReadWriteMany რეჟიმით. | [24](24/ge.md) |
| **EFS CSI driver** | `aws-efs-csi-driver`, managed addon provisioner-ით `efs.csi.aws.com`; წინასწარ შექმნილ file system-ზე მუშაობს. | [24](24/ge.md) |
| **EKS audit log** | control plane log type (`audit`), Kubernetes audit JSON events: ვინ, რომელი verb-ით, რომელ resource-ზე, საიდან და რა შედეგით; CloudWatch Logs-ში იწერება. | [21](21/ge.md) |
| **EKS authenticator** | control plane webhook, რომელიც presigned STS token-ს ამოწმებს და IAM identity-ს Kubernetes subject-ს უკავშირებს. | [47](47/ge.md) |
| **EKS Auto Mode** | რეჟიმი, სადაც AWS მართავს appliance nodes-ს (Bottlerocket, read-only root, SSH/SSM-ის გარეშე, 21-დღიანი სიცოცხლე), Karpenter scaling-სა და ჩაშენებულ networking, DNS, EBS CSI, ELB-ს. | [01](01/ge.md), [09](09/ge.md) |
| **EKS Cluster State** | Kubernetes objects-ის manifests (Secret, ConfigMap, StatefulSet, PVC, RBAC, CRD და სხვ.) და cluster configuration. | [41](41/ge.md) |
| **EKS Pod Identity** | node agent-ითა და EKS API-ით pod-ისთვის IAM role-ის გაცემის მექანიზმი, cluster OIDC provider-ისა და კონკრეტულ cluster-ზე მიბმული trust policy-ის გარეშე. | [17](17/ge.md), [47](47/ge.md) |
| **EKS Pod Identity Agent** | addon `eks-pod-identity-agent`, რომელიც nodes-ზე `DaemonSet`-ად მუშაობს და local endpoint-ით pods-ს temporary credentials-ს აძლევს. | [17](17/ge.md) |
| **EKS-optimized AMI** | AWS image node components-ის საჭირო versions-ით; families AL2023, Bottlerocket, Windows და მოძველებადი AL2. | [10](10/ge.md) |
| **eksctl** | EKS-ის official CLI, მუშაობს CloudFormation-ით და imperative-ია. | [0.5](00-5-tools/ge.md) |
| **enableNetworkPolicy** | VPC CNI managed addon parameter, რომელიც standard NetworkPolicy enforcement-ს რთავს. | [30](30/ge.md) |
| **Encryption at rest** | ECR layers-ის encryption: default SSE-S3 (AES-256), optional SSE-KMS key `aws/ecr`-ით ან საკუთარი customer managed key-ით; creation-ზე განისაზღვრება და immutable-ია. | [20](20/ge.md) |
| **endpoint service** | საკუთარი service-ის (NLB-ის უკან) PrivateLink target-ად გამოქვეყნება სხვა VPC-ებისა და accounts-ის consumers-ისთვის. | [31](31/ge.md) |
| **`endpointPublicAccess` / `endpointPrivateAccess`** | access mode-ის boolean flags; default-ად `true` და `false`. | [02](02/ge.md) |
| **enforcer** | CNI component, რომელიც NetworkPolicy-ს რეალურ traffic filters-ად გარდაქმნის; EKS-ში ჩართვამდე default-ად არ არის. | [30](30/ge.md) |
| **Enhanced subnet discovery** | `kubernetes.io/role/cni=1` tag-ის მქონე subnets `ENIConfig`-ის გარეშე. | [07](07/ge.md) |
| **ENI** | elastic network interface; instance-ზე ENI-ების და ENI-ზე IPv4 addresses-ის რაოდენობა instance type-ზეა დამოკიდებული. | [0.3](00-3-vpc/ge.md), [06](06/ge.md) |
| **Envelope encryption** | two-key encryption: DEK encrypts data, KEK (KMS key) encrypts DEK-ს. EKS ამას etcd secrets-ზე Kubernetes KMS provider v2-ით იყენებს. | [18](18/ge.md) |
| **ephemeral ports** | მაღალი დიაპაზონი `1024-65535`, სადაც return traffic მიდის; NACL-ში ხელით უნდა დაუშვათ. | [46](46/ge.md) |
| **eviction threshold** | memory buffer, რომლის ქვემოთ kubelet pods-ს evict-ს უკეთებს. | [14](14/ge.md) |
| **kubeconfig exec plugin** | `exec` section, რომელიც `aws eks get-token`-ს იძახებს; file-ში long-lived token არ არის, მიღებულ credentials-ს კი `client-go` `status.expirationTimestamp`-მდე cache-ს უკეთებს. | [0.5](00-5-tools/ge.md) |
| **Expander** | Cluster Autoscaler strategy node group-ის ასარჩევად, როცა pod რამდენიმე group-ს ერგება: `least-waste` (default), `priority`, `most-pods`, `random`. | [11](11/ge.md) |
| **Extended support** | standard phase-ის შემდეგი ეტაპი (დაახლოებით 12 თვე): version ჯერ მხარდაჭერილია, მაგრამ cluster-hour-ზე გაზრდილი საფასურით; default-ად ჩართულია. | [03](03/ge.md), [38](38/ge.md) |
| **External Secrets Operator (ESO)** | controller, რომელიც AWS-დან secret-ს კითხულობს და native `Secret`-ს ქმნის; objects `SecretStore`/`ClusterSecretStore` და `ExternalSecret`. | [18](18/ge.md) |
| **external-dns** | controller, რომელიც DNS provider-ში records-ს Kubernetes objects-თან (Ingress, Service) ასინქრონებს; AWS-ში Route 53-თან მუშაობს. | [29](29/ge.md) |
| **external.metrics.k8s.io** | external metrics API (queues, topics) HPA-სთვის (External type). | [35](35/ge.md) |
| **externalTrafficPolicy** | Service policy: `Cluster` (ნებისმიერ node-ზე forwarding, SNAT) ან `Local` (მხოლოდ local pods, client IP-ის შენარჩუნება). | [26](26/ge.md) |
| **`failed to assign an IP address to container`** | VPC CNI-მ pod-ს IP ვერ მისცა: node-ზე ან subnet-ში addresses ამოიწურა. | [46](46/ge.md) |
| **failurePolicy** | unavailable webhook-ზე რეაქცია: `Fail` admission-ს აჩერებს, `Ignore` object-ს check-ის გვერდის ავლით ატარებს. | [22](22/ge.md) |
| **Fargate** | pod-ის dedicated micro-VM-ზე nodes-ის გარეშე გაშვება; DaemonSet-ის, privileges-ის, `HostNetwork`-ის, GPU-ისა და node access-ის გარეშე. ფასი pod-ის vCPU-სა და memory-ზეა. | [09](09/ge.md) |
| **fargate-scheduler** | EKS scheduler, რომელიც kube-scheduler-ის გვერდით მუშაობს და profile-ს შესაბამის pods-ს Fargate-ზე მიმართავს. | [15](15/ge.md) |
| **Fargate profile** | cluster-level object selectors-ით (namespace და optional labels), pod execution role-ითა და private subnets-ით; განსაზღვრავს, რომელი pods წავა Fargate-ზე. შეცვლა შეუძლებელია, მხოლოდ ხელახლა შექმნა. | [15](15/ge.md) |
| **Finding** | GuardDuty finding; alerts-ისა და response-ისთვის Security Hub-სა და EventBridge-ში მიდის. | [21](21/ge.md) |
| **Fluent Bit** | მსუბუქი C log forwarder, რომელიც თითო node-ზე DaemonSet-ად ეშვება; log files-ს კითხულობს, ამდიდრებს და destinations-ში აგზავნის. | [34](34/ge.md) |
| **Forbidden (403)** | authorization failure: RBAC action-ის უფლებას არ იძლევა. | [47](47/ge.md) |
| **game day** | სწავლება, სადაც DR და incident scenarios პრაქტიკაში მოწმდება. | [48](48/ge.md) |
| **Gatekeeper** | OPA-ზე აგებული policy engine; rules Rego-ზე, model `ConstraintTemplate` (template + schema) და `Constraint` (instance). | [22](22/ge.md) |
| **Gateway** | entry point listeners-ით (protocol, port, TLS); owner platform team-ია. VPC Lattice-ში Service Network-ად აისახება. | [28](28/ge.md) |
| **Gateway API** | traffic management-ის Kubernetes standard, Ingress-ის მემკვიდრე: typed resources-ის ნაკრები role separation-ით. | [28](28/ge.md) |
| **gateway endpoint** | VPC endpoint type S3-სა და DynamoDB-სთვის route table entry-ით; უფასოა. | [25](25/ge.md), [31](31/ge.md) |
| **GatewayClass** | implementation template `controllerName` field-ით; განსაზღვრავს, რომელი controller დაამუშავებს Gateway-ს (IngressClass-ის ანალოგი). | [28](28/ge.md) |
| **GitOps** | model, სადაც desired state Git-შია აღწერილი, agent კი cluster-ს უწყვეტად ამ მდგომარეობასთან შესაბამისობაში მოჰყავს (პრინციპებს CNCF project OpenGitOps აყალიბებს). | [44](44/ge.md) |
| **GitOps Toolkit** | Flux controllers-ის ნაკრები (source, kustomize, helm, image და სხვ.). | [44](44/ge.md) |
| **Golden image** | reproducible custom image, რომელიც optimized AMI-ზე image builder-ითაა აგებული. | [10](10/ge.md) |
| **graceful node shutdown** | kubelet feature, რომელიც OS shutdown-ისას pods-ს grace period-ით აჩერებს. | [40](40/ge.md) |
| **Grafana Loki** | log storage, რომელიც მხოლოდ stream labels-ს ინდექსირებს; logs object storage-ში compressed chunks-ად ინახება, queries LogQL-ზეა. Labels low-cardinality უნდა იყოს, high cardinality-სთვის structured metadata არსებობს; native agent Grafana Alloy-ია (Promtail მასში გაერთიანდა). | [34](34/ge.md) |
| **`granted` (`assume`)** | SSO profiles-ის სწრაფი switching და console login. | [0.5](00-5-tools/ge.md) |
| **Graviton** | AWS arm64 processors (`g` suffix), საჭიროებს multi-arch images-ს. | [0.4](00-4-ec2/ge.md) |
| **GuardDuty EKS Protection** | EKS audit logs-ის threats-ზე ანალიზი GuardDuty-ის დამოუკიდებელი stream-ით, control plane logging-ის აუცილებელი ჩართვის გარეშე. | [21](21/ge.md) |
| **GuardDuty Runtime Monitoring** | nodes-ზე behavior monitoring agent `aws-guardduty-agent`-ით (eBPF): processes, network, files; Fargate-სა და Hybrid Nodes-ს არ უჭერს მხარს. | [21](21/ge.md) |
| **Hard multi-tenancy** | tenants ცალკე clusters/accounts-ში; მკაცრი boundary გაზრდილი complexity-ის ფასად. | [22](22/ge.md) |
| **HashiCorp Vault** | AWS-ის გარეთ არსებული external secret storage, Secrets Manager-ის ანალოგიური როლით: pod authentication Kubernetes, JWT/OIDC ან AWS IAM auth-ით; delivery Vault Agent Injector-ით, Vault Secrets Operator-ით, ESO-თი ან Vault provider-ის მქონე CSI Driver-ით. | [18](18/ge.md) |
| **head-based და tail-based sampling** | request-ის დასაწყისში, შედეგის ცოდნამდე recording decision, gateway-ზე trace-ის აწყობის შემდეგ decision-ის საპირისპიროდ (error და latency policies). Tail-based-ისთვის ერთი trace-ის ყველა span collector-ის ერთ instance-ში უნდა მოხვდეს. | [36](36/ge.md) |
| **helmfile** | helm releases-ის ნაკრების versions-ითა და values-ით declarative description ერთ file-ში. | [0.5](00-5-tools/ge.md) |
| **hop limit (`httpPutResponseHopLimit`)** | IMDS response-ის network hops-ის რაოდენობა; 1-ისას pod IMDS-მდე ვერ აღწევს, node კი მუშაობს. | [19](19/ge.md) |
| **hosted zone** | Route 53-ში domain DNS records-ის container; public (internet) ან private (VPC-ზე მიბმული). | [29](29/ge.md) |
| **HPA (HorizontalPodAutoscaler)** | controller, რომელიც Deployment replicas-ის რაოდენობას metric-ის მიხედვით ცვლის. | [35](35/ge.md) |
| **HTTPRoute** | host, path და headers-ის მიხედვით backend-ზე routing rules; Gateway-ს `parentRefs`-ით მიუთითებს. VPC Lattice-ში VPC Lattice Service-ად აისახება. | [28](28/ge.md) |
| **hub-and-spoke** | topology ცენტრალური Transit Gateway-ით (hub) და მასთან დაკავშირებული teams-ის VPC-ებით (spokes). | [32](32/ge.md) |
| **Hubble** | Cilium observability subsystem: flow map და per-flow verdict, რაც VPC CNI network policy-ს არ აქვს. | [08](08/ge.md), [30](30/ge.md) |
| **IAM Access Analyzer** | resource-based policies-სა და trust policy-ში external trusted entities-ს (external access) პოულობს. | [0.2](00-2-iam/ge.md) |
| **IAM auth policy** | IAM format policy services-ს შორის traffic authorization-ისთვის; controller-ში resource `IAMAuthPolicy`. | [28](28/ge.md) |
| **IAM database authentication** | password-ის ნაცვლად temporary token-ით RDS ან Aurora login (`aws rds generate-db-auth-token`, default 15 წუთი); rotation საჭირო არ არის. | [18](18/ge.md) |
| **IAM Identity Center** | single sign-on და access-ის permission sets-ით გაცემა. | [0.1](00-1-aws/ge.md) |
| **IAM OIDC identity provider** | IAM object, რომელიც cluster issuer URL-ს არეგისტრირებს; role trust policies მასზე მიუთითებს. თითო cluster-ზე ერთხელ იქმნება. | [16](16/ge.md) |
| **IAM role** | მუდმივი keys-ის არმქონე identity, რომელსაც დროებით იღებენ. | [0.2](00-2-iam/ge.md) |
| **IAM user / group** | long-lived identity და ასეთი identities-ის ნაკრები; production-ში ერიდებიან. | [0.2](00-2-iam/ge.md) |
| **idle capacity** | paid node capacity-სა და რეალურად მოხმარებულს შორის სხვაობა; ზედმეტი requests-ისა და ცუდი bin packing-ის მაჩვენებელი. | [43](43/ge.md) |
| **image automation** | Flux controllers, რომლებიც image-ის ახალ tags-ს Git-ში უკან commit-ს უკეთებს. | [44](44/ge.md) |
| **IMDS** | Instance Metadata Service `169.254.169.254`-ზე; node role metadata-სა და credentials-ის წყარო. IMDSv1 token-ის გარეშეა, IMDSv2 session-based (`PUT` + token). | [0.2](00-2-iam/ge.md), [0.4](00-4-ec2/ge.md), [19](19/ge.md) |
| **Immutable parameter** | cluster parameter, რომლის შეცვლაც შექმნის შემდეგ შეუძლებელია: `ipFamily`, custom `serviceIpv4Cidr`, VPC, cluster name და IAM role. | [04](04/ge.md) |
| **In-place upgrade** | იმავე cluster-ის შემდეგ minor-ზე update: control plane, შემდეგ addons, შემდეგ nodes. | [03](03/ge.md), [38](38/ge.md) |
| **in-tree cloud provider** | Kubernetes components-ში ჩაშენებული AWS code, რომელიც default-ად LoadBalancer ტიპის Service-სთვის Classic Load Balancer-ს ქმნის. | [26](26/ge.md) |
| **in-tree provisioner** | ჩაშენებული `kubernetes.io/aws-ebs`, deprecated, `gp3`-ისა და snapshots-ის გარეშე; EKS-ის default `gp2` ჯერაც მას იყენებს. | [23](23/ge.md) |
| **IngressClass alb** | class controller-ით `ingress.k8s.aws/alb`; Ingress-ს `ingressClassName: alb`-ით AWS Load Balancer Controller ამუშავებს. | [27](27/ge.md) |
| **IngressGroup** | რამდენიმე Ingress-ის `group.name`-ით ერთ საერთო ALB-ში გაერთიანება; `group.order` rules-ის priority-ს განსაზღვრავს. | [27](27/ge.md) |
| **INPUT / FILTER / OUTPUT** | Fluent Bit pipeline sections-ის სამი ტიპი: read, process, send. | [34](34/ge.md) |
| **`InsufficientCidrBlocks`** | EC2 API error contiguous blocks-ის არარსებობაზე, მიუხედავად იმისა, რომ ცალკეული addresses ფორმალურად თავისუფალია. | [07](07/ge.md) |
| **Interface endpoint** | PrivateLink-ზე აგებული VPC endpoint type: ENI subnet-ში, hourly fee და data fee. | [31](31/ge.md) |
| **Internet Gateway** | public addresses-ისთვის უფასო internet gateway. | [0.3](00-3-vpc/ge.md) |
| **involuntary disruption** | uncontrolled failure: node/AZ failure, OOM, spot interruption; PDB-ის ნაცვლად placement-ით დაცვა სჭირდება. | [40](40/ge.md) |
| **ipamd** | `aws-node`-ში daemon, რომელიც node address pool-ს მართავს: secondary addresses-ს აბამს და EC2 API-ით ENI-ს ქმნის. | [06](06/ge.md) |
| **`ipFamily`** | cluster address family, რომელიც მხოლოდ creation-ზე განისაზღვრება. | [07](07/ge.md) |
| **IRSA** | IAM Roles for Service Accounts: OIDC federation-ზე დაფუძნებული დაკავშირებული `ServiceAccount`-ით pod-ისთვის IAM role-ის გაცემა. | [0.2](00-2-iam/ge.md), [16](16/ge.md), [47](47/ge.md) |
| **Karpenter** | node autoscaler, რომელიც კონკრეტული unscheduled pods-ისთვის EC2 instances-ს პირდაპირ ქმნის და type-ს allowed range-დან თავად ირჩევს. | [11](11/ge.md) |
| **KEDA** | event-driven autoscaling layer: metrics-ს HPA-ში აყენებს და მას მართავს. | [35](35/ge.md) |
| **`kms:CreateGrant`** | უფლება, რომლის გარეშეც driver volume-ს საკუთარი CMK-ით შექმნის, მაგრამ ვერ დაამაუნტებს: EBS encryption grants-ით მუშაობს და permission key policy-შიც საჭიროა. | [23](23/ge.md) |
| **krew** | plugin manager: index, `search`, `install`, `upgrade`; custom indexes-ს უჭერს მხარს. | [0.5](00-5-tools/ge.md) |
| **kube-prometheus-stack** | Helm chart Prometheus Operator-ით, Prometheus-ით, Grafana-თი, Alertmanager-ით, node-exporter-ითა და kube-state-metrics-ით. | [33](33/ge.md) |
| **`kube-reserved` / `system-reserved`** | kubelet-ის მიერ Kubernetes-ისა და OS-ისთვის reserved resources. | [14](14/ge.md) |
| **kube-state-metrics** | component, რომელიც Kubernetes objects-ის state-ს (Pending, replicas, restarts) metrics-ის სახით იძლევა. | [33](33/ge.md) |
| **Kubecost** | OpenCost-ზე დაფუძნებული product UI-ით, reports-ითა და recommendations-ით; EKS-სთვის არსებობს EKS-optimized bundle (add-on ან Helm). | [43](43/ge.md) |
| **`kubectl plugin list`** | რას ხედავს kubectl `PATH`-ში. | [0.5](00-5-tools/ge.md) |
| **`kubeProxyReplacement`** | Cilium რეჟიმი, სადაც Service/NodePort balancing-ს kube-proxy-ის ნაცვლად eBPF ასრულებს; `true` replacement-ს რთავს. საჭიროებს ახალ kernel-სა და balancing-ის კონტროლს. | [08](08/ge.md) |
| **Kustomization / HelmRelease** | Flux CRD-ები: რა და სად გამოიყენოს source-დან. | [44](44/ge.md) |
| **Kyverno** | policy engine, სადაც policy YAML resource-ია (`ClusterPolicy`/`Policy`) validate/mutate/generate/verifyImages rules-ით; reaction `Enforce`/`Audit`. | [22](22/ge.md) |
| **Landing zone** | preconfigured multi-account structure (management, shared services, environments, teams); მათ შორის AWS Control Tower-ით იშლება. | [0.1](00-1-aws/ge.md), [32](32/ge.md) |
| **Launch template** | versioned instance template (AMI, type, disk, SG, user data, IMDS); managed node group ყოველთვის მისით იშლება. | [10](10/ge.md) |
| **Launch template / Auto Scaling group** | versioned launch template / instance group `min`, `desired`, `max`-ით AZ subnets-ზე. | [0.4](00-4-ec2/ge.md) |
| **Lifecycle policy** | images-ის age-ის ან count-ის მიხედვით auto-delete rules. | [20](20/ge.md) |
| **limits** | container resource consumption-ის ზედა ზღვარი. | [14](14/ge.md) |
| **log group / log stream** | CloudWatch Logs-ში group (ჩვეულებრივ application-ზე) და მის შიგნით stream (ჩვეულებრივ pod-ზე). | [34](34/ge.md) |
| **Managed / inline policy** | reusable versioned policy / role-ში ჩაშენებული policy. | [0.2](00-2-iam/ge.md) |
| **Managed addon (EKS managed addon)** | AWS-ის მიერ curated cluster component (VPC CNI, CoreDNS, kube-proxy, CSI), რომლის version-ს EKS საკუთარი API-ით მართავს. | [0.5](00-5-tools/ge.md), [01](01/ge.md), [37](37/ge.md) |
| **managed collector (scraper)** | AMP-ის managed agentless collector, რომელიც EKS metrics-ს scrape-ს უკეთებს და workspace-ში remote-write-ით წერს. | [33](33/ge.md) |
| **managed fields / server-side apply** | mechanism, რომლითაც addon საკუთარ fields-ს აცხადებს და იყენებს; conflict resolution მას ეფუძნება. | [37](37/ge.md) |
| **Managed node group** | EKS-managed EC2 group: AWS მართავს ASG-სა და launch template-ს, command-ით update drain-ით ხდება, მაგრამ OS და node contents თქვენზეა. | [01](01/ge.md), [09](09/ge.md) |
| **Management account** | root payer account, სადაც workloads არ თავსდება. | [0.1](00-1-aws/ge.md) |
| **`matchLabelKeys`** | pod label keys, რომლებიც placement constraint-ის `labelSelector`-ს ემატება; `pod-template-hash`-ით skew ერთი Deployment revision-ის ფარგლებში ითვლება. | [40](40/ge.md) |
| **max-pods** | node-ზე pod limit: `ENI * (IP per ENI - 1) + 2`; managed node groups-ში ზედა ზღვარია 110 ან 250. | [0.4](00-4-ec2/ge.md), [06](06/ge.md), [46](46/ge.md) |
| **maxSkew** | pods count-ის დასაშვები სხვაობა ყველაზე სავსე და ყველაზე ცარიელ domain-ს შორის. | [40](40/ge.md) |
| **`memory_limiter`** | Collector processor, რომელიც memory consumption-ს ზღუდავს: threshold-ზე data ingestion-ს უარყოფს, ნაცვლად `OOMKilled`-ისა; pipeline-ში პირველი უნდა იყოს. | [36](36/ge.md) |
| **metric_relabel_configs** | scrape config section (ServiceMonitor-ში `metricRelabelings`), რომელიც high-cardinality metrics-ს (`drop` `__name__`-ით) და labels-ს (`labeldrop`) recording და remote-write-მდე შლის; volume და cost control-ის ინსტრუმენტი. | [33](33/ge.md) |
| **Metrics API (`metrics.k8s.io`)** | Kubernetes API current resource metrics-ისთვის, `kubectl top`-ისა და resource metrics-ზე HPA-ს წყარო. | [33](33/ge.md), [35](35/ge.md) |
| **metrics-server** | component, რომელიც kubelet-იდან CPU-სა და memory-ს აგროვებს და `kubectl top`-ისა და HPA-სთვის Metrics API-ით გასცემს; history და storage არ აქვს. | [33](33/ge.md) |
| **mount target** | EFS network interface კონკრეტული AZ-ის subnet-ში; ამ zone-ის nodes-ის entry point, თითო availability zone-ზე ერთი. | [24](24/ge.md) |
| **Mountpoint for Amazon S3** | client, რომელიც bucket objects-ს file interface-ით გასცემს; CSI driver-ის საფუძველი. | [25](25/ge.md) |
| **Mountpoint S3 CSI driver** | `aws-mountpoint-s3-csi-driver`, managed addon provisioner-ით `s3.csi.aws.com`; მხოლოდ static provisioning. | [25](25/ge.md) |
| **must have** | პუნქტი, რომლის გარეშეც production launch სახიფათოა და უნდა დაიბლოკოს. | [48](48/ge.md) |
| **NACL** | stateless filter subnet level-ზე; inbound და outbound rules დამოუკიდებელია. | [46](46/ge.md) |
| **namespace restore** | existing cluster-ში მაქსიმუმ 5 namespace-ის selective restore cluster-scoped resources-ის გარეშე, დაკავშირებული PV-ების გარდა. | [42](42/ge.md) |
| **NAT Gateway** | AWS managed address translation service, რომელიც private subnets-ს outbound internet access-ს აძლევს; ფასი hourly და processed GB-ზეა. | [0.3](00-3-vpc/ge.md), [31](31/ge.md) |
| **`ndots:5`** | pod resolv.conf setting, რის გამოც names search domains-ით მოწმდება. | [46](46/ge.md) |
| **nested (child) recovery point** | composite-ის შიგნით nested point: cluster state ან ცალკე volume. | [41](41/ge.md) |
| **Network ACL** | subnet-ის stateless filter, allow და deny numbered rules-ით. | [0.3](00-3-vpc/ge.md) |
| **`NETWORK_POLICY_ENFORCING_MODE`** | pod startup-ზე policy application რეჟიმი: `standard` (default allow, policies-ის გარეშე window) ან `strict` (default deny). | [08](08/ge.md), [30](30/ge.md) |
| **NetworkPolicy** | standard Kubernetes object, რომელიც pods-ისთვის allowed ingress-სა და egress-ს აცხადებს; enforcer-ის გარეშე თავად არაფერს ბლოკავს. | [30](30/ge.md) |
| **nice to have** | maturity-ის გამზრდელი პუნქტი, რომლის დასრულებაც production-ში მოგვიანებით დასაშვებია. | [48](48/ge.md) |
| **NLB (Network Load Balancer)** | L4 load balancer (TCP/UDP), high performance, static IPs; LBC მას LoadBalancer ტიპის Service-იდან ქმნის. | [26](26/ge.md) |
| **node instance role** | IAM role, რომელსაც EC2 node იღებს; kubelet მისით მიმართავს AWS API-ს. | [45](45/ge.md) |
| **Node Termination Handler (NTH)** | AWS component interruptions-ის დასამუშავებლად managed და self-managed nodes-ზე Karpenter-ის გარეშე; IMDS და Queue Processor modes. | [13](13/ge.md) |
| **nodeadm** | AL2023 და Bottlerocket node initializer; input YAML manifest `NodeConfig` (`apiVersion: node.eks.aws/v1alpha1`), `bootstrap.sh`-ის შემცვლელი. | [10](10/ge.md), [45](45/ge.md) |
| **NodeClaim** | Karpenter request კონკრეტულ node-ზე; `NodePool`-ს რეალურ `Node`-თან აკავშირებს. | [12](12/ge.md) |
| **NodeCreationFailure** | managed node group health issue: nodes launch-იდან 15 წუთში cluster-ს ვერ შეუერთდა. | [45](45/ge.md) |
| **NodeLocal DNSCache** | node-local caching DNS, რომელიც CoreDNS load-სა და per-ENI throttling-ს ამცირებს. | [46](46/ge.md) |
| **NodePool** | CRD (`karpenter.sh/v1`), რომელიც node boundaries-ს განსაზღვრავს: `requirements`, `limits`, `weight`, labels/taints და disruption policy. | [12](12/ge.md) |
| **NodePool და NodeClass** | objects, რომლებიც აღწერს, რა nodes და როგორ უნდა შეიქმნას; Auto Mode-ში defaults immutable-ია, custom-ების დამატება შეიძლება. | [09](09/ge.md) |
| **non-destructive restore** | რეჟიმი, სადაც existing objects არ გადაიწერება და გამოტოვებულია (skips SNS-ით ჩანს). | [42](42/ge.md) |
| **NotReady ცოცხალი kubelet-ით** | ჩვეულებრივ CNI მზად არ არის და pods IP-ს ვერ იღებს. | [45](45/ge.md) |
| **OIDC issuer URL** | cluster public OIDC endpoint (`oidc.eks.<region>.amazonaws.com/id/`) projected tokens-ის public signing keys-ით. | [16](16/ge.md) |
| **On-demand / Spot** | გამოყენების მიხედვით გადახდა / discounted capacity ორწუთიანი interruption-ით. | [0.4](00-4-ec2/ge.md) |
| **OOMKilled** | memory limit-ის გადაჭარბებისას kernel-ის მიერ container-ის მოკვლა. | [14](14/ge.md) |
| **OpenCost** | open vendor-neutral cost allocation standard და engine, CNCF project; consumption-ს Prometheus-იდან, resource prices-ს AWS-დან იღებს. | [43](43/ge.md) |
| **OpenSearch Service** | managed OpenSearch full-text search-ისა და dashboards-ისთვის; ფასი cluster nodes-ზეა. | [34](34/ge.md) |
| **OpenTelemetry (OTel)** | CNCF standard: unified APIs, SDK და protocol; instrumentation-ს backend-ისგან გამოყოფს. | [36](36/ge.md) |
| **OpenTelemetry Collector** | collector: receivers იღებს, processors ამუშავებს, exporters telemetry-ს backends-ში აგზავნის. | [36](36/ge.md) |
| **OpenTelemetry Operator** | operator, რომელიც pod-ში agent injection-ით auto-instrumentation-ს აკეთებს. | [36](36/ge.md) |
| **OpenTofu** | terraform-ის open fork, course modules-თან compatible; აირჩევა attribute-ით `terraform_binary = "tofu"`. | [0.5](00-5-tools/ge.md) |
| **OTLP** | telemetry transfer protocol application-იდან collector-მდე და collectors-ს შორის. | [36](36/ge.md) |
| **OU** | accounts group, რომელზეც policies გამოიყენება. | [0.1](00-1-aws/ge.md) |
| **ownership** | domain-ზე ან checklist item-ზე განსაზღვრული პასუხისმგებლობა. | [48](48/ge.md) |
| **Permissions boundary** | role ან user permissions-ის ceiling; უფლებებს თავად არ გასცემს. | [0.2](00-2-iam/ge.md) |
| **Placement group** | instances placement management: `cluster` (ერთმანეთთან ახლოს, მინიმალური latency, ერთი AZ), `partition` (partitions-ზე სხვადასხვა racks, AZ-ზე 7-მდე), `spread` (თითო ცალკე hardware-ზე, AZ-ზე მაქსიმუმ 7 running). | [0.4](00-4-ec2/ge.md) |
| **`placementGroupSelector`** | custom `NodeClass` field, რომელიც placement group-ს name ან id-ით ირჩევს. Group წინასწარ თავად იქმნება; pod-ის group membership `nodeSelector`-ით label `eks.amazonaws.com/placement-group-id`-ზე განისაზღვრება. | [09](09/ge.md), [12](12/ge.md) |
| **Platform version** | Kubernetes minor version-ის შიგნით EKS control plane-ის patch level და feature set, format `eks.<n>`, AWS ავტომატურად აახლებს. | [01](01/ge.md), [02](02/ge.md) |
| **pluto / kube-no-trouble (kubent)** | deprecated API search tools: pluto Git-სა და Helm-ში, kubent live cluster-ში. | [38](38/ge.md) |
| **Pod execution role** | IAM role, რომლითაც Fargate-ის underlying `kubelet` cluster-ში რეგისტრირდება და ECR-დან images-ს იღებს; profile creation-ზე განისაზღვრება. Built-in log router-იც ამ როლით წერს, ამიტომ log write permissions სწორედ მას სჭირდება. | [15](15/ge.md) |
| **Pod Identity association** | EKS API record, რომელიც `cluster + namespace + ServiceAccount`-ს IAM role-ს უკავშირებს; იქმნება `aws eks create-pod-identity-association`-ით. | [17](17/ge.md), [37](37/ge.md) |
| **pod readiness gate** | pod readiness-ის დამატებითი condition; AWS Load Balancer Controller `target-health.elbv2.k8s.aws`-ს false-ად ტოვებს, სანამ target `healthy` არ გახდება. | [40](40/ge.md) |
| **Pod Security Admission (PSA)** | built-in admission controller, რომელიც Pod Security Standards-ს namespace-ზე labels-ით იყენებს; Pod Security Policies ჩაანაცვლა. | [19](19/ge.md) |
| **Pod Security Standards** | profiles privileged, baseline, restricted (მკაცრი, production-ისთვის). | [19](19/ge.md) |
| **`POD_SECURITY_GROUP_ENFORCING_MODE`** | `strict` source NAT-ის გარეშე, `standard`-ის საპირისპიროდ, სადაც VPC-ს გარეთ traffic primary ENI-ით node SG rules-ის ქვეშ მიდის. | [46](46/ge.md) |
| **PodDisruptionBudget (PDB)** | object, რომელიც voluntary disruptions-ისას ერთდროულად evicted pods-ის რაოდენობას ზღუდავს (`minAvailable`/`maxUnavailable`). | [40](40/ge.md) |
| **`pods.eks.amazonaws.com`** | Pod Identity role trust policy-ის service principal; საერთოა ყველა cluster-ისა და account-ისთვის. Role credentials-ს EKS Auth API `AssumeRoleForPodIdentity`-ით გასცემს. | [17](17/ge.md) |
| **Policy** | JSON `Version`, `Statement`, `Effect`, `Action`, `Resource`, `Condition`-ით; შეიძლება იყოს identity-based (principal-ზე) ან resource-based (თავად resource-ზე). | [0.2](00-2-iam/ge.md) |
| **Policy engine** | admission webhook თქვენი rules-ით (Kyverno, Gatekeeper); etcd-ში ჩაწერამდე rules-ის მიხედვით objects-ს ამოწმებს და საჭიროებისას ცვლის. | [22](22/ge.md) |
| **`pollingInterval` და `cooldownPeriod`** | KEDA source polling period (default 30 s) და zero-ზე გადასვლამდე wait (default 300 s); მეორე მხოლოდ scale-to-zero-ზე მოქმედებს. | [35](35/ge.md) |
| **Prefix delegation** | რეჟიმი, სადაც ENI slot-ს `/28` prefix (16 addresses) იკავებს; ირთვება `ENABLE_PREFIX_DELEGATION`-ით და Nitro სჭირდება. | [07](07/ge.md), [46](46/ge.md) |
| **preserve_client_ip** | NLB target group attribute, რომელიც `ip` mode-ში original client IP-ის შენარჩუნებას მართავს. | [26](26/ge.md) |
| **preStop** | hook, რომელიც SIGTERM-მდე სრულდება; shutdown-მდე pause-ისთვის გამოიყენება. | [40](40/ge.md) |
| **Principal** | მოთხოვნის შემსრულებელი: user, role, AWS service. | [0.2](00-2-iam/ge.md) |
| **private / public endpoint** | cluster API server access mode. | [45](45/ge.md) |
| **Private hosted zone** | Route 53 zone, რომელსაც EKS ქმნის და თქვენს VPC-ს უკავშირებს, რათა endpoint name private address-ად resolve-დეს. | [02](02/ge.md) |
| **Projected service account token** | OIDC-compatible JWT SA identity-ით, audience `sts.amazonaws.com` და lifetime-ით; pod-ში mount-დება და STS-ში credentials-ზე იცვლება. | [16](16/ge.md) |
| **prometheus-adapter** | adapter, რომელიც Prometheus metrics-ს custom/external API-ში აქვეყნებს. | [35](35/ge.md) |
| **provisioningMode: efs-ap** | StorageClass mode, სადაც driver თითო PVC-ზე access point-ს ქმნის. | [24](24/ge.md) |
| **`publicAccessCidrs`** | CIDR list, რომელსაც public endpoint-ზე წვდომა აქვს; default `0.0.0.0/0`. | [02](02/ge.md) |
| **Pull through cache** | ECR rule, რომელიც external registry-ის (Docker Hub, Quay, `registry.k8s.io` და სხვ.) images-ს მოთხოვნისას თქვენს private ECR-ში cache-ს უკეთებს. | [20](20/ge.md) |
| **pull model** | cluster-ის შიგნით agent თავად იღებს Git-იდან; push-ისას ამას external pipeline აკეთებს. | [44](44/ge.md) |
| **QoS class** | `Guaranteed`, `Burstable` ან `BestEffort`; memory pressure-ისას eviction order-ს განსაზღვრავს. | [14](14/ge.md) |
| **ReadWriteMany (RWX)** | access mode: volume ერთდროულად read-write რეჟიმში ბევრ pod-ზე, ბევრ node-ზე mount-დება. | [24](24/ge.md) |
| **Rebalance recommendation** | reclamation-ის გაზრდილი რისკის ადრეული signal, რომელიც two-minute notice-მდე მოდის და workload-ის წინასწარ გატანის დროს იძლევა. | [13](13/ge.md) |
| **recovery point** | restore point, successful backup job-ის შედეგი. | [41](41/ge.md) |
| **ReferenceGrant** | Gateway API resource target resource-ის namespace-ში; ჩამოთვლილი namespaces-იდან cross-namespace references-ს (`backendRefs`, `certificateRefs`) რთავს. | [28](28/ge.md) |
| **Replication configuration** | ECR rules, რომლებიც images-ს სხვა regions-სა და accounts-ში აკოპირებს; cross-account შემთხვევაში destination account source-ს თავის registry policy-ში `ecr:CreateRepository` და `ecr:ReplicateImage` უფლებებს აძლევს. | [20](20/ge.md) |
| **Repository creation template** | settings template (encryption, lifecycle, immutability, policy) repositories-ისთვის, რომლებსაც ECR pull through cache-ისთვის prefix-ით თავად ქმნის; მის გარეშე cache repository defaults-ს იღებს (`MUTABLE`, SSE-S3, policies-ის გარეშე). | [20](20/ge.md) |
| **Repository policy / registry policy** | resource-based policies ერთ repository-ზე და account-ის მთელ registry-ზე; მათში `aws:PrincipalOrgID` მუშაობს, ამიტომ pull მთელი organization-ისთვის ერთდროულად გაიცემა. | [20](20/ge.md), [32](32/ge.md) |
| **requests** | resource amount, რომლის მიხედვითაც packing და autoscaler decision ხდება; pod-ისთვის reservation. | [14](14/ge.md) |
| **resolveConflicts** | addon field conflicts-ისას ქცევა: `NONE`, `OVERWRITE`, `PRESERVE`. | [37](37/ge.md) |
| **Resource Modifiers** | Velero ConfigMap JSON patches-ით restore-ისას objects-ზე (`--resource-modifier-configmap`); target cluster-თან incompatible fields-ის მოსაშორებლად. | [42](42/ge.md) |
| **ResourceQuota / LimitRange** | შესაბამისად namespace-ის total consumption limit და individual container-ის defaults/bounds. | [22](22/ge.md) |
| **restore hook** | init container ან exec command, რომელსაც Velero pod restore-ისას უშვებს. | [42](42/ge.md) |
| **restore job** | AWS Backup restore task; იწყება `start-restore-job`-ით, მონიტორინგი `list-restore-jobs`/`describe-restore-job`-ით. | [42](42/ge.md) |
| **retention policy** | log group-ში logs-ის შენახვის ვადა, რომლის გასვლის შემდეგ records იშლება; default-ად logs არ იწურება. | [34](34/ge.md) |
| **right-sizing** | node density-ისთვის requests/limits-ის რეალურ consumption-თან შესაბამისობაში მოყვანა. | [14](14/ge.md), [43](43/ge.md) |
| **rollback readiness** | version rollback-ისთვის მზადყოფნა: window და procedure ცნობილია. | [48](48/ge.md) |
| **rollback readiness insights** | `ROLLBACK_READINESS` category-ის cluster insights type, რომელიც rollback readiness-ს ამოწმებს; statuses PASSING/WARNING/ERROR/UNKNOWN. | [39](39/ge.md) |
| **Root user** | account owner unlimited permissions-ით, რომელიც მხოლოდ initial setup-ისასაა საჭირო. | [0.1](00-1-aws/ge.md) |
| **Route 53 Resolver** | built-in VPC DNS მისამართზე „CIDR + 2“, CoreDNS-ის upstream. | [0.3](00-3-vpc/ge.md) |
| **Route table** | subnet routes table; public და private subnet მხოლოდ default route-ით განსხვავდება. | [0.3](00-3-vpc/ge.md) |
| **RPO** | data loss-ის დასაშვები მოცულობა; backup frequency-ით განისაზღვრება. | [42](42/ge.md) |
| **RTO** | disaster-ის შემდეგ service recovery-ის target time. | [42](42/ge.md) |
| **S3 Express One Zone** | zonal storage class (directory buckets) low latency-ითა და high IOPS-ით ერთ AZ-ში; general purpose buckets-ისგან განსხვავებით `append`-ს უჭერს მხარს. | [25](25/ge.md) |
| **S3 Object Lock** | S3 bucket-ის WORM protection: object versions-ის immutability retention period-ით (Governance/Compliance), იცავს Velero backups-ს deletion-ისა და encryption-ისგან. | [42](42/ge.md) |
| **sampling** | volume და cost control-ისთვის traces-ის მხოლოდ ნაწილის ჩაწერა. | [36](36/ge.md) |
| **sampling rules** | X-Ray rules, რომლებიც reservoir-ითა და fixed rate-ით recorded requests-ის წილს განსაზღვრავს. | [36](36/ge.md) |
| **Savings Plans / RI** | 30-70% discount 1 ან 3-წლიან commitment-ზე. | [0.4](00-4-ec2/ge.md) |
| **scale-to-zero** | idle-ისას Deployment-ის zero replicas-მდე შემცირება; KEDA-ს შეუძლია, HPA-ს არა. | [35](35/ge.md) |
| **ScaledJob** | KEDA CRD work portions-ისთვის parallel Jobs count-ის scaling-ზე. | [35](35/ge.md) |
| **ScaledObject** | KEDA CRD, რომელიც Deployment scaling target-სა და triggers-ს აღწერს. | [35](35/ge.md) |
| **scaler** | KEDA metric source: `aws-sqs-queue`, `aws-cloudwatch`, `prometheus`, `kafka`, `cron` და ათეულობით სხვა. | [35](35/ge.md) |
| **Schedule** | periodic cron backup-ის Velero object; RPO-ს განსაზღვრავს. | [42](42/ge.md) |
| **SCP (Service Control Policy)** | OU ან account limiter policy: maximum permissions-ს ადგენს და თავად არაფერს რთავს. | [0.1](00-1-aws/ge.md), [0.2](00-2-iam/ge.md) |
| **Secondary CIDR** | VPC-ის დამატებითი IPv4 block; EKS-ისთვის ჩვეულებრივ `100.64.0.0/10`-დან (RFC 6598). | [07](07/ge.md) |
| **Secrets Store CSI Driver + AWS provider (ASCP)** | driver, რომელიც AWS secret-ს node volume-ში files-ად mount-ს უკეთებს; object `SecretProviderClass`, optional sync `Secret`-ში. | [18](18/ge.md) |
| **Security group** | stateful firewall ENI-ზე, მხოლოდ allow; source შეიძლება სხვა SG იყოს. | [0.3](00-3-vpc/ge.md), [46](46/ge.md) |
| **`SecurityGroupPolicy`** | resource, რომელიც selector-ით SG-ს pods-ს უკავშირებს (security groups for pods); branch ENI-ის მქონე pod node SG rules-ს აღარ inherits. | [46](46/ge.md) |
| **self-heal** | drift-ის Git-ში აღწერილ state-ზე ავტომატური დაბრუნება. | [44](44/ge.md) |
| **self-managed addon** | Helm-ით ან manifest-ით დაყენებული component; lifecycle და compatibility მთლიანად engineer-ზეა. | [37](37/ge.md) |
| **Self-managed node** | EC2 instance, რომელსაც თავად ქმნით და აერთებთ (`EC2_LINUX` ტიპის access entry); node lifecycle მთლიანად თქვენზეა. | [09](09/ge.md) |
| **service map** | services-ისა და მათ შორის links-ის map latency-ითა და edge error rate-ით. | [36](36/ge.md) |
| **Service Network** | VPC Lattice boundary services-ის ნაკრებისთვის; client VPC-ები მას services-ზე access-ისთვის უკავშირდება. | [28](28/ge.md) |
| **Service Quotas** | service limits account-სა და region-ზე, request-ით იზრდება. | [0.1](00-1-aws/ge.md) |
| **`serviceIpv4Cidr`** | virtual Service address range, რომელიც VPC-სთან დაკავშირებული არ არის. | [06](06/ge.md) |
| **ServiceMonitor, PodMonitor** | Prometheus Operator CRD-ები, რომლებიც declaratively აღწერს, რომელი endpoints უნდა დაი-scrape-ოს. | [33](33/ge.md) |
| **Session tags** | session tags (cluster, namespace, SA), რომლებსაც Pod Identity STS request-ს უმატებს და რომლებზეც ABAC იგება; policies-ში `aws:PrincipalTag/kubernetes-namespace` და `aws:PrincipalTag/eks-cluster-name`; trust policy-ში `sts:TagSession` სჭირდება. | [17](17/ge.md) |
| **shared costs** | cluster-ის საერთო ხარჯები (control plane, system namespaces, idle), რომლებიც rule-ით teams-ზე ნაწილდება ან ცალკე ნაჩვენებია. | [43](43/ge.md) |
| **Shared responsibility** | AWS პასუხისმგებელია cloud-ის უსაფრთხოებაზე, თქვენ კი cloud-ში უსაფრთხოებაზე. | [0.1](00-1-aws/ge.md), [01](01/ge.md) |
| **shared services account** | account საერთო resources-ით (ECR, private DNS zones, observability), რომლებსაც სხვა accounts იყენებს. | [32](32/ge.md) |
| **shared VPC** | model, სადაც owner subnets-ს RAM-ით აზიარებს, სხვა accounts კი იქ საკუთარ resources-ს, მათ შორის EKS nodes-ს, უშვებს. | [32](32/ge.md) |
| **showback** | teams-ს მათი cost ეჩვენება money transfer-ის გარეშე. | [43](43/ge.md) |
| **SNAT** | pod outbound traffic-ის source address-ის node address-ით ჩანაცვლება; ითიშება `AWS_VPC_K8S_CNI_EXTERNALSNAT`-ით. | [06](06/ge.md) |
| **Soft multi-tenancy** | tenants ერთ cluster-ში (namespace, RBAC, ResourceQuota, LimitRange, NetworkPolicy, policies); საერთო control plane და kernel. | [22](22/ge.md) |
| **span** | trace-ის შიგნით ცალკე operation (processing, call, database query) time-ითა და attributes-ით; spans trace tree-ს ქმნის. | [36](36/ge.md) |
| **split-horizon DNS** | ერთი name სხვადასხვა external და VPC-internal პასუხით, public და private zones-ის წყვილის მეშვეობით. | [29](29/ge.md) |
| **Spot interruption notice** | instance stop ან termination-მდე ორი წუთით ადრე notification; graceful shutdown-ის მკაცრი დროითი ჩარჩო. | [13](13/ge.md) |
| **Spot instance** | discounted spare EC2 capacity, რომლის დაბრუნებაც AWS-ს ნებისმიერ დროს შეუძლია, როცა on-demand demand-ს დასჭირდება. | [13](13/ge.md) |
| **Spot pool** | „instance type + availability zone“ წყვილი; capacity pools-ის მიხედვით იბრუნება. | [13](13/ge.md) |
| **ssl-redirect** | annotation, რომელიც HTTP-დან HTTPS-ზე მითითებულ listener port-ზე redirect-ს რთავს. | [27](27/ge.md) |
| **SSM Session Manager** | SSM agent-ით instance access SSH-ის გარეშე. | [45](45/ge.md) |
| **Staging labels** | Secrets Manager secret version labels: `AWSCURRENT` default-ად იკითხება, `AWSPENDING` rotation-ზე შესამოწმებელი value-ა, `AWSPREVIOUS` წინაა. | [18](18/ge.md) |
| **Stakater Reloader** | controller, რომელიც mounted `Secret` ან `ConfigMap` change-ისას annotation-ით Deployment rolling restart-ს აკეთებს, რათა pod-მა ახალი value აიღოს. | [18](18/ge.md) |
| **Standard support** | EKS minor version support phase (დაახლოებით 14 თვე), ჩვეულებრივი მუშაობა version surcharge-ის გარეშე. | [03](03/ge.md), [38](38/ge.md), [48](48/ge.md) |
| **State** | Terraform code-სა და real resources-ს შორის mapping file; ინახება S3-ში versioning-ითა და write locking-ით. | [0.5](00-5-tools/ge.md), [04](04/ge.md) |
| **stdout/stderr** | container standard output streams; Kubernetes convention-ით application logs-ს იქ წერს და არა container-ის შიდა files-ში. | [34](34/ge.md) |
| **STS** | temporary keys service; `sts:AssumeRole`, `sts:AssumeRoleWithWebIdentity`. | [0.2](00-2-iam/ge.md) |
| **Subnet CIDR reservation** | subnet-ის შიგნით contiguous block-ის prefixes-ისთვის reservation. | [07](07/ge.md) |
| **subnet IP exhaustion** | subnet-ში ENI-ებისა და pods-ისთვის free addresses აღარ დარჩა. | [46](46/ge.md) |
| **sync waves** | Argo CD-ში sync phases-ის შიგნით resources application order waves-ით. | [44](44/ge.md) |
| **Tag immutability** | repository mode `IMMUTABLE`, რომელიც tag-ის სხვა image-ით overwrite-ს კრძალავს; `MUTABLE` (default) overwrite-ს რთავს. | [20](20/ge.md) |
| **target EKS cluster** | existing cluster, სადაც restore ხდება; ან AWS Backup ქმნის restore-ის ფარგლებში (`newCluster=true`). | [42](42/ge.md) |
| **target-type** | NLB target type: `instance` (node `NodePort`-ით) ან `ip` (პირდაპირ pod IP-ზე, საჭიროებს VPC CNI-ს და Fargate-ზე სავალდებულოა). | [26](26/ge.md), [27](27/ge.md) |
| **`terminationGracePeriod`** | node drain limit; მისი არსებობისას drift blocking PDB-ებისა და `do-not-disrupt`-ის მიუხედავად სრულდება. | [12](12/ge.md) |
| **terminationGracePeriodSeconds** | pod shutdown-ისთვის SIGTERM-სა და SIGKILL-ს შორის დრო (default 30). | [40](40/ge.md) |
| **terragrunt** | terraform wrapper: common backend, `env.hcl`, `dependency`, `run-all`, DRY modules copy-paste-ის გარეშე. | [0.5](00-5-tools/ge.md) |
| **Thanos** | components-ის ნაკრები, რომელიც Prometheus-ს object storage-ში long-term storage-ს უმატებს: `sidecar` blocks-ს S3-ში ტვირთავს, `store gateway` უკან კითხულობს, `compactor` compact/downsampling/retention-ს აკეთებს, `querier` unified PromQL-სა და HA pair deduplication-ს იძლევა, `ruler` history-ზე rules-ს ითვლის. | [33](33/ge.md) |
| **throughput mode** | EFS throughput რეჟიმი: Elastic, Bursting ან Provisioned. | [24](24/ge.md) |
| **topology aware routing** | client zone-ში endpoints-ის preference; Service-ში `trafficDistribution: PreferClose` field-ით ირთვება. | [31](31/ge.md) |
| **topologySpreadConstraints** | pod field replicas-ის domains-ზე თანაბარი განაწილებისთვის (`maxSkew`, `topologyKey`, `whenUnsatisfiable`, `minDomains`). | [40](40/ge.md) |
| **trace** | ერთი request-ის სრული გზა services-ში, საერთო `trace id`-ით. | [36](36/ge.md) |
| **Transit Gateway** | regional router-hub transitive routing-ით დაკავშირებულ VPC-ებს, VPN-სა და Direct Connect-ს შორის; RAM-ით share-დება. | [32](32/ge.md) |
| **TriggerAuthentication** | KEDA CRD trigger access parameters-ით; AWS-ისთვის provider `aws` IRSA ან Pod Identity-ით. | [35](35/ge.md) |
| **Trust policy** | role trust policy: `Federated` principal (OIDC provider ARN), `Action` `sts:AssumeRoleWithWebIdentity` და `StringEquals` conditions `sub`-სა და `aud`-ზე. | [0.2](00-2-iam/ge.md), [16](16/ge.md), [47](47/ge.md) |
| **TXT registry** | external-dns mechanism, რომელიც საკუთარ records-ს TXT marker-ით აღნიშნავს; owner `--txt-owner-id`-ით განისაზღვრება. | [29](29/ge.md) |
| **Unauthorized (401)** | authentication failure: identity არ დადასტურდა ან mapping არ აქვს. | [47](47/ge.md) |
| **`unhealthyPodEvictionPolicy`** | PDB field: `IfHealthyBudget` (default) unhealthy pods-ის eviction-ს უკვე disrupted application-ში კრძალავს, `AlwaysAllow` კი ყოველთვის რთავს. | [40](40/ge.md) |
| **upgrade insights** | insights type, რომელიც upgrade readiness-სა და removed APIs-ს აღნიშნავს. | [38](38/ge.md) |
| **Upgrade policy (`supportType`)** | cluster configuration field values-ით `STANDARD` და `EXTENDED`, რომელიც standard support-ის ბოლოს ქცევას განსაზღვრავს. Extended support default-ად ჩართულია; policy switch-ით მისგან გამოსვლა შეუძლებელია, მხოლოდ upgrade-ით. | [03](03/ge.md) |
| **`useCachedMetrics` და `fallback`** | polling interval-ში value caching და source unavailable-ისას replica count; ერთად API throttling-ისა და `TARGETS`-ში `<unknown>`-ის რისკს ამცირებს. | [35](35/ge.md) |
| **User data** | script ან config, რომელიც instance first boot-ზე სრულდება; bootstrap-ს უშვებს და `kubelet`-ს აწყობს. | [0.4](00-4-ec2/ge.md), [10](10/ge.md) |
| **ValidatingAdmissionPolicy** | apiserver-ში built-in CEL validation (Kubernetes 1.30+), external webhook-ის გარეშე; წყვილია `ValidatingAdmissionPolicyBinding`-თან (scope და reaction `Deny`/`Warn`/`Audit`). | [22](22/ge.md) |
| **Vault Lock** | vault-ის WORM protection backup deletion-ისგან; governance mode (IAM-ით იხსნება) და compliance mode (grace time-ის შემდეგ immutable). | [41](41/ge.md) |
| **Velero** | Kubernetes-native backup/restore; objects S3-ში (BackupStorageLocation), volumes CSI snapshots-ით ან File System Backup-ით. | [42](42/ge.md) |
| **velero-plugin-for-aws** | official Velero plugin AWS-ისთვის: S3 object store (BSL) და EBS snapshots-ის volume snapshotter. | [42](42/ge.md) |
| **Version skew** | upstream policy-ით kubelet-ის API server-ისგან დასაშვები ჩამორჩენა; „ჯერ control plane, შემდეგ nodes“ order-ის მიზეზი. | [03](03/ge.md), [37](37/ge.md) |
| **version skew policy** | Kubernetes rule: nodes control plane-ზე ახალი არ უნდა იყოს; rollback order-ს განსაზღვრავს (ჯერ nodes, შემდეგ control plane). | [38](38/ge.md), [39](39/ge.md) |
| **VersionRollback** | rollback-ისას `update-cluster-version` response-ში update type. | [39](39/ge.md) |
| **VictoriaLogs** | dependency-free log database schema-სა და index configuration-ის გარეშე; columnar disk storage, LogsQL queries, ingestion Elasticsearch bulk, Loki push, OTLP და syslog protocols-ით; აქვს cluster variant (`vlinsert`, `vlstorage`, `vlselect`). | [34](34/ge.md) |
| **VictoriaMetrics** | metrics storage replacement და არა layer: `vmagent` collection-ისთვის, `vmsingle` ან cluster `vminsert`/`vmstorage`/`vmselect`, `vmalert` rules-ისთვის, retention flag `-retentionPeriod`, MetricsQL როგორც PromQL extension. | [33](33/ge.md) |
| **volume node affinity conflict** | scheduler event, როცა volume `nodeAffinity` მიუთითებს zone-ზე, სადაც suitable node არ არის. | [23](23/ge.md) |
| **`volumeBindingMode`** | volume provisioning-ის დრო: `Immediate` (PVC-ის გაჩენისას) ან `WaitForFirstConsumer` (pod scheduling-ისას). | [23](23/ge.md) |
| **VolumeSnapshot / Content / Class** | CSI snapshot objects: request, AWS snapshot, class. | [23](23/ge.md) |
| **voluntary disruption** | განზრახ pod eviction: drain, node upgrade, consolidation; PDB-ით არის დაცული. | [40](40/ge.md) |
| **VPC** | isolated regional network; primary CIDR (`/16` ... `/28`) immutable-ია და მხოლოდ secondary CIDR-ით ფართოვდება. | [0.3](00-3-vpc/ge.md) |
| **VPC CNI** | AWS network plugin, რომელიც pods-ს VPC subnets-იდან real private addresses-ს ანიჭებს; DaemonSet `aws-node` `kube-system`-ში. | [06](06/ge.md) |
| **VPC CNI network policy** | eBPF-ზე `NetworkPolicy`-ის built-in implementation: control plane controller და `aws-node`-ში agent `aws-network-policy-agent`; addon parameter `enableNetworkPolicy`-ით ირთვება. | [08](08/ge.md), [30](30/ge.md) |
| **VPC endpoint** | AWS service-ზე private access: gateway (S3, DynamoDB) ან interface (PrivateLink). | [0.3](00-3-vpc/ge.md), [31](31/ge.md) |
| **VPC endpoint (PrivateLink)** | VPC-ის შიგნით AWS service-ის private entry point; private data node-სთვის აუცილებელია ECR, S3, STS, EKS და სხვა services-ზე. | [19](19/ge.md) |
| **VPC Flow Logs** | accepted და rejected flows-ის records; CloudWatch Logs Insights-ში filter `action = REJECT` SecOps-ისა და diagnostics-ის ინსტრუმენტია. | [0.3](00-3-vpc/ge.md) |
| **VPC Lattice** | managed application networking service VPC-ებსა და accounts-ს შორის east-west communication-ისთვის sidecars-ისა და peering-ის გარეშე. | [28](28/ge.md) |
| **VPC peering** | ორი VPC-ის direct one-to-one connection; non-transitive-ია და non-overlapping CIDR-ებს საჭიროებს. | [32](32/ge.md) |
| **wafv2-acl-arn** | annotation AWS WAF v2 Web ACL-ის ALB-ზე მისაბმელად request filtering-ისთვის. | [27](27/ge.md) |
| **warm pool** | pod fast startup-ისთვის node-ზე წინასწარ გამოყოფილი IPv4 addresses-ის მარაგი. | [06](06/ge.md) |
| **`WARM_PREFIX_TARGET`** | node-ზე prefixes-ის მარაგი; `WARM_IP_TARGET` და `MINIMUM_IP_TARGET` მასზე priority-ს ფლობს. | [07](07/ge.md) |
| **workspace** | AMP-ში isolated metrics storage საკუთარი remote-write endpoint-ითა და Prometheus-compatible API-ით. | [33](33/ge.md) |
| **X-Amzn-Trace-Id** | X-Ray header fields-ით `Root`, `Parent`, `Sampled`; ADOT X-Ray propagator მას W3C `traceparent`-ს უკავშირებს და end-to-end `trace id`-ს ინარჩუნებს. | [36](36/ge.md) |
| **ZoneId (`euc1-az1`)** | stable availability zone name, რომელიც ყველა account-ში ერთნაირია. | [0.1](00-1-aws/ge.md) |
| **`adot` addon** | EKS managed addon, რომელიც collectors-ის სამართავად ADOT Operator-ს შლის. | [36](36/ge.md) |
| **Account** | resources-ის isolated space და billing unit; 12-digit number ARN-სა და trust policy-ში გამოიყენება. | [0.1](00-1-aws/ge.md) |
| **Secondary private address** | node ENI-ზე დამატებითი IPv4 address, რომელიც pod-ს ეძლევა. | [06](06/ge.md) |
| **Diversification** | ბევრი instance type რამდენიმე AZ-ში, რათა ერთი pool-ის reclamation-მა nodes-ის კრიტიკული წილი არ გათიშოს. | [13](13/ge.md) |
| **Readiness domain** | operation-ის ერთი განზომილება (control plane, nodes, security, networking, storage, observability, operations, incidents), რომელიც ცალკე მოწმდება. | [48](48/ge.md) |
| **Drift** | actual state-ის code-ში ან Git-ში აღწერილისგან განსხვავება. | [04](04/ge.md), [44](44/ge.md) |
| **inter-stack dependency** | ერთი stack-ის outputs-ის მეორის inputs-ში გადაცემა (Terragrunt-ში `dependency` block). | [04](04/ge.md) |
| **EC2 instance** | virtual machine; EKS-ისთვის node containerd-ითა და kubelet-ით. | [0.4](00-4-ec2/ge.md) |
| **local cache** | node volume-ზე Mountpoint data cache (`cache: emptyDir`/`ephemeral`), რომელიც repeated reads-ს აჩქარებს; metadata cache `metadata-ttl`-ით განისაზღვრება. | [25](25/ge.md) |
| **node scaling და pod scaling** | სხვადასხვა levels: nodes-ს CA და Karpenter scale-ს უკეთებს, pods-ს HPA, VPA, KEDA. | [11](11/ge.md) |
| **Micro-VM** | თითო pod-ისთვის dedicated virtual machine საკუთარი kernel-ით, CPU-ით, memory-ითა და network interface-ით; Fargate isolation boundary. | [15](15/ge.md) |
| **Object storage** | key-value model: object (bytes + metadata) string key-ის ქვეშ, immutable, მთლიანად ახლდება `PutObject`-ით. | [25](25/ge.md) |
| **rollback window (7 დღე)** | upgrade-ის შემდეგ period, როცა rollback ხელმისაწვდომია; გასვლის შემდეგ rollback და მისი insights აღარ არის. | [39](39/ge.md) |
| **kubectl plugin** | `PATH`-ში file `kubectl-<name>`, რომელიც ხელმისაწვდომია როგორც `kubectl <name>`. | [0.5](00-5-tools/ge.md) |
| **Subnet** | VPC CIDR-ის ნაწილი ერთ AZ-ში. | [0.3](00-3-vpc/ge.md) |
| **Full replacement** | `aws-node` წაშლილია, Cilium ერთადერთი CNI-ა საკუთარი IPAM-ით: ENI IPAM (real VPC addresses) ან cluster-pool (overlay/VXLAN, virtual addresses). | [08](08/ge.md) |
| **prefix** | key-ის ნაწილი `/`-მდე, რომლითაც Mountpoint directory-ს ემულირებს; S3-ში ნამდვილი directories არ არის. | [25](25/ge.md) |
| **forced upgrade** | extended support-ის დასრულებისას automatic version upgrade; ასეთი cluster-ის rollback შეუძლებელია. | [38](38/ge.md) |
| **Provider** | terraform plugin (`aws`, `kubernetes`, `helm`). | [0.5](00-5-tools/ge.md) |
| **progressive delivery** | applications-ის canary/blue-green deployment (Argo Rollouts, Flagger). | [44](44/ge.md) |
| **Production checklist** | domains-ის მიხედვით readiness checks-ის სისტემური list, სადაც ყოველი item ან დახურულია, ან known risk-ად მონიშნული. | [48](48/ge.md) |
| **Profile** | named parameters set: region, role, SSO. | [0.5](00-5-tools/ge.md) |
| **Region** | geographic location (`eu-central-1`), რომელსაც resources ეკუთვნის. | [0.1](00-1-aws/ge.md) |
| **external რეჟიმი** | `aws-load-balancer-type` annotation value, რომელიც Service reconciliation-ს in-tree provider-ის ნაცვლად external LBC controller-ს გადასცემს. | [26](26/ge.md) |
| **EBS access modes** | `ReadWriteOnce` (ერთი node) და `ReadWriteOncePod` (ზუსტად ერთი pod); `ReadWriteMany` შესაძლებელია მხოლოდ Multi-Attach `io2`-ით `volumeMode: Block` რეჟიმში ერთ AZ-ში და filesystem-ის გარეშე. Shared file access-ისთვის EFS ან FSx გამოიყენება. | [23](23/ge.md) |
| **reconciliation** | desired state-ის (Git) actual state-თან (cluster) შედარებისა და შესაბამისობაში მოყვანის უწყვეტი cycle. | [44](44/ge.md) |
| **static provisioning** | PV ხელით აღიწერება `bucketName`-ით; driver-ს dynamic provisioning და bucket creation არ აქვს. | [25](25/ge.md) |
| **Stack** | infrastructure-ის independently applied unit საკუთარი state-ით. | [0.5](00-5-tools/ge.md), [04](04/ge.md) |
| **Rotation strategy** | `single user` (ერთი user-ის password იცვლება, არსებობს failures-ის მოკლე risk window, რომელიც delayed retries-ით იფარება) ან `alternating users` (ორი user მონაცვლეობით, valid credentials ყოველთვის არსებობს, საჭიროა superuser permissions-ის secret). | [18](18/ge.md) |
| **Spot strategy** | pool selection: `capacity-optimized(-prioritized)` ან `lowest-price`; capacity-oriented strategies ნაკლებად ხშირად წყდება. | [0.4](00-4-ec2/ge.md) |
| **Tag** | key/value pair; tags-ით EKS controllers resources-ს პოულობს, activated cost allocation tag კი billing breakdown-ისთვის გამოიყენება. | [0.1](00-1-aws/ge.md) |
| **Instance type** | `family + generation + suffix . size`, მაგალითად `m7g.xlarge`. | [0.4](00-4-ec2/ge.md) |
| **control plane log types** | `api`, `audit`, `authenticator`, `controllerManager`, `scheduler`; მხოლოდ ჩართვის შემდეგ იწერება CloudWatch Logs-ში. | [02](02/ge.md) |
| **EKS managed capability for Argo CD** | Argo CD როგორც EKS Capability: controllers AWS control plane-შია, targets მხოლოდ ARN-ით EKS clusters-ია, access მათში EKS access entries-ით ხდება. | [44](44/ge.md) |
| **kubernetes filter** | Fluent Bit FILTER, რომელიც records-ს namespace, pod, container, labels და annotations-ს უმატებს. | [34](34/ge.md) |
| **Argo CD sharding** | connected clusters-ის application-controller replicas-ზე განაწილება. | [44](44/ge.md) |
| **--force** | flag, რომელიც insights checks-ს (ERROR/WARNING/UNKNOWN) გვერდს უვლის, მაგრამ prerequisites-ს არა (window, ერთი minor, created-on-version, feature compatibility). | [39](39/ge.md) |
| **/var/log/containers** | node directory container log files-ის symlinks-ით; ადგილი, საიდანაც collector logs-ს იღებს. | [34](34/ge.md) |
