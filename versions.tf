terraform {
  required_version = ">= 1.4.0"  # For terraform_data; fallback to >=1.0.0 without it

  # No required_providers here—module is provider-agnostic (inherits from root)
}
