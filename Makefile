.ONESHELL:

prefix_dir="${USER_ID}_${ENV_ID}_"
region := $(shell grep 'backend_region' terraform/environments/terragrunt.hcl | awk -F '"' '{print $$2}')
backend_bucket := $(shell grep '^  backend_bucket' terraform/environments/terragrunt.hcl | awk -F '=' '{gsub(/ /, "", $$2); print $$2}' | tr -d '"')
dynamodb_table := $(backend_bucket)-lock

# Set prefix_dir to empty if it contains '__'
ifneq ($(findstring __,$(prefix_dir)),)
  # If '__' is found, set prefix_dir to an empty string
  prefix_dir :=
endif
# command{run}, type{mock,labs},task_number{0..x}
define terragrint_run
    @case "$(1)" in
        run)
            @echo "command = run"
            ;;
        delete)
            @echo "command = delete"
            ;;
        clean)
            @echo "command = clean"
            ;;
        output)
            @echo "command = output"
            ;;
    esac
#	@terragrunt_env_dir="terraform/environments/${prefix_dir}cka/"
#    @echo "terrgunt = $(1) , $(2) , $(3)"

endef

test:
	$(call terragrint_run,'run','cks','xxx')
	$(call terragrint_run,$(prefix_dir),'cks','run')

# CKA task
run_cka_task:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cka/"
	@echo "*** run cka , task ${TASK} .  terragrunt_env_dir =$$terragrunt_env_dir"
	@mkdir $$terragrunt_env_dir -p >/dev/null
	@cp -r tasks/cka/labs/${TASK}/* $$terragrunt_env_dir
	@export TF_VAR_STACK_TASK=${TASK} ;export TF_VAR_STACK_NAME="cka_task"; export TF_VAR_USER_ID=${USER_ID} ; export TF_VAR_ENV_ID=${ENV_ID} ; cd $$terragrunt_env_dir && terragrunt run-all  apply

delete_cka_task:
	@terragrunt_env_dir=terraform/environments/${prefix_dir}cka/
	@echo "*** delete cka , task ${TASK} .  terragrunt_env_dir =$$terragrunt_env_dir "
	@mkdir $${terragrunt_env_dir} -p >/dev/null
	@cp -r tasks/cka/labs/${TASK}/* ${terragrunt_env_dir}
	@export TF_VAR_STACK_TASK=${TASK} ;export TF_VAR_STACK_NAME="cka_task" ;export TF_VAR_USER_ID=${USER_ID} ; export TF_VAR_ENV_ID=${ENV_ID} ; cd $${terragrunt_env_dir} && terragrunt run-all  destroy

clean_cka_task:
	@echo "*** clean cka task "
	@terragrunt_env_dir=terraform/environments/${prefix_dir}cka/
	@rm -rf $${terragrunt_env_dir}/*

run_cka_task_clean: clean_cka_task  run_cka_task

output_cka_task:
	@terragrunt_env_dir=terraform/environments/${prefix_dir}cka/
	@cd $${terragrunt_env_dir} && terragrunt run-all output

#CKA mock
run_cka_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cka-mock/"
	@echo "*** run cka mock , task ${TASK} . terragrunt_env_dir =$$terragrunt_env_dir"
	@mkdir $$terragrunt_env_dir -p >/dev/null
	@cp -r tasks/cka/mock/${TASK}/* $$terragrunt_env_dir
	@export TF_VAR_STACK_TASK=${TASK} ;export TF_VAR_STACK_NAME="cka-mock" ; export TF_VAR_USER_ID=${USER_ID} ; export TF_VAR_ENV_ID=${ENV_ID} ; cd $$terragrunt_env_dir && terragrunt run-all apply

delete_cka_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cka-mock/"
	@mkdir $$terragrunt_env_dir -p >/dev/null
	@echo "*** delete cka mock task ${TASK} . terragrunt_env_dir =$$terragrunt_env_dir"
	@cp -r tasks/cka/mock/${TASK}/* $$terragrunt_env_dir
	@export TF_VAR_STACK_TASK=${TASK} ;export TF_VAR_STACK_NAME="cka-mock" ; export TF_VAR_USER_ID=${USER_ID} ; export TF_VAR_ENV_ID=${ENV_ID} ; cd $$terragrunt_env_dir && terragrunt run-all destroy
	@rm -rf $$terragrunt_env_dir

clean_cka_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cka-mock/"
	@echo "*** clean cka mock terragrunt_env_dir=$$terragrunt_env_dir "
	@rm -rf $$terragrunt_env_dir

run_cka_mock_clean: clean_cka_mock run_cka_mock

output_cka_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cks/"
	@cd $$terragrunt_env_dir && terragrunt run-all output

#####

#CKS task
run_cks_task:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cks/"
	@mkdir $$terragrunt_env_dir -p >/dev/null
	@echo "*** run cks , task ${TASK} terragrunt_env_dir =$$terragrunt_env_dir"
	@cp -r tasks/cks/labs/${TASK}/* $$terragrunt_env_dir
	@export TF_VAR_STACK_TASK=${TASK} ;export TF_VAR_STACK_NAME="cks-task" ; export TF_VAR_USER_ID=${USER_ID} ; export TF_VAR_ENV_ID=${ENV_ID} ; cd $$terragrunt_env_dir && terragrunt run-all  apply

delete_cks_task:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cks/"
	@mkdir $$terragrunt_env_dir -p >/dev/null
	@echo "*** delete cks , task ${TASK} terragrunt_env_dir =$$terragrunt_env_dir"
	cp -r tasks/cks/labs/${TASK}/* $$terragrunt_env_dir
	cd $$terragrunt_env_dir && terragrunt run-all  destroy

clean_cks_task:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cks/"
	@echo "*** clean cks task  terragrunt_env_dir=$$terragrunt_env_dir  "
	@rm -rf $$terragrunt_env_dir/*

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
	@export TF_VAR_STACK_TASK=${TASK} ;export TF_VAR_STACK_NAME="cks-mock" ; export TF_VAR_USER_ID=${USER_ID} ; export TF_VAR_ENV_ID=${ENV_ID} ;cd $$terragrunt_env_dir && terragrunt run-all apply

delete_cks_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cks-mock/"
	@mkdir $$terragrunt_env_dir -p >/dev/null
	@echo "*** delete cks mock terragrunt_env_dir =$$terragrunt_env_dir "
	@export TF_VAR_STACK_TASK=${TASK} ;export TF_VAR_STACK_NAME="cks-mock" ; export TF_VAR_USER_ID=${USER_ID} ; export TF_VAR_ENV_ID=${ENV_ID} ;cd $$terragrunt_env_dir && terragrunt run-all destroy

clean_cks_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cks-mock/"
	@echo "*** clean cks mock terragrunt_env_dir =$$terragrunt_env_dir  "
	@rm -rf $$terragrunt_env_dir/*

run_cks_mock_clean: clean_cks_mock  run_cks_mock

output_cks_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cks-mock/"
	@export TF_VAR_USER_ID=${USER_ID} ; export TF_VAR_ENV_ID=${ENV_ID} ; cd $$terragrunt_env_dir && terragrunt run-all output

#CKAD mock
run_ckad_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}ckad-mock/"
	@mkdir $$terragrunt_env_dir -p >/dev/null
	@echo "*** run ckad mock , task ${TASK} . terragrunt_env_dir =$$terragrunt_env_dir"
	@cp -r tasks/ckad/mock/${TASK}/* $$terragrunt_env_dir
	@export TF_VAR_STACK_TASK=${TASK} ;export TF_VAR_STACK_NAME="ckad-mock"  ; export TF_VAR_USER_ID=${USER_ID} ; export TF_VAR_ENV_ID=${ENV_ID} ; cd $$terragrunt_env_dir   && terragrunt run-all apply

delete_ckad_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}ckad-mock/"
	@mkdir $$terragrunt_env_dir -p >/dev/null
	@echo "*** delete ckad mock task ${TASK} . terragrunt_env_dir =$$terragrunt_env_dir"
	@cp -r tasks/ckad/mock/${TASK}/* $$terragrunt_env_dir
	@export TF_VAR_USER_ID=${USER_ID} ; export TF_VAR_ENV_ID=${ENV_ID} ; cd $$terragrunt_env_dir  && terragrunt run-all destroy

clean_ckad_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}ckad-mock/"
	@echo "*** run clean ckad mock . terragrunt_env_dir =$$terragrunt_env_dir"
	rm -rf $$terragrunt_env_dir

run_ckad_mock_clean: clean_ckad_mock  run_ckad_mock

output_ckad_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}ckad-mock/"
	@cd $$terragrunt_env_dir  && terragrunt run-all output


#HR mock
run_hr_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}hr/"
	@mkdir $$terragrunt_env_dir -p >/dev/null
	@echo "*** run HR mock , task ${TASK} . terragrunt_env_dir =$$terragrunt_env_dir "
	@cp -r tasks/hr/mock/${TASK}/* $$terragrunt_env_dir
	@export TF_VAR_STACK_TASK=${TASK} ;export TF_VAR_STACK_NAME="hr" ; export TF_VAR_USER_ID=${USER_ID} ; export TF_VAR_ENV_ID=${ENV_ID} ;cd $$terragrunt_env_dir && terragrunt run-all apply

delete_hr_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}hr/"
	@mkdir $$terragrunt_env_dir -p >/dev/null
	@echo "*** delete hr mock task ${TASK} . terragrunt_env_dir =$$terragrunt_env_dir "
	@export TF_VAR_USER_ID=${USER_ID} ; export TF_VAR_ENV_ID=${ENV_ID} ;cd $$terragrunt_env_dir  && terragrunt run-all destroy

clean_hr_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}cks-mock/"
	@echo "*** clean hr mock terragrunt_env_dir =$$terragrunt_env_dir "
	@rm -rf $$terragrunt_env_dir/*

run_hr_mock_clean: clean_hr_mock  run_hr_mock

output_hr_mock:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}hr/"
	@export TF_VAR_USER_ID=${USER_ID} ; export TF_VAR_ENV_ID=${ENV_ID} ; cd $$terragrunt_env_dir && terragrunt run-all output



#EKS
run_eks_task:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}eks/"
	@mkdir $$terragrunt_env_dir -p >/dev/null
	@echo "*** run run_eks_task , task ${TASK} . terragrunt_env_dir =$$terragrunt_env_dir"
	@rm -rf $$terragrunt_env_dir/*
	@cp -r tasks/eks/labs/${TASK}/* $$terragrunt_env_dir
	@export TF_VAR_STACK_TASK=${TASK} ;export TF_VAR_STACK_NAME="eks" ; export TF_VAR_USER_ID=${USER_ID} ; export TF_VAR_ENV_ID=${ENV_ID} ;cd $$terragrunt_env_dir && terragrunt run-all apply

delete_eks_task:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}eks/"
	@mkdir $$terragrunt_env_dir -p >/dev/null
	@echo "*** delete delete_eks_task ${TASK} . terragrunt_env_dir =$$terragrunt_env_dir "
	@export TF_VAR_STACK_TASK=${TASK} ;export TF_VAR_STACK_NAME="eks" ; export TF_VAR_USER_ID=${USER_ID} ; export TF_VAR_ENV_ID=${ENV_ID} ;cd $$terragrunt_env_dir && terragrunt run-all destroy

output_eks_task:
	@terragrunt_env_dir="terraform/environments/${prefix_dir}eks/"
	@export TF_VAR_USER_ID=${USER_ID} ; export TF_VAR_ENV_ID=${ENV_ID} ; cd $$terragrunt_env_dir && terragrunt run-all output


#DEV

lint:
	pre-commit run --all-files -c .hooks/.pre-commit-config.yaml

# CMDB
cmdb_get_env_all:
	@aws dynamodb scan  --table-name $(dynamodb_table)  --filter-expression "begins_with(LockID, :lockid)"     --expression-attribute-values '{":lockid":{"S":"CMDB_"}}'     --projection-expression "LockID"     --region $(region) | jq -r '.Items[].LockID.S'
# make cmdb_get_env_all

cmdb_get_user_env_data:
	@aws dynamodb scan  --table-name $(dynamodb_table)  --filter-expression "begins_with(LockID, :lockid)"     --expression-attribute-values '{":lockid":{"S":"CMDB_data_'${USER_ID}'_'${ENV_ID}'"}}'     --projection-expression "LockID"     --region $(region) | jq -r '.Items[].LockID.S'
# USER_ID='myuser' ENV_ID='01' TASK=01 make cmdb_get_user_env_data

cmdb_get_user_env_lock:
	@aws dynamodb scan  --table-name $(dynamodb_table)  --filter-expression "begins_with(LockID, :lockid)"     --expression-attribute-values '{":lockid":{"S":"CMDB_lock_'${USER_ID}'_'${ENV_ID}'"}}'     --projection-expression "LockID"     --region $(region) | jq -r '.Items[].LockID.S'
# only 01 env by user vkfedorov
# USER_ID='myuser' ENV_ID='01' TASK=01 make cmdb_get_user_env_lock

# all envs by user
# USER_ID='myuser' ENV_ID='' TASK=01 make cmdb_get_user_env_lock

cmdb_get_item:
	@aws dynamodb get-item --table-name $(dynamodb_table) --region $(region)  --key '{"LockID": {"S": "'${CMDB_ITEM}'"}}'
# CMDB_ITEM=CMDB_data_myuser_02_k8s_cluster1 make cmdb_get_item