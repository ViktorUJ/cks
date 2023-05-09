include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  #source = "git::git@github.com:ViktorUJ/cks.git//terraform/modules/k8s_self_managment/?ref=task_01"
  source = "../../..//modules/ssh-keys/"

  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }

}
