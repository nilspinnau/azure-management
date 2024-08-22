data "azurerm_client_config" "current" {

}

module "keyvault" {
  count = var.key_vault.enabled == true ? 1 : 0

  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "0.7.1"

  name                = module.naming.key_vault.name_unique # this has to be a unique name across all azure, maybe it makes sense to use something more unique here
  location            = var.location
  resource_group_name = var.resource_group_name

  enable_telemetry = false
  tenant_id        = data.azurerm_client_config.current.tenant_id

  public_network_access_enabled = var.key_vault.config.public_network_access_enabled
  network_acls                  = var.key_vault.config.network_acls

  enabled_for_disk_encryption     = var.key_vault.config.enabled_for_disk_encryption
  enabled_for_deployment          = var.key_vault.config.enabled_for_deployment
  enabled_for_template_deployment = var.key_vault.config.enabled_for_template_deployment

  purge_protection_enabled   = var.key_vault.config.disk_encryption_set_enabled || var.key_vault.config.purge_protection_enabled # has to be enabled if we use disk encryption set
  soft_delete_retention_days = var.key_vault.config.soft_delete_retention_days

  sku_name = var.key_vault.config.sku_name

  keys = local.keys

  private_endpoints = var.key_vault.config.private_endpoints

  diagnostic_settings = var.key_vault.config.diagnostic_settings.enabled == true ? {
    workspace_resource_id = try(coalesce(var.key_vault.config.diagnostic_settings.workspace_id, try(azurerm_log_analytics_workspace.default.0.id, null)), null)
  } : null
}


locals {
  keys = merge(var.key_vault.config.keys, var.key_vault.config.disk_encryption_set_enabled == true ? { "cmk-disk-encryption-set" = {
    key_opts = tolist([
      "decrypt",
      "encrypt",
      "sign",
      "unwrapKey",
      "verify",
      "wrapKey",
    ])
    key_size = 2048
    key_type = "RSA"
    name     = "cmk-disk-encryption-set"
  } } : null)
}

resource "azurerm_disk_encryption_set" "default" {
  count = var.key_vault.enabled == true && var.key_vault.config.disk_encryption_set_enabled == true ? 1 : 0

  name                = module.naming.disk_encryption_set.name
  resource_group_name = var.resource_group_name
  location            = var.location


  key_vault_key_id          = module.keyvault.0.keys_resource_ids["cmk-disk-encryption-set"].versionless_id
  auto_key_rotation_enabled = true

  encryption_type = "EncryptionAtRestWithPlatformAndCustomerKeys"

  identity {
    type = "SystemAssigned"
  }

  depends_on = [module.keyvault]
}

resource "azurerm_role_assignment" "encryption_set" {
  count = var.key_vault.enabled == true && var.key_vault.config.disk_encryption_set_enabled == true ? 1 : 0

  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_disk_encryption_set.default.0.identity[0].principal_id

  scope = module.keyvault.0.resource_id
}
