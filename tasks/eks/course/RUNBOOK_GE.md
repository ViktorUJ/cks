[Русская версия](RUNBOOK_RU.md) · [Eng version](RUNBOOK.md) · [Versión en español](RUNBOOK_ES.md) · [Version française](RUNBOOK_FR.md) · [Deutsche Version](RUNBOOK_DE.md) · [繁體中文版](RUNBOOK_TW.md) · [日本語版](RUNBOOK_JP.md)

# EKS-ის დიაგნოსტიკური ცნობარი: სიმპტომი, მიზეზი, შემოწმება

[კურსის სარჩევი](README_GE.md) · [ტერმინთა ლექსიკონი](GLOSSARY_GE.md)

## როგორ გამოვიყენოთ ეს ცნობარი

ეს არის 45-ე, 46-ე და 47-ე თავების „დიაგნოსტიკის თანმიმდევრობა და ხელსაწყოები“ სექციების
ერთ ფაილში თავმოყრილი შეჯამება მორიგეობისთვის: ინციდენტის დროს სამი თავის ფურცვლა მოუხერხებელია.
გამოყენების წესი ასეთია: ჯერ „სიმპტომის მიხედვით სწრაფი ძიების“ ცხრილში განსაზღვრეთ სიმპტომის
კლასი, შემდეგ გადადით შესაბამის ფენაზე და ზემოდან ქვემოთ მიჰყევით ნაბიჯებს. კლასიფიკაცია
ხელსაწყოზე მნიშვნელოვანია: `ContainerCreating` მდგომარეობაში მყოფ პოდსა და დამბალანსებლიდან
მიღებულ 503-ს სხვადასხვა ბრძანებებით აგვარებენ.
აქ მხოლოდ შემოწმების თანმიმდევრობა, საკონტროლო სიები და ბრძანებებია. მიზეზების განხილვა,
მექანიკა და განმარტებები 45-47-ე თავებში დარჩა; მათი ბმულები ნავიგატორის თითოეულ სტრიქონშია.

## სიმპტომის მიხედვით სწრაფი ძიება

| რას ხედავთ | კლასი | სად გადახვიდეთ |
|---|---|---|
| `kubectl get nodes` ცარიელია, ნოდები არ არის | ნოდი არ შეუერთდა | [ნოდი](#ნოდი-არ-შეუერთდა-კლასტერს), [თავი 45](45/ge.md) |
| `NodeCreationFailure`, `Instances failed to join the kubernetes cluster` | ნოდი არ შეუერთდა | [ნოდი](#ნოდი-არ-შეუერთდა-კლასტერს), [თავი 45](45/ge.md) |
| node group არის `CREATE_FAILED` ან `DEGRADED` მდგომარეობაში | ნოდი არ შეუერთდა | [ნოდი](#ნოდი-არ-შეუერთდა-კლასტერს), [თავი 45](45/ge.md) |
| kubelet-ის ლოგშია `node "" not found` | ნოდი: DNS და private DNS name | [ნოდი](#ნოდი-არ-შეუერთდა-კლასტერს), [თავი 45](45/ge.md) |
| ნოდი ჩანს, მაგრამ `NotReady` მდგომარეობაშია | CNI მზად არ არის, სხვა ფენა | [ნოდი](#ნოდი-არ-შეუერთდა-კლასტერს), [თავი 45](45/ge.md), თავი 8 |
| პოდი `ContainerCreating` მდგომარეობაშია, `failed to assign an IP address to container` | ქსელი: IP და ENI | [ქსელი](#ქსელური-გაუმართაობები-მოქმედ-კლასტერში), [თავი 46](46/ge.md) |
| პოდი-პოდი ან პოდი-RDS: `connection timed out`, DNS რეზოლვინგი მუშაობს | ქსელი: security group | [ქსელი](#ქსელური-გაუმართაობები-მოქმედ-კლასტერში), [თავი 46](46/ge.md) |
| მოთხოვნა იგზავნება, მაგრამ კავშირი იჭედება | ქსელი: NACL და ephemeral ports | [ქსელი](#ქსელური-გაუმართაობები-მოქმედ-კლასტერში), [თავი 46](46/ge.md) |
| პოდი სახელებს ვერ არეზოლვებს და readiness შემოწმებას ვერ გადის | ქსელი: პოდის საკუთარი SG | [ქსელი](#ქსელური-გაუმართაობები-მოქმედ-კლასტერში), [თავი 46](46/ge.md) |
| DNS ხან მუშაობს, ხან არა; არასტაბილური timeout-ები | ქსელი: DNS | [ქსელი](#ქსელური-გაუმართაობები-მოქმედ-კლასტერში), [თავი 46](46/ge.md) |
| ზედმეტი DNS დატვირთვა გარე სახელებისთვის | ქსელი: `ndots:5`-ის ეფექტი | [ქსელი](#ქსელური-გაუმართაობები-მოქმედ-კლასტერში), [თავი 46](46/ge.md) |
| target group-ში target-ები `unhealthy` მდგომარეობაშია, 502 `Bad gateway` | ქსელი: დამბალანსებელი | [ქსელი](#ქსელური-გაუმართაობები-მოქმედ-კლასტერში), [თავი 46](46/ge.md) |
| LB-ის უკან არსებული სერვისიდან 503 `Service unavailable` | ქსელი: გამართული target-ები არ არის | [ქსელი](#ქსელური-გაუმართაობები-მოქმედ-კლასტერში), [თავი 46](46/ge.md) |
| `You must be logged in to the server (Unauthorized)` | წვდომა: ავთენტიფიკაცია | [წვდომა](#წვდომაზე-უარი-ადამიანი-და-პოდი), [თავი 47](47/ge.md) |
| `couldn't get current server API group list: Unauthorized` | წვდომა: kubeconfig ან რეგიონი | [წვდომა](#წვდომაზე-უარი-ადამიანი-და-პოდი), [თავი 47](47/ge.md) |
| `Forbidden: cannot <verb> resource` | წვდომა: RBAC | [წვდომა](#წვდომაზე-უარი-ადამიანი-და-პოდი), [თავი 47](47/ge.md) |
| AWS-ის გამოძახებისას პოდი `AccessDenied` შეცდომით ითიშება | პოდის წვდომა: STS და როლი | [წვდომა](#წვდომაზე-უარი-ადამიანი-და-პოდი), [თავი 47](47/ge.md) |
| პოდი `WebIdentityErr: failed to retrieve credentials` შეცდომით ითიშება | პოდის წვდომა: IRSA | [წვდომა](#წვდომაზე-უარი-ადამიანი-და-პოდი), [თავი 47](47/ge.md) |

## ნოდი არ შეუერთდა კლასტერს

თავი 45. სიმპტომი ერთია: ცარიელი `kubectl get nodes` და `NodeCreationFailure`, მიზეზები კი
სხვადასხვა ფენაზეა. შემოწმების თანმიმდევრობა ზემოდან ქვემოთ ასეთია:

1. IAM ფენა: node instance role-ის უფლებები და კლასტერში როლის ავტორიზაცია (სექცია 45.2).
2. ქსელის ფენა: API server-ის endpoint-მდე გზა 443 პორტზე, endpoint-ის ტიპი, DNS (სექცია 45.3).
3. user data და bootstrap ფენა: `bootstrap.sh` AL2-ზე, `nodeadm`/`NodeConfig` AL2023-ზე (45.4).
4. kubelet-ის ფენა: დემონი გაშვებულია, kubeconfig და სერტიფიკატი დაზიანებული არ არის, რეგისტრაცია დასრულდა (45.5).

ლოგიკა ასეთია: ჯერ `describe-nodegroup`-ით ჰკითხეთ EKS-ს, შემდეგ შეამოწმეთ როლის ავტორიზაცია
(იაფია და ყველაზე ხშირად სწორედ ის არის მიზეზი), მერე endpoint-მდე ქსელი და მხოლოდ ამის შემდეგ
შედით ნოდზე cloud-init-ისა და kubelet-ის ლოგების სანახავად. განასხვავეთ „ნოდები არ არის“ და
`NotReady`: მოქმედი kubelet-ის შემთხვევაში მეორე თითქმის ყოველთვის CNI-ს უკავშირდება, რაც მე-8 თავშია განხილული.

| სიმპტომი | სავარაუდო მიზეზი | რა შევამოწმოთ |
|---|---|---|
| `NodeCreationFailure`, ნოდები არ არის | ნოდის როლი ავტორიზებული არ არის | `aws eks list-access-entries`, `aws-auth` |
| ნოდები არ არის, IAM გამართულია | 443 პორტზე API-მდე გზა არ არის | SG, NAT/IGW მარშრუტი, endpoint-ის ტიპი |
| ნოდები არ არის, კლასტერი კერძოა | endpoint არ რეზოლვდება | DNS, DHCP options set VPC-ში |
| ნოდები არ არის, მორგებული AMI | bootstrap არ შესრულდა | `/var/log/cloud-init-output.log` |
| ნოდები არ არის, kubelet ითიშება | დაზიანებული kubeconfig/სერტიფიკატი | `journalctl -u kubelet` |
| ნოდი არის, მაგრამ `NotReady` მდგომარეობაშია | CNI მზად არ არის, პოდებისთვის IP-ები არ არის | `aws-node` პოდი, ნოდის მოვლენები (თავი 8) |
| ლოგშია `node "" not found` | private DNS name არ არის | DHCP options, DNS VPC-ში |

```bash
# 1. რას ამბობს თავად EKS node group-ის შესახებ
aws eks describe-nodegroup --cluster-name prod --nodegroup-name ng-1 \
  --query 'nodegroup.health.issues'
# 2. ხედავს თუ არა კლასტერი ნოდებს
kubectl get nodes
# 3. ავტორიზებულია თუ არა ნოდის როლი
aws eks list-access-entries --cluster-name prod
# მოძველებული გზა: mapping-ები aws-auth-ში
kubectl -n kube-system get configmap aws-auth -o yaml
# 4. ნოდზე SSM Session Manager-ის მეშვეობით: bootstrap/cloud-init-ის ლოგი
sudo cat /var/log/cloud-init-output.log
# 5. ნოდზე: kubelet-ის სტატუსი და ლოგები
systemctl status kubelet
journalctl -u kubelet -n 200 --no-pager
```

ნოდზე SSH-ის გარეშე წვდომისთვის იყენებენ SSM Session Manager-ს: საჭიროა SSM agent და უფლებები.
თუ SSM მიუწვდომელია, რჩება ინსტანსის კონსოლის გამონატანი (system log) და `/var/log`.

## ქსელური გაუმართაობები მოქმედ კლასტერში

თავი 46. კლასტერი მუშაობს და ნოდები `Ready` მდგომარეობაშია, მაგრამ ქსელი სხვადასხვა გზით ფერხდება.
ჯერ დაახარისხეთ სიმპტომი: IP არ არის, კავშირი წყდება, DNS, დამბალანსებლიდან 5xx. კლასი განსაზღვრავს
ფენასა და ბრძანებას. `describe pod` და `get pods -o wide` იაფია და პირველივე ეტაპზე გამორიცხავს
IP-სთან დაკავშირებულ პრობლემებს, `describe-target-health` მყისიერად ადგენს დამბალანსებლის
გაუმართაობის ადგილს, ხოლო VPC Flow Logs ბოლო საშუალებაა იმ წყვეტებისთვის, რომლებსაც ვერც IP და
ვერც health check ვერ ხსნის. გახსოვდეთ ფენებს შორის განსხვავება: security group არის stateful და
ENI-ის დონეზე მუშაობს, NACL კი stateless არის და ქვექსელის დონეზე მუშაობს, ამიტომ NACL-ში
ephemeral ports-ზე საპასუხო ტრაფიკს ხელით რთავენ.

| სიმპტომი | სავარაუდო მიზეზი | რა შევამოწმოთ |
|---|---|---|
| `failed to assign an IP address` | ნოდზე ან ქვექსელში თავისუფალი IP-ები არ არის | `describe pod`, `AvailableIpAddressCount` |
| პოდი-პოდი ან პოდი-RDS timeout | SG ტრაფიკს არ უშვებს | `describe-network-interfaces` Groups, RDS-ის SG |
| კავშირი წყდება, თუმცა მოთხოვნა იგზავნება | NACL ephemeral ports-ს ბლოკავს | NACL-ის in/out წესები, VPC Flow Logs |
| DNS-ს მონაცვლეობითი timeout-ები აქვს | CoreDNS, conntrack, per-ENI throttling | CoreDNS-ის მეტრიკები (თავი 33), conntrack, PPS |
| ზედმეტი DNS დატვირთვა გარე სახელებისთვის | `ndots:5`-ის ეფექტი | search დომენები, წერტილით დასრულებული FQDN |
| LB-ის უკან არსებული სერვისიდან 502 ან 503 | target-ები `unhealthy` მდგომარეობაშია | `describe-target-health`, health check, SG |
| target-ები `unhealthy` მდგომარეობაშია, პოდი მოქმედია | health check-ის გზა/პორტი ან SG | შემოწმების გზა და პორტი, დამბალანსებლის SG |
| პოდს არც DNS აქვს და არც readiness | ნოდის SG-ის ნაცვლად პოდის საკუთარი SG | პოდის `SecurityGroupPolicy`, 53 TCP/UDP, ნოდების SG-დან შემავალი ტრაფიკი |

```bash
# 1. პოდის მოვლენები: ContainerCreating-ისა და IP-ის გაცემის პრობლემის მიზეზი
kubectl describe pod <pod>
# 2. სად არის პოდი და რომელ ნოდზეა
kubectl get pods -o wide
# 3. კონკრეტულ მისამართზე არსებული ENI, IP და SG
aws ec2 describe-network-interfaces \
  --filters "Name=private-ip-address,Values=<ip>" --query 'NetworkInterfaces[0]'
# 4. თავისუფალი მისამართები ქვექსელში
aws ec2 describe-subnets --subnet-ids <subnet> \
  --query 'Subnets[0].AvailableIpAddressCount'
# 5. დამბალანსებლის target-ების მდგომარეობა
aws elbv2 describe-target-health --target-group-arn "$TG_ARN"
# არის თუ არა სერვისის უკან მზა endpoints
kubectl get endpointslices -l kubernetes.io/service-name=<svc>
# 6. რეზოლვინგის შემოწმება პოდიდან
kubectl run dnstest --image=busybox:1.36 --rm -it --restart=Never -- nslookup <name>
# პოდის საკუთარი SG: გამოყენების რეჟიმი და შეცდომის ძიება SG-ის id-ში
kubectl describe daemonset aws-node -n kube-system | grep -iE 'SECURITY_GROUP|DEMUX'
kubectl describe pod <pod> | grep -i InvalidSecurityGroupID
# 7. ნოდზე: VPC CNI-ის ქსელის dump-ის შეგროვება (ipamd/plugin-ის ლოგები, ENI, eni-configs)
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids <instance-id> \
  --parameters 'commands=["/opt/cni/bin/aws-cni-support.sh"]'
```

ipamd-ის მდგომარეობა უშუალოდ მისი ლოკალური endpoint-იდანაც ჩანს: `/v1/enis` გაცემულ ENI-ებსა და
IP-ებს აჩვენებს, `/v1/pods` კი მისამართების პოდებთან მიბმას.

## წვდომაზე უარი: ადამიანი და პოდი

თავი 47. წვდომის გაუმართაობები ორ დამოუკიდებელ ღერძად იყოფა და მორიგის პირველი შეკითხვაა,
რომელი მათგანი გაფუჭდა: ადამიანი ან CI ვერ შედის კლასტერში, თუ პოდი AWS-ის გამოძახებისას
`AccessDenied`-ს იღებს. შემდეგ კლასიფიკაციას უარის კოდი ასრულებს. `Unauthorized` (401)
ავთენტიფიკაციის ჩავარდნაა: token არ არის, ვადა გაუვიდა ან identity mapping-ში არ არის; ამას
kubeconfig-ში, credentials-სა და mapping-ში (access entry ან aws-auth) ასწორებენ. `Forbidden`
(403) ავტორიზაციის ჩავარდნაა: identity უკვე ცნობილია, მაგრამ RBAC უფლებას არ აძლევს; ამას Role-ში,
ClusterRole-სა და binding-ებში ასწორებენ. პოდიდან მიღებული `AccessDenied` IRSA-სთან ან Pod Identity-სთან
მიგიყვანთ. სწრაფი გარჩევა „კლასტერი თუ მე“: თუ `aws sts get-caller-identity` სხვა identity-ს აჩვენებს,
პრობლემა ლოკალურია: პროფილი, რეგიონი ან credentials.

| სიმპტომი | სავარაუდო მიზეზი | რა შევამოწმოთ |
|---|---|---|
| `Unauthorized`, `must be logged in` | სხვა identity ან mapping-ში არ არის | `sts get-caller-identity`, `list-access-entries` |
| `Unauthorized` უშუალოდ `edit aws-auth`-ის შემდეგ | საკუთარი mapping წაიშალა | `get cm aws-auth`, აღდგენა access entry-ის მეშვეობით |
| `Forbidden: cannot <verb>` | RBAC უფლებას არ აძლევს | `kubectl auth can-i`, Role და binding-ები |
| `couldn't get server API group` | დაზიანებული kubeconfig ან არასწორი რეგიონი | `update-kubeconfig`, `current-context`, პროფილი |
| პოდის `AccessDenied` IRSA-ს გამოყენებისას | trust policy, OIDC, SA-ს annotation | OIDC provider, `sub`/`aud`, `role-arn` annotation |
| პოდის `WebIdentityErr` | token არ არის დამონტაჟებული ან როლი არასწორია | პოდის ხელახლა შექმნა, trust policy-ის შემოწმება |
| პოდის `AccessDenied` Pod Identity-ის გამოყენებისას | association, agent ან token არ არის | `list-pod-identity-associations`, agent, token პოდში |

```bash
# ვინ ვარ სინამდვილეში AWS-ის თვალით
aws sts get-caller-identity
# კლასტერის ავთენტიფიკაციის რეჟიმი და accessConfig
aws eks describe-cluster --name <cluster> --query 'cluster.accessConfig'
# ვინ არის mapping-ში access entries-ის მეშვეობით
aws eks list-access-entries --cluster-name <cluster>
# რა არის aws-auth-ში (თუ რეჟიმი მას ჯერ კიდევ იყენებს)
kubectl -n kube-system get cm aws-auth -o yaml
# authz: საერთოდ რისი უფლება მაქვს
kubectl auth can-i --list
kubectl auth can-i get pods -n <ns>
# kubeconfig-ის ხელახლა გენერირება და context-ის შემოწმება
aws eks update-kubeconfig --name <cluster> --region <region> --profile <profile>
kubectl config current-context
# პოდის ღერძი: როლის annotation ServiceAccount-ზე (IRSA)
kubectl get sa <sa> -n <ns> -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
# Pod Identity-ის associations
aws eks list-pod-identity-associations --cluster-name <cluster>
# გაშვებულია თუ არა Pod Identity agent
kubectl -n kube-system get pods -l app.kubernetes.io/name=eks-pod-identity-agent
# დამონტაჟებულია თუ არა Pod Identity-ის token თავად პოდში (თუ ფაილი არ არის, agent/association არ ამუშავდა)
kubectl exec <pod> -n <ns> -- ls /var/run/secrets/pods.eks.amazonaws.com/serviceaccount/
```

ჩაკეტილ კლასტერს EKS API-ის მეშვეობით აღადგენენ: `update-cluster-config` პარამეტრით
`authenticationMode=API_AND_CONFIG_MAP`, შემდეგ `create-access-entry` და
`associate-access-policy` პოლიტიკით `AmazonEKSClusterAdminPolicy` (სექცია 47.4).
`CONFIG_MAP`-ზე უკან გადასვლა შეუძლებელია.

## რა შევამოწმოთ, როდესაც არაფერი ემთხვევა

- **VPC Flow Logs** აღრიცხავს, მიიღო თუ არა პაკეტმა `ACCEPT` ან `REJECT` ENI-ის ან ქვექსელის დონეზე.
  `REJECT` SG-ზე ან NACL-ზე მიუთითებს, ხოლო გაგზავნილი მოთხოვნის შემდეგ საპასუხო პაკეტების
  არარსებობა stateless NACL-სა და ephemeral ports-ზე.
- **control plane-ის ლოგები** (api, audit, authenticator) წინასწარ უნდა ჩაირთოს და არა ფაქტის
  შემდეგ: authenticator-ის ლოგები აჩვენებს, არის თუ არა მიღებული identity mapping-ში (თავები 21 და 34).
- **`aws-cni-support.sh` SSM-ის მეშვეობით** ipamd-ისა და plugin-ის ლოგებს ENI/IP-ის მდგომარეობასა
  და კონფიგურაციასთან ერთად აგროვებს არქივში `/var/log/eks_<instance-id>_<...>.tar.gz`, ნოდზე SSH-ის გარეშე.
- **`/var/log/aws-routed-eni`-ის ლოგებს** (`ipamd.log`, `plugin.log`) ნოდზე კითხულობენ, როდესაც
  პოდი `failed to assign an IP address` შეცდომით იჭედება და გაურკვეველია, IP-ები ამოიწურა თუ ENI არ გაეშვა.

## რა არ არის აქ

ეს თავების შემცვლელი არ არის: აქ ვერ ნახავთ მიზეზების განმარტებას, ფენების მექანიკასა და იმის
განხილვას, თუ რატომ გამოიყურება სიმპტომი სწორედ ასე; ეს ყველაფერი 45-ე, 46-ე და 47-ე თავებშია.
აქ მხოლოდ შემოწმების თანმიმდევრობა და ბრძანებებია. კურსის troubleshooting ლაბები (119, 120,
121 და ასევე 126, რომელიც security groups for pods-ს ეხება) ამ ფაილში არ მეორდება: ისინი
საკუთარი დავალებების მიხედვით სრულდება.
