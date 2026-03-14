# ADR 0002: Secrets Management Strategy

- Status: Accepted
- Date: 2026-03-14
- Owners: Security Team, Platform Team, SRE Team
- Related: `security/policies/secrets-management.md`, ADR 0001

## Context
OpenShelter operates across Terraform-managed AWS infrastructure and Kubernetes workloads delivered by GitOps. The platform must prevent secret exposure in Git, support auditable access, and enable safe credential rotation without disrupting deployments.

The architecture includes:
- Terraform for AWS resources including state backend
- Helm and ArgoCD for Kubernetes deployment
- Ansible for API-driven Zabbix configuration
- CI/CD pipelines in GitHub Actions

This requires a consistent secret handling model across infrastructure, application runtime, and automation workflows.

## Decision
Adopt AWS Secrets Manager as the primary secret source of truth and allow Kubernetes Secrets only as runtime delivery artifacts.

Decision details:
- Secrets are never committed to Git repositories.
- Terraform receives sensitive values from secure runtime inputs (CI secrets, environment injection, or approved secret retrieval flows), not plaintext files.
- Helm values tracked in Git must not contain secret material.
- Kubernetes Secrets may exist only for runtime consumption and are populated from approved secret sources.
- Ansible playbooks and role defaults must not contain plaintext credentials.
- Access to secrets follows least privilege IAM/RBAC and must be auditable.

## Alternatives Considered
- Store encrypted secrets in Git (for example via repo-level encryption tooling)
  - Rejected to keep policy and operational complexity lower in the initial baseline and avoid repository coupling to encrypted payload lifecycle.
- Use Kubernetes Secrets as the primary long-term secret store
  - Rejected because platform scope extends beyond Kubernetes and requires stronger centralized audit and rotation controls across AWS services.
- Keep manual secret distribution per environment
  - Rejected due to high operational risk, poor traceability, and inconsistent rotation practices.

## Consequences
### Positive
- Centralized secret governance with AWS-native auditability
- Reduced risk of secret leakage in source control
- Clear separation between secret source (Secrets Manager) and runtime materialization (Kubernetes Secrets)
- Better support for automated rotation and incident response

### Negative / Trade-offs
- Additional integration work is required for secret injection into workloads and automation tools
- Team workflows must include strict handling for local development and testing credentials
- Secret access outages can affect deployment or runtime paths if fallback strategies are not defined

## Implementation Notes
- Define naming conventions for secrets by environment and service.
- Add least-privilege IAM policies for workload/service identities.
- Implement runtime secret injection mechanism for Kubernetes workloads.
- Ensure CI jobs consume secrets through secure runner context only.
- Add runbooks for secret rotation and compromised credential response.

## Security and Reliability Considerations
- Security:
  - Enforce no-secret-in-Git policy with CI checks and review gates.
  - Log and monitor secret access events.
- Reliability:
  - Validate application behavior during secret rotation.
  - Define retry/backoff and failure behavior when secret retrieval fails.

## Rollback / Exit Strategy
If AWS Secrets Manager cannot satisfy future requirements, evaluate a centralized alternative secret platform with equivalent auditability, access control, and rotation capabilities. Migration must preserve no-secret-in-Git guarantees and include dual-read cutover during transition.
