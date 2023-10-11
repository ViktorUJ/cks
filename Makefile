# CKA task
run_cka_task:
	@echo "*** run cka , task ${TASK}"
	cp -r tasks/cka/labs/${TASK}/* terraform/environments/cka/
	cd terraform/environments/cka/ && terragrunt run-all  apply

delete_cka_task:
	@echo "*** delete cka , task ${TASK}"
	cp -r tasks/cka/labs/${TASK}/* terraform/environments/cka/
	cd terraform/environments/cka/ && terragrunt run-all  destroy

clean_cka_task:
	@echo "*** clean cka task "
	rm -rf terraform/environments/cka/*

run_cka_task_clean: clean_cka_task  run_cka_task

output_cka_task:
	cd terraform/environments/cka/ && terragrunt run-all output

#CKA mock
run_cka_mock:
	@echo "*** run cka mock , task ${TASK}"
	cp -r tasks/cka/mock/${TASK}/* terraform/environments/cka-mock/
	cd terraform/environments/cka-mock/ && terragrunt run-all apply

delete_cka_mock:
	@echo "*** delete cka mock "
	cd terraform/environments/cka-mock/ && terragrunt run-all destroy
	rm -rf terraform/environments/cka-mock/*

clean_cka_mock:
	@echo "*** clean cka mock "
	rm -rf terraform/environments/cka-mock/*

run_cka_mock_clean: clean_cka_mock run_cka_mock

output_cka_mock:
	cd terraform/environments/cka/ && terragrunt run-all output


#CKS task
run_cks_task:
	@echo "*** run cks , task ${TASK}"
	cp -r tasks/cks/labs/${TASK}/* terraform/environments/cks/
	cd terraform/environments/cks/ && terragrunt run-all  apply

delete_cks_task:
	@echo "*** delete cks , task ${TASK}"
	cp -r tasks/cks/labs/${TASK}/* terraform/environments/cks/
	cd terraform/environments/cks/ && terragrunt run-all  destroy

clean_cks_task:
	@echo "*** clean cks task "
	rm -rf terraform/environments/cks/*

run_cks_task_clean: clean_cks_task  run_cks_task

output_cks_task:
	cd terraform/environments/cks/ && terragrunt run-all output

#CKS mock
run_cks_mock:
	@echo "*** run cks mock clean , task ${TASK}"
	cp -r tasks/cks/mock/${TASK}/* terraform/environments/cks-mock/
	cd terraform/environments/cks-mock/ && terragrunt run-all apply

delete_cks_mock:
	@echo "*** delete cks mock "
	cd terraform/environments/cks-mock/ && terragrunt run-all destroy

clean_cks_mock:
	@echo "*** clean cks mock "
	rm -rf terraform/environments/cks-mock/*

run_cks_mock_clean: clean_cks_mock  run_cks_mock

output_cks_mock:
	cd terraform/environments/cks-mock/ && terragrunt run-all output

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
