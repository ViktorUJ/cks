#CKS
run_cks_k8s_mock:
	@echo "*** run cks mock clean , task ${TASK}"
	cp -r tasks/cks/mock/${TASK}/* terraform/environments/cks-mock/
	cd terraform/environments/cks-mock/ && terragrunt run-all apply

clean_cks_k8s_mock:
	@echo "*** clean cks mock "
	rm -rf terraform/environments/cks-mock/*

run_cks_k8s_mock_clean: clean_cks_k8s_mock  run_cks_k8s_mock

delete_cks_k8s_mock:
	@echo "*** delete cks mock "
	cd terraform/environments/cks-mock/ && terragrunt run-all destroy

clean_cks_k8s_task:
	@echo "*** clean cks task "
	rm -rf terraform/environments/cks/*

run_cks_k8s_task:
	@echo "*** run cks , task ${TASK}"
	cp -r tasks/cks/labs/${TASK}/* terraform/environments/cks/
	cd terraform/environments/cks/ && terragrunt run-all  apply

run_cks_k8s_task_clean: clean_cks_k8s_task  run_cks_k8s_task

delete_cks_k8s_task:
	@echo "*** delete cks , task ${TASK}"
	cp -r tasks/cks/labs/${TASK}/* terraform/environments/cks/
	cd terraform/environments/cks/ && terragrunt run-all  destroy

output_cks_task:
	cd terraform/environments/cks/ && terragrunt run-all output

# CKA

clean_cka_k8s_mock:
	@echo "*** clean cka mock "
	rm -rf terraform/environments/cka-mock/*

run_cka_k8s_mock:
	@echo "*** run cka mock , task ${TASK}"
	cp -r tasks/cka/mock/${TASK}/* terraform/environments/cka-mock/
	cd terraform/environments/cka-mock/ && terragrunt run-all apply

run_cka_k8s_mock_clean: clean_cka_k8s_mock run_cka_k8s_mock

run_cka_k8s_task:
	@echo "*** run cks , task ${TASK}"
	cp tasks/cka/labs/${TASK}/scripts/terragrunt.hcl terraform/environments/cka/k8s/
	cd terraform/environments/cka/k8s/ && terragrunt apply

delete_cka_k8s_mock:
	@echo "*** delete cka mock "
	cd terraform/environments/cka-mock/ && terragrunt run-all destroy
	rm -rf terraform/environments/cka-mock/*

delete_cka_k8s:
	cd terraform/environments/cka/k8s/ && terragrunt destroy

clean_cka_k8s:
	cd terraform/environments/cka/k8s/ && rm -rf .terr*

#EKS
run_eks_task:
	@echo "*** run run_eks_task , task ${TASK}"
	rm -rf terraform/environments/eks/*
	cp -r tasks/eks/labs/${TASK}/* terraform/environments/eks/
	cd terraform/environments/eks/ && terragrunt run-all apply

delete_eks_task:
	@echo "*** delete delete_eks_task "
	cd terraform/environments/eks/ && terragrunt run-all destroy
	rm -rf terraform/environments/eks/*

#DEV

lint:
	pre-commit run --all-files -c .hooks/.pre-commit-config.yaml
