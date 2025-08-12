# Welcome to the SRE Learning Platform!
<p align="center">
    <a href="https://github.com/ViktorUJ/cks"><img src="https://raw.githubusercontent.com/ViktorUJ/terraform-aws-vpc/master/img/logo_192x192.png" width="192" height="192" alt="SRE Learning Platform"/></a>
</p>


The **SRE Learning Platform** is an open-source hub designed to help IT engineers effectively prepare for the **CKA (Certified Kubernetes Administrator)**, **CKS (Certified Kubernetes Security Specialist)**, **CKAD (Certified Kubernetes Application Developer)**, and **LFCS (Linux Foundation Certified System Administrator)** exams. Additionally, this platform offers invaluable hands-on experience with **AWS EKS (Elastic Kubernetes Service)**, equipping users with practical insights for real-world applications. Whether you're aiming to validate your skills, boost your career prospects in Kubernetes administration, security, application development, or delve into AWS EKS, this platform provides hands-on labs, practice tests, and expert guidance to ensure certification success.

- Prepare for the **CKA**: [Certified Kubernetes Administrator Exam](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/)
- Enhance your skills for the **CKS**: [Certified Kubernetes Security Specialist Exam](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
- Excel in the **CKAD**: [Certified Kubernetes Application Developer Exam](https://training.linuxfoundation.org/certification/certified-kubernetes-application-developer-ckad/)
- Prepare for the **KCNA**: [Kubernetes and Cloud Native Associate](https://training.linuxfoundation.org/certification/kubernetes-cloud-native-associate/)
- Prepare for the **KCSA**: [Kubernetes and Cloud Native Security Associate](https://training.linuxfoundation.org/certification/kubernetes-and-cloud-native-security-associate-kcsa/)
- Prepare for the **LFCS**: [Linux Foundation Certified System Administrator](https://training.linuxfoundation.org/certification/linux-foundation-certified-sysadmin-lfcs/)
- Prepare for the **KCNA**: [Kubernetes and Cloud Native Associate](https://training.linuxfoundation.org/certification/kubernetes-cloud-native-associate/)
- Prepare for the [AWS Certified AI Practitioner](https://aws.amazon.com/certification/certified-ai-practitioner/)


Master Kubernetes concepts, gain practical experience, and excel in the CKA, CKS, and CKAD exams with the **SRE Learning Platform**.


## Quick start
[run via docker](docs%2Frun_from_docker.MD)

[![video instruction](docs%2Fimages%2Frun_via_docker.gif)](https://youtu.be/Xh6sWzafBmw "run via docker")


<details>
  <summary style="font-weight: bold; font-size: 1.5em;">Requirements</summary>

- [GNU Make](https://www.gnu.org/software/make/) >= 4.2.1
- [terrafrom](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)  >= v1.6.6
- [terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) >= v0.54.8
- [jq](https://jqlang.github.io/jq/download/) >= 1.6
- [aws IAM user](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html)  + [Access key](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)  (or [IAM role](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) ) with  [Admin privilege  for VPC, EC2, IAM, EKS](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-version.html) > 2.2.30
- [aws profile](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)

**Or you can** [run via docker](docs%2Frun_from_docker.MD)  ( [video instruction](https://youtu.be/Xh6sWzafBmw) )

</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">Repository Structure</summary>

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

</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">About CKA, CKS, CKAD scenarios</summary>

- the platform uses **aws**  to create following resources :  **vpc**, **subnets**, **security groups**, **ec2** (spot ), **s3**
- after you launch the scenarios the platform will create all the necessary resources   and give access to k8s clusters.
- to create clusters the platform uses **kubeadm**
- you can easily add your own scenario using the already existing terraform module [k8s_self_managment](terraform%2Fmodules%2Fk8s_self_managment)
- [k8s_self_managment](terraform%2Fmodules%2Fk8s_self_managment)  module supports versions:
````
k8s version  : [ 1.21 , 1.33 ]   https://kubernetes.io/releases/
Rintime :
    docker                   [1.21 , 1.23]
    cri-o                    [1.21 , 1.29]
    containerd               [1.21 , 1.33]   # cks, cka  default 1.32
    containerd_gvizor        [1.21 , 1.33]
OS for nodes  :
   ubuntu  :  20.04 LTS  ,  22.04 LTS   # cks default  22.04 LTS
CNI :  calico ,culium
````
</details>

## Configuration
- change  **backend_bucket** ( **region** , **backend_region**  optional ) in [terraform/environments/terragrunt.hcl](terraform%2Fenvironments%2Fterragrunt.hcl#L4) :


## Command
Every command should be run from the project's root directory.
<details>
  <summary style="font-weight: bold; font-size: 1.5em;">CMDB</summary>

- ``make cmdb_get_env_all`` - get a list of all resources in CMDB
- ``USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_data`` - show all created resources of user **myuser** in environment **01**
- ``USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_lock`` - show all lock resources of user **myuser** in environment **01**
- ``USER_ID='myuser' ENV_ID='01' make cmdb_get_user_env_lock`` - show all lock resources of user **myuser** in environment **01**
- ``USER_ID='myuser' make cmdb_get_user_env_lock`` - show all lock resources of user **myuser** in **all** environment
- ``USER_ID='myuser' make cmdb_get_user_env_data`` - show all data resources of user **myuser** in **all** environment
- ``CMDB_ITEM='CMDB_data_myuser_02_k8s_cluster1' make cmdb_get_item`` - getting detailed information about **CMDB_data_myuser_02_k8s_cluster1** resource.


</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">CKA</summary>

### cka task
- ``TASK=01 make run_cka_task`` - create cka [hands-on labs](docs%2Flabs.MD#cka-labs) number 01
- ``TASK=01 make delete_cka_task`` - delete cka hands-on labs
- ``TASK=01 make run_cka_task_clean`` - run cka_task with clean terragrunt cache  for  cka_task
- ``make output_cka_task `` - show **outputs** from   **cka_task**
### cka mock
- ``TASK=01 make run_cka_mock`` - create mock  CKA exam [number 01](tasks%2Fcka%2Fmock%2F01)
- ``make delete_cka_mock`` - delete mock  CKA exam
- ``TASK=01 make run_cka_mock_clean`` - create mock  CKA exam [number 01](tasks%2Fcka%2Fmock%2F01)  with clean terragrunt cache
- ``make output_cka_mock `` - show **outputs** from   **cka_mock**

</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">CKAD</summary>

### ckad mock
- ``TASK=01 make run_ckad_mock`` - create mock  CKAD exam [number 01](tasks%2Fckad%2Fmock%2F01)
- ``make delete_ckad_mock`` - delete mock  CKAD exam
- ``TASK=01 make run_ckad_mock_clean`` - create mock  CKAD exam [number 01](tasks%2Fckad%2Fmock%2F01)  with clean terragrunt cache
- ``make output_ckad_mock `` - show **outputs** from   **ckad_mock**

</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">CKS</summary>

### cks task
- ``TASK=10 make run_cks_task`` - create cks [hands-on labs](docs%2Flabs.MD#cks-labs) number 10
- ``TASK=10 make delete_cks_task`` - delete cks hands-on labs
- ``TASK=10  make run_cks_task_clean`` - run cks_task with clean terragrunt cache  for  cks_task
- ``make output_cks_task `` - show **outputs** from   **cks_task**
### cks mock
- ``TASK=01 make run_cks_mock`` - create mock  CKS exam [number 01](tasks%2Fcks%2Fmock%2F01)
- ``make delete_cks_mock`` - delete mock  CKS exam
- ``TASK=01 make run_cks_mock_clean`` - create mock  CKS exam [number 01](tasks%2Fcks%2Fmock%2F01)  with clean terragrunt cache
- ``make output_cks_mock `` - show **outputs** from   **cks_mock**
</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">LFCS</summary>

### lfcs mock

- ``TASK=01 make run_lfcs_mock`` - create mock LFCS exam [number 01](tasks/lfcs/mock/01/)
- ``make delete_lfcs_mock`` - delete mock LFCS exam
- ``TASK=01 make delete_lfcs_mock_clean`` - delete mock LFCS exam [number 01](tasks/lfcs/mock/01/) with cleaning terragrunt cache
- ``make output_lfcs_mock`` - show **outputs** from  **lfcs_mock**

</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">KCNA</summary>

### KCNA

- check examle questions in [kcna](tasks%2Fkcna) directory

</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">KCSA</summary>

- check examle questions in [kcsa](tasks%2Fkcsa) directory

</details>


<details>
  <summary style="font-weight: bold; font-size: 1.5em;">HR</summary>

- ``TASK=01 make run_hr_mock`` - create mock  hr exam [number 01](tasks%2Fhr%2Fmock%2F01)
- ``make delete_hr_mock`` - delete mock  hr exam
- ``TASK=01 make run_hr_mock_clean`` - create mock  CKS exam [number 01](tasks%2Fhr%2Fmock%2F01)  with clean terragrunt cache
- ``make output_hr_mock `` - show **outputs** from   **hr_mock**
</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">EKS</summary>

- ``TASK={lab_number} make run_eks_task`` create hands-on lab
- ``make delete_eks_task`` delete eks lab cluster
</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">DEV</summary>

- ``make lint`` run linter on the project

</details>

## Usage scenarios

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">AWS Certified AI Practitioner </summary>

### example questions for **AWS Certified AI Practitioner** exam

- check examle questions in [AWS Certified AI Practitioner](tasks/aws_AI_practitioner) directory
</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">CKA hands-on lab</summary>

- choose [a hands-on lab](docs%2Flabs.MD#cka-labs) number
- create cka lab cluster ``TASK={lab_number} make run_cka_task``
- find {master_external_ip} in terraform output
- log in to master node via ssh  ``ssh ubuntu@{master_external_ip} -i {key}``
- check init logs `` tail -f /var/log/cloud-init-output.log ``
- read lab descriptions in ``{lab_number}/README.MD``
- check solution in ``{lab_number}/SOLUTION.MD``
- delete cka lab cluster ``make delete_cka_task``
- clean cka lab cluster ``.terraform`` folder  ``make clean_cka_task ``
</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">mock CKA exam</summary>

  [Video instruction for launching **CKA mock exam**](https://www.youtube.com/watch?v=P-YYX4CTWIg)

- choose [a mock exam](tasks%2Fcka%2Fmock) number
- change instance type from ``spot`` to ``ondemand`` in  ``{mock_number}/env.hcl`` if you need
- create mock  CKA exam ``TASK={mock_number} make run_cka_mock``
- find ``worker_pc_ip`` in ``terraform output``
- connect to ``worker_pc_ip``  with your ssh key and user ``ubuntu``
- open questions list ``{mock_number}/README.MD`` and do tasks
- use ``ssh  {kubernetes_nodename}`` from  work pc to connect to node
- run ``time_left`` on work pc to check time
- run ``check_result`` on work pc to check result
- delete mock  CKA exam `make delete_cka_mock`
- find exam solutions  in ``{mock_number}/worker/files/solutions)`` and * [Video](https://youtu.be/IZsqAPpbBxM)  for [mock 01](tasks%2Fcka%2Fmock%2F01) .
- find  exam tests in ``{mock_number}/worker/files/tests.bats)``
</details>


<details>
  <summary style="font-weight: bold; font-size: 1.5em;">CKS hands-on lab</summary>

- choose [CKS lab](docs%2Flabs.MD#cks-labs)  number
- change **ami_id** in ``{lab_number}/scripts/terragrunt.hcl`` if you changed **region**
- create cka lab cluster ``TASK={lab_number} make run_cks_task``
- find {master_external_ip} in terraform output
- log in to master node via ssh  ``ssh ubuntu@{master_external_ip} -i {key}``
- check init logs `` tail -f /var/log/cloud-init-output.log ``
- read lab descriptions in ``{lab_number}/README.MD``
- check solution in ``{lab_number}/SOLUTION.MD``
- delete cks lab cluster ``make delete_cks_task``
- clean cks lab cluster ``.terraform`` folder  ``make clean_cks_task ``
</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">mock CKS exam</summary>

  [Video instruction for launching **CKS mock exam**](https://youtu.be/_GbsBOMaJ9Q)

### mock  CKS exam
- choose [a mock exam](tasks%2Fcks%2Fmock) number
- change **ubuntu_version** in ``{mock_number}/env.hcl`` if you need
- change instance type from ``spot`` to ``ondemand`` in  ``{mock_number}/env.hcl`` if you need
- create mock  CKS exam ``TASK={mock_number} make run_cks_mock`` or ``TASK={mock_number} make run_cks_mock_clean`` if you'd like  to run with **clean** terragrunt cache
- find ``worker_pc_ip`` in ``terraform output``
- connect to ``worker_pc_ip``  with your ssh key and user ``ubuntu``
- open questions list ``{mock_number}/README.MD`` and do tasks
- use ``ssh  {kubernetes_nodename}`` from  work pc to connect to node
- run ``time_left`` on work pc to check time
- run ``check_result`` on work pc to check result
- delete mock  CKS exam `make delete_cks_mock`
- find exam solutions in ``{mock_number}/worker/files/solutions``  [mock 1 solutions](tasks%2Fcks%2Fmock%2F01%2Fworker%2Ffiles%2Fsolutions)  and [video](https://youtu.be/I8CPwcGbrG8)
- find exam tests in ``{mock_number}/worker/files/tests.bats``
</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">mock CKAD exam</summary>

  [Video instruction for launching **CKAD mock exam**](https://youtu.be/7X4Y9QhbTsk)

### mock  CKAD exam
- choose [a mock exam](tasks%2Fckad%2Fmock)  number
- change **ubuntu_version** in ``{mock_number}/env.hcl`` if you need
- change instance type from ``spot`` to ``ondemand`` in  ``{mock_number}/env.hcl`` if you need
- create mock  CKAD exam ``TASK={mock_number} make run_ckad_mock`` or ``TASK={mock_number} make run_ckad_mock_clean`` if you'd like  to run with **clean** terragrunt cache
- find ``worker_pc_ip`` in ``terraform output``
- connect to ``worker_pc_ip``  with your ssh key and user ``ubuntu``
- open questions list ``{mock_number}/README.MD`` and do tasks
- use ``ssh  {kubernetes_nodename}`` from  work pc to connect to node
- run ``time_left`` on work pc to check time
- run ``check_result`` on work pc to check result
- delete mock  CKAD exam `make delete_ckad_mock`
- find exam solutions in ``{mock_number}/worker/files/solutions``  [mock 1 solutions](tasks%2Fckad%2Fmock%2F01%2Fworker%2Ffiles%2Fsolutions)   and [video](https://youtu.be/yQK7Ca8d-yw)
- find exam tests in ``{mock_number}/worker/files/tests.bats``
</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">KCNA </summary>

### example questions for KCNA exam

- check examle questions in [kcna](tasks%2Fkcna) directory
</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">KCSA</summary>

### example questions for KCSA exam

- check examle questions in [kcsa](tasks%2Fkcsa) directory
</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">mock HR exam</summary>

  [Video instruction for launching **HR mock exam**](https://youtu.be/4CTC1jl8lxE)

### mock  HR exam
- choose [a mock exam](tasks%2Fhr%2Fmock) number
- change **ubuntu_version** in ``{mock_number}/env.hcl`` if you need
- change instance type from ``spot`` to ``ondemand`` in  ``{mock_number}/env.hcl`` if you need
- create mock  CKS exam ``TASK={mock_number} make run_hr_mock`` or ``TASK={mock_number} make run_hr_mock_clean`` if you'd like  to run with **clean** terragrunt cache
- find ``worker_pc_ip`` in ``terraform output``
- connect to ``worker_pc_ip``  with your ssh key and user ``ubuntu``
- open questions list ``{mock_number}/README.MD`` and do tasks
- use ``ssh  {kubernetes_nodename}`` from  work pc to connect to node
- run ``time_left`` on work pc to check time
- run ``check_result`` on work pc to check result
- delete mock  CKA exam `make delete_hr_mock`
- find exam solutions in ``{mock_number}/worker/files/solutions``  [mock 1 solutions](tasks%2Fhr%2Fmock%2F01%2Fworker%2Ffiles%2Fsolutions)  and [video](https://youtu.be/4CTC1jl8lxE)
- find exam tests in ``{mock_number}/worker/files/tests.bats``
</details>

<details>
  <summary style="font-weight: bold; font-size: 1.5em;">EKS hands-on lab</summary>

- choose [labs](docs%2Flabs.MD#eks-labs)  number
- create hands-on lab `` TASK={lab_number} make run_eks_task ``
- find ``worker_pc_ip`` in ``terraform output``
- log in to worker_pc node via ssh  ``ssh ubuntu@{worker_pc_ip} -i {key}``
- read lab descriptions in ``{lab_number}/README.MD``
- check solution in ``{lab_number}/SOLUTION.MD``
- delete eks lab cluster ``make delete_eks_task``
</details>

## [Simultaneous work with independent environments](docs%2Fmultiple_users_envs.MD)

## [Useful links](docs%2Flinks.MD)

## [Tips And Tricks](docs%2Ftips_and_tricks.MD)

## [CHANGELOG](CHANGELOG%2FCHANGELOG.MD)

## [CODE OF CONDUCT](docs%2FCODE_OF_CONDUCT.md)

## Contribution
If you want to be part of the project development team, get in touch with [us](https://github.com/ViktorUJ/cks/tree/master#contacts). We are always happy to welcome new members to our development team.


If you want to say **thank you** or/and support the active development of **SRE Learning Platform project** :
- [Star](https://github.com/ViktorUJ/cks) the **SRE Learning Platform project** on Github
- Feel free to write articles about the project on [dev.to](https://dev.to/), [medium](https://medium.com/), [hackernoon](https://hackernoon.com) or on your personal blog and share your experiences


## License and Usage Agreement
- [Apache License 2.0](LICENSE)

## Channels for cooperative preparation
 -  [cka](https://t.me/sre_platform_cka)
 -  [cks](https://t.me/sre_platform_cks)
 -  [ckad](https://t.me/sre_platform_ckad)

## Contacts

If you encounter any issues or have questions about the project, you can reach out to:

[![email](https://badgen.net/badge/icon/email?icon=email&label)](mailto:viktoruj@gmail.com) [![Telegram](https://badgen.net/badge/icon/telegram?icon=telegram&label)](https://t.me/viktor_uj) [![LinkedI](https://badgen.net/badge/icon/linkedin?icon=linkedin&label)](https://www.linkedin.com/in/viktar-mikalayeu-mns)




