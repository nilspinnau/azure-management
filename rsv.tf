resource "azurerm_recovery_services_vault" "rsv" {
  count = var.bcdr.enabled == true ? 1 : 0

  name                = module.naming.recovery_services_vault.unique_name
  resource_group_name = var.resource_group_name
  location            = var.location

  sku = "Standard" #"RS0" for LRS

  cross_region_restore_enabled = var.bcdr.config.replication_type == "GeoRedundant" ? var.bcdr.config.cross_region_restore_enabled : false
  storage_mode_type            = var.bcdr.config.replication_type

  soft_delete_enabled = true # deactivate soft delete for dev environment

  identity {
    type = "SystemAssigned"
  }

  monitoring {
    alerts_for_critical_operation_failures_enabled = true
  }

  public_network_access_enabled = true

  tags = var.tags
}


data "azuread_service_principal" "backup_mgmt_serv" {
  count = var.key_vault.enabled == true && var.bcdr.enabled == true ? 1 : 0

  display_name = "Backup Management Service"
}

resource "azurerm_role_assignment" "rsv_keyvault" {
  count                = var.key_vault.enabled == true && var.bcdr.enabled == true ? 1 : 0
  scope                = module.keyvault.0.resource_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azuread_service_principal.backup_mgmt_serv.0.object_id
}


data "azurerm_monitor_diagnostic_categories" "rsv" {
  count = var.monitoring.enabled == true && var.bcdr.enabled == true ? 1 : 0

  resource_id = azurerm_recovery_services_vault.rsv.0.id
}


resource "azurerm_monitor_diagnostic_setting" "rsv" {
  count = var.monitoring.enabled == true && var.bcdr.enabled == true ? 1 : 0

  name                           = "mon-"
  target_resource_id             = azurerm_recovery_services_vault.rsv.0.id
  log_analytics_destination_type = "Dedicated"
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.default.0.id

  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.rsv.0.log_category_types
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = data.azurerm_monitor_diagnostic_categories.rsv.0.metrics
    content {
      category = metric.value
    }
  }
}


# storage account required for the 
resource "azurerm_storage_account" "staging" {
  count = var.bcdr.enabled == true ? 1 : 0

  name                = "${module.naming.storage_account.unique_name}stg"
  location            = var.location
  resource_group_name = var.resource_group_name

  account_kind = "StorageV2"
  account_tier = "Standard"

  access_tier              = "Hot"
  account_replication_type = "LRS"

  cross_tenant_replication_enabled = false
  allow_nested_items_to_be_public  = false

  shared_access_key_enabled = true

  sas_policy {
    # 10 min max for sas tokens
    expiration_period = "00.00:10:00"
    expiration_action = "Log"
  }

  enable_https_traffic_only         = true
  infrastructure_encryption_enabled = true

  min_tls_version = "TLS1_2"

  public_network_access_enabled = false
  network_rules {
    bypass                     = ["AzureServices", "Metrics", "Logging"]
    default_action             = "Deny"
    virtual_network_subnet_ids = []
    ip_rules                   = []
  }

  tags = var.tags
}