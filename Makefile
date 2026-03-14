SHELL := /bin/bash

.PHONY: fmt validate terraform-bootstrap terraform-dev-plan helm-lint ansible-lint argocd-bootstrap

fmt:
	@echo "Formatting Terraform files..."
	@terraform -chdir=platform/terraform/bootstrap fmt -recursive
	@terraform -chdir=platform/terraform/envs/dev fmt -recursive
	@terraform -chdir=platform/terraform/envs/stg fmt -recursive
	@terraform -chdir=platform/terraform/envs/prod fmt -recursive

validate:
	@echo "Validating Terraform and Helm scaffolding..."
	@terraform -chdir=platform/terraform/envs/dev init -backend=false
	@terraform -chdir=platform/terraform/envs/dev validate
	@terraform -chdir=platform/terraform/envs/stg init -backend=false
	@terraform -chdir=platform/terraform/envs/stg validate
	@terraform -chdir=platform/terraform/envs/prod init -backend=false
	@terraform -chdir=platform/terraform/envs/prod validate
	@helm lint platform/gitops/helm/charts/openshelter-stack

terraform-bootstrap:
	@terraform -chdir=platform/terraform/bootstrap init
	@terraform -chdir=platform/terraform/bootstrap plan

terraform-dev-plan:
	@terraform -chdir=platform/terraform/envs/dev init
	@terraform -chdir=platform/terraform/envs/dev plan

helm-lint:
	@helm lint platform/gitops/helm/charts/openshelter-stack

ansible-lint:
	@cd ops/ansible && ansible-playbook --syntax-check playbooks/zabbix-config.yml

argocd-bootstrap:
	@bash scripts/argocd-bootstrap.sh
