# ArgoCD GitOps Bootstrap

This directory contains the OpenShelter ArgoCD App-of-Apps bootstrap manifests.

## Structure
- `projects/`: ArgoCD AppProject definitions
- `apps/root-app.yaml`: root application that manages child applications
- `apps/children/`: child applications per environment
- `bootstrap/cluster-secret-store.yaml`: ClusterSecretStore manifest consumed during bootstrap

## Bootstrapping
1. Configure central settings in `config/global.env` and environment settings in `config/env/{dev,stg,prod}.env`.
2. Render runtime artifacts with `make render-config`.
3. Ensure kubeconfig points to the target cluster (`make eks-kubeconfig ENV=<env> CLUSTER_NAME=<name>`).
4. Run full bootstrap (`make cluster-bootstrap ENV=<env> ESO_IRSA_ROLE_ARN=<arn>`).
5. ArgoCD reconciles child applications for `dev`, `stg`, and `prod` from `apps/children/`.

## Notes
- Environment-specific Helm values are in `platform/gitops/helm/values/{dev,stg,prod}`.
- The bootstrap script (`scripts/argocd-bootstrap.sh`) installs ArgoCD, installs External Secrets Operator, applies `ClusterSecretStore`, and then applies root manifests.
- Secret values must not be committed to Git.
