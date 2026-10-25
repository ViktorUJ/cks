[Русский](run_from_docker_RU.MD) · English · [Español](run_from_docker_ES.MD) · [Français](run_from_docker_FR.MD) · [Deutsch](run_from_docker_DE.MD) · [ქართული](run_from_docker_GE.MD) · [繁體中文](run_from_docker_TW.MD) · [日本語](run_from_docker_JP.MD) · [Home](../README.MD)

# Quick start with Docker

The ready-to-use Docker image includes the dependencies and utilities needed to run hands-on labs and practical mock exams. The example below launches CKA mock exam 01.

[Video instructions](https://youtu.be/Xh6sWzafBmw)

## 1. Start the container

On a machine with Docker installed, run:

```bash
sudo docker run -it viktoruj/runner
```

Run all subsequent commands inside the container.

## 2. Clone the repository

```bash
git clone https://github.com/ViktorUJ/cks.git
cd cks
```

## 3. Configure Terraform state storage

Open [terraform/environments/terragrunt.hcl](../terraform/environments/terragrunt.hcl). Replace `backend_bucket` with your own S3 bucket name for Terraform state. If needed, change the infrastructure region `region` and the state-storage region `backend_region`:

```hcl
locals {
  region                 = "eu-north-1"
  backend_region         = "eu-north-1"
  backend_bucket         = "your-platform-state-bucket"
  backend_dynamodb_table = "${local.backend_bucket}-lock"
}
```

Also check the region and settings in the selected scenario's `env.hcl`.

## 4. Configure AWS access

Replace the placeholders with your own access keys:

```bash
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_ACCESS_KEY
```

If you use temporary credentials, also set `AWS_SESSION_TOKEN`.

## 5. Check AWS quotas

The environment may need several EC2 instances. In the AWS console, open **Service Quotas → AWS services → Amazon Elastic Compute Cloud (Amazon EC2)** and check the quotas for your region and instance family:

- **Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances** for On-Demand.
- **All Standard (A, C, D, H, I, M, R, T, Z) Spot Instance Requests** for Spot.

These quotas measure vCPUs, not instance counts. If the available quota is insufficient for your scenario, request an increase. For other instance families, check the corresponding quotas.

## 6. Launch the scenario

For a single environment:

```bash
TASK=01 make run_cka_mock
```

For a specific user or multiple independent environments:

```bash
USER_ID='user1' ENV_ID='01' TASK=01 make run_cka_mock
```

Connect to the workstation using the details in the Terraform output and follow the [exam instructions](../tasks/cka/mock/01/README.MD).

For another exercise, choose its track and number in the [lab catalog](labs.MD) or on the [home page](../README.MD). Launch commands are listed in the [command reference](commands.md).

## 7. Delete the environment after practice

Resources are billed to your AWS account. Perform any preliminary cleanup required by the scenario's README, then delete the environment.

For a single environment:

```bash
TASK=01 make delete_cka_mock
```

For a specific user's environment:

```bash
USER_ID='user1' ENV_ID='01' TASK=01 make delete_cka_mock
```

Use the same `TASK`, `USER_ID`, and `ENV_ID` values that you used to launch the scenario.

[Independent environments and CMDB](environments.md) · [Usage scenarios](usage_scenarios.md)
