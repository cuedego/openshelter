#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV="${ENV:-dev}"
FIRST_APPLY="${FIRST_APPLY:-false}"
TF_TIMEOUT_SECONDS="${TF_TIMEOUT_SECONDS:-0}"
ARGO_WAIT_TIMEOUT_SECONDS="${ARGO_WAIT_TIMEOUT_SECONDS:-900}"
ALLOW_PROGRESSING_HEALTH_ON_TIMEOUT="${ALLOW_PROGRESSING_HEALTH_ON_TIMEOUT:-false}"

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
CLUSTER_NAME="${CLUSTER_NAME:-openshelter-${ENV}-eks}"
VPC_CIDR="${VPC_CIDR:-}"

for cmd in terraform kubectl aws bash; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: '$cmd' is required but not found in PATH."
    exit 1
  fi
done

if [[ -z "$AWS_REGION" ]]; then
  echo "ERROR: AWS_REGION is empty. Configure config/global.env."
  exit 1
fi

if [[ -z "$VPC_CIDR" ]]; then
  echo "ERROR: VPC_CIDR is empty for ENV=$ENV. Configure config/env/${ENV}.env."
  exit 1
fi

if [[ "$FIRST_APPLY" != "true" && "$FIRST_APPLY" != "false" ]]; then
  echo "ERROR: FIRST_APPLY must be 'true' or 'false'."
  exit 1
fi

if [[ "$FIRST_APPLY" == "true" ]] && ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: 'python3' is required for FIRST_APPLY=true password generation."
  exit 1
fi

if [[ "$TF_TIMEOUT_SECONDS" != "0" ]] && ! command -v timeout >/dev/null 2>&1; then
  echo "ERROR: 'timeout' is required when TF_TIMEOUT_SECONDS is set."
  exit 1
fi

generate_password() {
  local length="$1"
  python3 - "$length" <<'PY'
import secrets
import string
import sys
alphabet = string.ascii_letters + string.digits
length = int(sys.argv[1])
print(''.join(secrets.choice(alphabet) for _ in range(length)))
PY
}

echo "==> Render central config"
bash "$REPO_ROOT/scripts/render-config.sh"

echo "==> Terraform init ($ENV)"
terraform -chdir="$REPO_ROOT/platform/terraform/envs/${ENV}" init -input=false -backend-config=backend.hcl -no-color

TF_APPLY_ARGS=(
  -chdir="$REPO_ROOT/platform/terraform/envs/${ENV}"
  apply
  -auto-approve
  -input=false
  -no-color
  -var="region=${AWS_REGION}"
  -var="environment=${ENV}"
  -var="vpc_cidr=${VPC_CIDR}"
)

if [[ "$FIRST_APPLY" == "true" ]]; then
  RDS_PASSWORD="${RDS_PASSWORD:-$(generate_password 28)}"
  ZABBIX_ADMIN_PASSWORD="${ZABBIX_ADMIN_PASSWORD:-$(generate_password 24)}"
  MQTT_PASSWORD="${MQTT_PASSWORD:-$(generate_password 24)}"
  TF_APPLY_ARGS+=(
    -var="use_existing_secret_values=false"
    -var="rds_password=${RDS_PASSWORD}"
    -var="zabbix_admin_password=${ZABBIX_ADMIN_PASSWORD}"
    -var="mqtt_password=${MQTT_PASSWORD}"
  )
fi

echo "==> Terraform apply ($ENV)"
if [[ "$TF_TIMEOUT_SECONDS" != "0" ]]; then
  timeout "$TF_TIMEOUT_SECONDS" terraform "${TF_APPLY_ARGS[@]}"
else
  terraform "${TF_APPLY_ARGS[@]}"
fi

echo "==> Read Terraform outputs ($ENV)"
ESO_IRSA_ROLE_ARN="$(terraform -chdir="$REPO_ROOT/platform/terraform/envs/${ENV}" output -raw eso_irsa_role_arn)"
ALB_CONTROLLER_IRSA_ROLE_ARN="$(terraform -chdir="$REPO_ROOT/platform/terraform/envs/${ENV}" output -raw alb_controller_irsa_role_arn)"

echo "==> Update kubeconfig alias '$ENV'"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" --alias "$ENV" >/dev/null

echo "==> Bootstrap ArgoCD stack (env-scoped)"
ENV="$ENV" \
AWS_REGION="$AWS_REGION" \
CLUSTER_NAME="$CLUSTER_NAME" \
ESO_IRSA_ROLE_ARN="$ESO_IRSA_ROLE_ARN" \
ALB_CONTROLLER_IRSA_ROLE_ARN="$ALB_CONTROLLER_IRSA_ROLE_ARN" \
APP_SCOPE="env" \
bash "$REPO_ROOT/scripts/argocd-bootstrap.sh"

echo "==> Wait for ArgoCD application to become Synced/Healthy"
APP_NAME="openshelter-${ENV}"
START_TS="$(date +%s)"
while true; do
  sync_status="$(kubectl --context "$ENV" -n argocd get application "$APP_NAME" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
  health_status="$(kubectl --context "$ENV" -n argocd get application "$APP_NAME" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"

  if [[ "$sync_status" == "Synced" && "$health_status" == "Healthy" ]]; then
    break
  fi

  now="$(date +%s)"
  elapsed="$((now - START_TS))"
  if (( elapsed > ARGO_WAIT_TIMEOUT_SECONDS )); then
    if [[ "$ALLOW_PROGRESSING_HEALTH_ON_TIMEOUT" == "true" && "$sync_status" == "Synced" && "$health_status" == "Progressing" ]]; then
      echo "WARN: Timed out waiting for Healthy, but app is Synced/Progressing; continuing due to ALLOW_PROGRESSING_HEALTH_ON_TIMEOUT=true."
      kubectl --context "$ENV" -n argocd get application "$APP_NAME" -o wide || true
      break
    fi

    echo "ERROR: Timeout waiting for $APP_NAME to become Synced/Healthy."
    kubectl --context "$ENV" -n argocd get application "$APP_NAME" -o wide || true
    exit 1
  fi

  sleep 10
done

echo "==> Read ingress status"
ingress_name="openshelter-${ENV}-zabbix-web"
scheme="$(kubectl --context "$ENV" -n "openshelter-${ENV}" get ingress "$ingress_name" -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/scheme}')"
address="$(kubectl --context "$ENV" -n "openshelter-${ENV}" get ingress "$ingress_name" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

echo ""
echo "Bootstrap E2E complete for ENV=$ENV"
echo "ArgoCD app: $APP_NAME (Synced/Healthy)"
echo "Ingress scheme: $scheme"
echo "Ingress address: $address"