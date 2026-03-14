# ADR 0001: Repository Architecture Baseline

- Status: Accepted
- Date: 2026-03-14
- Owners: Platform Team, SRE Team
- Related: CI Umbrella workflow, Terraform scaffolding, GitOps scaffolding

## Context
OpenShelter requires a cloud-native platform with clear ownership boundaries, immutable workload deployment, infrastructure-as-code, and operational reliability guardrails from day one.

The repository must support:
- AWS infrastructure lifecycle through Terraform
- Kubernetes application delivery via Helm and ArgoCD
- Monitoring configuration management through Ansible and API-driven workflows
- CI/CD as a single source of truth using GitHub Actions
- Security policy that keeps secrets out of Git

## Decision
Adopt a mono-repository structure with domain-oriented top-level directories:
- `platform/terraform` for cloud infrastructure and environment stacks
- `platform/gitops` for ArgoCD and Helm delivery definitions
- `ops/ansible` for Zabbix API-oriented configuration management
- `.github/workflows` for CI/CD automation and quality gates
- `docs/sre` and `security/policies` for operational and security baseline

Apply an umbrella CI workflow to run language policy checks, Terraform formatting/validation, Helm lint, and Ansible syntax checks on pull requests and main branch pushes.

## Alternatives Considered
- Multi-repository split by function (infra/app/ops)
  - Rejected due to higher coordination overhead and weaker change traceability.
- Separate CI workflows per tool only
  - Rejected because governance and branch protection are simpler with one umbrella workflow.

## Consequences
### Positive
- Clear ownership boundaries and reduced onboarding ambiguity
- Single CI gate for architecture and quality controls
- Better auditability for security and reliability practices

### Negative / Trade-offs
- Mono-repo requires disciplined review boundaries and CODEOWNERS usage
- Umbrella pipeline can grow in runtime as checks expand

## Implementation Notes
- Keep environment parity across `dev`, `stg`, and `prod` Terraform stacks
- Evolve Helm and Ansible placeholders into production-grade definitions incrementally
- Add ADRs for key future decisions (network topology, secret rotation strategy, observability stack)

## Security and Reliability Considerations
- Secrets must remain outside Git; use AWS Secrets Manager and runtime injection patterns
- Reliability controls should include SLO/SLI tracking and incident/postmortem routines

## Rollback / Exit Strategy
If the mono-repo model becomes a bottleneck, split by capability domain while preserving ADR history and CI policy parity across repositories.
