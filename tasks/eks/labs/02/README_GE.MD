[Русская версия](README_RUS.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)


# ლაბორატორიული სამუშაო: Karpenter-ის საფუძვლები

## აღწერა

ეს ლაბორატორიული სამუშაო გაგაცნობთ **Karpenter**-ს — Amazon EKS კლასტერში კვანძების (nodes) ავტომატური მასშტაბირების ინსტრუმენტს. Karpenter დინამიკურად ქმნის და შლის EC2 ინსტანსებს თქვენი აპლიკაციების საჭიროებების შესაბამისად, რითაც ხარჯებისა და წარმადობის ოპტიმიზაციას ახდენს.

**რას შეისწავლით:**
- როგორ დააკონფიგურიროთ საბაზისო NodePool და EC2NodeClass
- როგორ ასრულებს Karpenter კვანძების ავტომატურ მასშტაბირებას დატვირთვის ცვლილებისას
- როგორ მართოთ რესურსები ლიმიტების მეშვეობით
- როგორ მუშაობს კონსოლიდაცია და კვანძების ზომების ოპტიმიზაცია
- როგორ განაახლოთ კვანძები კონფიგურაციის ცვლილებისას (drift)
- როგორ გამოიყენოთ რამდენიმე NodePool სხვადასხვა ტიპის დატვირთვისთვის

## სარჩევი
- [გარემოს მომზადება](#გარემოს-მომზადება)
  - [ლაბორატორიული სამუშაოს გაშვება](#ლაბორატორიული-სამუშაოს-გაშვება)
  - [შესაქმნელი რესურსები](#შესაქმნელი-რესურსები)
  - [წინაპირობები](#წინაპირობები)
- [NodePool-ის საბაზისო კონფიგურაცია](#nodepool-ის-საბაზისო-კონფიგურაცია)
  - [Karpenter-ის მუშაობის შემოწმება](#karpenter-ის-მუშაობის-შემოწმება)
  - [სატესტო აპლიკაციის შექმნა](#სატესტო-აპლიკაციის-შექმნა)
  - [NodePool-ისა და EC2NodeClass-ის შექმნა](#nodepool-ისა-და-ec2nodeclass-ის-შექმნა)
  - [კვანძების ავტომატური შექმნის შემოწმება](#კვანძების-ავტომატური-შექმნის-შემოწმება)
- [აპლიკაციების მასშტაბირება](#აპლიკაციების-მასშტაბირება)
  - [ჰორიზონტალური მასშტაბირება](#ჰორიზონტალური-მასშტაბირება)
  - [კვანძების ავტომატური დამატება](#კვანძების-ავტომატური-დამატება)
- [რესურსების შეზღუდვა](#რესურსების-შეზღუდვა)
  - [CPU-ის ლიმიტების კონფიგურაცია](#cpu-ის-ლიმიტების-კონფიგურაცია)
  - [ლიმიტებთან დაკავშირებული პრობლემების დიაგნოსტიკა](#ლიმიტებთან-დაკავშირებული-პრობლემების-დიაგნოსტიკა)
- [კვანძების სასიცოცხლო ციკლის მართვა (Disruption)](#კვანძების-სასიცოცხლო-ციკლის-მართვა-disruption)
- [კვანძების ზომების ოპტიმიზაცია (RightSizing)](#კვანძების-ზომების-ოპტიმიზაცია-rightsizing)
  - [ოპტიმალური ზომის ავტომატური შერჩევა](#ოპტიმალური-ზომის-ავტომატური-შერჩევა)
  - [მოთხოვნების ცვლილებისას კვანძების ჩანაცვლება](#მოთხოვნების-ცვლილებისას-კვანძების-ჩანაცვლება)
- [კვანძების კონფიგურაციის განახლება (Drift)](#კვანძების-კონფიგურაციის-განახლება-drift)
  - [AMI გამოსახულებების განახლება](#ami-გამოსახულებების-განახლება)
  - [ახალ ვერსიებზე ავტომატური მიგრაცია](#ახალ-ვერსიებზე-ავტომატური-მიგრაცია)
- [რამდენიმე NodePool-თან მუშაობა](#რამდენიმე-nodepool-თან-მუშაობა)
  - [დატვირთვის იზოლაცია Taints-ისა და Tolerations-ის მეშვეობით](#დატვირთვის-იზოლაცია-taints-ისა-და-tolerations-ის-მეშვეობით)
  - [სპეციალიზებული კვანძები Job-ისთვის](#სპეციალიზებული-კვანძები-job-ისთვის)
- [რესურსების გასუფთავება](#რესურსების-გასუფთავება)


## გარემოს მომზადება

### ლაბორატორიული სამუშაოს გაშვება
[გაშვება docker-ის მეშვეობით ](https://github.com/ViktorUJ/cks/blob/master/docs%2Frun_from_docker.MD)
ლაბორატორიული სამუშაოს გასაშვებად შეასრულეთ შემდეგი ბრძანება:

```bash
TASK=02 make run_eks_task
```

**რა ხდება ბრძანების შესრულებისას:**
- Terraform/Terragrunt ავტომატურად განათავსებს AWS-ში მთელ საჭირო ინფრასტრუქტურას
- პროცესს დაახლოებით 15-20 წუთი დასჭირდება
- ბრძანების გამოტანილ შედეგში იხილავთ მნიშვნელოვან ინფორმაციას (SSH კავშირი, რესურსების სახელები)

### შესაქმნელი რესურსები

ბრძანების შესრულებისას განთავსდება შემდეგი AWS ინფრასტრუქტურა:

#### ქსელური ინფრასტრუქტურა (VPC)
- **VPC** CIDR ბლოკით `10.10.0.0/16` რეგიონში `eu-central-1`
- **საჯარო ქვექსელები** (ინტერნეტთან წვდომის მქონე რესურსებისთვის):
  - `eks-AZ-1` (10.10.1.0/24) ხელმისაწვდომობის ზონაში `eu-central-1a`
  - `eks-AZ-2` (10.10.2.0/24) ხელმისაწვდომობის ზონაში `eu-central-1b`
- **კერძო ქვექსელები** (შიდა რესურსებისთვის):
  - `private-subnet-1` (10.10.15.0/24) EKS კვანძებისთვის `eu-central-1a`-ში
  - `private-subnet-2` (10.10.16.0/24) EKS კვანძებისთვის `eu-central-1b`-ში
  - `rds-subnet-1` (10.10.21.0/24) RDS-ისთვის `eu-central-1a`-ში
  - `rds-subnet-2` (10.10.22.0/24) RDS-ისთვის `eu-central-1b`-ში
- **NAT Gateway** კერძო ქვექსელებიდან გამავალი ინტერნეტ-ტრაფიკისთვის

#### EKS კლასტერი
- **EKS Control Plane** ვერსია `1.34` (Kubernetes-ის მართვის ფენა)
- **Fargate profile** სისტემური პოდებისთვის (kube-system, karpenter)
- **Karpenter** ვერსია `1.8.1` (ავტომასშტაბირების კონტროლერი)
- **EKS Add-ons**: coredns, kube-proxy, vpc-cni, eks-pod-identity-agent

#### Karpenter-ის კონფიგურაცია
- Karpenter-ის კონტროლერი გამოყოფილი რესურსებით:
  - CPU: 0.4 ბირთვი (requests და limits)
  - Memory: 0.5Gi (requests და limits)
- ქვექსელების ავტომატური აღმოჩენა ტეგების `karpenter.sh/discovery` მეშვეობით

#### დამატებითი კომპონენტები
- **Security Groups** უსაფრთხოების შესაბამისი წესებით
- **IAM როლები და პოლიტიკები** Karpenter-ისა და EKS-ისთვის
- **OIDC provider** AWS სერვისებთან ინტეგრაციისთვის

#### კონფიგურაციის ძირითადი ფაილი

ინფრასტრუქტურის ყველა პარამეტრი განსაზღვრულია ფაილში `tasks/eks/labs/02/env.hcl`. კონფიგურაციის შესაცვლელად დაარედაქტირეთ შესაბამისი პარამეტრები ამ ფაილში.

### წინაპირობები

დარწმუნდით, რომ გამართული გაქვთ:
- **AWS CLI** შესაბამისი წვდომის უფლებებით
- რეგიონში `eu-central-1` კვანძების რაოდენობის გაზრდილი ლიმიტები (საჭიროების შემთხვევაში)

## NodePool-ის საბაზისო კონფიგურაცია

### Karpenter-ის მუშაობის შემოწმება

**ნაბიჯი 1: სამუშაო კვანძთან დაკავშირება**

ბრძანების გამოტანილ შედეგში იპოვეთ SSH კავშირის სტრიქონი და დაუკავშირდით სამუშაო კვანძს:

```bash
# გამოტანილი შედეგის მაგალითი:
# 18:45:18.510 STDOUT [worker] terraform: worker_pc_ssh = "   ssh ubuntu@18.199.222.47 password= x2HcfbM577   "

ssh ubuntu@18.199.222.47  # გამოიყენეთ თქვენი IP მისამართი და პაროლი
```

**ნაბიჯი 2: Karpenter-ის კონტროლერის სტატუსის შემოწმება**

დარწმუნდით, რომ Karpenter-ის კონტროლერი გაშვებულია და მუშაობს:

```bash
kubectl get po -n karpenter
```

**მოსალოდნელი შედეგი:**
```
NAME                         READY   STATUS    RESTARTS   AGE
karpenter-846b886fb4-6fpxw   1/1     Running   0          12m
```

**ნაბიჯი 3: არსებული NodePool-ებისა და EC2NodeClass-ების შემოწმება**

შეამოწმეთ, რომ ჯერ არცერთი NodePool არ არის შექმნილი:

```bash
kubectl get nodepools
```

**შედეგი:**
```
No resources found
```

შეამოწმეთ EC2NodeClass:

```bash
kubectl get ec2nodeclasses
```

**შედეგი:**
```
No resources found
```

**რას ნიშნავს ეს:** NodePool და EC2NodeClass Karpenter-ის ძირითადი რესურსებია. NodePool განსაზღვრავს, რომელი კვანძები შეიქმნას, ხოლო EC2NodeClass — როგორ დაკონფიგურირდეს ისინი (AMI, ქვექსელები, security groups და ა.შ.).

### სატესტო აპლიკაციის შექმნა

განვათავსოთ მარტივი სატესტო აპლიკაცია:

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**შედეგი:**
```
namespace/team-19 created
deployment.apps/team19 created
service/team19 created
```

**ნაბიჯი 4: პოდების მდგომარეობის შემოწმება**

შეამოწმეთ შექმნილი პოდების სტატუსი:

```bash
kubectl get po -n team-19
```

**შედეგი:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-6c59b6bf7b-4pqvn   0/1     Pending   0          2m6s
```

**მიაქციეთ ყურადღება:** პოდი `Pending` (მოლოდინის) სტატუსშია. ამ ეტაპზე ეს ნორმალურია.

**ნაბიჯი 5: პრობლემის დიაგნოსტიკა**

ვნახოთ პოდის დეტალური ინფორმაცია:

```bash
kubectl describe po -n team-19
```

**გამოტანილი შედეგის მნიშვნელოვანი ნაწილი:**
```
Events:
  Type     Reason            Age    From               Message
  ----     ------            ----   ----               -------
  Warning  FailedScheduling  2m56s  default-scheduler  0/3 nodes are available: 3 node(s) had untolerated taint(s). no new claims to deallocate, preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.
```

**პრობლემის განმარტება:**
- პოდის დაგეგმვა ვერცერთ კვანძზე ვერ ხერხდება
- სამივე არსებული კვანძი სისტემური პოდებისთვის განკუთვნილი Fargate კვანძია (kube-system, karpenter)
- Fargate profile მხოლოდ განსაზღვრული namespace-ებისთვისაა კონფიგურირებული და `team-19` მათ შორის არ არის
- უნდა შევქმნათ NodePool, რათა Karpenter-მა შესაფერისი EC2 კვანძების შექმნა შეძლოს

### NodePool-ისა და EC2NodeClass-ის შექმნა

**ნაბიჯი 6: NodePool-ის შექმნა**

NodePool განსაზღვრავს იმ კვანძების პარამეტრებს, რომლებსაც Karpenter შექმნის:

```bash
cat <<EoF> default-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        work_type: "default_karpenter"  # კვანძების იდენტიფიკაციის ჭდე
    spec:
      requirements:
        # პროცესორის მხარდაჭერილი არქიტექტურები
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64","arm64"]
        # ოპერაციული სისტემა
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        # ინსტანსების ტიპი: spot (იაფი) ან on-demand (სტაბილური)
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        # ინსტანსების კატეგორიები (t - burstable, m - general purpose, r - memory optimized)
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "r"]
        # ინსტანსების თაობა (2-ზე მეტი = უფრო ახალი)
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        # ინსტანსების ზომები
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["small","medium","large", "xlarge"]
      # ბმული AWS პარამეტრების მქონე EC2NodeClass-ზე
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      # კვანძის სიცოცხლის ხანგრძლივობა (30 დღე)
      expireAfter: 720h # 30 * 24h = 720h
  # რესურსების ლიმიტები მთელი NodePool-ისთვის
  limits:
    cpu: 4  # მაქსიმუმ 4 CPU ამ pool-ის ყველა კვანძისთვის
  # კონსოლიდაციის (ოპტიმიზაციის) პარამეტრები
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized  # ცარიელი ან არასრულად გამოყენებული კვანძების წაშლა
    consolidateAfter: 30s  # 30 წამში მას შემდეგ, რაც კვანძი დაცარიელდება
EoF

kubectl apply -f default-nodepool.yaml
```

**ნაბიჯი 7: პარამეტრების მიღება Terraform-ის გამოტანილი შედეგიდან**

`make run_eks_task` ბრძანების გამოტანილ შედეგში იპოვეთ შემდეგი მნიშვნელობები:

```bash
# გამოტანილი შედეგის მაგალითი:
# 19:53:19.507 STDOUT [worker] terraform: eks_name = "eks2-viktor-01"
# 20:26:31.128 STDOUT [worker] terraform: karpenter_node_iam_role_name = "Karpenter-eks2-viktor-01-20260111144312385200000005"
```

**ნაბიჯი 8: EC2NodeClass-ის შექმნა**

EC2NodeClass განსაზღვრავს კვანძების AWS-სპეციფიკურ პარამეტრებს:

```bash
cat <<EoF> default-nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  # IAM როლი კვანძებისთვის (ჩაანაცვლეთ თქვენი მნიშვნელობით Terraform-ის გამოტანილი შედეგიდან)
  role: "Karpenter-eks2-viktor-01-20260111144312385200000005"
  # AMI გამოსახულების შერჩევა
  amiSelectorTerms:
    - alias: "al2023@latest"  # Amazon Linux 2023, უახლესი ვერსია
  # ქვექსელების შერჩევა ტეგების მიხედვით
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # ჩაანაცვლეთ თქვენი კლასტერის სახელით
  # security groups-ის შერჩევა ტეგების მიხედვით
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # ჩაანაცვლეთ თქვენი კლასტერის სახელით
  # შექმნილი EC2 ინსტანსების ტეგები
  tags:
      Name: "eks2-viktor-01-default"  # ჩაანაცვლეთ თქვენი კლასტერის სახელით
      team: "infra"
      operation: "my eks lab"
      city: "myCity"
      resource_type: "dynamic"
      karpenter.sh/discovery: eks2-viktor-01  # ჩაანაცვლეთ თქვენი კლასტერის სახელით
  # დისკების კონფიგურაცია
  blockDeviceMappings:
    - deviceName: /dev/xvda    # ძირეული დისკი
      ebs:
        volumeType: gp3        # დისკის ტიპი (gp3 - თანამედროვე, მაღალი წარმადობის)
        volumeSize: 25Gi       # დისკის ზომა
        iops: 3000             # IOPS gp3-ისთვის
        throughput: 125        # გამტარუნარიანობა MiB/s
        encrypted: true        # დისკის დაშიფვრა
        deleteOnTermination: true  # ინსტანსის წაშლისას დისკის წაშლა
EoF

kubectl create -f default-nodeclass.yaml
```

### კვანძების ავტომატური შექმნის შემოწმება

**ნაბიჯი 9: რესურსების სტატუსის შემოწმება**

შეამოწმეთ, რომ EC2NodeClass შექმნილი და მზადაა:

```bash
kubectl get ec2nodeclasses.karpenter.k8s.aws
```

**მოსალოდნელი შედეგი:**
```
NAME      READY   AGE
default   True    2m17s
```

შეამოწმეთ NodePool:

```bash
kubectl get nodepools.karpenter.sh
```

**მოსალოდნელი შედეგი:**
```
NAME      NODECLASS   NODES   READY   AGE
default   default     1       True    55m
```

**თუ სტატუსი READY არ არის:**

ჩაატარეთ EC2NodeClass-ის დიაგნოსტიკა:

```bash
kubectl describe ec2nodeclasses.karpenter.k8s.aws default
```

**წარმატებული გამოტანილი შედეგის მაგალითი:**
```
Events:
  Type    Reason                     Age    From       Message
  ----    ------                     ----   ----       -------
  Normal  AMIsReady                  5m44s  karpenter  Status condition transitioned, Type: AMIsReady, Status: Unknown -> True
  Normal  CapacityReservationsReady  5m44s  karpenter  Status condition transitioned, Type: CapacityReservationsReady, Status: Unknown -> True
  Normal  SubnetsReady               5m44s  karpenter  Status condition transitioned, Type: SubnetsReady, Status: Unknown -> True
  Normal  SecurityGroupsReady        5m44s  karpenter  Status condition transitioned, Type: SecurityGroupsReady, Status: Unknown -> True
  Normal  InstanceProfileReady       5m44s  karpenter  Status condition transitioned, Type: InstanceProfileReady, Status: Unknown -> True
  Normal  ValidationSucceeded        5m31s  karpenter  Status condition transitioned, Type: ValidationSucceeded, Status: Unknown -> True
  Normal  Ready                      5m31s  karpenter  Status condition transitioned, Type: Ready, Status: Unknown -> True
```

შეამოწმეთ NodePool:

```bash
kubectl describe nodepools.karpenter.sh default
```

**თუ შეცდომებია, შეამოწმეთ კონტროლერის ჟურნალები:**

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq
```

**წარმატებული ჟურნალების მაგალითი:**
```json
{
  "level": "INFO",
  "time": "2026-01-11T16:30:19.194Z",
  "logger": "controller",
  "message": "discovered ssm parameter",
  "parameter": "/aws/service/eks/optimized-ami/1.34/amazon-linux-2023/arm64/nvidia/recommended/image_id",
  "value": "ami-0e8c1e804635db463"
}
```

**ნაბიჯი 10: NodeClaim-ის შემოწმება**

NodeClaim არის კვანძის შექმნის მოთხოვნა. Karpenter ქმნის NodeClaim-ს, რომელიც შემდეგ რეალურ EC2 ინსტანსად გარდაიქმნება:

```bash
kubectl get nodeclaims.karpenter.sh
```

**შედეგი:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-c549s   t3a.small   spot       eu-central-1a   ip-10-10-15-190.eu-central-1.compute.internal   True    67s
```

**რას ვხედავთ:**
- შეიქმნა NodeClaim სახელით `default-c549s`
- არჩეულია `t3a.small` ტიპის ინსტანსი (2 vCPU, 2GB RAM)
- გამოიყენება spot ინსტანსი (უფრო იაფი)
- კვანძი მდებარეობს ზონაში `eu-central-1a`

**ნაბიჯი 11: აპლიკაციის პოდის შემოწმება**

ახლა პოდი წარმატებით უნდა გაეშვას:

```bash
kubectl get po -n team-19
```

**შედეგი:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-6c59b6bf7b-m9plq   1/1     Running   0          17m
```

**სტატუსი შეიცვალა `Running`-ზე!**

**ნაბიჯი 12: კლასტერის კვანძების შემოწმება**

ვნახოთ კლასტერის ყველა კვანძი:

```bash
kubectl get no
```

**შედეგი:**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-15-205.eu-central-1.compute.internal   Ready    <none>   149m    v1.34.2-eks-b3126f4
fargate-ip-10-10-16-183.eu-central-1.compute.internal   Ready    <none>   146m    v1.34.2-eks-b3126f4
fargate-ip-10-10-16-196.eu-central-1.compute.internal   Ready    <none>   149m    v1.34.2-eks-b3126f4
ip-10-10-16-59.eu-central-1.compute.internal            Ready    <none>   9m13s   v1.34.2-eks-ecaa3a6
```

**მიაქციეთ ყურადღება:**
- პირველი 3 კვანძი Fargate-ია (სისტემური პოდებისთვის)
- ბოლო კვანძი Karpenter-ის მიერ შექმნილი EC2 ინსტანსია

### კვანძების ავტომატური წაშლის შემოწმება

**ნაბიჯი 13: აპლიკაციის წაშლა**

წავშალოთ ჩვენი აპლიკაცია:

```bash
kubectl delete -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**შედეგი:**
```
namespace "team-19" deleted
deployment.apps "team19" deleted
service "team19" deleted
```

**ნაბიჯი 14: პოდების წაშლის შემოწმება**

```bash
kubectl get po -n team-19
```

**შედეგი:**
```
No resources found in team-19 namespace.
```

**ნაბიჯი 15: NodeClaim-ის წაშლის ლოდინი**

დაელოდეთ დაახლოებით 30 წამს (NodePool-ში `consolidateAfter`-ის მნიშვნელობა) და შეამოწმეთ:

```bash
kubectl get nodeclaims.karpenter.sh
```

**შედეგი:**
```
No resources found
```

**Karpenter-მა NodeClaim ავტომატურად წაშალა, რადგან კვანძი დაცარიელდა!**

**ნაბიჯი 16: კვანძების შემოწმება**

```bash
kubectl get no
```

**შედეგი:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-205.eu-central-1.compute.internal   Ready    <none>   155m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-183.eu-central-1.compute.internal   Ready    <none>   152m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-196.eu-central-1.compute.internal   Ready    <none>   155m   v1.34.2-eks-b3126f4
```

**EC2 კვანძი წაშლილია! დარჩა მხოლოდ Fargate კვანძები.**

**დასკვნა:** Karpenter კვანძების სასიცოცხლო ციკლს ავტომატურად მართავს — საჭიროებისას ქმნის მათ, ხოლო როცა აღარ არის საჭირო, შლის და ამით ხარჯების ოპტიმიზაციას ახდენს.


## აპლიკაციების მასშტაბირება

ამ განყოფილებაში შევისწავლით, როგორ ამატებს Karpenter ავტომატურად კვანძებს დატვირთვის გაზრდისას.

### ჰორიზონტალური მასშტაბირება

**ნაბიჯი 1: სატესტო აპლიკაციის განთავსება**

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**ნაბიჯი 2: შექმნილი რესურსების შემოწმება**

შეამოწმეთ NodeClaim:

```bash
kubectl get nodeclaims.karpenter.sh
```

**შედეგი:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    6m6s
```

შეამოწმეთ კვანძები:

```bash
kubectl get no
```

**შედეგი:**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-15-87.eu-central-1.compute.internal    Ready    <none>   30m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-112.eu-central-1.compute.internal   Ready    <none>   32m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-72.eu-central-1.compute.internal    Ready    <none>   32m     v1.34.2-eks-b3126f4
ip-10-10-16-67.eu-central-1.compute.internal            Ready    <none>   6m34s   v1.34.2-eks-ecaa3a6
```

შეამოწმეთ პოდები:

```bash
kubectl get po -n team-19
```

**შედეგი:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-bzq77   1/1     Running   0          11m
```

### კვანძების ავტომატური დამატება

**ნაბიჯი 3: მასშტაბირება 6 რეპლიკამდე**

გავზარდოთ აპლიკაციის რეპლიკების რაოდენობა:

```bash
kubectl scale deployment -n team-19 team19 --replicas 6
```

**შედეგი:**
```
deployment.apps/team19 scaled
```

**ნაბიჯი 4: პოდების მდგომარეობის შემოწმება**

```bash
kubectl get po -n team-19
```

**შედეგი:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          2m41s
team19-5d69f69559-bzq77   1/1     Running   0          17m
team19-5d69f69559-gpzgc   1/1     Running   0          2m41s
team19-5d69f69559-kxw6k   1/1     Running   0          2m41s
team19-5d69f69559-pc2dv   1/1     Running   0          2m41s
team19-5d69f69559-q6brn   1/1     Running   0          2m41s
```

**ექვსივე პოდი წარმატებით გაეშვა!**

**ნაბიჯი 5: NodeClaim-ის შემოწმება**

```bash
kubectl get nodeclaims.karpenter.sh
```

**შედეგი:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-gm8sj   t4g.small   spot       eu-central-1b   ip-10-10-16-66.eu-central-1.compute.internal   True    4m24s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    15m
```

**მიაქციეთ ყურადღება:** Karpenter-მა ავტომატურად დაამატა მეორე კვანძი (`default-gm8sj`), რადგან ერთი კვანძი ექვსივე პოდის განსათავსებლად საკმარისი არ იყო.

**ნაბიჯი 6: მასშტაბირება 16 რეპლიკამდე**

კიდევ უფრო გავზარდოთ დატვირთვა:

```bash
kubectl scale deployment -n team-19 team19 --replicas 16
```

**ნაბიჯი 7: პოდების მდგომარეობის შემოწმება**

```bash
kubectl get po -n team-19
```

**შედეგი:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          10m
team19-5d69f69559-4m772   0/1     Pending   0          2m37s
team19-5d69f69559-5ml7m   1/1     Running   0          2m37s
team19-5d69f69559-6dk8l   1/1     Running   0          2m37s
team19-5d69f69559-9qs2b   1/1     Running   0          2m37s
team19-5d69f69559-bzq77   1/1     Running   0          24m
team19-5d69f69559-fmcjq   1/1     Running   0          2m37s
team19-5d69f69559-gpzgc   1/1     Running   0          10m
team19-5d69f69559-kxw6k   1/1     Running   0          10m
team19-5d69f69559-ndg8q   1/1     Running   0          2m37s
team19-5d69f69559-pc2dv   1/1     Running   0          10m
team19-5d69f69559-q6brn   1/1     Running   0          10m
team19-5d69f69559-qgrqt   1/1     Running   0          2m37s
team19-5d69f69559-rss5s   1/1     Running   0          2m37s
team19-5d69f69559-x6qp8   1/1     Running   0          2m37s
team19-5d69f69559-z2wbm   0/1     Pending   0          2m37s
```

**პრობლემა:** ზოგიერთი პოდი `Pending` სტატუსშია. რატომ? ამის გასარკვევად გადავიდეთ შემდეგ განყოფილებაზე.

## რესურსების შეზღუდვა

ამ განყოფილებაში გავარკვევთ, რატომ დარჩა ზოგიერთი პოდი `Pending` სტატუსში და ვისწავლით NodePool-ში რესურსების ლიმიტების მართვას.

### CPU-ის ლიმიტების კონფიგურაცია

**ნაბიჯი 1: NodePool-ის მიმდინარე ლიმიტების შემოწმება**

```bash
kubectl get nodepools.karpenter.sh default -o jsonpath='{.spec.limits}' | jq
```

**შედეგი:**
```json
{
  "cpu": 4
}
```

**რას ნიშნავს ეს:** NodePool-ში დაწესებულია 4 CPU-ის ლიმიტი. ეს ნიშნავს, რომ ამ pool-ის ყველა კვანძის CPU-ების ჯამური რაოდენობა 4 ბირთვს ვერ გადააჭარბებს.

**ნაბიჯი 2: არსებული NodeClaim-ების შემოწმება**

```bash
kubectl get nodeclaims.karpenter.sh
```

**შედეგი:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-gm8sj   t4g.small   spot       eu-central-1b   ip-10-10-16-66.eu-central-1.compute.internal   True    4m24s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    15m
```

**ანალიზი:**
- გვაქვს `t4g.small` ტიპის 2 კვანძი
- თითოეულ `t4g.small`-ს აქვს 2 vCPU
- ჯამში: 2 კვანძი × 2 vCPU = 4 vCPU
- **ლიმიტს მივაღწიეთ!** Karpenter მეტ კვანძს ვეღარ შექმნის.

### ლიმიტებთან დაკავშირებული პრობლემების დიაგნოსტიკა

**ნაბიჯი 3: Karpenter-ის ჟურნალების შემოწმება**

ვნახოთ, რას გვიჩვენებს კონტროლერის ჟურნალები:

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq | grep ERROR -A 20
```

**შედეგი:**
```json
{
  "level": "ERROR",
  "time": "2026-01-13T17:41:15.044Z",
  "logger": "controller",
  "message": "could not schedule pod",
  "commit": "1ad0d78",
  "controller": "provisioner",
  "namespace": "",
  "name": "",
  "reconcileID": "0e86c755-4ab9-4d86-abb5-7e15e91241fc",
  "Pod": {
    "name": "team19-5d69f69559-4m772",
    "namespace": "team-19"
  },
  "NodePool": {
    "name": "default"
  },
  "error": "all available instance types exceed limits for nodepool (NodePool=default)"
}
```

**საკვანძო შეტყობინება:** `"all available instance types exceed limits for nodepool"`

ეს ადასტურებს, რომ CPU-ის ლიმიტის გამო Karpenter ახალ კვანძებს ვერ ქმნის.

**ნაბიჯი 4: CPU-ის ლიმიტის გაზრდა**

გავზარდოთ CPU-ის ლიმიტი 6 ბირთვამდე:

```bash
kubectl edit nodepools.karpenter.sh default
```

იპოვეთ სექცია `limits` და შეცვალეთ მნიშვნელობა:

```yaml
spec:
  disruption:
    budgets:
    - nodes: 10%
    consolidateAfter: 30s
    consolidationPolicy: WhenEmptyOrUnderutilized
  limits:
    cpu: 4     # შეცვალეთ 6-ით
```

შეინახეთ ცვლილებები (`:wq` vim-ში ან Ctrl+O, Enter, Ctrl+X nano-ში).

**ნაბიჯი 5: ახალი კვანძის შექმნის შემოწმება**

დაელოდეთ რამდენიმე წამს და შეამოწმეთ NodeClaim:

```bash
kubectl get nodeclaims.karpenter.sh
```

**შედეგი:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-927zs   t4g.small   spot       eu-central-1b   ip-10-10-16-179.eu-central-1.compute.internal   True    19m
default-gpgn9   t4g.small   spot       eu-central-1b   ip-10-10-16-30.eu-central-1.compute.internal    True    66s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal    True    38m
```

**შესანიშნავია!** Karpenter-მა შექმნა მესამე კვანძი (`default-gpgn9`).

**ნაბიჯი 6: აპლიკაციის პოდების შემოწმება**

```bash
kubectl get po -n team-19
```

**შედეგი:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          29m
team19-5d69f69559-4m772   1/1     Running   0          22m
team19-5d69f69559-5ml7m   1/1     Running   0          22m
team19-5d69f69559-6dk8l   1/1     Running   0          22m
team19-5d69f69559-9qs2b   1/1     Running   0          22m
team19-5d69f69559-bzq77   1/1     Running   0          44m
team19-5d69f69559-fmcjq   1/1     Running   0          22m
team19-5d69f69559-gpzgc   1/1     Running   0          29m
team19-5d69f69559-kxw6k   1/1     Running   0          29m
team19-5d69f69559-ndg8q   1/1     Running   0          22m
team19-5d69f69559-pc2dv   1/1     Running   0          29m
team19-5d69f69559-q6brn   1/1     Running   0          29m
team19-5d69f69559-qgrqt   1/1     Running   0          22m
team19-5d69f69559-rss5s   1/1     Running   0          22m
team19-5d69f69559-x6qp8   1/1     Running   0          22m
team19-5d69f69559-z2wbm   1/1     Running   0          22m
```

**ახლა თექვსმეტივე პოდი `Running` სტატუსშია!**

### ავტომატური კონსოლიდაციის შემოწმება

**ნაბიჯი 7: რეპლიკების რაოდენობის შემცირება**

შევამციროთ რეპლიკების რაოდენობა 3-მდე:

```bash
kubectl scale deployment -n team-19 team19 --replicas 3
```

**ნაბიჯი 8: Karpenter-ის ჟურნალების მონიტორინგი**

თვალი ადევნეთ ჟურნალებს რეალურ დროში:

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter -f | jq
```

**იხილავთ შეტყობინებებს კონსოლიდაციის შესახებ:**

```json
{
  "level": "INFO",
  "time": "2026-01-13T17:51:58.119Z",
  "logger": "controller",
  "message": "disrupting node(s)",
  "commit": "1ad0d78",
  "controller": "disruption",
  "reason": "underutilized",
  "decision": "delete",
  "disrupted-node-count": 1,
  "replacement-node-count": 0,
  "pod-count": 2,
  "disrupted-nodes": [
    {
      "Node": {
        "name": "ip-10-10-16-30.eu-central-1.compute.internal"
      },
      "NodeClaim": {
        "name": "default-gpgn9"
      },
      "capacity-type": "spot",
      "instance-type": "t4g.small"
    }
  ]
}
```

**რა ხდება:**
- Karpenter-მა აღმოაჩინა არასრულად გამოყენებული კვანძი (`underutilized`)
- მიიღო კვანძის წაშლის გადაწყვეტილება (`decision: delete`)
- თავდაპირველად კვანძს აღნიშნავს taint-ით `karpenter.sh/disrupted:NoSchedule`
- პოდები გადააქვს სხვა კვანძებზე
- შლის კვანძს

**ნაბიჯი 9: დარჩენილი კვანძების შემოწმება**

დაელოდეთ დაახლოებით ერთ წუთს და შეამოწმეთ:

```bash
kubectl get nodeclaims.karpenter.sh
```

**შედეგი:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-927zs   t4g.small   spot       eu-central-1b   ip-10-10-16-179.eu-central-1.compute.internal   True    30m
```

**მხოლოდ ერთი კვანძი დარჩა!** Karpenter-მა ზედმეტი კვანძები წაშალა და ხარჯების ოპტიმიზაცია მოახდინა.

### დამატებითი ინფორმაცია ლიმიტების შესახებ

ლიმიტები შეიძლება დაწესდეს სხვადასხვა ტიპის რესურსზე:
- **cpu** — პროცესორის ბირთვების რაოდენობა
- **memory** — ოპერატიული მეხსიერების მოცულობა
- **gpu** — GPU-ების რაოდენობა (ML/AI დატვირთვებისთვის)
- **nodes** — კვანძების მაქსიმალური რაოდენობა

**რამდენიმე ლიმიტის მქონე კონფიგურაციის მაგალითი:**

```yaml
limits:
  cpu: 100
  memory: 1000Gi
  nodes: 10
```

ლიმიტების შესახებ დაწვრილებით წაიკითხეთ [Karpenter-ის ოფიციალურ დოკუმენტაციაში](https://karpenter.sh/docs/concepts/nodepools/#speclimits).


## კვანძების სასიცოცხლო ციკლის მართვა (Disruption)

Karpenter მხარს უჭერს კვანძების სასიცოცხლო ციკლის ავტომატურ მართვას NodePool-ის სპეციფიკაციაში `consolidateAfter` პარამეტრის მეშვეობით.

**ძირითადი კონცეფციები:**

- **consolidateAfter** — ლოდინის დრო კვანძის წაშლამდე მას შემდეგ, რაც იგი ცარიელი ან არასრულად გამოყენებული გახდება
- **consolidationPolicy** — კონსოლიდაციის პოლიტიკა:
  - `WhenEmpty` — მხოლოდ სრულიად ცარიელი კვანძების წაშლა
  - `WhenEmptyOrUnderutilized` — ცარიელი და არასრულად გამოყენებული კვანძების წაშლა (რეკომენდებულია)

**კონფიგურაციის მაგალითი:**

```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 30s  # გათავისუფლებიდან 30 წამში წაშლა
```

**როგორ მუშაობს ეს:**

1. Karpenter მუდმივად აკონტროლებს კვანძებზე რესურსების გამოყენებას
2. როდესაც კვანძი ცარიელი ან არასრულად გამოყენებული ხდება, Karpenter ტაიმერს უშვებს
3. თუ მითითებული დროის (`consolidateAfter`) შემდეგ კვანძი კვლავ არ არის საჭირო, Karpenter:
   - კვანძს აღნიშნავს taint-ით `karpenter.sh/disrupted:NoSchedule`
   - პოდები უსაფრთხოდ გადააქვს სხვა კვანძებზე
   - შლის კვანძს

**დამატებითი პარამეტრები:**

```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 30s
  budgets:
    - nodes: "10%"  # ერთდროულად კვანძების 10%-ზე მეტის წაშლა არ შეიძლება
```

Disruption-ის შესახებ დაწვრილებით წაიკითხეთ [ოფიციალურ დოკუმენტაციაში](https://karpenter.sh/docs/concepts/disruption/).

---

## კვანძების ზომების ოპტიმიზაცია (RightSizing)

Karpenter პოდების მოთხოვნების შესაბამისად ავტომატურად არჩევს კვანძების ოპტიმალურ ზომას. ამას ეწოდება „right-sizing“ — ყველაზე შესაფერისი და ეკონომიური ინსტანსის ტიპის შერჩევა.

### ოპტიმალური ზომის ავტომატური შერჩევა

**ნაბიჯი 1: CPU-ის ლიმიტის დაყენება**

გავზარდოთ NodePool-ის ლიმიტი 10 ბირთვამდე:

```bash
kubectl edit nodepools.karpenter.sh default
```

შეცვალეთ:

```yaml
spec:
  limits:
    cpu: 6     # შეცვალეთ 10-ით
```

**ნაბიჯი 2: დიდი მოთხოვნების მქონე აპლიკაციის განთავსება**

განვათავსოთ აპლიკაცია, რომელიც 3 CPU-ს ითხოვს:

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/2.yaml
```

**ნაბიჯი 3: შექმნილი NodeClaim-ის შემოწმება**

```bash
kubectl get nodeclaims.karpenter.sh
```

**შედეგი:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-6ltdb   t3.xlarge   spot       eu-central-1a   ip-10-10-15-179.eu-central-1.compute.internal   True    117s
```

**მიაქციეთ ყურადღება:** Karpenter-მა აირჩია `t3.xlarge` ინსტანსი 4 vCPU-ით, რადგან პოდი 3 CPU-ს ითხოვს.

**ნაბიჯი 4: კვანძის დეტალების შემოწმება**

```bash
kubectl get no ip-10-10-15-179.eu-central-1.compute.internal -o yaml
```

**მნიშვნელოვანი ჭდეები:**

```yaml
labels:
  karpenter.k8s.aws/instance-cpu: "4"
  karpenter.k8s.aws/instance-type: t3.xlarge
  karpenter.k8s.aws/instance-category: t
  karpenter.sh/capacity-type: spot
```

### მოთხოვნების ცვლილებისას კვანძების ჩანაცვლება

**ნაბიჯი 5: პოდის მოთხოვნების შემცირება**

შევცვალოთ CPU-ის მოთხოვნები deployment-ში:

```bash
kubectl edit deployments.apps -n team-19 team19
```

იპოვეთ სექცია `resources` და შეცვალეთ:

```yaml
spec:
  containers:
  - image: viktoruj/ping_pong:alpine
    name: app
    resources:
      requests:
        cpu: "3"      # შეცვალეთ "50m"-ით (50 მილიკორი)
        memory: 500Mi
```

შეინახეთ ცვლილებები.

**ნაბიჯი 6: Karpenter-ის ჟურნალების მონიტორინგი**

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter -f | jq
```

**იხილავთ:**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:07.171Z",
  "logger": "controller",
  "message": "disrupting node(s)",
  "controller": "disruption",
  "reason": "underutilized",
  "decision": "replace",
  "disrupted-node-count": 1,
  "replacement-node-count": 1,
  "pod-count": 1,
  "disrupted-nodes": [
    {
      "Node": {
        "name": "ip-10-10-15-179.eu-central-1.compute.internal"
      },
      "NodeClaim": {
        "name": "default-6ltdb"
      },
      "capacity-type": "spot",
      "instance-type": "t3.xlarge"
    }
  ],
  "replacement-nodes": [
    {
      "capacity-type": "spot",
      "instance-types": "t4g.small, t3.small, t3a.small, m8gd.medium, r7gd.medium and 10 other(s)"
    }
  ]
}
```

**რა ხდება:**
- Karpenter-მა აღმოაჩინა, რომ კვანძი არასრულად გამოიყენება (`underutilized`)
- მიიღო კვანძის ჩანაცვლების გადაწყვეტილება (`decision: replace`)
- ქმნის ახალ, უფრო იაფ კვანძს

**ახალი NodeClaim-ის შექმნა:**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:07.219Z",
  "logger": "controller",
  "message": "created nodeclaim",
  "controller": "disruption",
  "NodeClaim": {
    "name": "default-48ck8"
  },
  "requests": {
    "cpu": "200m",
    "memory": "50Mi",
    "pods": "4"
  },
  "instance-types": "m6g.medium, m6gd.medium, m7g.medium, m8g.medium, m8gd.medium and 10 other(s)"
}
```

**ახალი ინსტანსის გაშვება:**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:10.582Z",
  "logger": "controller",
  "message": "launched nodeclaim",
  "provider-id": "aws:///eu-central-1b/i-0f0d32ba789615574",
  "instance-type": "t4g.small",
  "zone": "eu-central-1b",
  "capacity-type": "spot",
  "allocatable": {
    "cpu": "1930m",
    "memory": "1359Mi"
  }
}
```

**ნაბიჯი 7: ახალი NodeClaim-ის შემოწმება**

```bash
kubectl get nodeclaims.karpenter.sh
```

**შედეგი:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-48ck8   t4g.small   spot       eu-central-1b   ip-10-10-16-44.eu-central-1.compute.internal   True    8m59s
```

**შესანიშნავია!** Karpenter-მა `t3.xlarge` (4 vCPU) ჩაანაცვლა `t4g.small`-ით (2 vCPU), რაც მნიშვნელოვნად იაფია.

**ნაბიჯი 8: გასუფთავება**

წაშალეთ deployment:

```bash
kubectl delete deployments.apps -n team-19 team19
```

დაელოდეთ NodeClaim-ის წაშლას:

```bash
kubectl get nodeclaims.karpenter.sh
```

**შედეგი:**
```
No resources found
```

**დასკვნა:** Karpenter ავტომატურად ახდენს კვანძების ზომების ოპტიმიზაციას და ირჩევს ყველაზე ეკონომიურ ვარიანტებს, რომლებიც აპლიკაციების მოთხოვნებს შეესაბამება.


## კვანძების კონფიგურაციის განახლება (Drift)

Drift არის EC2NodeClass-ის კონფიგურაციის ცვლილებისას კვანძების ავტომატური განახლების მექანიზმი. როდესაც ცვლით AMI-ს, security groups-ს, user data-ს ან სხვა პარამეტრებს, Karpenter არსებულ კვანძებს ავტომატურად ანაცვლებს განახლებული კონფიგურაციის მქონე ახლებით.

### AMI გამოსახულებების განახლება

**ნაბიჯი 1: EKS-ის წინა ვერსიის AMI-ის მიღება**

მივიღოთ AMI ID EKS-ის 1.33 ვერსიისთვის:

```bash
aws ssm get-parameter \
  --name /aws/service/eks/optimized-ami/1.33/amazon-linux-2023/x86_64/standard/recommended/image_id \
  --query "Parameter.Value" \
  --output text
```

**შედეგი:**
```
ami-0fc1cdef3ebc3a8fe
```

**ნაბიჯი 2: ძველი AMI-ის დაყენება EC2NodeClass-ში**

დაარედაქტირეთ EC2NodeClass:

```bash
kubectl edit ec2nodeclasses.karpenter.k8s.aws default
```

იპოვეთ სექცია `amiSelectorTerms` და შეცვალეთ:

```yaml
spec:
  amiSelectorTerms:
  - alias: al2023@latest  # იყო
```

შემდეგით:

```yaml
spec:
  amiFamily: AL2023
  amiSelectorTerms:
  - id: "ami-0fc1cdef3ebc3a8fe"  # 1.33 ვერსიის კონკრეტული AMI ID
```

**ნაბიჯი 3: აპლიკაციის განთავსება**

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/2.yaml
```

**ნაბიჯი 4: კვანძის ვერსიის შემოწმება**

```bash
kubectl get no
```

**შედეგი:**
```
NAME                                                    STATUS   ROLES    AGE   VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   60m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   60m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   58m   v1.34.2-eks-b3126f4
ip-10-10-15-175.eu-central-1.compute.internal           Ready    <none>   2m23s v1.33.5-eks-ecaa3a6   <-- ვერსია 1.33!
```

**მიაქციეთ ყურადღება:** კვანძი იყენებს Kubernetes-ის 1.33.5 ვერსიას (ძველი AMI-დან).

### ახალ ვერსიებზე ავტომატური მიგრაცია

**ნაბიჯი 5: AMI-ის ავტომატურ შერჩევაზე დაბრუნება**

კვლავ დაარედაქტირეთ EC2NodeClass:

```bash
kubectl edit ec2nodeclasses.karpenter.k8s.aws default
```

შეცვალეთ შემდეგით:

```yaml
spec:
  amiSelectorTerms:
  - alias: al2023@latest  # უახლესი ვერსიის ავტომატური შერჩევა
```

**რა ხდება:**
- Karpenter აღმოაჩენს EC2NodeClass-ში ცვლილებას
- განსაზღვრავს, რომ არსებული კვანძი მოძველებულ კონფიგურაციას (drift) იყენებს
- ავტომატურად ქმნის ახალ კვანძს განახლებული AMI-ით
- პოდები უსაფრთხოდ გადააქვს ახალ კვანძზე
- შლის ძველ კვანძს

**ნაბიჯი 6: კვანძის განახლების შემოწმება**

დაელოდეთ დაახლოებით ერთ წუთს და შეამოწმეთ კვანძები:

```bash
kubectl get no
```

**შედეგი (~30 წამის შემდეგ):**
```
NAME                                                    STATUS   ROLES    AGE   VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   89m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   89m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   87m   v1.34.2-eks-b3126f4
ip-10-10-15-175.eu-central-1.compute.internal           Ready    <none>   33s   v1.34.2-eks-ecaa3a6   <-- ახალი ვერსია!
```

**შედეგი (~4 წუთის შემდეგ):**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   93m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   93m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   91m     v1.34.2-eks-b3126f4
ip-10-10-16-230.eu-central-1.compute.internal           Ready    <none>   4m22s   v1.34.2-eks-ecaa3a6
```

**შესანიშნავია!** Karpenter-მა კვანძი ავტომატურად ჩაანაცვლა ახლით, განახლებული AMI ვერსიით (1.34.2).

**ნაბიჯი 7: გასუფთავება**

```bash
kubectl delete deployments.apps -n team-19 team19
```

დაელოდეთ NodeClaim-ის წაშლას:

```bash
kubectl get nodeclaims.karpenter.sh
```

**შედეგი:**
```
No resources found
```

**დასკვნა:** Drift კონფიგურაციის ცვლილებისას კვანძების ხელით ჩარევის გარეშე ავტომატურად განახლების საშუალებას იძლევა. ეს განსაკუთრებით სასარგებლოა შემდეგისთვის:
- AMI-ის განახლება (უსაფრთხოების პატჩები, Kubernetes-ის ახალი ვერსიები)
- security groups-ის შეცვლა
- user data სკრიპტების განახლება
- IAM როლების შეცვლა

---

## რამდენიმე NodePool-თან მუშაობა

Production გარემოში ხშირად საჭიროა დატვირთვის კვანძების სხვადასხვა ჯგუფზე განაწილება. მაგალითად:
- Ingress კონტროლერები გამოყოფილ კვანძებზე
- მძლავრი კვანძები პერიოდული ამოცანებისთვის (jobs)
- GPU-ს მქონე კვანძები ML/AI დატვირთვებისთვის
- დიდი მოცულობის მეხსიერების მქონე კვანძები მონაცემთა ბაზებისთვის

### დატვირთვის იზოლაცია Taints-ისა და Tolerations-ის მეშვეობით

**სცენარი:** საჭიროა რესურსებზე (CPU, მეხსიერება, GPU) დიდი მოთხოვნების მქონე პერიოდული job-ების გაშვება.

**მოთხოვნები:**
1. ამ კვანძებზე ჩვეულებრივი პოდები არ უნდა განთავსდეს (მხოლოდ job)
2. სანამ კვანძზე job მუშაობს, კონსოლიდაცია არ უნდა მოხდეს
3. როგორც კი job დასრულდება, კვანძი უნდა წაიშალოს

### სპეციალიზებული კვანძები Job-ისთვის

**ნაბიჯი 1: სპეციალიზებული NodePool-ის შექმნა**

```bash
cat <<EoF> job-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: job
spec:
  template:
    metadata:
      labels:
        work_type: "job_karpenter"  # იდენტიფიკაციის ჭდე
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64","arm64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["small","medium","large", "xlarge"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: job
      expireAfter: 720h # 30 დღე
      # მნიშვნელოვანია: Taint ხელს უშლის ამ კვანძებზე ჩვეულებრივი პოდების გაშვებას
      taints:
        - key: workType
          value: "job"
          effect: NoSchedule  # შესაბამისი toleration-ის გარეშე პოდები ვერ გაეშვება
  limits:
    cpu: 6
  disruption:
    consolidationPolicy: WhenEmpty  # მხოლოდ ცარიელი კვანძების წაშლა (არა job-ის მუშაობისას)
    consolidateAfter: 10s           # სწრაფი წაშლა job-ის დასრულების შემდეგ
EoF

kubectl apply -f job-nodepool.yaml
```

**ძირითადი განსხვავებები default NodePool-ისგან:**

1. **Taints** — ხელს უშლის ჩვეულებრივი პოდების გაშვებას:
   ```yaml
   taints:
     - key: workType
       value: "job"
       effect: NoSchedule
   ```

2. **consolidationPolicy: WhenEmpty** — კვანძი მხოლოდ მაშინ იშლება, როცა სრულად ცარიელია (მომუშავე job-ებს არ წყვეტს)

3. **consolidateAfter: 10s** — დასრულების შემდეგ სწრაფი წაშლა

**ნაბიჯი 2: პარამეტრების მიღება Terraform-ის გამოტანილი შედეგიდან**

გამოტანილ შედეგში იპოვეთ:

```bash
# მაგალითი:
# eks_name = "eks2-viktor-01"
# karpenter_node_iam_role_name = "Karpenter-eks2-viktor-01-20260111144312385200000005"
```

**ნაბიჯი 3: EC2NodeClass-ის შექმნა job-ისთვის**

```bash
cat <<EoF> job-nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: job
spec:
  role: "Karpenter-eks2-viktor-01-20260111144312385200000005"  # ჩაანაცვლეთ თქვენი მნიშვნელობით
  amiSelectorTerms:
    - alias: "al2023@latest"
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # ჩაანაცვლეთ თქვენი კლასტერის სახელით
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # ჩაანაცვლეთ თქვენი კლასტერის სახელით
  tags:
      Name: "eks2-viktor-01-job"  # ჩაანაცვლეთ თქვენი კლასტერის სახელით
      team: "infra"
      work_type: "job"
      operation: "my eks lab"
      city: "myCity"
      resource_type: "dynamic"
      karpenter.sh/discovery: eks2-viktor-01
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeType: gp3
        volumeSize: 25Gi
        iops: 3000
        throughput: 125
        encrypted: true
        deleteOnTermination: true
EoF

kubectl create -f job-nodeclass.yaml
```

**ნაბიჯი 4: რესურსების სტატუსის შემოწმება**

```bash
kubectl get ec2nodeclasses.karpenter.k8s.aws
```

**შედეგი:**
```
NAME      READY   AGE
default   True    8m10s
job       True    2m22s
```

```bash
kubectl get nodepools.karpenter.sh
```

**შედეგი:**
```
NAME      NODECLASS   NODES   READY   AGE
default   default     0       True    9m30s
job       job         0       True    3m38s
```

**თუ სტატუსი READY არ არის**, ჩაატარეთ დიაგნოსტიკა:

```bash
kubectl describe ec2nodeclasses.karpenter.k8s.aws job
kubectl describe nodepools.karpenter.sh job
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq
```

**ნაბიჯი 5: Job-ის გაშვება Toleration-ით**

შექმენით job, რომელსაც შეუძლია გაეშვას `workType=job` taint-ის მქონე კვანძებზე:

```bash
cat <<EoF> test-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: testjob
spec:
  template:
    spec:
      # Toleration პოდს შესაბამისი taint-ის მქონე კვანძებზე გაშვების საშუალებას აძლევს
      tolerations:
      - key: workType
        operator: Equal
        value: job
        effect: NoSchedule
      # Affinity უზრუნველყოფს, რომ პოდი სწორედ job NodePool-ის კვანძებზე გაეშვას
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: work_type
                operator: In
                values:
                - job_karpenter
      containers:
      - name: job-container
        image: busybox
        command: ["sh", "-c", "echo 'Job started'; sleep 30; echo 'Job completed'"]
      restartPolicy: Never
  backoffLimit: 1
EoF

kubectl apply -f test-job.yaml
```

**ნაბიჯი 6: NodeClaim-ის შექმნის შემოწმება**

```bash
kubectl get nodeclaims.karpenter.sh
```

**შედეგი:**
```
NAME        TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
job-mpt7v   t4g.small   spot       eu-central-1b   ip-10-10-16-18.eu-central-1.compute.internal   True    58s
```

**პოდის შემოწმება:**

```bash
kubectl get po
```

**შედეგი (შესრულების დროს):**
```
NAME            READY   STATUS    RESTARTS   AGE
testjob-gtlbk   1/1     Running   0          64s
```

**შედეგი (დასრულების შემდეგ):**
```
NAME            READY   STATUS      RESTARTS   AGE
testjob-gtlbk   0/1     Completed   0          72s
```

**კვანძების შემოწმება:**

```bash
kubectl get no
```

**შედეგი:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   130m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   128m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   130m   v1.34.2-eks-b3126f4
ip-10-10-16-18.eu-central-1.compute.internal            Ready    <none>   59s    v1.34.2-eks-ecaa3a6
```

**ნაბიჯი 7: კვანძის ავტომატური წაშლის შემოწმება**

job-ის დასრულების შემდეგ დაელოდეთ დაახლოებით 10-15 წამს და შეამოწმეთ კვანძები:

```bash
kubectl get no
```

**შედეგი:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   133m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   131m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   133m   v1.34.2-eks-b3126f4
```

**კვანძი წარმატებით წაიშალა!** Karpenter-მა job-ის დასრულებიდან 10 წამში კვანძი ავტომატურად წაშალა.

**დასკვნა:** რამდენიმე NodePool-ის taints-თან და tolerations-თან ერთად გამოყენება საშუალებას გაძლევთ:
- სხვადასხვა ტიპის დატვირთვა ერთმანეთისგან იზოლირებული იყოს
- მოახდინოთ ხარჯების ოპტიმიზაცია (job-ის დასრულების შემდეგ კვანძების სწრაფი წაშლა)
- სპეციალიზებულ კვანძებზე ჩვეულებრივი პოდების გაშვება თავიდან აიცილოთ
- სხვადასხვა ტიპის დატვირთვისთვის კონსოლიდაციის პოლიტიკები მოქნილად მართოთ



## რესურსების გასუფთავება

ლაბორატორიული სამუშაოს დასრულების შემდეგ ზედმეტი ხარჯების თავიდან ასაცილებლად ყველა შექმნილი რესურსი უნდა წაშალოთ.

**ნაბიჯი 1: აქტიური NodeClaim-ების არარსებობის შემოწმება**

დარწმუნდით, რომ აქტიური NodeClaim არ არსებობს:

```bash
kubectl get nodeclaims.karpenter.sh
```

**მოსალოდნელი შედეგი:**
```
No resources found
```

**თუ აქტიური NodeClaim-ები არსებობს:**

1. შეამოწმეთ, არის თუ არა კვანძებზე გაშვებული პოდები:

```bash
kubectl get pods --all-namespaces -o wide
```

2. წაშალეთ deployment, pods ან jobs:

```bash
# deployment-ის წაშლის მაგალითი
kubectl delete deployment -n team-19 team19

# job-ის წაშლის მაგალითი
kubectl delete job testjob
```

3. პოდების წაშლის შემდეგ ხელით წაშალეთ NodeClaim (საჭიროების შემთხვევაში):

```bash
kubectl delete nodeclaim <name-of-nodeclaim>
```

**ნაბიჯი 2: კლასტერის კვანძების შემოწმება**

დარწმუნდით, რომ მხოლოდ Fargate კვანძები დარჩა:

```bash
kubectl get no
```

**მოსალოდნელი შედეგი:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   133m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   131m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   133m   v1.34.2-eks-b3126f4
```

**ყველა კვანძის სახელი უნდა იწყებოდეს `fargate-`-ით.**

**ნაბიჯი 3: ინფრასტრუქტურის წაშლა**

წაშალეთ ლაბორატორიული სამუშაოსთვის შექმნილი ყველა რესურსი:

```bash
TASK=02 make delete_eks_task
```

**ბრძანების გამოტანილი შედეგი:**

```
16:14:15.750 INFO   The stack at . will be processed in the following order for command destroy:
Group 1
- Module ./worker

Group 2
- Module ./eks_karpenter
- Module ./ssh-keys

Group 3
- Module ./eks_addons

Group 4
- Module ./eks_fargate_system

Group 5
- Module ./eks_control_plane

Group 6
- Module ./vpc


WARNING: Are you sure you want to run `terragrunt destroy` in each folder of the stack described above? There is no undo! (y/n)
```

**წაშლის დასადასტურებლად შეიყვანეთ `y`.**

**რა წაიშლება:**
- სამუშაო კვანძი (worker)
- Karpenter-ის კონტროლერი და მასთან დაკავშირებული რესურსები
- SSH გასაღებები
- EKS add-ons
- Fargate profile
- EKS Control Plane
- VPC და ქსელური ინფრასტრუქტურა

**წაშლის პროცესს დაახლოებით 10-15 წუთი დასჭირდება.**

---

## დასკვნა

გილოცავთ! თქვენ წარმატებით დაასრულეთ ლაბორატორიული სამუშაო Karpenter-ის საფუძვლების შესახებ.

**რა შეისწავლეთ:**

1. **საბაზისო კონფიგურაცია** — NodePool-ისა და EC2NodeClass-ის შექმნა კვანძების ავტომატური მართვისთვის
2. **ავტომატური მასშტაბირება** — Karpenter დატვირთვის ზრდისას დინამიკურად ამატებს კვანძებს
3. **ლიმიტების მართვა** — limits-ის მეშვეობით რესურსების მაქსიმალური რაოდენობის კონტროლი
4. **კონსოლიდაცია** — ხარჯების ოპტიმიზაციისთვის ცარიელი და არასრულად გამოყენებული კვანძების ავტომატური წაშლა
5. **Right-sizing** — პოდების მოთხოვნების მიხედვით კვანძების ოპტიმალური ზომის ავტომატური შერჩევა
6. **Drift** — კონფიგურაციის ცვლილებისას კვანძების ავტომატური განახლება (AMI, security groups და ა.შ.)
7. **რამდენიმე NodePool** — სხვადასხვა ტიპის დატვირთვის იზოლაცია taints-ის, tolerations-ისა და affinity-ის მეშვეობით

**Karpenter-ის ძირითადი უპირატესობები:**

- **სწრაფი მასშტაბირება** — კვანძები წუთების ნაცვლად წამებში იქმნება
- **ხარჯების ოპტიმიზაცია** — ინსტანსების ყველაზე ეკონომიური ტიპების ავტომატური შერჩევა
- **მოქნილობა** — spot და on-demand ინსტანსებისა და სხვადასხვა არქიტექტურის (amd64, arm64) მხარდაჭერა
- **სიმარტივე** — დეკლარაციული კონფიგურაცია Kubernetes რესურსების მეშვეობით
- **ავტომატიზაცია** — კვანძების მართვაში მინიმალური ხელით ჩარევა

**დამატებითი რესურსები:**

- [Karpenter-ის ოფიციალური დოკუმენტაცია](https://karpenter.sh/docs/)
- [Karpenter-ის საუკეთესო პრაქტიკები](https://karpenter.sh/docs/concepts/nodepools/#best-practices)
- [პრობლემების აღმოფხვრის სახელმძღვანელო](https://karpenter.sh/docs/troubleshooting/)
- [AWS EKS-ის საუკეთესო პრაქტიკები](https://aws.github.io/aws-eks-best-practices/)

**შემდეგი ნაბიჯები:**

- შეისწავლეთ Karpenter-ის გაფართოებული შესაძლებლობები (weighted NodePools, custom AMI, GPU support)
- მოახდინეთ Karpenter-ის ინტეგრაცია თქვენს production აპლიკაციებთან
- დააკონფიგურირეთ Karpenter-ის მონიტორინგი და გაფრთხილებები
- spot და on-demand ინსტანსების გამოყენების ანალიზით მოახდინეთ ხარჯების ოპტიმიზაცია

