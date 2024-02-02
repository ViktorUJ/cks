# Changelog

## 0.8.1 (xx.02.2024)
### Features
* update ping_pong service
* split CMDB and  resources aws region 
* add cka lab 02 (HPA by CPU)

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
