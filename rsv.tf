resource "azurerm_recovery_services_vault" "default" {
  count = var.recovery_vault.enabled == true ? 1 : 0

  name                = module.naming.recovery_services_vault.name
  resource_group_name = var.resource_group_name
  location            = var.location

  sku = "Standard" #"RS0" for LRS

  cross_region_restore_enabled = var.recovery_vault.config.storage_mode_type == "GeoRedundant" ? var.recovery_vault.config.cross_region_restore_enabled : false
  storage_mode_type            = var.recovery_vault.config.storage_mode_type

  soft_delete_enabled = var.recovery_vault.config.soft_delete_enabled # deactivate soft delete for dev environment

  identity {
    type = "SystemAssigned"
  }

  monitoring {
    alerts_for_critical_operation_failures_enabled = true
    alerts_for_all_job_failures_enabled            = false
  }

  public_network_access_enabled = var.recovery_vault.config.public_network_access_enabled

  tags = var.tags
}



#############
# Backup policies

resource "azurerm_backup_policy_vm" "default" {
  for_each = { for policy in var.recovery_vault.config.policies : policy.name => policy }

  name                = each.value.name
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.default.0.name

  timezone = each.value.time_zone

  instant_restore_retention_days = each.value.instant_restore_retention_days #snapshots to save, default=2

  instant_restore_resource_group {
    prefix = try(each.value.resource_group.prefix, "${module.naming.resource_group.name}-backup")
    suffix = try(each.value.resource_group.suffix, null)
  }

  policy_type = "V2"

  dynamic "backup" {
    for_each = each.value.backup != null ? [1] : []
    content {
      frequency     = each.value.backup.frequency
      time          = each.value.backup.time
      hour_interval = each.value.backup.frequency == "Hourly" ? each.value.backup.hour_interval : null
      weekdays      = each.value.backup.frequency == "Weekly" ? each.value.backup.weekdays : null
    }
  }

  dynamic "retention_daily" {
    for_each = each.value.retention_daily != null ? [1] : []
    content {
      count = each.value.retention_daily.count
    }
  }
  dynamic "retention_weekly" {
    for_each = each.value.retention_weekly != null ? [1] : []
    content {
      count    = each.value.retention_weekly.count
      weekdays = each.value.retention_weekly.weekdays
    }
  }
  dynamic "retention_monthly" {
    for_each = each.value.retention_monthly != null ? [1] : []
    content {
      count    = each.value.retention_monthly.count
      weekdays = each.value.retention_monthly.weekdays
      weeks    = each.value.retention_monthly.weeks
    }
  }
  dynamic "retention_yearly" {
    for_each = each.value.retention_yearly != null ? [1] : []
    content {
      count    = each.value.retention_yearly.count
      weekdays = each.value.retention_yearly.weekdays
      weeks    = each.value.retention_yearly.weeks
      months   = each.value.retention_yearly.months
    }
  }
}




################
# Recovery Policies










############
# Key vault Disk Encryption

# This is for Azure Disk Encryption
data "azuread_service_principal" "backup_mgmt_serv" {
  count = var.key_vault.enabled == true && var.recovery_vault.enabled == true ? 1 : 0

  display_name = "Backup Management Service"
}

resource "azurerm_role_assignment" "rsv_keyvault" {
  count                = var.key_vault.enabled == true && var.recovery_vault.enabled == true ? 1 : 0
  scope                = module.keyvault.0.resource_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azuread_service_principal.backup_mgmt_serv.0.object_id
}



##### 
# Diagnostics


data "azurerm_monitor_diagnostic_categories" "rsv" {
  count = var.recovery_vault.enabled == true && var.recovery_vault.config.diagnostic_settings.enabled == true && local.bcdr_diagnostics_workspace_id != null ? 1 : 0

  resource_id = azurerm_recovery_services_vault.default.0.id
}


locals {
  bcdr_diagnostics_workspace_id = try(coalesce(var.recovery_vault.config.diagnostic_settings.workspace_id, try(azurerm_log_analytics_workspace.default.0.id, null)), null)
}

resource "azurerm_monitor_diagnostic_setting" "rsv" {
  count = var.recovery_vault.enabled == true && var.recovery_vault.config.diagnostic_settings.enabled == true && local.bcdr_diagnostics_workspace_id != null ? 1 : 0

  name                           = "mondiag-${basename(local.bcdr_diagnostics_workspace_id)}"
  target_resource_id             = azurerm_recovery_services_vault.default.0.id
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
  count = var.recovery_vault.enabled == true ? length(var.recovery_vault.config.private_endpoints) * 2 : 0

  location                      = coalesce(var.recovery_vault.config.private_endpoints[floor(count.index / 2)].location, var.location)
  name                          = var.recovery_vault.config.private_endpoints[floor(count.index / 2)].name != null ? var.recovery_vault.config.private_endpoints[floor(count.index / 2)].name : "pe-${azurerm_recovery_services_vault.default.0.name}"
  resource_group_name           = var.recovery_vault.config.private_endpoints[floor(count.index / 2)].resource_group_name != null ? var.recovery_vault.config.private_endpoints[floor(count.index / 2)].resource_group_name : var.resource_group_name
  subnet_id                     = var.recovery_vault.config.private_endpoints[floor(count.index / 2)].subnet_resource_id
  custom_network_interface_name = var.recovery_vault.config.private_endpoints[floor(count.index / 2)].network_interface_name
  tags                          = var.recovery_vault.config.private_endpoints[floor(count.index / 2)].tags

  private_service_connection {
    is_manual_connection           = false
    name                           = var.recovery_vault.config.private_endpoints[floor(count.index / 2)].private_service_connection_name != null ? var.recovery_vault.config.private_endpoints[floor(count.index / 2)].private_service_connection_name : "pse-${azurerm_recovery_services_vault.default.0.name}"
    private_connection_resource_id = azurerm_recovery_services_vault.default.0.id
    subresource_names              = ["AzureSiteRecovery", "AzureBackup"]
  }
  dynamic "ip_configuration" {
    for_each = var.recovery_vault.config.private_endpoints[floor(count.index / 2)].ip_configurations

    content {
      name               = ip_configuration.value.name
      private_ip_address = ip_configuration.value.private_ip_address
      member_name        = "rsv"
      subresource_name   = "rsv"
    }
  }
  dynamic "private_dns_zone_group" {
    for_each = length(var.recovery_vault.config.private_endpoints[floor(count.index / 2)].private_dns_zone_resource_ids) > 0 ? ["this"] : []

    content {
      name                 = var.recovery_vault.config.private_endpoints[floor(count.index / 2)].private_dns_zone_group_name
      private_dns_zone_ids = var.recovery_vault.config.private_endpoints[floor(count.index / 2)].private_dns_zone_resource_ids
    }
  }
}


# storage account required for the 
resource "azurerm_storage_account" "staging" {
  count = var.recovery_vault.enabled == true ? 1 : 0

  name                = module.naming.storage_account.name_unique
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
    virtual_network_subnet_ids = try(var.recovery_vault.config.private_endpoints.subnet_resource_ids, [])
    ip_rules                   = []
  }

  tags = var.tags
}