run_cks_vpc:
	cd terraform/environments/cks/vpc/ && terragrunt apply
output_cks_vpc:
	cd terraform/environments/cks/vpc/ && terragrunt output

delete_cks_vpc:
	cd terraform/environments/cks/vpc/ && terragrunt destroy

clean_cks_vpc:
	cd terraform/environments/cks/vpc/ && rm -rf .terr*


output_cks_k8s:
	cd terraform/environments/cks/k8s/ && terragrunt output

delete_cks_k8s:
	cd terraform/environments/cks/k8s/ && terragrunt destroy

clean_cks_k8s:
	cd terraform/environments/cks/k8s/ && rm -rf .terr*


run_cks_k8s_task:
	@echo "*** run cks , task ${TASK}"
	cp tasks/cks/${TASK}/scripts/terragrunt.hcl terraform/environments/cks/k8s/
	cd terraform/environments/cks/k8s/ && terragrunt apply