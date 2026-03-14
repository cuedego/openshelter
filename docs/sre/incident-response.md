# Incident Response

## Severity Levels
- SEV1: Customer-facing outage or major data risk
- SEV2: Partial degradation with significant impact
- SEV3: Minor degradation with workaround available
- SEV4: Low-risk issue with no immediate customer impact

## Roles
- Incident Commander (IC): coordinates response and priorities
- Communications Lead: updates stakeholders and status
- Operations Lead: executes mitigations
- Subject Matter Expert: supports root-cause analysis

## Response Workflow
1. Detect and acknowledge alert
2. Classify severity and open incident channel
3. Stabilize service (mitigation first)
4. Communicate updates every 15-30 minutes (SEV1/SEV2)
5. Recover, validate, and close incident
6. Start postmortem within 48 hours for SEV1/SEV2

## Configuration Change Failure Playbook
Use this playbook for failed Terraform/GitOps/config changes.

1. Freeze additional changes (stop merges/deploys for affected environment).
2. Confirm effective environment config and detect drift:
	- `make show-config ENV=<dev|stg|prod>`
	- `make render-config`
	- `make config-check`
3. Validate infra/chart state before retry:
	- `make validate`
	- `make terraform-env-plan ENV=<dev|stg|prod>`
4. If plan/output is unsafe, rollback to last known-good Git commit and re-run render/validate.
5. If cluster bootstrap is involved, re-run only after config and plan are clean:
	- `make cluster-bootstrap ENV=<dev|stg|prod> ESO_IRSA_ROLE_ARN=<arn>`
6. Verify recovery:
	- ArgoCD applications healthy/synced
	- Monitoring and alerting stable
	- No failing CI checks related to Terraform/Helm/Ansible

## Rollback Guidelines
- Prefer Git revert over manual in-cluster/manual-console drift.
- Roll back one environment at a time (`dev` -> `stg` -> `prod`).
- Keep incident timeline updated with exact commit hash and command outputs.
- Open follow-up tasks for any manual emergency action performed during mitigation.

## Escalation
- Auto-escalate to on-call SRE after 10 minutes unacknowledged
- Escalate to Platform lead for infra-impacting SEV1/SEV2
- Escalate to Security lead for suspected security incidents

## Postmortem Requirements
- Timeline with UTC timestamps
- Root cause and contributing factors
- Corrective and preventive actions with owners and due dates
- Follow-up tracking in backlog with status visibility
- Explicit note whether centralized config (`config/global.env`, `config/env/*`) contributed to or prevented the incident

## Command Bundle (Copy/Paste)

### 1) Triage + Validate (`dev`)
```bash
cd /home/cuedego/openshelter
make show-config ENV=dev
make render-config
make config-check
make validate
make terraform-env-plan ENV=dev
```

### 2) Triage + Validate (`stg`)
```bash
cd /home/cuedego/openshelter
make show-config ENV=stg
make render-config
make config-check
make validate
make terraform-env-plan ENV=stg
```

### 3) Triage + Validate (`prod`)
```bash
cd /home/cuedego/openshelter
make show-config ENV=prod
make render-config
make config-check
make validate
make terraform-env-plan ENV=prod
```

### 4) Re-bootstrap (if incident involves ArgoCD/ESO bootstrap)
```bash
cd /home/cuedego/openshelter
make cluster-bootstrap ENV=<dev|stg|prod> ESO_IRSA_ROLE_ARN=<arn>
```

### 5) Fast rollback to last known good commit
```bash
cd /home/cuedego/openshelter
git log --oneline -n 20
git revert <bad_commit_hash>
make render-config
make config-check
make terraform-env-plan ENV=<dev|stg|prod>
```
