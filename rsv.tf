resource "azurerm_recovery_services_vault" "rsv" {
  count = var.bcdr.enabled == true ? 1 : 0

  name                = module.naming.recovery_services_vault.unique_name
  resource_group_name = local.resource_group_name
  location            = var.location

  sku = "Standard" #"RS0" for LRS

  cross_region_restore_enabled = var.bcdr.config.replication_type == "GeoRedundant" ? var.bcdr.config.cross_region_restore_enabled : false
  storage_mode_type            = var.bcdr.config.replication_type

  soft_delete_enabled = false # deactivate soft delete for dev environment

  identity {
    type = "SystemAssigned"
  }

  monitoring {
    alerts_for_critical_operation_failures_enabled = true
    alerts_for_all_job_failures_enabled            = false
  }

  public_network_access_enabled = var.bcdr.config.public_network_access_enabled

  tags = var.tags
}

# This is for Azure Disk Encryption
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
  count = var.bcdr.enabled == true && var.bcdr.config.diagnostic_settings.enabled == true && local.bcdr_diagnostics_workspace_id != null ? 1 : 0

  resource_id = azurerm_recovery_services_vault.rsv.0.id
}


locals {
  bcdr_diagnostics_workspace_id = try(coalesce(var.bcdr.config.diagnostic_settings.workspace_id, try(azurerm_log_analytics_workspace.default.0.id, null)), null)
}

resource "azurerm_monitor_diagnostic_setting" "rsv" {
  count = var.bcdr.enabled == true && var.bcdr.config.diagnostic_settings.enabled == true && local.bcdr_diagnostics_workspace_id != null ? 1 : 0

  name                           = "mondiag-${basename(local.bcdr_diagnostics_workspace_id)}"
  target_resource_id             = azurerm_recovery_services_vault.rsv.0.id
  log_analytics_destination_type = "Dedicated"
  log_analytics_workspace_id     = local.bcdr_diagnostics_workspace_id

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

## private endpoint
resource "azurerm_private_endpoint" "this" {
  count = var.bcdr.enabled == true ? length(var.bcdr.config.private_endpoints * 2) : 0

  location                      = coalesce(var.bcdr.config.private_endpoints[floor(count.index / 2)].location, var.location)
  name                          = var.bcdr.config.private_endpoints[floor(count.index / 2)].name != null ? var.bcdr.config.private_endpoints[floor(count.index / 2)].name : "pe-${azurerm_recovery_services_vault.rsv.0.name}"
  resource_group_name           = var.bcdr.config.private_endpoints[floor(count.index / 2)].resource_group_name != null ? var.bcdr.config.private_endpoints[floor(count.index / 2)].resource_group_name : local.resource_group_name
  subnet_id                     = var.bcdr.config.private_endpoints[floor(count.index / 2)].subnet_resource_id
  custom_network_interface_name = var.bcdr.config.private_endpoints[floor(count.index / 2)].network_interface_name
  tags                          = var.bcdr.config.private_endpoints[floor(count.index / 2)].tags

  private_service_connection {
    is_manual_connection           = false
    name                           = var.bcdr.config.private_endpoints[floor(count.index / 2)].private_service_connection_name != null ? var.bcdr.config.private_endpoints[floor(count.index / 2)].private_service_connection_name : "pse-${azurerm_recovery_services_vault.rsv.0.name}"
    private_connection_resource_id = azurerm_recovery_services_vault.rsv.0.id
    subresource_names              = ["AzureSiteRecovery", "AzureBackup"]
  }
  dynamic "ip_configuration" {
    for_each = var.bcdr.config.private_endpoints[floor(count.index / 2)].ip_configurations

    content {
      name               = ip_configuration.value.name
      private_ip_address = ip_configuration.value.private_ip_address
      member_name        = "rsv"
      subresource_name   = "rsv"
    }
  }
  dynamic "private_dns_zone_group" {
    for_each = length(var.bcdr.config.private_endpoints[floor(count.index / 2)].private_dns_zone_resource_ids) > 0 ? ["this"] : []

    content {
      name                 = var.bcdr.config.private_endpoints[floor(count.index / 2)].private_dns_zone_group_name
      private_dns_zone_ids = var.bcdr.config.private_endpoints[floor(count.index / 2)].private_dns_zone_resource_ids
    }
  }
}


# storage account required for the 
resource "azurerm_storage_account" "staging" {
  count = var.bcdr.enabled == true ? 1 : 0

  name                = "${module.naming.storage_account.unique_name}stg"
  location            = var.location
  resource_group_name = local.resource_group_name

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