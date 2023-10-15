# Welcome to the SRE Learning Platform!

The **SRE Learning Platform** is an open-source hub designed to help IT engineers effectively prepare for the **CKA (Certified Kubernetes Administrator)**, **CKS (Certified Kubernetes Security Specialist)**, and **CKAD (Certified Kubernetes Application Developer)** exams. Additionally, this platform offers invaluable hands-on experience with **AWS EKS (Elastic Kubernetes Service)**, equipping users with practical insights for real-world applications. Whether you're aiming to validate your skills, boost your career prospects in Kubernetes administration, security, application development, or delve into AWS EKS, this platform provides hands-on labs, practice tests, and expert guidance to ensure certification success.

- Prepare for the **CKA**: [Certified Kubernetes Administrator Exam](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/)
- Enhance your skills for the **CKS**: [Certified Kubernetes Security Specialist Exam](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
- Excel in the **CKAD**: [Certified Kubernetes Application Developer Exam](https://training.linuxfoundation.org/certification/certified-kubernetes-application-developer-ckad/)

Master Kubernetes concepts, gain practical experience, and excel in the CKA, CKS, and CKAD exams with the **SRE Learning Platform**.


## Repository Structure

The repository is organized into the following sections:

- **[Makefile](Makefile)** - File contains scenarios for launching hands-on labs and mock exams.
- **[tasks](tasks)** - Directory contains lab scenarios and mock exam scripts.
  - **[cka](tasks%2Fcka)** - Directory contains everything related to CKA.
    - **[labs](tasks%2Fcka%2Flabs)**  - Directory  contains hands-on labs for the CKA exam.
    - **[mock](tasks%2Fcka%2Fmock)**  - Directory contains mock scripts for the CKA exam.
  - **[cks](tasks%2Fcks)** - Directory contains everything related to CKS.
    - **[labs](tasks%2Fcks%2Flabs)**  - Directory contains hands-on labs for the CKS exam.
    - **[mock](tasks%2Fcks%2Fmock)**  - Directory contains mock scripts for the CKS exam.
- **[terraform](terraform)** - Directory contains  modules and Terraform environments.
  - **[environments](terraform%2Fenvironments)** - Directory contains terragrunt (terraform) environments.
  - **[modules](terraform%2Fmodules)** - Directory contains terraform modules.

## Requirements
- [terrafrom](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)  >= v1.5.6
- [terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) >= v0.36.1
- [aws IAM user](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html)  + [Access key](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)  (or [IAM role](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) ) with  [Admin privilege  for VPC, EC2, IAM, EKS](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html)
- [aws profile](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)


### About CKA, CKS, CKAD scenarios
- the platform uses **aws**  to create following resources :  **vpc**, **subnets**, **security groups**, **ec2** (spot ), **s3**
- after you launch the scenarios the platform will create all the necessary resources   and give access to k8s clusters.
- to create clusters the platform uses **kubeadm** 
- you can easily add your own scenario using the already existing terraform module [k8s_self_managment](terraform%2Fmodules%2Fk8s_self_managment) 
- [k8s_self_managment](terraform%2Fmodules%2Fk8s_self_managment)  module supports versions:
````
k8s version  : [ 1.21 , 1.28 ]   https://kubernetes.io/releases/
Rintime :
    docker                   [1.21 , 1.23]
    cri-o                    [1.21 , 1.28]
    containerd               [1.21 , 1.28]   # cks, cka  default 1.28
    containerd_gvizor        [1.21 , 1.28]
OS for nodes  :
   ubuntu  :  20.04 LTS  ,  22.04 LTS   # cks default  20.04 LTS
CNI :  calico
````

## Configuration
- change  **backend_bucket** ( **region** , **backend_region**  optional ) in [terraform/environments/terragrunt.hcl](terraform%2Fenvironments%2Fterragrunt.hcl#L4) :
- create  [aws ec2 key-pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html) with name=cks  in our region (default region = eu-north-1)


## Command
Every command should be run from the project's root directory.
<details>
  <summary style="font-weight: bold; font-size: 1.5em;">CKA</summary>

### cka task
- ``TASK=01 make run_cka_task`` - create cka [hands-on labs](tasks%2Fcka%2Flabs)  [number 01](tasks%2Fcka%2Flabs%2F01)
- ``TASK=01 make delete_cka_task`` - delete cka hands-on labs
- ``make clean_cka_task`` - clean terragrunt cache  for  cka_task
- ``TASK=01 make run_cka_task_clean`` - run cka_task with clean terragrunt cache  for  cka_task
- ``make output_cka_task `` - show **outputs** from   **cka_task**
### cka mock
- ``TASK=01 make run_cka_k8s_mock`` - create mock  CKA exam [number 01](tasks%2Fcka%2Fmock%2F01)
- ``make delete_cka_k8s_mock`` - delete mock  CKA exam
- ``make clean_cka_mock`` clean terragrunt cache  for  cka_mock
- ``TASK=01 make run_cka_mock_clean`` - create mock  CKA exam [number 01](tasks%2Fcks%2Fmock%2F01)  with clean terragrunt cache 
- ``make output_cka_mock `` - show **outputs** from   **cka_mock**

</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">CKS</summary>

### cks task
- ``TASK=10 make run_cks_task`` - create cks [hands-on labs](tasks%2Fcks%2Flabs)  [number 10](tasks%2Fcks%2Flabs%2F10)
- ``TASK=10 make delete_cks_task`` - delete cks hands-on labs
- ``make clean_cks_task`` - clean terragrunt cache  for  cks_task
- ``TASK=10  make run_cks_task_clean`` - run cks_task with clean terragrunt cache  for  cks_task
- ``make output_cks_task `` - show **outputs** from   **cks_task**
### cks mock
- ``TASK=01 make run_cks_mock`` - create mock  CKS exam [number 01](tasks%2Fcks%2Fmock%2F01)
- ``make delete_cks_mock`` - delete mock  CKS exam
- ``make clean_cks_mock`` clean terragrunt cache  for  cks_mock
- ``TASK=01 make run_cks_mock_clean`` - create mock  CKS exam [number 01](tasks%2Fcks%2Fmock%2F01)  with clean terragrunt cache 
- ``make output_cks_mock `` - show **outputs** from   **cks_mock**
</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">EKS</summary>

- ``TASK={lab_number} make run_eks_task`` create hands-on lab
- ``make delete_eks_task`` delete eks lab cluster
</details>

## Usage scenarios

[Video instruction for launching **CKA mock exam**](https://www.youtube.com/watch?v=P-YYX4CTWIg)

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">CKA hands-on lab</summary>

- choose [a hands-on lab](tasks%2Fcka%2Flabs) number
- create cka lab cluster ``TASK={lab_number} make run_cka_k8s_task``
- find {master_external_ip} in terraform output
- log in to master node via ssh  ``ssh ubuntu@{master_external_ip} -i {key}``
- check init logs `` tail -f /var/log/cloud-init-output.log ``
- read lab descriptions in ``{lab_number}/README.MD``
- check solution in ``{lab_number}/SOLUTION.MD``
- delete cka lab cluster ``make delete_cka_k8s_task``
- clean cka lab cluster ``.terraform`` folder  ``make clean_cka_k8s ``
</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">mock CKA exam</summary>

- choose [a mock exam](tasks%2Fcka%2Fmock) number
- change instance type from ``spot`` to ``on-demand`` in  ``{mock_number}/env.hcl`` if you need
- create mock  CKA exam ``TASK={mock_number} make run_cka_k8s_mock``
- find ``worker_pc_ip`` in ``terraform output``
- connect to ``worker_pc_ip``  with your ssh key and user ``ubuntu``
- open questions list ``{mock_number}/README.MD`` and do tasks
- use ``ssh  {kubernetes_nodename}`` from  work pc to connect to node
- run ``time_left`` on work pc to check time
- run ``check_result`` on work pc to check result
- delete mock  CKA exam `make delete_cka_k8s_mock`
- find exam solutions  in ``{mock_number}/worker/files/solutions)`` and * [Video](https://youtu.be/IZsqAPpbBxM)  for [mock 01](tasks%2Fcka%2Fmock%2F01) .
- find  exam tests in ``{mock_number}/worker/files/tests.bats)``
</details>


<details>
  <summary style="font-weight: bold; font-size: 1.5em;">CKS hands-on lab</summary>

- choose [CKS lab](tasks%2Fcks%2Flabs%2FREADME.MD)  number
- change **ami_id** in ``{lab_number}/scripts/terragrunt.hcl`` if you changed **region**
- create cka lab cluster ``TASK={lab_number} make run_cks_k8s_task``
- find {master_external_ip} in terraform output
- log in to master node via ssh  ``ssh ubuntu@{master_external_ip} -i {key}``
- check init logs `` tail -f /var/log/cloud-init-output.log ``
- read lab descriptions in ``{lab_number}/README.MD``
- check solution in ``{lab_number}/SOLUTION.MD``
- delete cks lab cluster ``make delete_cks_k8s_task``
- clean cks lab cluster ``.terraform`` folder  ``make clean_cks_k8s ``
</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">mock CKS exam</summary>

### mock  CKS exam
- choose [a mock exam](tasks%2Fcks%2Fmock) number
- change **ubuntu_version** in ``{mock_number}/env.hcl`` if you need 
- change instance type from ``spot`` to ``on-demand`` in  ``{mock_number}/env.hcl`` if you need
- create mock  CKS exam ``TASK={mock_number} make run_cks_mock`` or ``TASK={mock_number} make run_cks_mock_clean`` if you'd like  to run with **clean** terragrunt cache
- find ``worker_pc_ip`` in ``terraform output``
- connect to ``worker_pc_ip``  with your ssh key and user ``ubuntu``
- open questions list ``{mock_number}/README.MD`` and do tasks
- use ``ssh  {kubernetes_nodename}`` from  work pc to connect to node
- run ``time_left`` on work pc to check time
- run ``check_result`` on work pc to check result
- delete mock  CKA exam `make delete_cks_mock`
- find exam solutions in ``{mock_number}/worker/files/solutions``  [mock 1 solutions](tasks%2Fcks%2Fmock%2F01%2Fworker%2Ffiles%2Fsolutions)  and [video](https://youtu.be/I8CPwcGbrG8)
- find exam tests in ``{mock_number}/worker/files/tests.bats``
</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">EKS hands-on lab</summary>

- choose [labs](tasks%2Feks%2Flabs)  number
- create hands-on lab `` TASK={lab_number} make run_eks_task ``
- find ``worker_pc_ip`` in ``terraform output``
- log in to worker_pc node via ssh  ``ssh ubuntu@{worker_pc_ip} -i {key}``
- read lab descriptions in ``{lab_number}/README.MD``
- check solution in ``{lab_number}/SOLUTION.MD``
- delete eks lab cluster ``make delete_eks_task``
</details>

## [Useful links](docs%2Flinks.MD)

## [Tips And Tricks](docs%2Ftips_and_tricks.MD)

## [CHANGELOG](CHANGELOG%2FCHANGELOG.MD)

## [CODE OF CONDUCT](docs%2FCODE_OF_CONDUCT.md)

## Contribution
If you want to be part of the project development team, get in touch with [us](https://github.com/ViktorUJ/cks/tree/master#contacts). We are always happy to welcome new members to our development team


If you want to say **thank you** or/and support the active development of **SRE Learning Platform project** :
- [Star](https://github.com/ViktorUJ/cks) the **SRE Learning Platform project** on Github
- Feel free to write articles about the project on [dev.to](https://dev.to/), [medium](https://medium.com/) or on your personal blog and share your experiences


## License and Usage Agreement
- [Apache License 2.0](LICENSE)

## Contacts

If you encounter any issues or have questions about the project, you can reach out to:

[![email](https://badgen.net/badge/icon/email?icon=email&label)](mailto:viktoruj@gmail.com) [![Telegram](https://badgen.net/badge/icon/telegram?icon=telegram&label)](https://t.me/viktor_uj) [![LinkedI](https://badgen.net/badge/icon/linkedin?icon=linkedin&label)](https://www.linkedin.com/in/viktar-mikalayeu-mns)
