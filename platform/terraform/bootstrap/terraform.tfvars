region            = "eu-central-1"
state_bucket_name = "openshelter-tfstate-052081665529-eu-central-1"
lock_table_name   = "openshelter-tfstate-lock"
github_org        = "cuedego"
github_repo       = "openshelter"

tags = {
  project     = "openshelter"
  managed_by  = "terraform"
  environment = "bootstrap"
}
