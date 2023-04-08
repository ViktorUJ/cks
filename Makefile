run_cks_vpc:
	cd terraform/environments/cks/vpc/ && terragrunt apply

delete_cks_vpc:
	cd terraform/environments/cks/vpc/ && terragrunt destroy
	pwd