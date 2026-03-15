output "repository_urls" {
  description = "Map of repository name to repository URL"
  value = {
    for name in toset(var.repository_names) :
    name => (var.create_repositories ? aws_ecr_repository.this[name].repository_url : data.aws_ecr_repository.existing[name].repository_url)
  }
}

output "repository_arns" {
  description = "Map of repository name to repository ARN"
  value = {
    for name in toset(var.repository_names) :
    name => (var.create_repositories ? aws_ecr_repository.this[name].arn : data.aws_ecr_repository.existing[name].arn)
  }
}
