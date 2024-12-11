TF_CMD := terraform
TF_DIR_BASE := ./terraform
TF_DIR_AWS := $(TF_DIR_BASE)/aws
TF_DIR_K8S := $(TF_DIR_BASE)/k8s
TF_VARS_DIR :=  ../../vars
TF_VARS_BACKEND := $(TF_VARS_DIR)/backend.tfvars
TF_VARS_ARGS := -var-file $(TF_VARS_DIR)/env.tfvars -var-file $(TF_VARS_BACKEND)
TF_BACKEND_ARGS := -backend-config $(TF_VARS_BACKEND)

.PHONY: tf-init-aws
tf-init-aws: ## Initialize terraform (AWS)
	$(TF_CMD) -chdir=$(TF_DIR_AWS) init -reconfigure -upgrade $(TF_BACKEND_ARGS)

.PHONY: tf-apply-aws
tf-apply-aws: tf-init-aws ## Apply terraform (AWS)
	$(TF_CMD) -chdir=$(TF_DIR_AWS) apply $(TF_VARS_ARGS)

.PHONY: tf-destroy-aws
tf-destroy-aws: tf-init-aws ## Destroy terraform (AWS)
	$(TF_CMD) -chdir=$(TF_DIR_AWS) destroy $(TF_VARS_ARGS)

.PHONY: tf-init-k8s
tf-init-k8s: ## Initialize terraform (Kubernetes)
	$(TF_CMD) -chdir=$(TF_DIR_K8S) init -reconfigure -upgrade $(TF_BACKEND_ARGS)

.PHONY: tf-apply-aws
tf-apply-k8s: tf-init-k8s ## Apply terraforKuber (Kubernetes)
	$(TF_CMD) -chdir=$(TF_DIR_K8S) apply $(TF_VARS_ARGS)

.PHONY: help
.DEFAULT_GOAL := help
help: ## HELP表示 
	@grep --no-filename -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'