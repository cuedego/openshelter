#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ ! -f "$REPO_ROOT/config/global.env" ]]; then
  echo "Missing config/global.env"
  exit 1
fi

set -a
source "$REPO_ROOT/config/global.env"
set +a

if [[ -f "$REPO_ROOT/config/local.env" ]]; then
  set -a
  source "$REPO_ROOT/config/local.env"
  set +a
fi

required_vars=(AWS_REGION TF_STATE_BUCKET TF_LOCK_TABLE TF_STATE_KEY_PREFIX)
for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "Missing required variable in config/global.env: ${var_name}"
    exit 1
  fi
done

replace_rds_host() {
  local file="$1"
  local env_file="$2"

  if [[ -f "$env_file" ]]; then
    set -a
    source "$env_file"
    set +a
  fi

  if [[ -n "${RDS_HOST:-}" ]]; then
    sed -i -E "s|^(\s*host:\s*\").*(\"\s*)$|\1${RDS_HOST}\2|" "$file"
  fi

  unset RDS_HOST || true
}

render_backend_hcl() {
  local file="$1"
  local env_name="$2"
  local env_file="$3"

  if [[ -f "$env_file" ]]; then
    set -a
    source "$env_file"
    set +a
  fi

  local state_key="${TF_STATE_KEY:-${TF_STATE_KEY_PREFIX}/${env_name}/terraform.tfstate}"

  cat > "$file" <<EOF
bucket         = "${TF_STATE_BUCKET}"
key            = "${state_key}"
region         = "${AWS_REGION}"
dynamodb_table = "${TF_LOCK_TABLE}"
encrypt        = true
EOF

  unset TF_STATE_KEY || true
}

for env in dev stg prod; do
  values_file="$REPO_ROOT/platform/gitops/helm/values/${env}/openshelter-stack.yaml"
  env_file="$REPO_ROOT/config/env/${env}.env"
  backend_file="$REPO_ROOT/platform/terraform/envs/${env}/backend.hcl"

  replace_rds_host "$values_file" "$env_file"
  render_backend_hcl "$backend_file" "$env" "$env_file"
done

echo "Config rendered successfully from config/global.env + config/env/*.env"
