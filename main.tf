resource "terraform_data" "dependency_guard" {
  count = max([length(var.vars_to_store), length(var.secrets_to_store)]) > 0 ? 1 : 0

  triggers_replace = {
    vars_hash = sha256(jsonencode(var.vars_to_store))
    secrets_hash = sha256(jsonencode(var.secrets_to_store))  # Full hash; sensitive but hashed
  }

  lifecycle {
    replace_triggered_reruns = true  # Re-run dependents if triggers change
  }
}

resource "null_resource" "store_regular_vars" {
  count = length(var.vars_to_store) > 0 ? 1 : 0

  triggers = {
    vars_hash = sha256(jsonencode(var.vars_to_store))
  }

  provisioner "local-exec" {
    command = <<-EOT
      OUTPUT_JSON=$(echo '${jsonencode(var.vars_to_store)}')
      echo "$OUTPUT_JSON" | clan vars set ${var.vars_key}
    EOT
    interpreter = ["bash", "-c"]
  }

  provisioner "local-exec" {
    when    = destroy
    command = "clan vars unset ${var.vars_key} || true"
    interpreter = ["bash", "-c"]
  }

  depends_on = [terraform_data.dependency_guard]
}

resource "null_resource" "store_secrets" {
  count = length(var.secrets_to_store) > 0 ? 1 : 0

  triggers = {
    secrets_hash = sha256(jsonencode(var.secrets_to_store))
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Requires jq: Loop and set each secret
      echo '${jsonencode(var.secrets_to_store)}' | jq -r 'to_entries[] | "echo \"\$.value)\" | clan vars set --secret ${var.secrets_key_prefix}\$.key)"' | bash
    EOT
    interpreter = ["bash", "-c"]
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Unset all prefixed secret keys
      ${join("\n", [for k in keys(var.secrets_to_store) : "clan vars unset ${var.secrets_key_prefix}${k} || true"])}
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [terraform_data.dependency_guard]
}
