locals {
  name_prefix = "openshelter-${var.environment}"
  common_tags = {
    project     = "openshelter"
    environment = var.environment
    managed_by  = "terraform"
  }
}

module "network" {
  source     = "../../modules/network"
  name       = local.name_prefix
  cidr_block = var.vpc_cidr
  tags       = local.common_tags
}

module "eks" {
  source              = "../../modules/eks"
  name                = "${local.name_prefix}-eks"
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.private_subnet_ids
  node_instance_types = ["t3.large"]
  node_desired_size   = 3
  node_min_size       = 2
  node_max_size       = 6
  tags                = local.common_tags
}

module "rds" {
  source         = "../../modules/rds-postgresql"
  identifier     = "${local.name_prefix}-rds"
  db_name        = "openshelter"
  username       = "openshelter_admin"
  password       = module.secrets.effective_secret_values["rds/password"]
  instance_class = "db.t3.medium"
  vpc_id         = module.network.vpc_id
  vpc_cidr       = var.vpc_cidr
  subnet_ids     = module.network.private_subnet_ids
  tags           = local.common_tags
}

module "ecr" {
  source              = "../../modules/ecr"
  repository_names    = ["openshelter/zabbix", "openshelter/mqtt"]
  create_repositories = false
  tags                = local.common_tags
}

module "secrets" {
  source                     = "../../modules/secrets"
  name_prefix                = local.name_prefix
  use_existing_secret_values = var.use_existing_secret_values
  recovery_window_in_days    = 30
  secret_configs = {
    "rds/password" = {
      description = "RDS master password for openshelter"
    }
    "zabbix/admin-password" = {
      description = "Zabbix admin user password"
    }
    "mqtt/password" = {
      description = "MQTT broker authentication password"
    }
  }
  secret_values = {
    "rds/password"          = var.rds_password
    "zabbix/admin-password" = var.zabbix_admin_password
    "mqtt/password"         = var.mqtt_password
  }
  tags = local.common_tags
}

module "irsa_eso" {
  source             = "../../modules/irsa-eso"
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.oidc_provider_url
  role_name          = "${local.name_prefix}-eso-irsa"
  secret_path_prefix = local.name_prefix
  tags               = local.common_tags
}

module "irsa_alb_controller" {
  source            = "../../modules/irsa-alb-controller"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  role_name         = "${local.name_prefix}-alb-controller-irsa"
  tags              = local.common_tags
}
