resource "aws_db_instance" "this" {
  identifier             = var.identifier
  engine                 = "postgres"
  instance_class         = var.instance_class
  allocated_storage      = 20
  db_name                = var.db_name
  username               = var.username
  password               = var.password
  skip_final_snapshot    = true
  publicly_accessible    = false
  backup_retention_period = 7

  tags = var.tags
}
