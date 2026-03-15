#!/usr/bin/env bash
# Full cluster bootstrap: ArgoCD + External Secrets Operator + App-of-Apps
# Usage: [ENV=dev] [SKIP_ARGOCD=false] [SKIP_ESO=false] bash scripts/argocd-bootstrap.sh
set -euo pipefail

# ──────────────────────────────────────────────
# Configuration (override via env vars)
# ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV="${ENV:-dev}"

# Load centralized config (if present)
if [[ -f "$REPO_ROOT/config/global.env" ]]; then
  set -a
  source "$REPO_ROOT/config/global.env"
  set +a
fi

if [[ -f "$REPO_ROOT/config/local.env" ]]; then
  set -a
  source "$REPO_ROOT/config/local.env"
  set +a
fi

if [[ -f "$REPO_ROOT/config/env/${ENV}.env" ]]; then
  set -a
  source "$REPO_ROOT/config/env/${ENV}.env"
  set +a
fi

AWS_REGION="${AWS_REGION:-}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ESO_NAMESPACE="${ESO_NAMESPACE:-external-secrets}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-7.3.4}"
ESO_CHART_VERSION="${ESO_CHART_VERSION:-0.10.3}"

# IRSA role ARN for the ESO controller service account.
# Obtain after applying env Terraform:
# terraform -chdir=platform/terraform/envs/${ENV} output -raw eso_irsa_role_arn
ESO_IRSA_ROLE_ARN="${ESO_IRSA_ROLE_ARN:-}"

PROJECT_MANIFEST="$REPO_ROOT/platform/gitops/argocd/projects/openshelter-project.yaml"
ROOT_APP_MANIFEST="$REPO_ROOT/platform/gitops/argocd/apps/root-app.yaml"
CSS_MANIFEST="$REPO_ROOT/platform/gitops/argocd/bootstrap/cluster-secret-store.yaml"

# ──────────────────────────────────────────────
# Pre-flight checks
# ──────────────────────────────────────────────
for cmd in kubectl helm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: '$cmd' is required but not found in PATH."
    exit 1
  fi
done

if ! kubectl config current-context >/dev/null 2>&1; then
  echo "ERROR: No active Kubernetes context. Run 'aws eks update-kubeconfig ...' first."
  exit 1
fi

if [[ -z "$AWS_REGION" ]]; then
  echo "ERROR: AWS_REGION is empty. Set it in config/global.env or export AWS_REGION."
  exit 1
fi

for f in "$PROJECT_MANIFEST" "$ROOT_APP_MANIFEST" "$CSS_MANIFEST"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: Missing manifest: $f"
    exit 1
  fi
done

echo "==> Cluster: $(kubectl config current-context)"
echo "==> Environment: $ENV | Region: $AWS_REGION"
echo ""

# ──────────────────────────────────────────────
# Step 1 — Install ArgoCD
# ──────────────────────────────────────────────
if [[ "${SKIP_ARGOCD:-false}" != "true" ]]; then
  echo "──────────────────────────────────────────────"
  echo "Step 1: Installing ArgoCD ${ARGOCD_CHART_VERSION}"
  echo "──────────────────────────────────────────────"
  kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

  helm repo add argo https://argoproj.github.io/argo-helm --force-update
  helm upgrade --install argocd argo/argo-cd \
    --namespace "$ARGOCD_NAMESPACE" \
    --version "$ARGOCD_CHART_VERSION" \
    --set server.service.type=ClusterIP \
    --set configs.params."server\.insecure"=true \
    --wait --timeout 5m
  echo "ArgoCD installed."
else
  echo "Step 1: Skipping ArgoCD install (SKIP_ARGOCD=true)"
fi

# ──────────────────────────────────────────────
# Step 2 — Install External Secrets Operator
# ──────────────────────────────────────────────
if [[ "${SKIP_ESO:-false}" != "true" ]]; then
  echo ""
  echo "──────────────────────────────────────────────"
  echo "Step 2: Installing External Secrets Operator ${ESO_CHART_VERSION}"
  echo "──────────────────────────────────────────────"
  kubectl create namespace "$ESO_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

  helm repo add external-secrets https://charts.external-secrets.io --force-update

  ESO_SA_ARGS=()
  if [[ -n "$ESO_IRSA_ROLE_ARN" ]]; then
    ESO_SA_ARGS+=(
      "--set" "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${ESO_IRSA_ROLE_ARN}"
    )
  fi

  helm upgrade --install external-secrets external-secrets/external-secrets \
    --namespace "$ESO_NAMESPACE" \
    --version "$ESO_CHART_VERSION" \
    --set installCRDs=true \
    "${ESO_SA_ARGS[@]+"${ESO_SA_ARGS[@]}"}" \
    --wait --timeout 5m
  echo "External Secrets Operator installed."
else
  echo "Step 2: Skipping ESO install (SKIP_ESO=true)"
fi

# ──────────────────────────────────────────────
# Step 3 — Apply ClusterSecretStore
# ──────────────────────────────────────────────
echo ""
echo "──────────────────────────────────────────────"
echo "Step 3: Applying ClusterSecretStore"
echo "──────────────────────────────────────────────"
# Substitute region placeholder if needed
sed "s|REPLACE_AWS_REGION|${AWS_REGION}|g" "$CSS_MANIFEST" | kubectl apply -f -
echo "ClusterSecretStore applied."

# ──────────────────────────────────────────────
# Step 4 — Apply ArgoCD project + root app
# ──────────────────────────────────────────────
echo ""
echo "──────────────────────────────────────────────"
echo "Step 4: Applying ArgoCD project and root application"
echo "──────────────────────────────────────────────"
kubectl apply -f "$PROJECT_MANIFEST"
kubectl apply -f "$ROOT_APP_MANIFEST"

echo ""
echo "Bootstrap complete."
echo "Monitor sync:  kubectl -n $ARGOCD_NAMESPACE get applications.argoproj.io"
echo "ArgoCD UI:     kubectl -n $ARGOCD_NAMESPACE port-forward svc/argocd-server 8080:80"
echo "Initial admin: kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
