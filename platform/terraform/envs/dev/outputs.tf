output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eso_irsa_role_arn" {
  description = "Pass to ESO Helm install: serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
  value       = module.irsa_eso.role_arn
}

output "rds_address" {
  description = "RDS endpoint address (use as DB_HOST in application config)"
  value       = module.rds.address
}

output "alb_controller_irsa_role_arn" {
  description = "Pass to AWS LB Controller Helm install: serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
  value       = module.irsa_alb_controller.role_arn
}
