SHELL := /bin/bash

AWS_REGION   ?= eu-central-1
AWS_ACCOUNT  ?= # Set to your 12-digit AWS account ID
ECR_REGISTRY ?= # Defaults to $(AWS_ACCOUNT).dkr.ecr.$(AWS_REGION).amazonaws.com
IMAGE_TAG    ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "local")

# Cluster bootstrap knobs
CLUSTER_NAME   ?= openshelter-dev
ENV            ?= dev
ESO_IRSA_ROLE_ARN ?= # Set after applying bootstrap Terraform

# Ansible knobs
ZABBIX_URL ?= http://localhost:8080/api_jsonrpc.php

.PHONY: fmt validate \
        terraform-bootstrap terraform-dev-plan \
        helm-lint ansible-lint ansible-syntax \
        eks-kubeconfig cluster-bootstrap install-argocd install-eso argocd-bootstrap \
        ecr-login docker-build docker-push docker-build-push

fmt:
	@echo "Formatting Terraform files..."
	@terraform fmt -recursive platform/terraform

validate:
	@echo "Validating Terraform and Helm scaffolding..."
	@terraform -chdir=platform/terraform/bootstrap init -backend=false
	@terraform -chdir=platform/terraform/bootstrap validate
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
## Usage: make cluster-bootstrap ENV=dev ESO_IRSA_ROLE_ARN=arn:aws:iam::...
cluster-bootstrap:
	@ENV=$(ENV) AWS_REGION=$(AWS_REGION) \
	 ESO_IRSA_ROLE_ARN=$(ESO_IRSA_ROLE_ARN) \
	 bash scripts/argocd-bootstrap.sh

## Alias kept for backward compatibility
argocd-bootstrap: cluster-bootstrap

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
