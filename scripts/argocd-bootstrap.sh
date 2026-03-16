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
APP_SCOPE="${APP_SCOPE:-env}"
ALLOW_CONTEXT_MISMATCH="${ALLOW_CONTEXT_MISMATCH:-false}"

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

# IRSA role ARN for the AWS Load Balancer Controller service account.
# Obtain after applying env Terraform:
# terraform -chdir=platform/terraform/envs/${ENV} output -raw alb_controller_irsa_role_arn
ALB_CONTROLLER_IRSA_ROLE_ARN="${ALB_CONTROLLER_IRSA_ROLE_ARN:-}"

ALB_CONTROLLER_CHART_VERSION="${ALB_CONTROLLER_CHART_VERSION:-1.8.1}"
ALB_CONTROLLER_NAMESPACE="${ALB_CONTROLLER_NAMESPACE:-kube-system}"

ARGOCD_REPO_URL="${ARGOCD_REPO_URL:-https://github.com/cuedego/openshelter.git}"
ARGOCD_REPO_USERNAME="${ARGOCD_REPO_USERNAME:-}"
ARGOCD_REPO_PASSWORD="${ARGOCD_REPO_PASSWORD:-}"

PROJECT_MANIFEST="$REPO_ROOT/platform/gitops/argocd/projects/openshelter-project.yaml"
ROOT_APP_MANIFEST="$REPO_ROOT/platform/gitops/argocd/apps/root-app.yaml"
ENV_APP_MANIFEST="$REPO_ROOT/platform/gitops/argocd/apps/children/openshelter-${ENV}.yaml"
CSS_MANIFEST="$REPO_ROOT/platform/gitops/argocd/bootstrap/cluster-secret-store.yaml"
VALUES_MANIFEST="$REPO_ROOT/platform/gitops/helm/values/${ENV}/openshelter-stack.yaml"

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

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "$ALLOW_CONTEXT_MISMATCH" != "true" && "$CURRENT_CONTEXT" != "$ENV" ]]; then
  echo "ERROR: Current context '$CURRENT_CONTEXT' does not match ENV='$ENV'."
  echo "       Run: make eks-kubeconfig ENV=$ENV CLUSTER_NAME=<cluster-name>"
  echo "       Or set ALLOW_CONTEXT_MISMATCH=true to bypass."
  exit 1
fi

if [[ -z "$AWS_REGION" ]]; then
  echo "ERROR: AWS_REGION is empty. Set it in config/global.env or export AWS_REGION."
  exit 1
fi

for f in "$PROJECT_MANIFEST" "$ROOT_APP_MANIFEST" "$ENV_APP_MANIFEST" "$CSS_MANIFEST" "$VALUES_MANIFEST"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: Missing manifest: $f"
    exit 1
  fi
done

if [[ "$APP_SCOPE" != "env" && "$APP_SCOPE" != "root" ]]; then
  echo "ERROR: APP_SCOPE must be 'env' or 'root'. Current value: '$APP_SCOPE'"
  exit 1
fi

if [[ "${SKIP_ESO:-false}" != "true" && -z "$ESO_IRSA_ROLE_ARN" ]]; then
  echo "ERROR: ESO_IRSA_ROLE_ARN is required unless SKIP_ESO=true"
  exit 1
fi

if [[ "${SKIP_ALB_CONTROLLER:-false}" != "true" && -z "$ALB_CONTROLLER_IRSA_ROLE_ARN" ]]; then
  echo "ERROR: ALB_CONTROLLER_IRSA_ROLE_ARN is required unless SKIP_ALB_CONTROLLER=true"
  exit 1
fi

if grep -q "REPLACE_ME.rds.amazonaws.com" "$VALUES_MANIFEST"; then
  echo "ERROR: Found placeholder RDS host in $VALUES_MANIFEST"
  exit 1
fi

if [[ "$ENV" == "stg" || "$ENV" == "prod" ]]; then
  if ! grep -q 'alb.ingress.kubernetes.io/scheme: internet-facing' "$VALUES_MANIFEST"; then
    echo "ERROR: Expected internet-facing ingress scheme for ENV=$ENV in $VALUES_MANIFEST"
    exit 1
  fi
fi

if [[ "$ENV" == "prod" ]]; then
  if grep -q "REPLACE_ACM_CERTIFICATE_ARN" "$VALUES_MANIFEST"; then
    echo "ERROR: Found placeholder ACM certificate ARN in $VALUES_MANIFEST"
    exit 1
  fi
fi

echo "==> Cluster: $CURRENT_CONTEXT"
echo "==> Environment: $ENV | Region: $AWS_REGION"
echo "==> Application scope: $APP_SCOPE"
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

  echo "Applying ArgoCD repository credential secret..."
  # Build the secret manifest; credentials are optional (omit for public repos)
  REPO_SECRET_MANIFEST=$(cat <<ENDOFMANIFEST
apiVersion: v1
kind: Secret
metadata:
  name: argocd-repo-openshelter
  namespace: ${ARGOCD_NAMESPACE}
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: ${ARGOCD_REPO_URL}
ENDOFMANIFEST
)
  if [[ -n "${ARGOCD_REPO_USERNAME:-}" && -n "${ARGOCD_REPO_PASSWORD:-}" ]]; then
    REPO_SECRET_MANIFEST+=$'\n  username: '"${ARGOCD_REPO_USERNAME}"
    REPO_SECRET_MANIFEST+=$'\n  password: '"${ARGOCD_REPO_PASSWORD}"
  fi
  echo "$REPO_SECRET_MANIFEST" | kubectl apply -f -
  echo "ArgoCD repository credential secret applied."
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
# Step 3 — Install AWS Load Balancer Controller
# ──────────────────────────────────────────────
if [[ "${SKIP_ALB_CONTROLLER:-false}" != "true" ]]; then
  echo ""
  echo "──────────────────────────────────────────────"
  echo "Step 3: Installing AWS Load Balancer Controller ${ALB_CONTROLLER_CHART_VERSION}"
  echo "──────────────────────────────────────────────"

  # cluster name is required for the controller to filter resources
  CLUSTER_NAME="${CLUSTER_NAME:-$(kubectl config current-context)}"
  AWS_REGION="${AWS_REGION}"

  if [[ -z "$CLUSTER_NAME" || -z "$AWS_REGION" ]]; then
    echo "ERROR: CLUSTER_NAME and AWS_REGION are required for ALB controller install."
    exit 1
  fi

  helm repo add eks https://aws.github.io/eks-charts --force-update

  ALB_SA_ARGS=(
    "--set" "clusterName=${CLUSTER_NAME}"
    "--set" "region=${AWS_REGION}"
    "--set" "vpcId=$(kubectl get configmap -n kube-system aws-auth -o jsonpath='{.data.mapRoles}' 2>/dev/null | true; \
      aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} \
        --query 'cluster.resourcesVpcConfig.vpcId' --output text)"
  )

  ALB_SA_ARGS+=(
    "--set" "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${ALB_CONTROLLER_IRSA_ROLE_ARN}"
  )

  helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --namespace "$ALB_CONTROLLER_NAMESPACE" \
    --version "$ALB_CONTROLLER_CHART_VERSION" \
    "${ALB_SA_ARGS[@]}" \
    --wait --timeout 5m
  echo "AWS Load Balancer Controller installed."
else
  echo "Step 3: Skipping ALB controller install (SKIP_ALB_CONTROLLER=true)"
fi

# ──────────────────────────────────────────────
# Step 4 — Apply ClusterSecretStore
# ──────────────────────────────────────────────
echo ""
echo "──────────────────────────────────────────────"
echo "Step 4: Applying ClusterSecretStore"
echo "──────────────────────────────────────────────"
# Substitute region placeholder if needed
sed "s|REPLACE_AWS_REGION|${AWS_REGION}|g" "$CSS_MANIFEST" | kubectl apply -f -
echo "ClusterSecretStore applied."

# ──────────────────────────────────────────────
# Step 5 — Apply ArgoCD project + application manifests
# ──────────────────────────────────────────────
echo ""
echo "──────────────────────────────────────────────"
echo "Step 5: Applying ArgoCD project and application manifests"
echo "──────────────────────────────────────────────"
kubectl apply -f "$PROJECT_MANIFEST"

if [[ "$APP_SCOPE" == "root" ]]; then
  kubectl apply -f "$ROOT_APP_MANIFEST"
  echo "Applied root application: openshelter-root"
else
  kubectl apply -f "$ENV_APP_MANIFEST"
  echo "Applied environment application: openshelter-$ENV"
fi

echo ""
echo "Bootstrap complete."
echo "Monitor sync:  kubectl -n $ARGOCD_NAMESPACE get applications.argoproj.io"
echo "ArgoCD UI:     kubectl -n $ARGOCD_NAMESPACE port-forward svc/argocd-server 8080:80"
echo "Initial admin: kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
