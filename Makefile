SHELL := /bin/bash

ENV ?= dev

# Central config (single source of truth)
-include config/global.env
-include config/local.env
-include config/env/$(ENV).env

AWS_REGION   ?=
AWS_ACCOUNT_ID ?= # Set locally in config/local.env or export in shell
ifeq ($(strip $(AWS_ACCOUNT_ID)),)
AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
endif
ECR_REGISTRY ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
IMAGE_TAG    ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "local")

# Cluster bootstrap knobs
CLUSTER_NAME   ?= openshelter-$(ENV)
ESO_IRSA_ROLE_ARN ?= # Set after applying bootstrap Terraform
ALB_CONTROLLER_IRSA_ROLE_ARN ?= # Set after applying env Terraform: terraform output -raw alb_controller_irsa_role_arn

# Ansible knobs
ZABBIX_URL ?= http://localhost:8080/api_jsonrpc.php

.PHONY: fmt validate \
	terraform-bootstrap terraform-shared-plan terraform-access-plan terraform-dev-plan terraform-env-plan \
        helm-lint ansible-lint ansible-syntax \
        eks-kubeconfig cluster-bootstrap bootstrap-e2e install-argocd install-eso argocd-bootstrap \
	ecr-login docker-build docker-push docker-build-push \
	config-check show-config render-config bootstrap-linux

fmt:
	@echo "Formatting Terraform files..."
	@terraform fmt -recursive platform/terraform

validate:
	@echo "Validating Terraform and Helm scaffolding..."
	@terraform -chdir=platform/terraform/bootstrap init -backend=false
	@terraform -chdir=platform/terraform/bootstrap validate
	@terraform -chdir=platform/terraform/shared init -backend=false
	@terraform -chdir=platform/terraform/shared validate
	@terraform -chdir=platform/terraform/access init -backend=false
	@terraform -chdir=platform/terraform/access validate
	@terraform -chdir=platform/terraform/envs/dev init -backend=false
	@terraform -chdir=platform/terraform/envs/dev validate
	@terraform -chdir=platform/terraform/envs/stg init -backend=false
	@terraform -chdir=platform/terraform/envs/stg validate
	@terraform -chdir=platform/terraform/envs/prod init -backend=false
	@terraform -chdir=platform/terraform/envs/prod validate
	@helm lint platform/gitops/helm/charts/openshelter-stack

show-config:
	@echo "ENV=$(ENV)"
	@echo "AWS_REGION=$(AWS_REGION)"
	@echo "CLUSTER_NAME=$(CLUSTER_NAME)"
	@echo "ECR_REGISTRY=$(ECR_REGISTRY)"

config-check:
	@echo "Checking for legacy region references (us-east-1)..."
	@! grep -RIn "us-east-1" . --exclude-dir=.git --exclude-dir=.terraform --exclude=Makefile

render-config:
	@bash scripts/render-config.sh

bootstrap-linux:
	@bash scripts/bootstrap-linux.sh

terraform-bootstrap:
	@test -n "$(AWS_REGION)" || (echo "AWS_REGION is empty. Configure config/global.env" && exit 1)
	@terraform -chdir=platform/terraform/bootstrap init
	@terraform -chdir=platform/terraform/bootstrap plan

terraform-shared-plan:
	@bash scripts/render-config.sh
	@test -n "$(AWS_REGION)" || (echo "AWS_REGION is empty. Configure config/global.env" && exit 1)
	@terraform -chdir=platform/terraform/shared init -backend-config=backend.hcl
	@terraform -chdir=platform/terraform/shared plan -var="region=$(AWS_REGION)"

terraform-access-plan:
	@bash scripts/render-config.sh
	@test -n "$(AWS_REGION)" || (echo "AWS_REGION is empty. Configure config/global.env" && exit 1)
	@test -n "$(BOOTSTRAP_ROLE_ARN)" || (echo "BOOTSTRAP_ROLE_ARN is empty. Configure config/local.env" && exit 1)
	@terraform -chdir=platform/terraform/access init -backend-config=backend.hcl
	@terraform -chdir=platform/terraform/access plan -var="region=$(AWS_REGION)" -var="bootstrap_role_arn=$(BOOTSTRAP_ROLE_ARN)"

terraform-dev-plan:
	@bash scripts/render-config.sh
	@test -n "$(AWS_REGION)" || (echo "AWS_REGION is empty. Configure config/global.env" && exit 1)
	@test -n "$(BOOTSTRAP_ROLE_ARN)" || (echo "BOOTSTRAP_ROLE_ARN is empty. Configure config/local.env" && exit 1)
	@terraform -chdir=platform/terraform/envs/dev init -backend-config=backend.hcl
	@terraform -chdir=platform/terraform/envs/dev plan -var="github_bootstrap_role_arn=$(BOOTSTRAP_ROLE_ARN)"

terraform-env-plan:
	@bash scripts/render-config.sh
	@test -n "$(AWS_REGION)" || (echo "AWS_REGION is empty. Configure config/global.env" && exit 1)
	@test -n "$(BOOTSTRAP_ROLE_ARN)" || (echo "BOOTSTRAP_ROLE_ARN is empty. Configure config/local.env" && exit 1)
	@terraform -chdir=platform/terraform/envs/$(ENV) init -backend-config=backend.hcl
	@terraform -chdir=platform/terraform/envs/$(ENV) plan -var="github_bootstrap_role_arn=$(BOOTSTRAP_ROLE_ARN)"

helm-lint:
	@helm lint platform/gitops/helm/charts/openshelter-stack

ansible-lint: ansible-syntax

ansible-syntax:
	@cd ops/ansible && ansible-playbook --syntax-check playbooks/zabbix-config.yml

## Install Ansible Galaxy collections defined in requirements.yml
ansible-install-deps:
	@ansible-galaxy collection install -r ops/ansible/requirements.yml

## Run Zabbix API configuration. Requires:
##   ZABBIX_URL=http://<lb-dns>/api_jsonrpc.php
##   OPENSHELTER_ENV=dev|stg|prod
##   AWS credentials in environment (e.g. via aws-vault or IAM role)
## Usage: make ansible-run OPENSHELTER_ENV=dev ZABBIX_URL=http://...
ansible-run:
	@cd ops/ansible && OPENSHELTER_ENV=$(ENV) ZABBIX_URL=$(ZABBIX_URL) \
	  ansible-playbook playbooks/zabbix-config.yml -i inventories/$(ENV)/hosts.yml

## ──────────────────────────────────────────────────────────────────────
## Cluster bootstrap
## ──────────────────────────────────────────────────────────────────────

## Update local kubeconfig from EKS. Usage: make eks-kubeconfig CLUSTER_NAME=openshelter-dev ENV=dev
eks-kubeconfig:
	@aws eks update-kubeconfig \
	  --region $(AWS_REGION) \
	  --name $(CLUSTER_NAME) \
	  --alias $(ENV)

## Install ArgoCD only (Helm).
install-argocd:
	@SKIP_ESO=true bash scripts/argocd-bootstrap.sh

## Install External Secrets Operator only (Helm).
install-eso:
	@SKIP_ARGOCD=true bash scripts/argocd-bootstrap.sh

## Full bootstrap: ArgoCD + ESO + ClusterSecretStore + App-of-Apps.
## Usage: make cluster-bootstrap ENV=dev ESO_IRSA_ROLE_ARN=arn:... ALB_CONTROLLER_IRSA_ROLE_ARN=arn:... [APP_SCOPE=env|root]
cluster-bootstrap:
	@ENV=$(ENV) AWS_REGION=$(AWS_REGION) \
	 CLUSTER_NAME=$(CLUSTER_NAME) \
	 ESO_IRSA_ROLE_ARN=$(ESO_IRSA_ROLE_ARN) \
	 ALB_CONTROLLER_IRSA_ROLE_ARN=$(ALB_CONTROLLER_IRSA_ROLE_ARN) \
	 APP_SCOPE=$${APP_SCOPE:-env} \
	 bash scripts/argocd-bootstrap.sh

## Alias kept for backward compatibility
argocd-bootstrap: cluster-bootstrap

## End-to-end bootstrap: render-config + terraform apply + kubeconfig + env-scoped argocd bootstrap + health checks
## Usage:
##   make bootstrap-e2e ENV=stg FIRST_APPLY=true
##   make bootstrap-e2e ENV=prod FIRST_APPLY=false
bootstrap-e2e:
	@ENV=$(ENV) FIRST_APPLY=$${FIRST_APPLY:-false} bash scripts/bootstrap-e2e.sh

## ──────────────────────────────────────────────────────────────────────
## Docker targets — require Docker daemon and AWS CLI configured locally
## ──────────────────────────────────────────────────────────────────────

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
