

output "recovery_services_vault" {
  value = var.recovery_vault.enabled == true ? {
    resource_id         = azurerm_recovery_services_vault.default.0.id
    vault_name          = azurerm_recovery_services_vault.default.0.name
    resource_group_name = azurerm_recovery_services_vault.default.0.resource_group_name
    principal_id        = azurerm_recovery_services_vault.default.0.identity.0.principal_id
    policy_ids          = { for policy in azurerm_backup_policy_vm.default : policy.name => policy.id }
    storage_account = {
      resource_id = try(module.staging_storage.0.id, null)
    }
    automation_account = {
      resource_id = try(azurerm_automation_account.default.0.id, null)
    }
  } : null
}


output "backup_services_vault" {
  value = var.backup_vault.enabled == true ? {
    resource_id         = azurerm_data_protection_backup_vault.default.0.id
    vault_name          = azurerm_data_protection_backup_vault.default.0.name
    resource_group_name = azurerm_data_protection_backup_vault.default.0.resource_group_name
    principal_id        = azurerm_data_protection_backup_vault.default.0.identity.0.principal_id
    policy_ids          = { for policy in azurerm_data_protection_backup_policy_disk.default : policy.name => policy.id }
  } : null
}

output "key_vault" {
  value = var.key_vault != null ? {
    resource_id         = azurerm_key_vault.default.0.id
    vault_name          = azurerm_key_vault.default.0.name
    resource_group_name = azurerm_key_vault.default.0.resource_group_name
  } : null
}


output "image_registry" {
  value = {
    resource_id = try(azurerm_shared_image_gallery.default.0.id, null)
    name        = try(azurerm_shared_image_gallery.default.0.unique_name, null)
  }
}


output "disk_encryption_set" {
  value = {
    resource_id = try(azurerm_disk_encryption_set.default.0.id, null)
    name        = try(azurerm_disk_encryption_set.default.0.name, null)
  }
}

output "container_registry" {
  value = {
    resource_id = try(azurerm_container_registry.default.0.id, null)
    name        = try(azurerm_container_registry.default.0.name, null)
  }
}


output "monitoring" {
  value = var.monitoring.enabled == true ? {
    log_analytics_workspace = {
      resource_id  = azurerm_log_analytics_workspace.default.0.id
      workspace_id = azurerm_log_analytics_workspace.default.0.workspace_id
      location     = azurerm_log_analytics_workspace.default.0.location
      name         = azurerm_log_analytics_workspace.default.0.name
    }
    storage_account = var.monitoring.config.storage_account.enabled == true ? {
      resource_id = module.monitor_storage.0.id
      name        = module.monitor_storage.0.name
      key         = module.monitor_storage.0.primary_access_key
    } : null
  } : null
  sensitive = true
}

output "patching" {
  value = {
    schedule = {
      name             = try(azurerm_maintenance_configuration.default.0.name, null)
      id               = try(azurerm_maintenance_configuration.default.0.id, null)
      is_dynamic_scope = var.patching.dynamic_scope != null
    }
    function = {
      resource_id     = try(module.functionapp.0.id, null)
      name            = try(module.functionapp.0.name, null)
      identity        = try(module.functionapp.0.identity, null)
      service_plan_id = try(module.serviceplan.0.service_plan.id, null)
    }
  }
}

output "shared_image_gallery" {
  value = var.shared_image_gallery.enabled == true ? {
    resource_id = azurerm_shared_image_gallery.default.0.id
    name        = azurerm_shared_image_gallery.default.0.name
  } : null
}



output "automation" {
  value = var.automation.enabled == true || var.recovery_vault.config.automation_account.enabled == true ? {
    resource_id  = try(azurerm_automation_account.default.0.id, null)
    name         = try(azurerm_automation_account.default.0.name, null)
    principal_id = try(azurerm_automation_account.default.0.identity.0.principal_id, null)
  } : null
}