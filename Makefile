SHELL := /bin/bash

AWS_REGION  ?= eu-central-1
ECR_REGISTRY ?= # Set to your ECR registry, e.g. 123456789012.dkr.ecr.eu-central-1.amazonaws.com
IMAGE_TAG   ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "local")

.PHONY: fmt validate terraform-bootstrap terraform-dev-plan helm-lint ansible-lint \
        argocd-bootstrap docker-build docker-push docker-build-push ecr-login

fmt:
	@echo "Formatting Terraform files..."
	@terraform fmt -recursive platform/terraform

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

## Docker targets — require Docker daemon and AWS CLI configured locally

ecr-login:
	@aws ecr get-login-password --region $(AWS_REGION) | \
	  docker login --username AWS --password-stdin $(ECR_REGISTRY)

docker-build:
	@echo "Building images with tag $(IMAGE_TAG)..."
	@docker build -t openshelter/zabbix:$(IMAGE_TAG) apps/zabbix
	@docker build -t openshelter/mqtt:$(IMAGE_TAG)   apps/mqtt

docker-push: ecr-login
	@echo "Pushing images to ECR ($(ECR_REGISTRY)) with tag $(IMAGE_TAG)..."
	@docker tag openshelter/zabbix:$(IMAGE_TAG) $(ECR_REGISTRY)/openshelter/zabbix:$(IMAGE_TAG)
	@docker tag openshelter/mqtt:$(IMAGE_TAG)   $(ECR_REGISTRY)/openshelter/mqtt:$(IMAGE_TAG)
	@docker push $(ECR_REGISTRY)/openshelter/zabbix:$(IMAGE_TAG)
	@docker push $(ECR_REGISTRY)/openshelter/mqtt:$(IMAGE_TAG)

docker-build-push: docker-build docker-push
