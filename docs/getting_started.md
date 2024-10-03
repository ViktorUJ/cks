## Welcome to SRE learning platform

The **SRE Learning Platform** is an open-source hub designed to help IT engineers effectively prepare for the **CKA (Certified Kubernetes Administrator)**, **CKS (Certified Kubernetes Security Specialist)**, **CKAD (Certified Kubernetes Application Developer)**, and **LFCS (Linux Foundation Certified System Administrator)** exams. Additionally, this platform offers invaluable hands-on experience with **AWS EKS (Elastic Kubernetes Service)**, equipping users with practical insights for real-world applications. Whether you're aiming to validate your skills, boost your career prospects in Kubernetes administration, security, application development, or delve into AWS EKS, this platform provides hands-on labs, practice tests, and expert guidance to ensure certification success.

- Prepare for the **CKA**: [Certified Kubernetes Administrator Exam](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/)
- Enhance your skills for the **CKS**: [Certified Kubernetes Security Specialist Exam](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
- Excel in the **CKAD**: [Certified Kubernetes Application Developer Exam](https://training.linuxfoundation.org/certification/certified-kubernetes-application-developer-ckad/)
- Prepare for the **LFCS**: [Linux Foundation Certified System Administrator](https://training.linuxfoundation.org/certification/linux-foundation-certified-sysadmin-lfcs/)

Master Kubernetes concepts, gain practical experience, and excel in the CKA, CKS, and CKAD exams with the **SRE Learning Platform**.

[![video instruction](../static/img/run_via_docker.gif)](https://youtu.be/Xh6sWzafBmw "run via docker")

## Run platform via docker

We have prepared a docker image including all necessary dependencies and utilities .

You can use it to run exams or labs by following the instructions below or use  [video instructions](https://youtu.be/Xh6sWzafBmw)

### Run the docker container

```sh
sudo docker run -it viktoruj/runner
```

### Clone the git repo

```sh
git clone https://github.com/ViktorUJ/cks.git

cd cks
```

### Update S3 bucket

```hcl
#vim terraform/environments/terragrunt.hcl

locals {
  region                 = "eu-north-1"
  backend_region         = "eu-north-1"
  backend_bucket         = "sre-learning-platform-state-backet"  # update to your own name
  backend_dynamodb_table = "${local.backend_bucket}-lock"
}
```

### Set the aws key

```sh
export AWS_ACCESS_KEY_ID=Your_Access_Key
export AWS_SECRET_ACCESS_KEY=Your_Secred_Access_Key
```

### Run your scenario

#### For single environment

````sh
TASK=01 make run_cka_mock
````

#### For multiple users or multiple environments

```sh
USER_ID='user1' ENV_ID='01' TASK=01 make run_cka_mock
```

### Delete your scenario

#### For single environment

```sh
TASK=01 make delete_cka_mock
```

#### For multiple users or multiple environments

```sh
USER_ID='user1' ENV_ID='01' TASK=01 make delete_cka_mock
```

Requirements

- [GNU Make](https://www.gnu.org/software/make/) >= 4.2.1
- [terrafrom](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)  >= v1.6.6
- [terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) >= v0.54.8
- [jq](https://jqlang.github.io/jq/download/) >= 1.6
- [aws IAM user](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html)  + [Access key](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)  (or [IAM role](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) ) with  [Admin privilege  for VPC, EC2, IAM, EKS](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-version.html) > 2.2.30
- [aws profile](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
