# Runbook Template

## Metadata
- Service:
- Owner Team:
- Last Reviewed:
- Related Dashboard:
- Related Alerts:

## Purpose
Describe what this runbook solves and when to use it.

## Preconditions
- Required access
- Required tools
- Safety checks
- Confirm `config/global.env` and `config/env/<env>.env` are updated
- Run `make render-config` and `make show-config ENV=<env>`

## Triage Steps
1. Confirm symptom and blast radius
2. Check dashboards and logs
3. Validate dependent services

## Mitigation Steps
1.
2.
3.

## Validation Steps
- Verify recovery indicators
- Verify user-facing behavior
- Confirm alert cleared

## Rollback Strategy
Describe rollback and recovery options.

## Command Bundle (Optional, Copy/Paste)

### Triage + Validate (dev)
```bash
cd /home/cuedego/openshelter
make show-config ENV=dev
make render-config
make config-check
make validate
make terraform-env-plan ENV=dev
```

### Triage + Validate (stg)
```bash
cd /home/cuedego/openshelter
make show-config ENV=stg
make render-config
make config-check
make validate
make terraform-env-plan ENV=stg
```

### Triage + Validate (prod)
```bash
cd /home/cuedego/openshelter
make show-config ENV=prod
make render-config
make config-check
make validate
make terraform-env-plan ENV=prod
```

### Re-bootstrap (if incident involves ArgoCD/ESO)
```bash
cd /home/cuedego/openshelter
make cluster-bootstrap ENV=<dev|stg|prod> ESO_IRSA_ROLE_ARN=<arn>
```

### Fast rollback to last known good commit
```bash
cd /home/cuedego/openshelter
git log --oneline -n 20
git revert <bad_commit_hash>
make render-config
make config-check
make terraform-env-plan ENV=<dev|stg|prod>
```

## Escalation
- Primary on-call:
- Secondary on-call:
- Escalation threshold:

## References
- Related incidents:
- Architecture docs:
- Terraform/Helm/Ansible paths:
- Validation commands (`make validate`, `make config-check`):
- Deployment commands (`make terraform-env-plan ENV=<env>`, `make cluster-bootstrap ENV=<env>`):
