prefix_dir="${USER_ID}_${ENV_ID}_"
terragrunt_vars="-var=\"prefix=$$prefix_dir\""

# Set prefix_dir to empty if it contains '__'
ifneq ($(findstring __,$(prefix_dir)),)
  # If '__' is found, set prefix_dir to an empty string
  prefix_dir :=
  terragrunt_vars :=
endif


test_multienv:
	@echo "*** run test_multienv  , prefix_dir=${prefix_dir}  dir=terraform/environments/${prefix_dir}cka/  task ${TASK}  "
	@echo "vars =   $$terragrunt_vars"
# CKA task

.ONESHELL:
run_cka_task:
	@echo "*** run cka , task ${TASK}"
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cka/"
	@echo "terragrunt_env_dir =$$terragrunt_env_dir"
	@mkdir $terragrunt_env_dir -p >/dev/null
	cp -r tasks/cka/labs/${TASK}/* $$terragrunt_env_dir
	cd $$terragrunt_env_dir && terragrunt run-all  apply

delete_cka_task:
	@echo "*** delete cka , task ${TASK}"
	@terragrunt_env_dir=terraform/environments/${prefix_dir}cka/
	@mkdir ${terragrunt_env_dir} -p >/dev/null
	cp -r tasks/cka/labs/${TASK}/* ${terragrunt_env_dir}
	cd ${terragrunt_env_dir} && terragrunt run-all  destroy

clean_cka_task:
	@echo "*** clean cka task "
	@terragrunt_env_dir=terraform/environments/${prefix_dir}cka/
	rm -rf ${terragrunt_env_dir}/*

run_cka_task_clean: clean_cka_task  run_cka_task

output_cka_task:
	@terragrunt_env_dir=terraform/environments/${prefix_dir}cka/
	@cd ${terragrunt_env_dir} && terragrunt run-all output

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
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cks/"
	@mkdir $$terragrunt_env_dir -p >/dev/null
	@echo "*** run cks , task ${TASK} terragrunt_env_dir =$$terragrunt_env_dir"
	cp -r tasks/cks/labs/${TASK}/* $$terragrunt_env_dir
	cd $$terragrunt_env_dir && terragrunt run-all  apply

delete_cks_task:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cks/"
	@mkdir $$terragrunt_env_dir -p >/dev/null
	@echo "*** delete cks , task ${TASK} terragrunt_env_dir =$$terragrunt_env_dir"
	cp -r tasks/cks/labs/${TASK}/* $$terragrunt_env_dir
	cd $$terragrunt_env_dir && terragrunt run-all  destroy

clean_cks_task:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cks/"
	@echo "terragrunt_env_dir =$$terragrunt_env_dir"
	@mkdir $$terragrunt_env_dir -p >/dev/null
	@echo "*** clean cks task  terragrunt_env_dir=$$terragrunt_env_dir  "
	rm -rf $$terragrunt_env_dir/*

run_cks_task_clean: clean_cks_task  run_cks_task

output_cks_task:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cks/"
	cd $$terragrunt_env_dir && terragrunt run-all output

#CKS mock
run_cks_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cks-mock/"
	@mkdir $$terragrunt_env_dir -p >/dev/null
	@echo "*** run cks mock clean , task ${TASK}  terragrunt_env_dir =$$terragrunt_env_dir "
	@cp -r tasks/cks/mock/${TASK}/* $$terragrunt_env_dir
	@cd $$terragrunt_env_dir && terragrunt run-all apply $$terragrunt_vars

delete_cks_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cks-mock/"
	@mkdir $$terragrunt_env_dir -p >/dev/null
	@echo "*** delete cks mock terragrunt_env_dir =$$terragrunt_env_dir "
	cd $$terragrunt_env_dir && terragrunt run-all destroy $$terragrunt_vars

clean_cks_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cks-mock/"
	@echo "*** clean cks mock terragrunt_env_dir =$$terragrunt_env_dir  "
	rm -rf $$terragrunt_env_dir/*

run_cks_mock_clean: clean_cks_mock  run_cks_mock

output_cks_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cks-mock/"
	cd $$terragrunt_env_dir && terragrunt run-all output $$terragrunt_vars

#CKAD mock
run_ckad_mock:
	@echo "*** run ckad mock , task ${TASK}"
	cp -r tasks/ckad/mock/${TASK}/* terraform/environments/ckad-mock/
	cd terraform/environments/ckad-mock/ && terragrunt run-all apply

delete_ckad_mock:
	@echo "*** delete ckad mock "
	cd terraform/environments/ckad-mock/ && terragrunt run-all destroy

clean_ckad_mock:
	@echo "*** run clean ckad mock "
	rm -rf terraform/environments/ckad-mock/*

run_ckad_mock_clean: clean_ckad_mock  run_ckad_mock

output_ckad_mock:
	cd terraform/environments/ckad-mock/ && terragrunt run-all output


#HR mock
run_hr_mock:
	@echo "*** run HR mock , task ${TASK}"
	cp -r tasks/hr/mock/${TASK}/* terraform/environments/hr/
	cd terraform/environments/hr/ && terragrunt run-all apply

delete_hr_mock:
	@echo "*** delete hr mock "
	cd terraform/environments/hr/ && terragrunt run-all destroy

clean_hr_mock:
	@echo "*** clean hr mock "
	rm -rf terraform/environments/hr/*

run_hr_mock_clean: clean_hr_mock  run_hr_mock

output_hr_mock:
	cd terraform/environments/hr/ && terragrunt run-all output



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
