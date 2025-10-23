variable "vars_to_store" {
  description = "Map of regular (non-secret) vars to store as JSON in Clan vars, each with a string value and list of target machines. Example: { debug_mode = { value = 'true', machines = ['server1', 'server2'] } }."
  type = map(object({
    value    = string
    machines = list(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, var_entry in var.vars_to_store : 
      length(var_entry.machines) > 0
    ])
    error_message = "Each var must have a string 'value', and 'machines' must be a list of strings (can be empty)."
  }
}

variable "secrets_to_store" {
  description = "Map of secrets to store individually, each with a value and recipients (users/hosts). Example: { vm_password = { value = 'supersecret', users = ['alice', 'bob'], hosts = ['server1'] } }."
  type = map(object({
    value  = string
    users  = list(string)
    hosts  = list(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, secret in var.secrets_to_store : 
      length(secret.users) + length(secret.hosts) > 0
    ])
    error_message = "Each secret must have a string 'value', and 'users'/'hosts' must be lists of strings (can be empty)."
  }
}

check "validate_vars_machines" {
  assert {
    condition = alltrue([
      for k, var_entry in var.vars_to_store : 
      alltrue([for m in var_entry.machines : contains(local.valid_machines_set, m)])
    ])
    
    error_message = "Invalid machines in vars_to_store: All machines must match output of 'clan secrets machines list'. Found invalid: ${join(", ", flatten([for k, var_entry in var.vars_to_store : [for m in var_entry.machines : m if !contains(local.valid_machines_set, m)]]))}"
  } 
}

check "validate_secrets_users" {
  assert {
    condition = alltrue([
      for k, secret in var.secrets_to_store : 
      alltrue([for u in secret.users : contains(local.valid_users_set, u)])
    ])
    
    error_message = "Invalid users in secrets_to_store: All users must match 'clan secrets users list'. Found invalid: ${join(", ", flatten([for k, secret in var.secrets_to_store : [for u in secret.users : u if !contains(local.valid_users_set, u)]]))}"
  }
}

check "validate_secrets_hosts" {
  assert {
    condition = alltrue([
      for k, secret in var.secrets_to_store : 
      alltrue([for h in secret.hosts : contains(local.valid_machines_set, h)])
    ])
    
    error_message = "Invalid hosts in secrets_to_store: All hosts must match 'clan secrets machines list'. Found invalid: ${join(", ", flatten([for k, secret in var.secrets_to_store : [for h in secret.hosts : h if !contains(local.valid_machines_set, h)]]))}"
  }
}

check "clan_lists_nonempty" {
  assert {
    condition = length(local.valid_users_set) > 0 || length(local.valid_machines_set) > 0  # Or stricter
    error_message = "Clan CLI returned empty users/machines lists—check auth/installation."
  }
}
