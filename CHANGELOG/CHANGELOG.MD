# Changelog

## 0.18.1 (20.02.2025)
### Features

* [cks mock exam 02](../tasks/cks/mock/02) is added.
* [cks mock exam 02 solutions](../tasks/cks/mock/02/worker/files/solutions) is added.
* **spot_additional_type** is added to [k8s_self_management](..%2Fterraform%2Fmodules%2Fk8s_self_managment_v2) module. Now you can use spot instances with additional type. [example](../tasks/cks/mock/02/env.hcl)
* **all_spot_subnet** is added to [k8s_self_management](..%2Fterraform%2Fmodules%2Fk8s_self_managment_v2) module. Now you can use spot instances in all subnets. [example](../tasks/cks/mock/02/env.hcl)
* **--terragrunt-parallelism** now is depends on cpu cores. It helps you create environments faster on multi-core computers.


## 0.17.1 (09.01.2025)
### Features

* [kcna](../tasks/kcna)  example is added.
* [kcsa](../tasks/kcsa)  example is added.
* K8s version **1.32** is added  to [k8s_self_management](..%2Fterraform%2Fmodules%2Fk8s_self_managment_v2) module.
* [cka lab 08](../tasks/cka/labs/08) is updated to  kubernetes version 1.32.
* slow start to [ping_pong](../docker/ping_pong/README.MD) is added. Now you can use `DELAY_START`  to delay start in seconds before start app (default = 0) . It is useful for testing slow start of app and test startup probes.

## 0.16.1 (09.12.2024)
### Features

* [CKS lab 26. Install Cilium with WireGuard](..%2Ftasks%2Fcks%2Flabs%2F26%2FREADME.MD) is added.
* Cks lab 26.Install Cilium with WireGuard [solutions](..%2Ftasks%2Fcks%2Flabs%2F26%2Fworker%2Ffiles%2Fsolutions%2F1.MD) are added.
* Cks lab 26.Install Cilium with WireGuard [video solution](https://youtu.be/lVrkuX6CriQ) is added.
* We have launched a comprehensive series on practical Kubernetes exam preparation with [devops kitchen talks](https://www.youtube.com/@DevOpsKitchenTalks) channel, starting with CKAD . [CKAD  01 episode](https://www.youtube.com/watch?v=4WXSijgYbVw) , [script](https://github.com/ViktorUJ/cks/blob/dkt_ckad_01/selfStudy/dkt/ckad/01/README.MD).
* [cka lab 08](../tasks/cka/labs/08) is updated to  kubernetes version 1.31.
* fixed issue with node labels in [k8s_self_managment_v2](../terraform/modules/k8s_self_managment_v2) module with 1.31 version.
* [ping_pong](../docker/ping_pong/README.MD) image is updated . Now default  **SERVER_NAME**  = pod name
* [ckad mock 02](../tasks/ckad/mock/02) is updated, question 21 is added.
* ckad mock 02 [solutions](../tasks/ckad/mock/02/worker/files/solutions/21.MD) are added.
* [ckad mock 02](../tasks/ckad/mock/02) is updated, question 02 is updated.
* ckad mock 02 [solution](../tasks/ckad/mock/02/worker/files/solutions/2.MD) are updated.


## 0.15.1 (28.10.2024)
### Features

* [cilium](https://cilium.io/) CNI is added to [k8s_self_management](..%2Fterraform%2Fmodules%2Fk8s_self_managment_v2) module. New cks exam contains [cilium questions](https://training.linuxfoundation.org/cks-program-changes/).
* [Cka lab 8.Cilium NetworkPolicy L7](..%2Ftasks%2Fcka%2Flabs%2F08%2FREADME.MD) is added.
* [solutions](..%2Ftasks%2Fcka%2Flabs%2F08%2Fworker%2Ffiles%2Fsolutions%2F1.MD) Cka lab 8.Cilium NetworkPolicy L7 is added.
* [Video](https://youtu.be/eFZQi6sy3SQ) for Cka lab 8 solution is added.



## 0.14.1 (17.09.2024)
### Features

* K8s version **1.31** is added  to [k8s_self_management](..%2Fterraform%2Fmodules%2Fk8s_self_managment) module.
* new terraform [aws vpc module](https://registry.terraform.io/modules/ViktorUJ/vpc/aws/latest) is crearated. [github](https://github.com/ViktorUJ/terraform-aws-vpc)
  * Creation of a VPC with specified CIDR blocks, tags, and NACL settings.
  * Dynamic creation of public and private subnets with automatic retrieval of their IDs.
  * Subnet creation with the ability to assign them to specific Availability Zones (AZ) or AZ IDs.
  * Independent tagging for each subnet, allowing for individual resource labeling.
  * Flexible network management: ability to add new subnets or remove existing ones without impacting other subnets.
  * Support for three NAT Gateway scenarios (by default, AZ NAT Gateway is used):
    * AZ: One NAT Gateway is created for each AZ specified in private subnets.
    * SINGLE: One NAT Gateway is created for the entire VPC.
    * SUBNET: One NAT Gateway per subnet.
    * NONE: No NAT Gateway is created for the subnet, and no routes for 0.0.0.0/0 are configured.
    * Each subnet can be configured with any NAT Gateway type, and all types can coexist within a single VPC.
  * Custom DHCP options to fine-tune network configurations.
  * Output of all created resources, including subnet IDs grouped by type, AZ, and AZ ID.

## 0.13.1 (09.08.2024)
### Features

* [Cka lab 6. Create general resources (Namespace, Deployment, Service)](..%2Ftasks%2Fcka%2Flabs%2F06%2FREADME.MD) is added.
* [Video](https://youtu.be/vqs_SUjKee8) for Cka lab 6 solution is added.
* [k3s template](..%2Fterraform%2Fmodules%2Fwork_pc%2Ftemplate%2Fworker_k3s.sh) is added. It helps to create k8s cluster with [k3s](https://k3s.io/) for simple scenarios.
* [Cka lab 7. CPU throttle](..%2Ftasks%2Fcka%2Flabs%2F07%2FREADME.MD) is added.
* [Cks labs](..%2Ftasks%2Fcks%2Flabs) are updated.


## 0.12.1 (04.07.2024)
### Features
* [Cka lab 5. PriorityClass ](..%2Ftasks%2Fcka%2Flabs%2F05%2FREADME.MD) is added.
* [Cka lab 5. PriorityClass solutions ](..%2Ftasks%2Fcka%2Flabs%2F05%2Fworker%2Ffiles%2Fsolutions%2F1.MD) is added.
* [Video](https://youtu.be/7MhXfbiMfOM) for Cka lab 5  solutions is added.
* [lfcs mock exam 1 ](..%2Ftasks%2Flfcs%2Fmock%2F01%2FREADME.md) is added .
* [lfcs mock exam 1 solutions](..%2Ftasks%2Flfcs%2Fmock%2F01%2Fworker-01%2Ffiles%2Fsolutions) are added


## 0.11.1 (24.05.2024)
### Features
* K8s version **1.30** is added  to [k8s_self_management](..%2Fterraform%2Fmodules%2Fk8s_self_managment) module.
* k8s version **1.30**  is used in [cka-mock 1](..%2Ftasks%2Fcka%2Fmock%2F01)
* k8s version **1.30**  is used in [cka-mock 2](..%2Ftasks%2Fcka%2Fmock%2F02)
* kube-bench in [cks mock1](..%2Ftasks%2Fcks%2Fmock%2F01) is updated to version  0.7.3 .
* k8s version **1.30**  is used in [cks mock1](..%2Ftasks%2Fcks%2Fmock%2F01)
* k8s version **1.30**  is used in [ckad mock1](..%2Ftasks%2Fckad%2Fmock%2F01)
* k8s version **1.30**  is used in [ckad mock2](..%2Ftasks%2Fckad%2Fmock%2F02)

## 0.10.1 (24.04.2024)
### Features
* [Cka lab 3. Nginx ingress. Routing by header ](..%2Ftasks%2Fcka%2Flabs%2F03%2FREADME.MD) is added.
* [Cka lab 3 solution ](..%2Ftasks%2Fcka%2Flabs%2F03%2Fworker%2Ffiles%2Fsolutions%2F1.MD) is added.
* [Video](https://youtu.be/1-qA7RjSx4A) for Cka lab 3 solution is added.
* [Cka lab 4. Nginx ingress. Routing 30% of requests to new version of app](..%2Ftasks%2Fcka%2Flabs%2F04%2FREADME.MD)  is added.
* [Cka lab 4 solution ](..%2Ftasks%2Fcka%2Flabs%2F04%2Fworker%2Ffiles%2Fsolutions%2F1.MD) is added.
* [Video](https://youtu.be/IC_0FeQtgwA) for Cka lab 4 solution is added.


## 0.9.1 (20.03.2024)
### Features
* [Ckad mock exam 2 ](..%2Ftasks%2Fckad%2Fmock%2F02%2FREADME.md) is added . List of questions updated as of March 2024
* [Ckad mock exam 2 solutions](..%2Ftasks%2Fckad%2Fmock%2F02%2Fworker%2Ffiles%2Fsolutions) are added
* [Video](https://youtu.be/_0nX68vil-A) for CKAD mock 2  solutions is added.

## 0.8.1 (10.02.2024)
### Features
*  Two new features **cpu and memory load profile** are added to [ping_pong service](..%2Fdocker%2Fping_pong%2FREADME.MD)
*  CMDB and resources aws regions are split
* [(HPA by CPU)](..%2Ftasks%2Fcka%2Flabs%2F02%2FREADME.MD) is   added cka lab 02
*  [solution](..%2Ftasks%2Fcka%2Flabs%2F02%2Fworker%2Ffiles%2Fsolutions%2F1.MD)  fo cka lab 02 [(HPA by CPU)](..%2Ftasks%2Fcka%2Flabs%2F02%2FREADME.MD) is added
* summary lisf of [labs](..%2Fdocs%2Flabs.MD) is  added
*  cka lab 01 [(Fix problems with kube-api)](..%2Ftasks%2Fcka%2Flabs%2F01%2FREADME.MD) is added
*  [solution](..%2Ftasks%2Fcka%2Flabs%2F01%2Fworker%2Ffiles%2Fsolutions) for cka lab 01 [(Fix problems with kube-api)](..%2Ftasks%2Fcka%2Flabs%2F01%2FREADME.MD) is added
*  [video solution](https://youtu.be/OFHiI_XAXNU) for  cka lab 01 [(Fix problems with kube-api)](..%2Ftasks%2Fcka%2Flabs%2F01%2FREADME.MD) is added
* k8s version **1.29**  is used in [cka-mock 1](..%2Ftasks%2Fcka%2Fmock%2F01)
* k8s version **1.29**  is used in [cka-mock 2](..%2Ftasks%2Fcka%2Fmock%2F02)
* k8s version **1.29**  is used in [ckad-mock 1](..%2Ftasks%2Fckad%2Fmock%2F01)
* k8s version **1.29**  is used in [cks-mock 1](..%2Ftasks%2Fcks%2Fmock%2F01)

## 0.7.1 (23.01.2024)
### Features
* [Cka mock exam 2 ](..%2Ftasks%2Fcka%2Fmock%2F02) is added . List of questions updated as of December 2023
* [Cka mock exam 2 solutions](..%2Ftasks%2Fcka%2Fmock%2F02%2Fworker%2Ffiles%2Fsolutions) are added
* [Video](https://youtu.be/ia6Vw_BR-L0) for CKA mock 2  solutions is added.
* **ssh_password_enable**  is added to configuration in  env.hcl  (default true).
* **access_cidrs**  is added to configuration in  env.hcl   (default ["0.0.0.0/0"] )
* **debug_output**  is added to configuration in  env.hcl  ( default false )
* **solutions_scripts**  is added to configuration in  env.hcl .
* **solutions_video**  is added to configuration in  env.hcl .
* **questions_list**  is added to configuration in  env.hcl . It is url  to  mock questions (like https://github.com/ViktorUJ/cks/blob/master/tasks/cks/mock/01/README.MD)
* [links](..%2Fdocs%2Flinks.MD) is updated. **killer shell cks**  free  course is added. It is **best** course for **cks** exam.


## 0.6.1 (30.12.2023)
### Features
* Support for [simultaneous creation of independent environments](..%2Fdocs%2Fmultiple_users_envs.MD) is added.
* The ability to create independent environments for different users is added.
* The ability to create independent environments for each user is added.
* CMDB is added. Now all created resources are automatically added to CMDB. [video instructions](https://youtu.be/3H0RMLXGmgg)
* Commands for working with CMDB are added (The user can get the list of all resources,  all user resources, detailed information on individual resources).
* K8s version **1.29** is added  to [k8s_self_management](..%2Fterraform%2Fmodules%2Fk8s_self_managment) module.
* Docker runner is added. Now you can run [make commands](..%2FREADME.MD#command)  from docker container. [more details](..%2Fdocs%2Frun_from_docker.MD)
* Terraform code is updated  to use **terraform** version **v1.6.6**
* Terragrunt is updated  to use  version **v0.54.8**
* [cka mock 02 questions list](..%2Ftasks%2Fcka%2Fmock%2F02) is added.
* [lfcs mock 01 questions list](..%2Ftasks%2Flfcs%2Fmock%2F01) is added.


## 0.5.1 (23.11.2023)
### Features
* [Ckad mock exam 1 ](..%2Ftasks%2Fckad%2Fmock%2F01) is added
* [Ckad mock exam 1 solutions](..%2Ftasks%2Fckad%2Fmock%2F01%2Fworker%2Ffiles%2Fsolutions) are added
* [Video](https://youtu.be/yQK7Ca8d-yw) for CKAD mock solutions is added
* [HR scenario 1 ](..%2Ftasks%2Fhr%2Fmock%2F01) is added
* HR scenario 1 [solutions](..%2Ftasks%2Fhr%2Fmock%2F01%2Fworker%2Ffiles%2Fsolutions) are added
* [Video](https://youtu.be/4CTC1jl8lxE) for HR scenario 1 solutions is added
* [Ping_pong](..%2Fdocker%2Fping_pong) server is added

## 0.4.1 (15.10.2023)
### Features
* Spot ec2 is moved  from **spot request** to  **spot fleet**, which gives spot ec2 more stability
* [Make commands](..%2FREADME.MD#command) is updated
* Terraform code is updated  to use **terraform** version **v1.5.6**
* Terraform aws provider is updated  to **v5.17.0**
* **Ubuntu_version** is added  to [k8s_self_management](..%2Fterraform%2Fmodules%2Fk8s_self_managment) module, which is the way to get **ami_id** by default
* k8s version **1.28**  is used in cka-mock and cks-mock exams
* The [cks mock exam 01](..%2Ftasks%2Fcks%2Fmock%2F01)  uses version  **Graviton** instances **t4g.medium**
* The cks labs use version **1.28** and Graviton instances **t4g.medium**
* [Cks labs](..%2Ftasks%2Fcks%2Flabs) are actualized, [list](..%2Ftasks%2Fcks%2Flabs%2FREADME.MD) is added to them
* Cks mock [solutions](..%2Ftasks%2Fcks%2Fmock%2F01%2Fworker%2Ffiles%2Fsolutions)  are added
* [Video](https://youtu.be/_GbsBOMaJ9Q) for run mock exam is added
* [Video](https://youtu.be/I8CPwcGbrG8) for cks mock solutions is added

## 0.3.1 (15.09.2023)
### Features
* The ability to run the [k8s_self_management](..%2Fterraform%2Fmodules%2Fk8s_self_managment) module on [EC2 Graviton](https://docs.aws.amazon.com/whitepapers/latest/aws-graviton-performance-testing/what-is-aws-graviton.html) is added
* Support for the new Kubernetes version [1.28](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.28.md) is introduced
* Version 1.27 and Graviton instance t4g.medium  is used in [cka mock exam 01](..%2Ftasks%2Fcka%2Fmock%2F01)
* [Video for solutions ](https://youtu.be/IZsqAPpbBxM)  to the [cka mock exam 01](..%2Ftasks%2Fcka%2Fmock%2F01) is added
