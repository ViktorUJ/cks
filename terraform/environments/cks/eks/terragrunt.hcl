include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/eks/"

  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }

}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  region                       = local.vars.locals.region
  aws                          = local.vars.locals.aws
  prefix                       = local.vars.locals.prefix
  vpc_id                       = dependency.vpc.outputs.vpc_id
  eks ={
    version= "1.24"
    cloudwatch_retention_in_days = "30"
    allow_cidrs = ["0.0.0.0/0"]

    node_group = {

   #  default = {
   #    ec2_types = ["t3.medium"]
   #    capacity_type = "SPOT"
   #    desired_size = "1"
   #    max_size = "2"
   #    min_size = "1"
   #    labels ={
   #      work_type = "default"
   #      cost_type = "devops"
   #    }
   #  }
   #
   #  job = {
   #    ec2_types = ["t3.medium"]
   #    capacity_type = "SPOT"
   #    desired_size = "1"
   #    max_size = "2"
   #    min_size = "1"
   #    labels ={
   #      work_type = "jov"
   #      cost_type = "devops"
   #    }
   #  }





    }



  }

}


