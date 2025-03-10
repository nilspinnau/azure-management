

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
  value = var.shared_image_gallery.enabled == true ? {
    resource_id = azurerm_shared_image_gallery.default.0.id
    name        = azurerm_shared_image_gallery.default.0.unique_name
  } : null
}


output "disk_encryption_set" {
  value = var.key_vault != null && try(var.key_vault.disk_encryption_set_enabled, false) == true ? {
    resource_id = azurerm_disk_encryption_set.default.0.id
    name        = azurerm_disk_encryption_set.default.0.name
  } : null
}


output "dns" {
  value = { for dns in module.dns : dns.name => dns }
}

output "container_registry" {
  value = var.container_registry != null ? {
    resource_id = azurerm_container_registry.default.0.id
    name        = azurerm_container_registry.default.0.name
  } : null
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


output "automanage" {
  value = {
    # if we do not configure custom, use the azure best practices
    configuration_id = try(azapi_resource.automanage.0.id, "/providers/Microsoft.Automanage/bestPractices/AzureBestPracticesProduction")
  }
}

output "patching" {
  value = {
    # if we do not configure custom, use the azure best practices
    schedule_name = local.schedule_name
    schedule_id   = var.patching.enabled ? azapi_resource.update_configuration.0.id : null
  }
}

output "shared_image_gallery" {
  value = var.shared_image_gallery.enabled == true ? {
    resource_id = azurerm_shared_image_gallery.default.0.id
    name        = azurerm_shared_image_gallery.default.0.name
  } : null
}