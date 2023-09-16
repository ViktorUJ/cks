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
	cp tasks/cks/labs/${TASK}/scripts/terragrunt.hcl terraform/environments/cks/k8s/
	cd terraform/environments/cks/k8s/ && terragrunt apply

run_cks_k8s_mock:
	@echo "*** run cks mock , task ${TASK}"
	rm -rf terraform/environments/cks-mock/*
	cp -r tasks/cks/mock/${TASK}/* terraform/environments/cks-mock/
	cd terraform/environments/cks-mock/ && terragrunt run-all apply --terragrunt-parallelism 10


delete_cks_k8s_mock:
	@echo "*** delete cks mock "
	cd terraform/environments/cks-mock/ && terragrunt run-all destroy --terragrunt-parallelism 10
	rm -rf terraform/environments/cks-mock/*

run_cka_vpc:
	cd terraform/environments/cka/vpc/ && terragrunt apply
delete_cka_vpc:
	cd terraform/environments/cka/vpc/ && terragrunt destroy

clean_cka_vpc:
	cd terraform/environments/cka/vpc/ && rm -rf .terr*

run_cka_k8s_mock:
	@echo "*** run cka mock , task ${TASK}"
	rm -rf terraform/environments/cka-mock/*
	cp -r tasks/cka/mock/${TASK}/* terraform/environments/cka-mock/
	cd terraform/environments/cka-mock/ && terragrunt run-all apply

run_cka_k8s_task:
	@echo "*** run cks , task ${TASK}"
	cp tasks/cka/labs/${TASK}/scripts/terragrunt.hcl terraform/environments/cka/k8s/
	cd terraform/environments/cka/k8s/ && terragrunt apply

delete_cka_k8s:
	cd terraform/environments/cka/k8s/ && terragrunt destroy

clean_cka_k8s:
	cd terraform/environments/cka/k8s/ && rm -rf .terr*

delete_cka_k8s_mock:
	@echo "*** delete cka mock "
	cd terraform/environments/cka-mock/ && terragrunt run-all destroy
	rm -rf terraform/environments/cka-mock/*

run_eks_task:
	@echo "*** run run_eks_task , task ${TASK}"
	rm -rf terraform/environments/eks/*
	cp -r tasks/eks/labs/${TASK}/* terraform/environments/eks/
	cd terraform/environments/eks/ && terragrunt run-all apply --terragrunt-parallelism 10

delete_eks_task:
	@echo "*** delete delete_eks_task "
	cd terraform/environments/eks/ && terragrunt run-all destroy --terragrunt-parallelism 10
	rm -rf terraform/environments/eks/*

lint:
	pre-commit run --all-files -c .pre-commit-config.yaml
