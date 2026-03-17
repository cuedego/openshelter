locals {
  repository_names_set = toset(var.repository_names)
  repositories_for_policy = var.create_repositories ? {
    for name, repository in aws_ecr_repository.this :
    name => repository.name
    } : {
    for name, repository in data.aws_ecr_repository.existing :
    name => repository.name
  }
}

resource "aws_ecr_repository" "this" {
  for_each = var.create_repositories ? local.repository_names_set : toset([])

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = var.tags
}

data "aws_ecr_repository" "existing" {
  for_each = var.create_repositories ? toset([]) : local.repository_names_set

  name = each.value
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = local.repositories_for_policy
  repository = each.value

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Retain last 20 tagged images"
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = ["v"]
        countType     = "imageCountMoreThan"
        countNumber   = 20
      }
      action = { type = "expire" }
      }, {
      rulePriority = 2
      description  = "Expire untagged images older than 7 days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 7
      }
      action = { type = "expire" }
    }]
  })
}
