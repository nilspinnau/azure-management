

output "recovery_services_vault" {
  value = var.bcdr.enabled == true ? {
    resource_id = azurerm_recovery_services_vault.rsv.0.id
    storage_account = {
      resource_id = azurerm_storage_account.staging.0.id
    }
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
    }
    storage_account = {
      resource_id = azurerm_storage_account.monitoring.0.id
    }
  } : null
}