#!/usr/bin/env bash
set -euo pipefail

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
PROJECT_MANIFEST="platform/gitops/argocd/projects/openshelter-project.yaml"
ROOT_APP_MANIFEST="platform/gitops/argocd/apps/root-app.yaml"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required but not found in PATH."
  exit 1
fi

if ! kubectl config current-context >/dev/null 2>&1; then
  echo "No active Kubernetes context found. Configure kubectl before bootstrapping ArgoCD."
  exit 1
fi

if [[ ! -f "$PROJECT_MANIFEST" ]]; then
  echo "Missing manifest: $PROJECT_MANIFEST"
  exit 1
fi

if [[ ! -f "$ROOT_APP_MANIFEST" ]]; then
  echo "Missing manifest: $ROOT_APP_MANIFEST"
  exit 1
fi

if ! kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
  echo "Namespace '$ARGOCD_NAMESPACE' does not exist. Install ArgoCD before running bootstrap."
  exit 1
fi

echo "Applying ArgoCD project manifest..."
kubectl apply -f "$PROJECT_MANIFEST"

echo "Applying ArgoCD root application manifest..."
kubectl apply -f "$ROOT_APP_MANIFEST"

echo "Bootstrap submitted successfully."
echo "Next: monitor with 'kubectl -n $ARGOCD_NAMESPACE get applications.argoproj.io'."
