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

# Fetch current var hashes from clan
data "external" "current_var_hashes" {
  for_each = {
    for var_entry in var.vars_to_store :
    sha256(jsonencode({ name = var_entry.name, machines = sort(var_entry.machines) })) => var_entry
  }

  program = ["bash", "-c", <<-EOT
    set -euo pipefail
    
    if [ ${length(each.value.machines)} -eq 0 ]; then
      echo '{"hash": ""}'
      exit 0
    fi
    
    # Get hash of all machine values concatenated (in sorted order)
    hash=""
    for machine in ${join(" ", sort(each.value.machines))}; do
      value=$(clan vars get "$machine" "terraform/${each.value.name}" 2>/dev/null || echo "")
      hash="$hash$value"
    done
    
    if [ -z "$hash" ]; then
      echo '{"hash": "none"}'
    else
      computed_hash=$(echo -n "$hash" | sha256sum | cut -d' ' -f1)
      echo "{\"hash\": \"$computed_hash\"}"
    fi
  EOT
  ]
}

# Fetch current secret hashes from clan
data "external" "current_secret_hashes" {
  for_each = var.secrets_to_store

  program = ["bash", "-c", <<-EOT
    set -euo pipefail
    
    value=$(clan secrets get "${each.key}" 2>/dev/null || echo "")
    
    if [ -z "$value" ]; then
      echo '{"hash": "none"}'
    else
      computed_hash=$(echo -n "$value" | sha256sum | cut -d' ' -f1)
      echo "{\"hash\": \"$computed_hash\"}"
    fi
  EOT
  ]
}

resource "null_resource" "store_vars" {
  for_each = {
    for var_entry in var.vars_to_store :
    sha256(jsonencode({ name = var_entry.name, machines = sort(var_entry.machines) })) => var_entry
  }

  triggers = {
    var_key      = each.value.name
    desired_hash = sha256(join("", [for _ in each.value.machines : each.value.value]))
    current_hash = data.external.current_var_hashes[each.key].result.hash
    machines     = join(",", sort(each.value.machines))
  }

  provisioner "local-exec" {
    command     = <<-EOT
      #!/bin/bash
      set -euo pipefail

      if [ ${length(each.value.machines)} -eq 0 ]; then
        echo "Skipping ${each.key}: No machines."
        exit 0
      fi

      for machine in ${join(" ", sort(each.value.machines))}; do
        echo -n "${each.value.value}" | clan vars set "$machine" "terraform/${each.value.name}"
      done
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [data.external.valid_machines]
}

resource "null_resource" "store_secrets" {
  for_each = var.secrets_to_store

  triggers = {
    key          = each.key
    desired_hash = sha256(each.value.value)
    current_hash = data.external.current_secret_hashes[each.key].result.hash
    users        = join(",", sort(each.value.users))
    hosts        = join(",", sort(each.value.hosts))
  }

  provisioner "local-exec" {
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

  depends_on = [data.external.valid_users, data.external.valid_machines]
}

output "clan_summary" {
  value = {
    vars_deployed    = [for var_entry in var.vars_to_store : var_entry.name]
    secrets_deployed = keys(var.secrets_to_store)
  }
}
