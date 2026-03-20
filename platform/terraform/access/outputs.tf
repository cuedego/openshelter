output "cluster_names" {
  description = "Managed EKS cluster names for bootstrap role access"
  value       = values(local.cluster_names)
}

output "bootstrap_role_arn" {
  description = "IAM role ARN granted EKS cluster-admin access"
  value       = var.bootstrap_role_arn
}
