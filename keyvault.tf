data "azurerm_client_config" "current" {

}

module "keyvault" {
  count = var.key_vault.enabled == true ? 1 : 0

  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "0.7.1"

  name                = module.naming.key_vault.name
  location            = var.location
  resource_group_name = var.resource_group_name

  enable_telemetry = false
  tenant_id        = data.azurerm_client_config.current.tenant_id

  public_network_access_enabled = var.key_vault.config.public_network_access_enabled
  network_acls                  = var.key_vault.config.network_acls

  enabled_for_disk_encryption     = var.key_vault.config.enabled_for_disk_encryption
  enabled_for_deployment          = var.key_vault.config.enabled_for_deployment
  enabled_for_template_deployment = var.key_vault.config.enabled_for_template_deployment

  sku_name = var.key_vault.config.sku_name

  private_endpoints = var.key_vault.config.private_endpoints

  diagnostic_settings = var.key_vault.config.diagnostic_settings.enabled == true ? {
    workspace_resource_id = try(coalesce(var.key_vault.config.diagnostic_settings.workspace_id, try(azurerm_log_analytics_workspace.default.0.id, null)), null)
  } : null
}

