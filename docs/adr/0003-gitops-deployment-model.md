# ADR 0003: GitOps Deployment Model (ArgoCD App-of-Apps + Helm Values per Environment)

- Status: Accepted
- Date: 2026-03-14
- Owners: Platform Team, SRE Team
- Related: ADR 0001, ADR 0002, `platform/gitops/argocd`, `platform/gitops/helm`

## Context
OpenShelter needs a deployment model that is auditable, reproducible, and aligned with SRE and security requirements. The platform spans multiple environments (`dev`, `stg`, `prod`) and requires clear promotion rules, separation of configuration by environment, and operational rollback safety.

Current constraints:
- Infrastructure is managed separately via Terraform.
- Application workloads are deployed to EKS.
- Secrets must remain outside Git.
- CI/CD in GitHub Actions is the single source of truth for validation gates.

## Decision
Adopt ArgoCD App-of-Apps as the GitOps orchestration model and Helm as the packaging mechanism, with environment-specific values files.

Decision details:
- Use ArgoCD as the continuous reconciliation engine from Git to cluster state.
- Use an App-of-Apps root application to manage child application definitions.
- Keep reusable workload templates in Helm charts.
- Store non-secret environment configuration in values files per environment.
- Promote changes through pull requests from `dev` to `stg` to `prod`.
- Keep secret material out of Helm values files and Git history.

## Alternatives Considered
- Plain Kubernetes manifests without Helm
  - Rejected due to template duplication and weaker reusability across environments.
- Separate ArgoCD applications managed manually per service
  - Rejected due to operational overhead and inconsistent governance.
- CI-only push-based deployment without GitOps reconciliation
  - Rejected because drift detection and desired-state convergence are weaker.

## Consequences
### Positive
- Strong auditability through Git history and ArgoCD sync status
- Clear promotion path across environments with PR-based controls
- Reduced configuration drift via continuous reconciliation
- Reusable chart structure with environment-specific overlays

### Negative / Trade-offs
- Additional complexity in chart design and values layering
- Need strict review discipline to avoid unsafe production values changes
- ArgoCD availability becomes operationally critical for deployment flow

## Implementation Notes
- Maintain this structure:
  - `platform/gitops/argocd/projects`
  - `platform/gitops/argocd/apps`
  - `platform/gitops/helm/charts`
  - `platform/gitops/helm/values/{dev,stg,prod}`
- Add AppProject boundaries to enforce namespace/repo scoping.
- Add sync policies with controlled automation and health checks.
- Standardize chart values keys across environments.

## Security and Reliability Considerations
- Security:
  - No secrets in Helm values tracked in Git.
  - Enforce branch protection and CODEOWNERS on GitOps paths.
- Reliability:
  - Use health probes and rollout strategies in chart templates.
  - Define rollback runbook for failed sync or unhealthy rollout.
  - Monitor ArgoCD sync lag and failed applications.

## Rollback / Exit Strategy
If App-of-Apps introduces unacceptable complexity, move to a flatter ArgoCD app topology while preserving GitOps reconciliation and environment values separation. Migration must remain PR-driven and auditable.
