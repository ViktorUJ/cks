# change app configuration on ec2 instance (you don't have ssh access to the instance).
 - create iam role with ssm instance core policy.
 - attach this role to the instance.
 - login to the instance via ssm session manager.