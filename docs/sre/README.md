# SRE Documentation Baseline

This folder defines the operational baseline for OpenShelter.

## Scope
- Reliability objectives and error budgets
- Incident response and communication
- Runbook structure and ownership
- On-call expectations and escalation
- Operational readiness checks before infra and GitOps changes

## Document Index
- `slos-and-slis.md`
- `incident-response.md`
- `runbook-template.md`

## Operational Entry Points
- Central configuration source: `config/global.env` and `config/env/{dev,stg,prod}.env`
- Render runtime artifacts: `make render-config`
- Inspect effective settings: `make show-config ENV=<dev|stg|prod>`
- Validate platform baseline: `make validate`
- Config consistency check: `make config-check`
- Environment plan: `make terraform-env-plan ENV=<dev|stg|prod>`
- Cluster bootstrap: `make cluster-bootstrap ENV=<dev|stg|prod> ESO_IRSA_ROLE_ARN=<arn>`

## SRE Change Checklist
1. Update central config (`config/global.env` and matching `config/env/*.env`).
2. Render artifacts and verify generated backend settings (`make render-config`).
3. Run validations (`make validate` and `make config-check`).
4. Execute environment-specific Terraform plan (`make terraform-env-plan ENV=<env>`).
5. Apply change windows, run bootstrap/reconciliation, and monitor recovery signals.

## Ownership
- Primary: SRE team
- Contributors: Platform, Operations, Security

## Review Cadence
- Monthly review for SLO and alert tuning
- Quarterly review for incident process and runbooks
