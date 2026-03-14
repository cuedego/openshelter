resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [role_arn, vpc_config]
  }
}
