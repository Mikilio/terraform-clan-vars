data "external" "valid_users" {
  program = ["bash", "${path.module}/scripts/fetch_clan_list.sh", "users"]
}

data "external" "valid_machines" {
  program = ["bash", "${path.module}/scripts/fetch_clan_list.sh", "machines"]
}

locals {
  valid_users_set    = length(data.external.valid_users.result["result"]) > 0 ? toset(split(",", data.external.valid_users.result["result"])) : toset([])
  valid_machines_set = length(data.external.valid_machines.result["result"]) > 0 ? toset(split(",", data.external.valid_machines.result["result"])) : toset([])
}

resource "terraform_data" "dependency_guard" {
  count = length(var.vars_to_store) + length(var.secrets_to_store) > 0 ? 1 : 0 # Simplified (maps always >=0, but this works)

  triggers_replace = {
    vars_hash         = sha256(jsonencode(var.vars_to_store))                                                                # Keep for vars
    secrets_structure = sha256(jsonencode({ for k, s in var.secrets_to_store : k => { users = s.users, hosts = s.hosts } })) # Hash only non-sensitive parts
  }
}

resource "null_resource" "store_vars" {
  for_each = {
    for var_entry in var.vars_to_store :
    sha256(jsonencode({ name = var_entry.name, machines = sort(var_entry.machines) })) => var_entry
  }

  triggers = {
    var_key   = each.value.name
    var_value = each.value.value
    machines  = join(",", sort(each.value.machines))
  }

  provisioner "local-exec" {
    command     = <<-EOT
      #!/bin/bash
      set -euo pipefail

      if [ ${length(each.value.machines)} -eq 0 ]; then
        echo "Skipping ${each.key}: No machines."
        exit 0
      fi

      for machine in ${join(" ", each.value.machines)}; do
        echo -n "${each.value.value}" | clan vars set "$machine" "terraform/${each.value.name}"
      done
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [data.external.valid_machines, terraform_data.dependency_guard]
}

resource "null_resource" "store_secrets" {
  for_each = var.secrets_to_store

  triggers = {
    key   = each.key
    value = sha256(each.value.value)
    users = join(",", sort(each.value.users))
    hosts = join(",", sort(each.value.hosts))
  }

  provisioner "local-exec" {
    # Pre-compute flags in HCL to avoid fragile Bash loops and word-splitting issues
    command     = <<-EOT
      #!/bin/bash
      set -euo pipefail

      %{~if length(each.value.users) > 0 || length(each.value.hosts) > 0~}
      echo -n "${base64encode(sensitive(each.value.value))}" | base64 -d | clan secrets set ${join(" ", [for user in each.value.users : "--user ${user}"])} ${join(" ", [for host in each.value.hosts : "--machine ${host}"])} ${each.key}
      %{~else~}
      echo "Skipping ${each.key}: No users or hosts."
      %{~endif~}
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [data.external.valid_users, data.external.valid_machines, terraform_data.dependency_guard]
}

output "clan_summary" {
  value = {
    vars_deployed    = [for var_entry in var.vars_to_store : var_entry.name]
    secrets_deployed = keys(var.secrets_to_store)
  }
}
