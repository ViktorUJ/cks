run_cks_vpc:
	cd terraform/environments/cks/vpc/ && terragrunt apply
	pwd

delete_cks_vpc:
	cd terraform/environments/cks/vpc/ && terragrunt destroy
