## Run platform via docker

We have prepared a docker image including all necessary dependencies and utilities.

You can use it to run exams or labs by following the instructions below or use [video instructions](https://youtu.be/Xh6sWzafBmw)

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

### Ensure AWS Quotes are set properly

You have to increase you AWS quotes to be able to launch such amount of on-demand and spot instances.

```text
Increase on-demand count of the instances (Default quota is 5):
Service Quotas -> AWS services -> Amazon Elastic Compute Cloud (Amazon EC2) -> Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances and submit a request to increase it to 40

Increase spot instances count (Default quota is 5):

Service Quotas -> AWS services -> Amazon Elastic Compute Cloud (Amazon EC2) -> All Standard (A, C, D, H, I, M, R, T, Z) Spot Instance Requests
```

If you're going to use different instance type, please ensure that your service quotes set accordinally.

## Run your scenario

### For single environment

```sh
TASK=01 make run_cka_mock
```

### For multiple users or multiple environments

```sh
USER_ID='user1' ENV_ID='01' TASK=01 make run_cka_mock
```

## Delete your scenario

### For single environment

```sh
TASK=01 make delete_cka_mock
```

### For multiple users or multiple environments

```sh
USER_ID='user1' ENV_ID='01' TASK=01 make delete_cka_mock
```
