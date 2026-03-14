# ArgoCD GitOps Bootstrap

This directory contains the OpenShelter ArgoCD App-of-Apps bootstrap manifests.

## Structure
- `projects/`: ArgoCD AppProject definitions
- `apps/root-app.yaml`: root application that manages child applications
- `apps/children/`: child applications per environment

## Bootstrapping
1. Replace `repoURL` placeholders with the real Git repository URL.
2. Apply project and root app manifests to the `argocd` namespace.
3. ArgoCD will reconcile child applications for `dev`, `stg`, and `prod`.

## Notes
- Environment-specific Helm values are in `platform/gitops/helm/values/{dev,stg,prod}`.
- Secret values must not be committed to Git.
