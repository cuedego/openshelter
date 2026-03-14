#!/usr/bin/env bash
set -euo pipefail

# OpenShelter Linux bootstrap
# Installs common tooling for this repository:
# awscli, terraform, kubectl, helm, docker, make, jq, yq, gh, ansible

AWS_REGION_DEFAULT="eu-central-1"
TF_VERSION_DEFAULT="1.8.5"
KUBECTL_VERSION_DEFAULT="v1.30.2"
YQ_VERSION_DEFAULT="v4.44.3"

AWS_REGION="${AWS_REGION:-$AWS_REGION_DEFAULT}"
TF_VERSION="${TF_VERSION:-$TF_VERSION_DEFAULT}"
KUBECTL_VERSION="${KUBECTL_VERSION:-$KUBECTL_VERSION_DEFAULT}"
YQ_VERSION="${YQ_VERSION:-$YQ_VERSION_DEFAULT}"
SKIP_DOCKER="${SKIP_DOCKER:-false}"

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as a regular user with sudo access (not as root)."
  exit 1
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

log() {
  echo "[bootstrap] $*"
}

sudo_cmd() {
  if require_cmd sudo; then
    sudo "$@"
  else
    "$@"
  fi
}

detect_pkg_manager() {
  if require_cmd apt-get; then
    echo "apt"
    return
  fi
  if require_cmd dnf; then
    echo "dnf"
    return
  fi
  if require_cmd yum; then
    echo "yum"
    return
  fi
  echo "none"
}

PKG_MANAGER="$(detect_pkg_manager)"

install_base_packages() {
  case "$PKG_MANAGER" in
    apt)
      log "Installing base packages via apt..."
      sudo_cmd apt-get update -y
      sudo_cmd apt-get install -y \
        ca-certificates curl unzip git make jq tar gzip python3 python3-pip
      ;;
    dnf)
      log "Installing base packages via dnf..."
      sudo_cmd dnf install -y \
        ca-certificates curl unzip git make jq tar gzip python3 python3-pip
      ;;
    yum)
      log "Installing base packages via yum..."
      sudo_cmd yum install -y \
        ca-certificates curl unzip git make jq tar gzip python3 python3-pip
      ;;
    *)
      log "No supported package manager found (apt/dnf/yum). Install dependencies manually."
      exit 1
      ;;
  esac
}

arch_map() {
  local machine
  machine="$(uname -m)"
  case "$machine" in
    x86_64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *)
      echo "Unsupported architecture: $machine" >&2
      exit 1
      ;;
  esac
}

install_awscli() {
  if require_cmd aws; then
    log "awscli already installed: $(aws --version 2>&1)"
    return
  fi

  local arch tmpdir
  arch="$(arch_map)"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  log "Installing AWS CLI v2..."
  if [[ "$arch" == "amd64" ]]; then
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$tmpdir/awscliv2.zip"
  else
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "$tmpdir/awscliv2.zip"
  fi

  unzip -q "$tmpdir/awscliv2.zip" -d "$tmpdir"
  sudo_cmd "$tmpdir/aws/install" --update
}

install_terraform() {
  if require_cmd terraform; then
    log "terraform already installed: $(terraform version | head -n1)"
    return
  fi

  local arch tmpdir url
  arch="$(arch_map)"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN
  url="https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_${arch}.zip"

  log "Installing Terraform ${TF_VERSION}..."
  curl -fsSL "$url" -o "$tmpdir/terraform.zip"
  unzip -q "$tmpdir/terraform.zip" -d "$tmpdir"
  sudo_cmd install -m 0755 "$tmpdir/terraform" /usr/local/bin/terraform
}

install_kubectl() {
  if require_cmd kubectl; then
    log "kubectl already installed: $(kubectl version --client --short 2>/dev/null || true)"
    return
  fi

  local arch tmpdir url
  arch="$(arch_map)"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN
  url="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${arch}/kubectl"

  log "Installing kubectl ${KUBECTL_VERSION}..."
  curl -fsSL "$url" -o "$tmpdir/kubectl"
  chmod +x "$tmpdir/kubectl"
  sudo_cmd install -m 0755 "$tmpdir/kubectl" /usr/local/bin/kubectl
}

install_helm() {
  if require_cmd helm; then
    log "helm already installed: $(helm version --short 2>/dev/null || true)"
    return
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  log "Installing Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o "$tmpdir/get_helm.sh"
  chmod 700 "$tmpdir/get_helm.sh"
  sudo_cmd "$tmpdir/get_helm.sh"
}

install_yq() {
  if require_cmd yq; then
    log "yq already installed: $(yq --version 2>/dev/null || true)"
    return
  fi

  local arch url
  arch="$(arch_map)"
  url="https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${arch}"

  log "Installing yq ${YQ_VERSION}..."
  sudo_cmd curl -fsSL "$url" -o /usr/local/bin/yq
  sudo_cmd chmod +x /usr/local/bin/yq
}

install_gh() {
  if require_cmd gh; then
    log "gh already installed: $(gh --version | head -n1)"
    return
  fi

  case "$PKG_MANAGER" in
    apt)
      log "Installing GitHub CLI via apt..."
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo_cmd dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null
      sudo_cmd chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo_cmd tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      sudo_cmd apt-get update -y
      sudo_cmd apt-get install -y gh
      ;;
    dnf)
      log "Installing GitHub CLI via dnf..."
      sudo_cmd dnf install -y 'dnf-command(config-manager)'
      sudo_cmd dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
      sudo_cmd dnf install -y gh
      ;;
    yum)
      log "Installing GitHub CLI via yum..."
      sudo_cmd yum install -y yum-utils
      sudo_cmd yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
      sudo_cmd yum install -y gh
      ;;
    *)
      log "Skipping gh install: unsupported package manager"
      ;;
  esac
}

install_ansible() {
  if require_cmd ansible; then
    log "ansible already installed: $(ansible --version | head -n1)"
    return
  fi

  case "$PKG_MANAGER" in
    apt)
      log "Installing Ansible via apt..."
      sudo_cmd apt-get install -y ansible
      ;;
    dnf)
      log "Installing Ansible via dnf..."
      sudo_cmd dnf install -y ansible
      ;;
    yum)
      log "Installing Ansible via yum..."
      sudo_cmd yum install -y ansible
      ;;
  esac
}

install_docker() {
  if [[ "$SKIP_DOCKER" == "true" ]]; then
    log "Skipping Docker installation (SKIP_DOCKER=true)."
    return
  fi

  if require_cmd docker; then
    log "docker already installed: $(docker --version)"
    return
  fi

  case "$PKG_MANAGER" in
    apt)
      log "Installing Docker via apt..."
      sudo_cmd apt-get install -y docker.io
      ;;
    dnf)
      log "Installing Docker via dnf..."
      sudo_cmd dnf install -y docker
      ;;
    yum)
      log "Installing Docker via yum..."
      sudo_cmd yum install -y docker
      ;;
  esac

  if require_cmd systemctl; then
    sudo_cmd systemctl enable docker || true
    sudo_cmd systemctl start docker || true
  fi

  if id -nG "$USER" | grep -qw docker; then
    true
  else
    sudo_cmd usermod -aG docker "$USER" || true
    log "Added $USER to docker group. Re-login may be required."
  fi
}

validate_tooling() {
  log "Validating installed tooling..."

  local failed=0
  for c in aws terraform kubectl helm make jq yq git python3 ansible; do
    if require_cmd "$c"; then
      echo "  OK: $c"
    else
      echo "  MISSING: $c"
      failed=1
    fi
  done

  if [[ "$SKIP_DOCKER" != "true" ]]; then
    if require_cmd docker; then
      echo "  OK: docker"
    else
      echo "  MISSING: docker"
      failed=1
    fi
  fi

  if require_cmd gh; then
    echo "  OK: gh"
  else
    echo "  WARN: gh (optional)"
  fi

  if [[ "$failed" -ne 0 ]]; then
    echo "Validation failed: one or more required tools are missing."
    exit 1
  fi

  log "Tooling validation passed."
}

print_next_steps() {
  cat <<EOF

Next steps:
1) Authenticate with AWS SSO profile:
   aws configure sso
   aws sso login --profile <your-profile>

2) Set profile for this shell:
   export AWS_PROFILE=<your-profile>

3) Fill central config values:
   edit config/global.env

4) Render config and run plan:
   make render-config
   make terraform-env-plan ENV=dev

(Region in use: ${AWS_REGION})
EOF
}

main() {
  log "Starting OpenShelter Linux bootstrap..."
  install_base_packages
  install_awscli
  install_terraform
  install_kubectl
  install_helm
  install_yq
  install_gh
  install_ansible
  install_docker
  validate_tooling
  print_next_steps
}

main "$@"
