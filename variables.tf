variable "vars_to_store" {
  description = "Map of regular (non-secret) vars to store as JSON in Clan vars."
  type        = map(any)
  default     = {}

  validation {
    condition     = length(var.vars_to_store) >= 0
    error_message = "Regular vars must be a valid map."
  }
}

variable "secrets_to_store" {
  description = "Map of secret vars to store individually with --secret (e.g., { vm_password = 'supersecret' })."
  type        = map(string)
  default     = {}
  sensitive   = true  # Hides in plans/vars

  validation {
    condition     = alltrue([for v in values(var.secrets_to_store) : type(v) == "string"])
    error_message = "Secret values must be strings."
  }
}

variable "vars_key" {
  description = "Key for the regular JSON output (default: 'terraform/regular_output')."
  type        = string
  default     = "terraform/public_data"
}

variable "secrets_key_prefix" {
  description = "Prefix for individual secret keys (default: 'terraform/secret_'). Full key: <prefix><original_key>."
  type        = string
  default     = "terraform/secret_"
}
