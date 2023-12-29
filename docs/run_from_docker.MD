# Run platform via docker 

We have prepared a docker image including all necessary dependencies and utilities .

You can use it to run exams or labs by following the instructions below or use  [video instructions](https://youtu.be/Xh6sWzafBmw)

```
sudo docker run -it viktoruj/runner

```
```
git clone https://github.com/ViktorUJ/cks.git

cd cks
```

``` 
#vim terraform/environments/terragrunt.hcl


locals {
  region                 = "eu-north-1"
  backend_region         = "eu-north-1"
  backend_bucket         = "sre-learning-platform-state-backet"  # update to your own name 
  backend_dynamodb_table = "${local.backend_bucket}-lock"
}

```
## set  aws key 
``` 
export AWS_ACCESS_KEY_ID=Your_Access_Key 
export AWS_SECRET_ACCESS_KEY=Your_Secred_Access_Key 
```

## run your scenario

```` 
TASK=01 make run_cka_mock
````
or (if you use multiple user or  multiple environments  )

```` 
USER_ID='user1' ENV_ID='01' TASK=01 make run_cka_mock 
````

## delete your scenario

``` 
TASK=01 make delete_cka_mock
```
or (if you use multiple user or  multiple environments  )
``` 
USER_ID='user1' ENV_ID='01' TASK=01 make delete_cka_mock 
```