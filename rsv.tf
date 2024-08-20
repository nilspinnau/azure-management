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


# automation account for recovery runbooks and automatic extension updates
resource "azurerm_role_assignment" "aa_contributor" {
  count = var.recovery_vault.enabled == true && var.recovery_vault.config.automation_account.enabled == true ? 1 : 0

  scope                = azurerm_automation_account.default.0.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_recovery_services_vault.default.0.identity.0.principal_id
}

resource "azurerm_automation_account" "default" {
  count = var.recovery_vault.enabled == true && var.recovery_vault.config.automation_account.enabled == true ? 1 : 0

  name                = module.naming.automation_account.name
  location            = var.location
  resource_group_name = var.resource_group_name

  public_network_access_enabled = true
  local_authentication_enabled  = false
  sku_name                      = "Basic"
}


############
# Key vault Disk Encryption

# This is for Azure Disk Encryption
resource "azurerm_role_assignment" "storage_blob_contributor" {
  for_each = { for k, principal_id in var.recovery_vault.config.storage_account.other_vault_principal_ids : k => principal_id if var.recovery_vault.enabled == true }

  scope                = azurerm_storage_account.staging.0.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "storage_contributor" {
  for_each = { for k, principal_id in var.recovery_vault.config.storage_account.other_vault_principal_ids : k => principal_id if var.recovery_vault.enabled == true }

  scope                = azurerm_storage_account.staging.0.id
  role_definition_name = "Contributor"
  principal_id         = each.value
}

data "azuread_service_principal" "backup_mgmt_serv" {
  count = var.key_vault.enabled == true && var.recovery_vault.enabled == true ? 1 : 0

  display_name = "Backup Management Service"
}


locals {
  bms_key_vault_role_assignments = concat(var.recovery_vault.config.disk_encryption.other_key_vault_ids, var.recovery_vault.config.disk_encryption.local_key_vault_enabled == true && var.key_vault.enabled == true ? [module.keyvault.0.resource_id] : [])
}

resource "azurerm_role_assignment" "backup_mgmt_service_keyvault" {
  count = var.recovery_vault.enabled == true ? length(local.bms_key_vault_role_assignments) : 0

  scope                = local.bms_key_vault_role_assignments[count.index]
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azuread_service_principal.backup_mgmt_serv.0.object_id
}

resource "azurerm_role_assignment" "backup_mgmt_service_staging_account" {
  count = var.recovery_vault.enabled == true ? 1 : 0

  scope                = azurerm_storage_account.staging.0.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_service_principal.backup_mgmt_serv.0.object_id
}


##### 
# Diagnostics


data "azurerm_monitor_diagnostic_categories" "rsv" {
  count = var.recovery_vault.enabled == true && var.recovery_vault.config.diagnostic_settings.enabled == true ? 1 : 0

  resource_id = azurerm_recovery_services_vault.default.0.id
}


locals {
  bcdr_diagnostics_workspace_id = try(coalesce(var.recovery_vault.config.diagnostic_settings.workspace_id, try(azurerm_log_analytics_workspace.default.0.id, null)), null)
}

resource "azurerm_monitor_diagnostic_setting" "rsv" {
  count = var.recovery_vault.enabled == true && var.recovery_vault.config.diagnostic_settings.enabled == true ? 1 : 0

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


# staging storage account
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

  https_traffic_only_enabled        = true
  infrastructure_encryption_enabled = true

  min_tls_version = "TLS1_2"

  public_network_access_enabled = var.recovery_vault.config.storage_account.public_network_access_enabled
  dynamic "network_rules" {
    for_each = var.recovery_vault.config.storage_account.network_rules != null ? { this = var.recovery_vault.config.storage_account.network_rules } : {}
    content {
      bypass                     = network_rules.value.bypass
      default_action             = network_rules.value.default_action
      ip_rules                   = network_rules.value.ip_rules
      virtual_network_subnet_ids = network_rules.value.virtual_network_subnet_ids
    }
  }

  tags = var.tags
}