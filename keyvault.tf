data "azurerm_client_config" "current" {

}
resource "azurerm_key_vault" "default" {
  count = var.key_vault != null ? 1 : 0

  name                = "kv-${var.resource_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = var.key_vault.sku_name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  enable_rbac_authorization       = true
  enabled_for_deployment          = var.key_vault.enabled_for_deployment
  enabled_for_disk_encryption     = var.key_vault.disk_encryption_set_enabled
  enabled_for_template_deployment = var.key_vault.enabled_for_template_deployment
  public_network_access_enabled   = var.key_vault.public_network_access_enabled
  purge_protection_enabled        = var.key_vault.purge_protection_enabled
  soft_delete_retention_days      = var.key_vault.soft_delete_retention_days
  tags                            = var.tags

  # Only one network_acls block is allowed.
  # Create it if the variable is not null.
  dynamic "network_acls" {
    for_each = var.key_vault.network_acls

    content {
      bypass                     = network_acls.value.bypass
      default_action             = network_acls.value.default_action
      ip_rules                   = network_acls.value.ip_rules
      virtual_network_subnet_ids = network_acls.value.virtual_network_subnet_ids
    }
  }
}

resource "azurerm_key_vault_key" "cmk" {
  count = var.key_vault != null && try(var.key_vault.disk_encryption_set_enabled, false) == true ? 1 : 0

  name         = "cmk-disk-encryption-set"
  key_vault_id = azurerm_key_vault.default.0.id

  key_opts = ["decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
  "wrapKey", ]
  key_type = "RSA"
  key_size = 2048

  tags = var.tags
}

resource "azurerm_disk_encryption_set" "default" {
  count = var.key_vault != null && try(var.key_vault.disk_encryption_set_enabled, false) == true ? 1 : 0

  name                = "dse-${var.resource_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location


  key_vault_key_id          = azurerm_key_vault_key.cmk[0].id
  auto_key_rotation_enabled = true

  encryption_type = "EncryptionAtRestWithPlatformAndCustomerKeys"

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "encryption_set" {
  count = var.key_vault != null && try(var.key_vault.disk_encryption_set_enabled, false) == true ? 1 : 0

  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_disk_encryption_set.default.0.identity[0].principal_id

  scope = azurerm_key_vault.default[0].id
}
