variable "name_prefix" {
  type        = string
  description = "Prefix for all secret names (e.g. openshelter-dev)"
}

variable "secret_configs" {
  type = map(object({
    description = string
  }))
  description = "Map of secret key to metadata. Used as for_each key — must not be sensitive."
}

variable "secret_values" {
  type        = map(string)
  description = "Map of secret key to plaintext value. Must match the keys in secret_configs."
  sensitive   = true
}

variable "use_existing_secret_values" {
  type        = bool
  description = "When true, read current secret values from AWS Secrets Manager instead of using secret_values input."
  default     = true
}

variable "recovery_window_in_days" {
  type        = number
  description = "Number of days before a deleted secret is purged"
  default     = 7
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
