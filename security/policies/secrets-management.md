# Secrets Management Policy

## Principles
- Never commit secrets to Git
- Prefer AWS Secrets Manager for long-lived application secrets
- Use Kubernetes Secrets only for runtime injection needs
- Rotate credentials on a defined schedule and on incident trigger

## Approved Secret Stores
- AWS Secrets Manager (primary)
- Kubernetes Secrets (runtime distribution only)

## Prohibited Patterns
- Plaintext secrets in Terraform variables files
- Secrets in Helm values files tracked in Git
- Secrets in Ansible playbooks or defaults
- Hardcoded credentials in source code or scripts

## Operational Controls
- Enable secret access audit trails
- Restrict read access by least privilege IAM roles
- Use short-lived credentials when feasible
- Define emergency rotation runbook

## CI Requirements
- Repository must pass secret scanning and language/security checks
- Pull requests that expose secret-like values must be blocked
