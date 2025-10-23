# Terraform Clan Vars Module

This module automatically helps to set secrets and variables using clan vars post-apply:
- Non-secrets: As a JSON blob (e.g., `clan vars set terraform/public_data`).
- Secrets: Individually with `--secret` (e.g., `clan vars set --secret terraform/secret_vm_password`).
- Runs last via implicit dependencies (reference resources in root locals).
- Cleanup on destroy.

## Requirements
- Terraform >=1.4.0 (for `terraform_data`; see fallback below).
- `bash`, `jq` (for secrets loop), and `clan` CLI in PATH.
- Provider-agnostic: Use with AWS, Cloudflare, etc., in your root.

## Usage
Just import the module like in the example below:

```hcl
# examples/basic/main.tf (complete single file)

terraform {
  required_version = ">= 1.4.0"

  required_providers {
    hetznercloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.36"
    }
  }
}

provider "hetznercloud" {
  token = var.hetzner_token  # Uses HETZNER_TOKEN env var if not set
}

# Variables with defaults
variable "hetzner_token" {
  description = "Hetzner API token (prefer env: HETZNER_TOKEN)"
  type        = string
  sensitive   = true
  default     = ""  # Forces env var
}

variable "location" {
  description = "Hetzner location"
  type        = string
  default     = "fsn1"
}

variable "server_type" {
  description = "Server type (cx11 for cheap)"
  type        = string
  default     = "cx11"
}

resource "hcloud_server" "example_vm" {
  name        = "clan-test-server"
  image       = "ubuntu-22.04"
  server_type = var.server_type
  location    = var.location

  # Optional: Add SSH key (uncomment and add to Hetzner console)
  # ssh_keys = [<name_of_your_uploaded_key>]
}

# Locals: Simple outputs (implicit dep on server)
locals {
  outputs_to_store = {
    server = {
      id     = hcloud_server.example_vm.id
      ipv6   = element(coalescelist(hcloud_server.example_vm.ipv6_address, ["none"]), 0)
      status = hcloud_server.example_vm.status
    }
  }

  secrets_to_store = {
    hetzner_token = var.hetzner_token  # Store the token as secret (just an example)
  }
}
# Module call
module "clan_outputs" {
  source = "https://github.com/Mikilio/terraform-clan-vars"

  outputs_to_store = local.outputs_to_store
  secrets_to_store = local.secrets_to_store
}
```
