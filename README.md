# Terraform Clan Vars Module

This Terraform module automates the storage of non-secret variables and secrets into Clan after infrastructure creation. It runs as the final step in `terraform apply` (via a dependency guard) to ensure all resources are provisioned first.

- **Non-secrets (`vars_to_store`)**: Stores string values per machine using `echo "value" | clan vars set <machine> terraform/<var-key>`. Supports targeting specific machines or skipping (empty list).
- **Secrets (`secrets_to_store`)**: Stores sensitive string values with user/host scoping using `echo "value" | clan secrets set --user <user1> --user <user2> ... --machine <host1> ... terraform/<secret-key>`. Flags are built dynamically from lists; skips if both users and hosts are empty.
- **Validation**: Dynamically fetches valid users and machines from `clan secrets users list` and `clan secrets machines list` during `plan`. Fails early if inputs don't match (via `check` blocks).

The module is provider-agnostic—use it after any resources (e.g., Hetzner, AWS) by calling it last in your root module.

## Requirements
- Terraform >= 1.5.0 (for `check` blocks; fallback to locals with `error()` for older versions).
- `bash` and `jq` (for the validation script).
- Clan CLI installed and clan repo set up (in PATH; supports `clan secrets users/machines list` and `set` commands).
- No external providers needed beyond your infrastructure ones.

## Usage

Call the module after your resources. Reference outputs/locals in the inputs to store dynamic values (e.g., server IDs). The dependency guard ensures it runs last.

### Example: Hetzner Server with Clan Storage
This creates a basic Hetzner VM, then stores its details as non-secrets (per machine) and the API token as a secret (global, via empty lists).

```hcl
# main.tf (complete single file example)

terraform {
  required_version = ">= 1.5.0"

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

# Variables
variable "hetzner_token" {
  description = "Hetzner API token (prefer env: HETZNER_TOKEN)"
  type        = string
  sensitive   = true
  default     = ""
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

variable "target_machines" {
  description = "Machines to deploy vars to (from Clan)"
  type        = list(string)
  default     = ["machine1", "machine2"]  # Replace with your Clan machines
}

# Infrastructure
resource "hcloud_server" "example_vm" {
  name        = "clan-test-server"
  image       = "ubuntu-22.04"
  server_type = var.server_type
  location    = var.location

  # Optional: Add SSH key (uncomment and add to Hetzner console)
  # ssh_keys = [hcloud_ssh_key.example.id]
}

# Module call (runs last)
module "clan_vars" {
  source = "../.."  # Or "https://github.com/Mikilio/terraform-clan-vars" for remote

  vars_to_store = {
    server_id = {
      value    = hcloud_server.example_vm.id  # Dynamic value
      machines = var.target_machines  # Store on specific machines
    }
    server_status = {
      value    = hcloud_server.example_vm.status
      machines = var.target_machines
    }
    # For global (all machines): Use machines = [] and handle in module if needed
  }

  secrets_to_store = {
    hetzner_token = {
      value  = var.hetzner_token  # Sensitive; masked
      users  = []  # Empty: No user scoping
      hosts  = []  # Empty: No host scoping (adjust if Clan requires at least one)
    }
  }
}
```
