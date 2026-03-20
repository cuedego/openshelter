output "ecr_repository_urls" {
  description = "Map of shared ECR repository names to URLs"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "Map of shared ECR repository names to ARNs"
  value       = module.ecr.repository_arns
}
