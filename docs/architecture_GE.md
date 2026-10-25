[Русский](architecture_RU.md) · [English](architecture.md) · [Español](architecture_ES.md) · [Français](architecture_FR.md) · [Deutsch](architecture_DE.md) · ქართული · [繁體中文](architecture_TW.md) · [日本語](architecture_JP.md) · [მთავარი გვერდი](../README_GE.MD)

<a id="architecture"></a>

# პლატფორმის არქიტექტურა

პრაქტიკული გარემოები კოდის სახითაა აღწერილი. Makefile სცენარს ირჩევს, Terragrunt Terraform-მოდულებს კოორდინაციას უწევს, Terraform კი AWS-ის საჭირო რესურსებს ქმნის და დაკავშირების მონაცემებს გამოაქვს.

თვითმართულ Kubernetes-სცენარებში კლასტერები **kubeadm**-ით ყენდება. **Amazon EKS**-ის სამუშაოები AWS-ის მართულ Kubernetes-ს იყენებს. სცენარის მიხედვით იქმნება VPC, ქვექსელები, security groups, EC2 instance-ები (მათ შორის Spot), S3 და სხვა საჭირო რესურსები.

<details>
<summary>რეპოზიტორიის სტრუქტურა</summary>

| გზა | დანიშნულება |
|---|---|
| [Makefile](../Makefile) | გარემოების გაშვების, წაშლის, ნახვისა და პროექტის შემოწმების ბრძანებები |
| [tasks](../tasks) | კურსები, დავალებები, ლაბორატორიული სამუშაოები და საცდელი გამოცდები |
| [tasks/cka](../tasks/cka) | CKA + CKAD-ის ერთობლივი კურსი, [ლაბორატორიული სამუშაოები](../tasks/cka/labs) და [CKA-ს საცდელი გამოცდები](../tasks/cka/mock) |
| [tasks/ckad](../tasks/ckad) | [CKAD-ის საცდელი გამოცდები](../tasks/ckad/mock) |
| [tasks/cks](../tasks/cks) | CKS-ის კურსი, [ლაბორატორიული სამუშაოები](../tasks/cks/labs) და [საცდელი გამოცდები](../tasks/cks/mock) |
| [tasks/eks](../tasks/eks) | Amazon EKS-ის კურსი და სამუშაოები |
| [tasks/ica](../tasks/ica) | Istio / ICA-ს კურსი, სამუშაოები და საცდელი გამოცდები |
| [tasks/kcsa](../tasks/kcsa) | KCSA-ს კურსი, კითხვები და საცდელი გამოცდები |
| [tasks/kcna](../tasks/kcna) | [KCNA-ს საცდელი გამოცდები](../tasks/kcna/mock) |
| [tasks/lfcs](../tasks/lfcs) | LFCS-ის პრაქტიკული საცდელი გამოცდები |
| [tasks/hr](../tasks/hr) | HR-სცენარები |
| [tasks/aws_AI_practitioner](../tasks/aws_AI_practitioner) | [AWS Certified AI Practitioner-ის საცდელი გამოცდები](../tasks/aws_AI_practitioner/mock) |
| [terraform](../terraform) | ინფრასტრუქტურის აღწერები |
| [terraform/environments](../terraform/environments) | Terragrunt-ის კონფიგურაცია და გარემოების ლოკალური დირექტორიები |
| [terraform/modules](../terraform/modules) | მრავალჯერადი გამოყენების Terraform-მოდულები |
| [docs](../docs) | ლაბორატორიული სამუშაოების კატალოგი, ინსტრუქციები და დამატებითი მასალები |
| [CHANGELOG](../CHANGELOG/CHANGELOG.MD) | პროექტის ცვლილებების ისტორია |

</details>

<details>
<summary>Kubernetes, runtime, ოპერაციული სისტემა და CNI</summary>

საკუთარი სცენარებისთვის შეგიძლიათ გამოიყენოთ [k8s_self_managment](../terraform/modules/k8s_self_managment) მოდული. ის თვითმართულ Kubernetes-კლასტერს აღწერს; ვერსია, runtime, ოპერაციული სისტემა, AMI და ქსელი კონკრეტული სცენარით განისაზღვრება.

პროექტში გამოიყენება ან გამოიყენებოდა შემდეგი ვარიანტები:

| კომპონენტი | ვარიანტები |
|---|---|
| Kubernetes | ძველი სცენარები ვერსიებით 1.21-1.34; ახალი სამუშაოების პარამეტრები იხილეთ `env.hcl`-სა და კურსის აღწერაში |
| Container runtime | `containerd`, `containerd_gvizor`; ძველ სცენარებში ასევე `docker` და `cri-o` |
| თვითმართული კლასტერის ნოდების ოპერაციული სისტემა | Ubuntu 20.04 LTS და 22.04 LTS, სცენარის მიხედვით |
| CNI | Calico ან Cilium, სცენარის მიხედვით |

პლატფორმის ძველი აღწერა უთითებდა Docker-ს Kubernetes 1.21-1.23-თან, CRI-O-ს 1.21-1.29-თან, containerd-სა და `containerd_gvizor`-ს 1.21-1.33-თან, ასევე CKA/CKS-ისთვის საწყის Kubernetes 1.33-ს და CKS-ისთვის Ubuntu 22.04-ს. ეს ძველი კონფიგურაციების მონაცემებია და არა ახალი სამუშაოების თავსებადობის მატრიცა. მიმდინარე პარამეტრები არჩეული სამუშაოს წყაროებში ნახეთ; [Kubernetes-ის გამოშვებების ისტორია](https://kubernetes.io/releases/) პროექტის საიტზეა.

</details>
