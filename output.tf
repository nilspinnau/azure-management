

output "recovery_services_vault" {
  value = var.recovery_vault.enabled == true ? {
    resource_id         = azurerm_recovery_services_vault.default.0.id
    vault_name          = azurerm_recovery_services_vault.default.0.name
    resource_group_name = azurerm_recovery_services_vault.default.0.resource_group_name
    principal_id        = azurerm_recovery_services_vault.default.0.identity.0.principal_id
    policy_ids          = { for policy in azurerm_backup_policy_vm.default : policy.name => policy.id }
    storage_account = {
      resource_id = azurerm_storage_account.staging.0.id
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
  value = try(module.keyvault.0, null)
}


output "image_registry" {
  value = var.shared_image_gallery.enabled == true ? {
    resource_id = azurerm_shared_image_gallery.default.0.id
    name        = azurerm_shared_image_gallery.default.0.unique_name
  } : null
}


output "disk_encryption_set" {
  value = var.key_vault.enabled == true && var.key_vault.config.disk_encryption_set_enabled == true ? {
    resource_id = azurerm_disk_encryption_set.default.0.id
    name        = azurerm_disk_encryption_set.default.0.name
  } : null
}


output "dns" {
  value = { for dns in module.dns : dns.name => dns }
}

output "container_registry" {
  value = try(module.container_registry, null)
}


output "monitoring" {
  value = var.monitoring.enabled == true ? {
    log_analytics_workspace = {
      resource_id  = azurerm_log_analytics_workspace.default.0.id
      workspace_id = azurerm_log_analytics_workspace.default.0.workspace_id
      location     = azurerm_log_analytics_workspace.default.0.location
      name         = azurerm_log_analytics_workspace.default.0.name
    }
    storage_account = {
      resource_id = azurerm_storage_account.monitoring.0.id
      name        = azurerm_storage_account.monitoring.0.name
      key         = azurerm_storage_account.monitoring.0.primary_access_key
    }
  } : null
  sensitive = true
}


output "automanage" {
  value = {
    # if we do not configure custom, use the azure best practices
    configuration_id = try(azapi_resource.automanage.0.id, "/providers/Microsoft.Automanage/bestPractices/AzureBestPracticesProduction")
  }
}