locals {
  common_tags = {
    project    = "openshelter"
    scope      = "shared"
    managed_by = "terraform"
  }
}

module "ecr" {
  source = "../modules/ecr"

  repository_names = var.repository_names
  tags             = local.common_tags
}
