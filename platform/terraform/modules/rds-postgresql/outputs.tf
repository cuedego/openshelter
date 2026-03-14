output "address" {
  description = "RDS endpoint address"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "RDS port"
  value       = aws_db_instance.this.port
}

output "endpoint" {
  description = "Full RDS connection endpoint (address:port)"
  value       = aws_db_instance.this.endpoint
}
