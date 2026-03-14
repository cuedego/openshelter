# OpenShelter

OpenShelter is a cloud-native monitoring platform built around Zabbix and MQTT.

The project is designed to monitor IoT devices and any systems that can publish telemetry through MQTT, while maintaining a resilient and auditable operations model.

## Platform Goals
- Centralize monitoring for MQTT-capable devices and services
- Keep infrastructure reproducible and environment-aware (`dev`, `stg`, `prod`)
- Enforce immutable deployments and GitOps reconciliation
- Apply SRE practices (SLO/SLI, runbooks, incident response)
- Keep secrets out of Git with secure runtime handling

## Core Architecture
- **Monitoring Engine:** Zabbix (containerized workload)
- **Message Ingestion:** MQTT server (containerized workload)
- **Cloud Runtime:** AWS EKS
- **Persistent Data:** AWS RDS PostgreSQL (managed outside Kubernetes)
- **Infrastructure as Code:** Terraform with S3 + DynamoDB remote state
- **Config Management:** Ansible for Zabbix API-driven configuration
- **GitOps Delivery:** Helm + ArgoCD App-of-Apps
- **CI/CD:** GitHub Actions umbrella workflow

## Architecture Diagram
```mermaid
flowchart TB
		subgraph Devices[IoT and MQTT-Capable Systems]
			D1[IoT Devices]
			D2[Other MQTT Publishers]
		end

		D1 -->|MQTT Telemetry| MQ
		D2 -->|MQTT Telemetry| MQ

		subgraph AWS[AWS]
			subgraph EKS[EKS Cluster]
				MQ[MQTT Server]
				ZB[Zabbix]
				AR[ArgoCD]
			end
			RDS[(RDS PostgreSQL)]
			SM[AWS Secrets Manager]
			S3[(S3 Terraform State)]
			DDB[(DynamoDB State Lock)]
		end

		MQ -->|Metrics and Events| ZB
		ZB -->|Persistent Data| RDS
		ZB -.Runtime Secrets.-> SM
		MQ -.Runtime Secrets.-> SM

		subgraph GitHub[GitHub]
			REPO[(OpenShelter Repo)]
			CI[GitHub Actions CI Umbrella]
		end

		CI -->|Validate and Gate| REPO
		REPO -->|GitOps Source| AR
		AR -->|Reconcile Helm Releases| ZB
		AR -->|Reconcile Helm Releases| MQ

		subgraph IaC[IaC and Config]
			TF[Terraform]
			AN[Ansible Zabbix API]
		end

		TF -->|Provision| EKS
		TF -->|Provision| RDS
		TF -->|Remote Backend| S3
		TF -->|State Lock| DDB
		AN -->|Configure Monitoring as Code| ZB
```

	### Legend
	- **IoT and MQTT-Capable Systems:** telemetry producers that publish MQTT messages.
	- **MQTT Server (EKS):** ingestion endpoint for device and system telemetry.
	- **Zabbix (EKS):** monitoring engine for metric/event processing, trigger evaluation, and alert generation.
	- **RDS PostgreSQL:** persistent monitoring data store managed outside Kubernetes.
	- **AWS Secrets Manager:** source of truth for secret values used at runtime.
	- **ArgoCD:** GitOps reconciler that applies desired Kubernetes state from Git.
	- **Helm:** reusable deployment template layer consumed by ArgoCD applications.
	- **Terraform:** infrastructure provisioning layer for AWS resources and state backend.
	- **Ansible (Zabbix API):** monitoring configuration automation as code.
	- **GitHub Actions CI Umbrella:** validation and policy gates before deployment changes are promoted.

	### Data Plane vs Control Plane
	- **Data Plane:** IoT/MQTT telemetry ingestion and monitoring data processing (`IoT devices -> MQTT -> Zabbix -> RDS`).
	- **Control Plane:** provisioning, deployment, policy, and configuration automation (`Terraform`, `ArgoCD`, `Helm`, `Ansible`, and `GitHub Actions`).

## Structure
- `platform/terraform`: bootstrap, modules, and environments
- `platform/gitops`: ArgoCD and Helm
- `config`: centralized global and per-environment configuration
- `apps`: containerized workloads (zabbix and mqtt)
- `ops/ansible`: automation via Zabbix API
- `scripts`: operational scripts (including ArgoCD bootstrap)
- `.github/workflows`: validation and delivery pipelines
- `docs/adr`: architecture decision records
- `docs/sre`: runbooks, SLO/SLI, and operations
- `security/policies`: security baseline

## Principles
1. State outside Kubernetes
2. Workload immutability
3. Secrets outside Git
4. Pull request-based promotion

## Monitoring Flow
1. IoT devices and systems publish telemetry to MQTT topics.
2. MQTT data is consumed by monitoring integrations.
3. Zabbix processes metrics/events and evaluates triggers.
4. Alerts and operational actions follow SRE runbooks and incident workflows.

## GitOps Deployment Model
- ArgoCD reconciles desired state from this repository.
- A root application manages child applications per environment.
- Helm chart templates are shared, while values are environment-specific.
- Environment values are stored in:
	- `platform/gitops/helm/values/dev/openshelter-stack.yaml`
	- `platform/gitops/helm/values/stg/openshelter-stack.yaml`
	- `platform/gitops/helm/values/prod/openshelter-stack.yaml`

## Security Model (Baseline)
- No secrets in source code, Terraform tfvars, or Helm values in Git.
- Preferred secret source: AWS Secrets Manager.
- Kubernetes Secrets are runtime delivery artifacts only.
- Access is controlled with least-privilege IAM/RBAC and audited.

## Quick start
0. Prepare local tooling (Linux): `make bootstrap-linux` (or `SKIP_DOCKER=true make bootstrap-linux` if Docker is managed externally).
1. Set central configuration values in `config/global.env` and `config/env/{dev,stg,prod}.env`.
	- Required in `config/global.env`: `AWS_REGION`, `AWS_ACCOUNT_ID`, `TF_STATE_BUCKET`, `TF_LOCK_TABLE`, `TF_STATE_KEY_PREFIX`.
	- Required in each `config/env/*.env`: `ENV`, `CLUSTER_NAME`, `VPC_CIDR`, `RDS_HOST` (and optional `TF_STATE_KEY`).
2. Configure AWS credentials with least-privilege permissions.
3. Run Terraform backend bootstrap in `platform/terraform/bootstrap`.
4. Inspect loaded config (`make show-config ENV=dev`).
5. Render environment artifacts from central config (`make render-config`) — this generates `backend.hcl` per Terraform environment and updates environment Helm values with `RDS_HOST`.
6. Plan Terraform for one environment (`make terraform-env-plan ENV=dev`).
7. Validate charts and checks (`make validate` and `make config-check`).
8. Bootstrap ArgoCD objects (`make argocd-bootstrap ENV=dev`).

## Quality Gates
- English-only repository policy check
- Terraform formatting and validation (`bootstrap`, `dev`, `stg`, `prod`)
- Helm linting
- Ansible playbook syntax validation
- Config consistency check for legacy region literals (`make config-check`)

## ADRs and Operational Docs
- Architecture decisions are tracked in `docs/adr`.
- Reliability and incident process baselines are tracked in `docs/sre`.
- Security controls and policies are tracked in `security/policies`.

## Status
Foundational scaffolding is in place.

Next iterations include production-grade chart templates, Zabbix API automation expansion, and environment hardening for EKS and RDS.
