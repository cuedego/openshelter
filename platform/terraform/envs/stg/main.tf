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
  source           = "../../modules/eks"
  name             = "${local.name_prefix}-eks"
  vpc_id           = module.network.vpc_id
  cluster_role_arn = var.eks_cluster_role_arn
  subnet_ids       = var.eks_subnet_ids
  tags             = local.common_tags
}

module "rds" {
  source         = "../../modules/rds-postgresql"
  identifier     = "${local.name_prefix}-rds"
  db_name        = "openshelter"
  username       = "openshelter_admin"
  password       = var.rds_password
  instance_class = "db.t4g.micro"
  tags           = local.common_tags
}
