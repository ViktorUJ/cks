[Русский](getting_started_RU.md) · English · [Español](getting_started_ES.md) · [Français](getting_started_FR.md) · [Deutsch](getting_started_DE.md) · [ქართული](getting_started_GE.md) · [繁體中文](getting_started_TW.md) · [日本語](getting_started_JP.md) · [Home](../README.MD)

<a id="quick-start"></a>

# Getting started and requirements

You can read the courses directly in the repository. Running practical environments requires AWS and the platform tools. Cloud resources are billed to your AWS account; delete environments after practice according to the scenario instructions.

## 1. Prepare the tools

You can use the ready-to-run Docker image with dependencies:

```bash
sudo docker run -it viktoruj/runner
```

[Docker launch instructions](run_from_docker.MD) · [Video instructions](https://youtu.be/Xh6sWzafBmw)

[![Run the platform with Docker](images/run_via_docker.gif)](https://youtu.be/Xh6sWzafBmw "Run the platform with Docker")

<details>
<summary>Local installation requirements</summary>

- [GNU Make](https://www.gnu.org/software/make/) ≥ 4.2.1.
- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) ≥ 1.6.6.
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) ≥ 0.54.8.
- [jq](https://jqlang.github.io/jq/download/) ≥ 1.6.
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-version.html) > 2.2.30.
- [AWS profile](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) or another configured authentication method.
- An [IAM user](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html) with an [access key](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html), or an [IAM role](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html), with permissions to create and delete scenario resources. The original configuration assumes broad permissions for VPC, EC2, IAM, and EKS; see [AWS access policies](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html).

These are the original minimum versions listed in the platform documentation. Check the chosen scenario and its Terraform configuration for additional tool and provider requirements.

</details>

## 2. Get the repository and configure AWS

Run the following commands inside the Docker container or on a machine with the tools installed:

```bash
git clone https://github.com/ViktorUJ/cks.git
cd cks
```

Configure AWS access. Set your own `backend_bucket` in [terraform/environments/terragrunt.hcl](../terraform/environments/terragrunt.hcl); change `region` and `backend_region` if needed. Check the region and settings in the chosen scenario's `env.hcl`. The [Docker guide](run_from_docker.MD) explains the setup in detail.

## 3. Choose and launch an exercise

Example for the first composite CKA + CKAD lab:

```bash
TASK=101 make run_cka_task
```

Open [lab 101](../tasks/cka/labs/101/README.MD), connect using the Terraform output, and complete the tasks.

## 4. Delete the environment

After the exercise, follow its deletion instructions, then run:

```bash
TASK=101 make delete_cka_task
```

For another exercise, substitute its number and the appropriate track's command from the [command reference](commands.md).
