resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = var.tags
}

module "github_oidc" {
  source = "../modules/github-oidc"

  github_org        = var.github_org
  github_repo       = var.github_repo
  state_bucket_name = var.state_bucket_name
  lock_table_name   = var.lock_table_name
  tags              = var.tags
}
