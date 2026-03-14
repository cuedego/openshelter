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
  source     = "../../modules/eks"
  name       = "${local.name_prefix}-eks"
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids
  tags       = local.common_tags
}

module "rds" {
  source         = "../../modules/rds-postgresql"
  identifier     = "${local.name_prefix}-rds"
  db_name        = "openshelter"
  username       = "openshelter_admin"
  password       = var.rds_password
  instance_class = "db.t3.small"
  vpc_id         = module.network.vpc_id
  vpc_cidr       = var.vpc_cidr
  subnet_ids     = module.network.private_subnet_ids
  tags           = local.common_tags
}

module "ecr" {
  source           = "../../modules/ecr"
  repository_names = ["openshelter/zabbix", "openshelter/mqtt"]
  tags             = local.common_tags
}

module "secrets" {
  source      = "../../modules/secrets"
  name_prefix = local.name_prefix
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
