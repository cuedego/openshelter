# OpenShelter

Resilient Cloud Native infrastructure following SRE practices.

## Stack
- AWS: EKS, RDS PostgreSQL
- IaC: Terraform with remote backend (S3 + DynamoDB)
- Config Management: Ansible (Zabbix API)
- GitOps: Helm + ArgoCD
- CI/CD: GitHub Actions (single point of truth)

## Structure
- `platform/terraform`: bootstrap, modules, and environments
- `platform/gitops`: ArgoCD and Helm
- `apps`: containerized workloads (zabbix and mqtt)
- `ops/ansible`: automation via Zabbix API
- `.github/workflows`: validation and delivery pipelines
- `docs/sre`: runbooks, SLO/SLI, and operations
- `security/policies`: security baseline

## Principles
1. State outside Kubernetes
2. Workload immutability
3. Secrets outside Git
4. Pull request-based promotion

## Quick start
1. Configure AWS credentials with least-privilege permissions.
2. Run Terraform backend bootstrap in `platform/terraform/bootstrap`.
3. Plan/apply the environment in `platform/terraform/envs/dev`.
4. Validate Helm charts and ArgoCD manifests.

## Status
Initial scaffolding created. Resources and pipelines will be incrementally expanded.
