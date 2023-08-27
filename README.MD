# Welcome to the SRE Learning Platform!

The **SRE Learning Platform** is an open-source hub designed to help IT engineers effectively prepare for the **CKA (Certified Kubernetes Administrator)**, **CKS (Certified Kubernetes Security Specialist)**, and **CKAD (Certified Kubernetes Application Developer)** exams. Additionally, this platform offers invaluable hands-on experience with **AWS EKS (Elastic Kubernetes Service)**, equipping users with practical insights for real-world applications. Whether you're aiming to validate your skills, boost your career prospects in Kubernetes administration, security, application development, or delve into AWS EKS, this platform provides hands-on labs, practice tests, and expert guidance to ensure certification success.

- Prepare for the **CKA**: [Certified Kubernetes Administrator Exam](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/)
- Enhance your skills for the **CKS**: [Certified Kubernetes Security Specialist Exam](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
- Excel in the **CKAD**: [Certified Kubernetes Application Developer Exam](https://training.linuxfoundation.org/certification/certified-kubernetes-application-developer-ckad/)

Master Kubernetes concepts, gain practical experience, and excel in the CKA, CKS, and CKAD exams with the **SRE Learning Platform**.


## Repository Structure

The repository is organized into the following sections:

- **/[Makefile](Makefile)** - File contains scenarios for launching hands-on labs and mock exams.
- **/[tasks](tasks)** - Directory contains lab scenarios and mock exam scripts.
  - **/[cka](tasks%2Fcka)** - Directory contains everything related to CKA.
    - **/[labs](tasks%2Fcka%2Flabs)**  - Directory  contains hands-on labs for the CKA exam.
    - **/[mock](tasks%2Fcka%2Fmock)**  - Directory contains mock scripts for the CKA exam.
  - **/[cks](tasks%2Fcks)** - Directory contains everything related to CKS.
    - **/[labs](tasks%2Fcks%2Flabs)**  - Directory contains hands-on labs for the CKS exam.
    - **/[mock](tasks%2Fcks%2Fmock)**  - Directory contains mock scripts for the CKS exam.
- **/[terraform](terraform)** - Directory contains  modules and Terraform environments.
  - **/[environments](terraform%2Fenvironments)** - Directory contains terragrunt (terraform) environments.
  - **/[modules](terraform%2Fmodules)** - Directory contains terraform modules.
 
## Requirements
- OS: linux or MacOS
- make 
- [terrafrom](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)  >= v1.1.7
- [terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) >= v0.36.1
- [aws IAM user](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html)  + [Access key](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)  (or [IAM role](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) ) with  [Admin privilege  form VPC, EC2, IAM, EKS](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html) 
- [aws profile](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) 


### About CKA, CKS, CKAD scenarios
- use **aws**
- create **vpc** , **subnets**
- create  **ec2** (spot ) master and workers 
- init master node by **kubeadm** 
- copy join token to **s3**
- load   join token  from **s3** to **worker node** and join to the cluster .
- support versions: 
````
k8s version  : [ 1.21 , 1.27 ]   https://kubernetes.io/releases/
Rintime : 
    docker                   [1.21 , 1.23]
    cri-o                    [1.21 , 1.27]
    containerd               [1.21 , 1.27]   # cks default 
    containerd_gvizor        [1.21 , 1.27] 
OS for nodes  : 
   ubuntu  :  20.04 LTS  ,  22.04 LTS 
CNI :  calico  
````

## Configuration 
- change  **backend_bucket** ( **region** , **backend_region**  optional ) in [terragrunt.hcl](terraform%2Fenvironments%2Fterragrunt.hcl) :
- create  [aws ec2 key-pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html) with name=cks  in our region (default region = eu-north-1)


## Command
Every command should be run from the project's root directory.
### CKA
- ``make run_cka_vpc``  - create vpc for CKA hands-on labs
- ``TASK=01 make run_cka_k8s_task`` - create cka [hands-on labs](tasks%2Fcka%2Flabs)  [number 01](tasks%2Fcka%2Flabs%2F01)
- ``make delete_cka_k8s`` - delete cka hands-on labs
- ``make delete_cka_vpc`` - delete vpc for CKA hands-on labs
- ``TASK=01 make run_cka_k8s_mock`` - create mock  CKA exam [number 01](tasks%2Fcka%2Fmock%2F01)
- ``make delete_cka_k8s_mock`` - delete mock  CKA exam
### CKS 
- ``make run_cks_vpc``  - create vpc for CKS hands-on labs
- ``TASK=10 make run_cks_k8s_task`` - create cks [hands-on labs](tasks%2Fcks%2Flabs)  [number 10](tasks%2Fcks%2Flabs%2F10)
- ``make delete_cks_k8s`` - delete cks hands-on labs
- ``make delete_cks_vpc`` - delete vpc for CKS hands-on labs
- ``TASK=01 make run_cks_k8s_mock`` - create mock  CKS exam [number 01](tasks%2Fcks%2Fmock%2F01)
- ``make delete_cks_k8s_mock`` - delete mock  CKS exam

## Usage scenarios
### CKA hands-on lab
- create vpc for CKA hands-on labs ``make run_cka_vpc``
- choose [a hands-on lab](tasks%2Fcka%2Flabs) number
- update ``s3_k8s_config`` in  ``{lab_number}/scripts/terragrunt.hcl`` 
- change **ami_id** in ``{lab_number}/scripts/terragrunt.hcl``  if you changed **region**      
- create cka lab cluster ``TASK={lab_number} make run_cka_k8s_task``
- find {master_external_ip} in terraform output
- log in to master node via ssh  ``ssh ubuntu@{master_external_ip} -i {key}``
- check init logs `` tail -f /var/log/cloud-init-output.log ``
- read lab descriptions in ``{lab_number}/README.MD``
- check solution in ``{lab_number}/SOLUTION.MD``
- delete cka lab cluster ``make delete_cka_k8s_task``
- clean cka lab cluster ``.terraform`` folder  ``make clean_cka_k8s ``

###  mock  CKA exam
- choose [a mock exam](tasks%2Fcka%2Fmock) number
- update ``s3_k8s_config`` in ``{mock_number}/env.hcl``
- change **ami_id** in ``{mock_number}/env.hcl``  if you changed **region**  
- change instance type from ``spot`` to ``on-demand`` in  ``{mock_number}/env.hcl`` if you need 
- create mock  CKA exam ``TASK={mock_number} make run_cka_k8s_mock`` 
- find ``worker_pc_ip`` in ``terraform output``
- connect to ``worker_pc_ip``  with your ssh key and user ``ubuntu``
- open questions list ``{mock_number}/README.MD`` and do tasks
- use ``ssh  {kubernetes_nodename}`` from  work pc to connect to node 
- run ``time_left`` on work pc to check time
- run ``check_result`` on work pc to check result 
- delete mock  CKA exam `make delete_cka_k8s_mock`
- find exam solutions  in ``{mock_number}/worker/files/solutions)``
- find  exam tests in ``{mock_number}/worker/files/tests.bats)``

### CKS hands-on lab
- create vpc for CKA hands-on labs ``make run_cks_vpc``
- choose [a hands-on lab](tasks%2Fcks%2Flabs) number
- update ``s3_k8s_config`` in  ``{lab_number}/scripts/terragrunt.hcl`` 
- change **ami_id** in ``{lab_number}/scripts/terragrunt.hcl`` if you changed **region**    
- create cka lab cluster ``TASK={lab_number} make run_cks_k8s_task``
- find {master_external_ip} in terraform output
- log in to master node via ssh  ``ssh ubuntu@{master_external_ip} -i {key}``
- check init logs `` tail -f /var/log/cloud-init-output.log ``
- read lab descriptions in ``{lab_number}/README.MD``
- check solution in ``{lab_number}/SOLUTION.MD``
- delete cks lab cluster ``make delete_cks_k8s_task``
- clean cks lab cluster ``.terraform`` folder  ``make clean_cks_k8s ``

### mock  CKS exam
- choose [a mock exam](tasks%2Fcks%2Fmock) number
- update ``s3_k8s_config`` in ``{mock_number}/env.hcl``
- change **ami_id** in ``{mock_number}/env.hcl`` if you changed **region** 
- change instance type from ``spot`` to ``on-demand`` in  ``{mock_number}/env.hcl`` if you need  
- create mock  CKA exam ``TASK={mock_number} make run_cks_k8s_mock`` 
- find ``worker_pc_ip`` in ``terraform output``
- connect to ``worker_pc_ip``  with your ssh key and user ``ubuntu``
- open questions list ``{mock_number}/README.MD`` and do tasks
- use ``ssh  {kubernetes_nodename}`` from  work pc to connect to node 
- run ``time_left`` on work pc to check time 
- run ``check_result`` on work pc to check result 
- delete mock  CKA exam `make delete_cks_k8s_mock`
- find exam solutions in ``{mock_number}/worker/files/solutions)``  
- find exam tests in ``{mock_number}/worker/files/tests.bats)``

## [Useful links](docs%2Flinks.MD)

## [Tips And Tricks](docs%2Ftips_tricks.MD)

## License and Usage Agreement
- [Apache License 2.0](LICENSE)

## Contacts

If you encounter any issues or have questions about the project, you can reach out to:

[![email](https://badgen.net/badge/icon/email?icon=email&label)](mailto:viktoruj@gmail.com) [![Telegram](https://badgen.net/badge/icon/telegram?icon=telegram&label)](https://t.me/viktor_uj) [![LinkedI](https://badgen.net/badge/icon/linkedin?icon=linkedin&label)](https://www.linkedin.com/in/viktar-mikalayeu-mns)