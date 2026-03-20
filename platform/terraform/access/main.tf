data "aws_partition" "current" {}

locals {
  cluster_names = {
    for env in var.environments :
    env => "${var.cluster_name_prefix}-${env}-eks"
  }

  common_tags = {
    project    = "openshelter"
    scope      = "access"
    managed_by = "terraform"
  }
}

resource "aws_eks_access_entry" "bootstrap_role" {
  for_each = local.cluster_names

  cluster_name  = each.value
  principal_arn = var.bootstrap_role_arn
  type          = "STANDARD"

  tags = merge(local.common_tags, {
    environment = each.key
  })
}

resource "aws_eks_access_policy_association" "bootstrap_role" {
  for_each = local.cluster_names

  cluster_name  = each.value
  principal_arn = var.bootstrap_role_arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bootstrap_role]
}
