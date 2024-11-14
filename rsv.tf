resource "azurerm_recovery_services_vault" "default" {
  count = var.recovery_vault.enabled == true ? 1 : 0

  name                = "rsv-${var.resource_suffix}"
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
  for_each = { for policy in var.recovery_vault.config.policies : policy.name => policy if var.recovery_vault.enabled == true }

  name                = each.value.name
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.default.0.name

  timezone = each.value.time_zone

  instant_restore_retention_days = each.value.instant_restore_retention_days #snapshots to save, default=2

  dynamic "instant_restore_resource_group" {
    for_each = each.value.instant_restore_resource_group != null ? [1] : []
    content {
      prefix = instant_restore_resource_group.value.prefix
      suffix = instant_restore_resource_group.value.suffix
    }
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

  name                = "aa-${var.resource_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name

  public_network_access_enabled = true
  local_authentication_enabled  = false
  sku_name                      = "Basic"

  identity {
    type = "SystemAssigned"
  }
}


############
# Key vault Disk Encryption

# This is for Azure Disk Encryption
resource "azurerm_role_assignment" "storage_blob_contributor" {
  for_each = { for k, principal in var.recovery_vault.config.storage_account.other_vault_principals : k => principal.id if var.recovery_vault.enabled == true }

  scope                = module.staging_storage.0.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "storage_contributor" {
  for_each = { for k, principal in var.recovery_vault.config.storage_account.other_vault_principals : k => principal.id if var.recovery_vault.enabled == true }

  scope                = module.staging_storage.0.id
  role_definition_name = "Contributor"
  principal_id         = each.value
}

data "azuread_service_principal" "backup_mgmt_serv" {
  count = var.recovery_vault.enabled == true ? 1 : 0

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

  scope                = module.staging_storage.0.id
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
}
# The PE resource when we are managing the private_dns_zone_group block:
resource "azurerm_private_endpoint" "this" {
  for_each = { for k, v in var.recovery_vault.config.private_endpoints : k => v if var.recovery_vault.config.private_endpoints_manage_dns_zone_group }

  location                      = coalesce(each.value.location, var.location)
  name                          = coalesce(each.value.name, "pep-${each.value.subresource_name}-rsv-${var.resource_suffix}")
  resource_group_name           = coalesce(each.value.resource_group_name, var.resource_group_name)
  subnet_id                     = each.value.subnet_resource_id
  custom_network_interface_name = coalesce(each.value.network_interface_name, "nic-${each.value.subresource_name}-rsv-${var.resource_suffix}")
  tags                          = each.value.tags

  private_service_connection {
    is_manual_connection           = false
    name                           = coalesce(each.value.private_service_connection_name, "pse-${each.value.subresource_name}-rsv-${var.resource_suffix}")
    private_connection_resource_id = module.staging_storage.0.id
    subresource_names              = [each.value.subresource_name] # can anyways only be ever one
  }
  dynamic "ip_configuration" {
    for_each = each.value.ip_configurations

    content {
      name               = ip_configuration.value.name
      private_ip_address = ip_configuration.value.private_ip_address
      member_name        = each.value.subresource_name
      subresource_name   = each.value.subresource_name
    }
  }
  dynamic "private_dns_zone_group" {
    for_each = length(each.value.private_dns_zone_resource_ids) > 0 ? ["this"] : []

    content {
      name                 = each.value.private_dns_zone_group_name
      private_dns_zone_ids = each.value.private_dns_zone_resource_ids
    }
  }
}

# The PE resource when we are managing **not** the private_dns_zone_group block, such as when using Azure Policy:
resource "azurerm_private_endpoint" "this_unmanaged_dns_zone_groups" {
  for_each = { for k, v in var.recovery_vault.config.private_endpoints : k => v if !var.recovery_vault.config.private_endpoints_manage_dns_zone_group }

  location                      = coalesce(each.value.location, var.location)
  name                          = coalesce(each.value.name, "pep-${each.value.subresource_name}-rsv-${var.resource_suffix}")
  resource_group_name           = coalesce(each.value.resource_group_name, var.resource_group_name)
  subnet_id                     = each.value.subnet_resource_id
  custom_network_interface_name = coalesce(each.value.network_interface_name, "nic-${each.value.subresource_name}-rsv-${var.resource_suffix}")
  tags                          = each.value.tags

  private_service_connection {
    is_manual_connection           = false
    name                           = coalesce(each.value.private_service_connection_name, "pse-${each.value.subresource_name}-rsv-${var.resource_suffix}")
    private_connection_resource_id = module.staging_storage.0.id
    subresource_names              = [each.value.subresource_name]
  }
  dynamic "ip_configuration" {
    for_each = each.value.ip_configurations

    content {
      name               = ip_configuration.value.name
      private_ip_address = ip_configuration.value.private_ip_address
      member_name        = each.value.subresource_name
      subresource_name   = ip_configuration.value.subresource_name
    }
  }
}

# staging storage account
module "staging_storage" {
  count = var.recovery_vault.enabled == true ? 1 : 0

  source = "github.com/nilspinnau/azure-modules.git/storage-account"

  name                = "stgarsv"
  resource_group_name = var.resource_group_name
  resource_suffix     = var.resource_suffix
  location            = var.location

  private_endpoints = var.recovery_vault.config.storage_account.private_endpoints

  private_endpoints_manage_dns_zone_group = true

  public_access = {
    enabled       = var.recovery_vault.config.storage_account.public_network_access_enabled
    network_rules = var.recovery_vault.config.storage_account.network_rules
  }

  file_shares     = []
  containers_list = []

  access_tier              = "Cool"
  account_kind             = "StorageV2"
  account_replication_type = "LRS"
  account_tier             = "Standard"

  blob_soft_delete_retention_days      = 2
  change_feed_retention_in_days        = 2
  container_soft_delete_retention_days = 2
  enable_change_feed                   = false
  enable_last_access_time              = false
  enable_point_in_time_restore         = false
  enable_versioning                    = false

  queue_retention_policy_days = 2

  enable_advanced_threat_protection = false
  enable_sas_key                    = true
  min_tls_version                   = "TLS1_2"

  data_lake_gen_2 = {
    enabled = false
    config = {
      sftp_enabled  = false
      nfsv3_enabled = false
    }
  }

  lifecycles = []

  monitoring = {
    enabled = false
  }
}