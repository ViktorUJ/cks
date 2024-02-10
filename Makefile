.ONESHELL:

prefix_dir="${USER_ID}_${ENV_ID}_"
region := $(shell grep 'backend_region' terraform/environments/terragrunt.hcl |grep -v 'local.'| awk -F '"' '{print $$2}')
backend_bucket := $(shell grep '^  backend_bucket' terraform/environments/terragrunt.hcl | awk -F '=' '{gsub(/ /, "", $$2); print $$2}' | tr -d '"')
dynamodb_table := $(backend_bucket)-lock
base_dir := $(shell pwd)
BASE_PATH := $(shell pwd)
VENV_PATH := $(BASE_PATH)/venv
VENV_BIN_PATH := $(VENV_PATH)/bin/

# Set prefix_dir to empty if it contains '__'
ifneq ($(findstring __,$(prefix_dir)),)
  # If '__' is found, set prefix_dir to an empty string
  prefix_dir :=
endif

# family_tasks{cka,cks,ckad,eks}, type{mock,task},command{run,delete,output},type_run{clean,or  empty}
define terragrint_run
    @case "$(2)" in
        mock)
            @run_type="mock"
            ;;
        task)
            @run_type="labs"
            ;;
    esac
	@terragrunt_env_dir="$(base_dir)/terraform/environments/${prefix_dir}$(1)-$$run_type"
	@echo "base_dir = $(base_dir)"
	@echo "**** terragrunt_env_dir = $$terragrunt_env_dir"
    @case "$(3)" in
        run)
            @commnand="terragrunt run-all  apply"
            ;;
        delete)
            @commnand="terragrunt run-all  destroy"
            ;;
        output)
            @commnand="terragrunt run-all  output"
            ;;
    esac

    @case "$(4)" in
        clean)
        	@echo "*** clean $$terragrunt_env_dir/*"
            @rm -rf $$terragrunt_env_dir/*
            ;;
    esac

	@echo "terragrunt_env_dir= $$terragrunt_env_dir command= $$commnand"
	@mkdir $$terragrunt_env_dir -p >/dev/null
	@cp -r $(base_dir)/tasks/$(1)/$$run_type/${TASK}/* $$terragrunt_env_dir
	@export TF_VAR_STACK_TASK=${TASK} ;export TF_VAR_STACK_NAME="$(1)-$$run_type"; export TF_VAR_USER_ID=${USER_ID} ; export TF_VAR_ENV_ID=${ENV_ID} ; cd $$terragrunt_env_dir && $$commnand
    @case "$(3)" in
        delete)
            @rm -rf $$terragrunt_env_dir
            ;;
    esac
endef


# CKA task
run_cka_task:
	$(call terragrint_run,cka,task,run)

delete_cka_task:
	$(call terragrint_run,cka,task,delete)


run_cka_task_clean:
	$(call terragrint_run,cka,task,run,clean)

delete_cka_task_clean:
	$(call terragrint_run,cka,task,delete,clean)

output_cka_task:
	$(call terragrint_run,cka,task,output)


#CKA mock
run_cka_mock:
	$(call terragrint_run,cka,mock,run)

delete_cka_mock:
	$(call terragrint_run,cka,mock,delete)

run_cka_mock_clean:
	$(call terragrint_run,cka,mock,run,clean)

delete_cka_mock_clean:
	$(call terragrint_run,cka,mock,delete,clean)

output_cka_mock:
	$(call terragrint_run,cka,mock,output)

#####

#CKS task
run_cks_task:
	$(call terragrint_run,cks,task,run)
delete_cks_task:
	$(call terragrint_run,cks,task,delete)

run_cks_task_clean:
	$(call terragrint_run,cks,task,run,clean)

delete_cks_task_clean:
	$(call terragrint_run,cks,task,delete,clean)

output_cks_task:
	$(call terragrint_run,cks,task,output)

#CKS mock
run_cks_mock:
	$(call terragrint_run,cks,mock,run)

delete_cks_mock:
	$(call terragrint_run,cks,mock,delete)

run_cks_mock_clean:
	$(call terragrint_run,cks,mock,run,clean)

delete_cks_mock_clean:
	$(call terragrint_run,cks,mock,delete,clean)

output_cks_mock:
	$(call terragrint_run,cks,mock,output)

#CKAD mock
run_ckad_mock:
	$(call terragrint_run,ckad,mock,run)
delete_ckad_mock:
	$(call terragrint_run,ckad,mock,delete)

run_ckad_mock_clean:
	$(call terragrint_run,ckad,mock,run,clean)

delete_ckad_mock_clean:
	$(call terragrint_run,ckad,mock,delete,clean)

output_ckad_mock:
	$(call terragrint_run,ckad,mock,output)

#LFCS mock
run_lfcs_mock:
	$(call terragrint_run,lfcs,mock,run)
delete_lfcs_mock:
	$(call terragrint_run,lfcs,mock,delete)

run_lfcs_mock_clean:
	$(call terragrint_run,lfcs,mock,run,clean)

delete_lfcs_mock_clean:
	$(call terragrint_run,lfcs,mock,delete,clean)

output_lfcs_mock:
	$(call terragrint_run,lfcs,mock,output)


#HR mock
run_hr_mock:
	$(call terragrint_run,hr,mock,run)

delete_hr_mock:
	$(call terragrint_run,hr,mock,delete)

run_hr_mock_clean:
	$(call terragrint_run,hr,mock,run,clean)

delete_hr_mock_clean:
	$(call terragrint_run,hr,mock,delete,clean)

output_hr_mock:
	$(call terragrint_run,hr,mock,output)



#EKS
run_eks_task:
	$(call terragrint_run,eks,task,run)
delete_eks_task:
	$(call terragrint_run,eks,task,delete)

run_eks_task_clean:
	$(call terragrint_run,eks,task,run,clean)

delete_eks_task_clean:
	$(call terragrint_run,eks,task,delete,clean)

output_eks_task:
	$(call terragrint_run,eks,task,output)

#DEV

lint:
	pre-commit run --all-files -c .hooks/.pre-commit-config.yaml

lint_go:
	cd docker/ping_pong/app ; go fmt ./... ; cd $(base_dir)

install_git_hooks:
	$(VENV_BIN_PATH)/pre-commit install
	@echo 'Pre-commit hooks installed'

venv:
	virtualenv -p python3 -q $(VENV_PATH)
	$(VENV_BIN_PATH)/pip install --default-timeout 60 -r .hooks/requirements.txt
	@echo 'Virtualenv created'

clean:
	@rm -fr $(VENV_PATH)
	@echo 'Removed virtualenv'

dev: venv install_git_hooks


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
