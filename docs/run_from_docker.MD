# Run platform via docker

We have prepared a docker image including all necessary dependencies and utilities .

You can use it to run exams or labs by following the instructions below or use  [video instructions](https://youtu.be/Xh6sWzafBmw)

### Run the docker container
```
sudo docker run -it viktoruj/runner

```
### Clone the git repo
```
git clone https://github.com/ViktorUJ/cks.git

cd cks
```
### Update S3 bucket
```
#vim terraform/environments/terragrunt.hcl


locals {
  region                 = "eu-north-1"
  backend_region         = "eu-north-1"
  backend_bucket         = "sre-learning-platform-state-backet"  # update to your own name
  backend_dynamodb_table = "${local.backend_bucket}-lock"
}

```
### Set the google cloud service account key

https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference#running-terraform-outside-of-google-cloud

```
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/json
```

### Run your scenario

#### For single environment
````
TASK=01 make run_cka_mock
````
#### For multiple users or multiple environments

````
USER_ID='user1' ENV_ID='01' TASK=01 make run_cka_mock
````

### Delete your scenario

#### For single environment
```
TASK=01 make delete_cka_mock
```
#### For multiple users or multiple environments
```
USER_ID='user1' ENV_ID='01' TASK=01 make delete_cka_mock
```
