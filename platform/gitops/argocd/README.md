# ArgoCD GitOps Bootstrap

This directory contains the OpenShelter ArgoCD App-of-Apps bootstrap manifests.

## Structure
- `projects/`: ArgoCD AppProject definitions
- `apps/root-app.yaml`: root application that manages child applications
- `apps/children/`: child applications per environment
- `bootstrap/cluster-secret-store.yaml`: ClusterSecretStore manifest consumed during bootstrap

## Bootstrapping
1. Ensure local tooling is available (`make bootstrap-linux` on Linux, optional `SKIP_DOCKER=true`).
2. Configure central settings in `config/global.env` and environment settings in `config/env/{dev,stg,prod}.env`.
3. Render runtime artifacts with `make render-config`.
4. Ensure kubeconfig points to the target cluster (`make eks-kubeconfig ENV=<env> CLUSTER_NAME=<name>`).
5. Run full bootstrap (`make cluster-bootstrap ENV=<env> ESO_IRSA_ROLE_ARN=<arn> ALB_CONTROLLER_IRSA_ROLE_ARN=<arn>`).
6. Default behavior applies only the target environment application (`openshelter-<env>`) from `apps/children/`.
7. If needed, set `APP_SCOPE=root` to apply the root app and reconcile all child applications.

## Notes
- Environment-specific Helm values are in `platform/gitops/helm/values/{dev,stg,prod}`.
- The bootstrap script (`scripts/argocd-bootstrap.sh`) installs ArgoCD, installs External Secrets Operator, applies `ClusterSecretStore`, and then applies either the environment app (`APP_SCOPE=env`, default) or the root app (`APP_SCOPE=root`).
- Default `APP_SCOPE=env` is safer for staged rollouts and prevents cross-environment reconciliation in a single cluster.
- Secret values must not be committed to Git.
