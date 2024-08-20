resource "azurerm_data_protection_backup_vault" "default" {
  count = var.backup_vault.enabled == true ? 1 : 0

  name                = "bvault-${join("-", var.resource_suffix)}"
  resource_group_name = var.resource_group_name
  location            = var.location
  datastore_type      = var.backup_vault.config.datastore_type
  redundancy          = var.backup_vault.config.redundancy

  soft_delete                = var.backup_vault.config.soft_delete
  retention_duration_in_days = var.backup_vault.config.retention_duration_in_days

  identity {
    type = "SystemAssigned"
  }
}



###############
# Policies

resource "azurerm_data_protection_backup_policy_disk" "default" {
  for_each = { for policy in var.backup_vault.config.policies : policy.name => policy if policy.type == "disk" }

  name     = each.value.name
  vault_id = azurerm_data_protection_backup_vault.default.0.id

  backup_repeating_time_intervals = each.value.backup_repeating_time_intervals
  default_retention_duration      = each.value.default_retention_duration
  time_zone                       = each.value.time_zone

  dynamic "retention_rule" {
    for_each = each.value.retention_rule
    content {
      name     = retention_rule.value.name
      duration = retention_rule.value.duration
      priority = retention_rule.value.priority
      criteria {
        absolute_criteria = retention_rule.value.absolute_criteria
      }
    }
  }
}


resource "azurerm_data_protection_backup_policy_blob_storage" "default" {
  for_each = { for policy in var.backup_vault.config.policies : policy.name => policy if policy.type == "blob_storage" }

  name     = each.value.name
  vault_id = azurerm_data_protection_backup_vault.default.0.id

  backup_repeating_time_intervals = each.value.backup_repeating_time_intervals
  time_zone                       = each.value.time_zone

  operational_default_retention_duration = each.value.default_retention_duration
  vault_default_retention_duration       = azurerm_data_protection_backup_vault.default.0.retention_duration_in_days

  dynamic "retention_rule" {
    for_each = each.value.retention_rule
    content {
      name     = retention_rule.value.name
      priority = retention_rule.value.priority
      criteria {
        absolute_criteria      = retention_rule.value.absolute_criteria
        days_of_month          = retention_rule.value.days_of_month
        days_of_week           = retention_rule.value.days_of_week
        months_of_year         = retention_rule.value.months_of_year
        scheduled_backup_times = retention_rule.value.scheduled_backup_times
        weeks_of_month         = retention_rule.value.weeks_of_month
      }
      life_cycle {
        data_store_type = ""
        duration        = ""
      }
    }
  }
}



########################
# Diagnostics




locals {
  backup_vault_diagnostics_workspace_id = try(coalesce(var.backup_vault.config.diagnostic_settings.workspace_id, try(azurerm_log_analytics_workspace.default.0.id, null)), null)
}


data "azurerm_monitor_diagnostic_categories" "backup_vault" {
  count = var.backup_vault.enabled == true && var.backup_vault.config.diagnostic_settings.enabled == true ? 1 : 0

  resource_id = azurerm_data_protection_backup_vault.default.0.id
}

resource "azurerm_monitor_diagnostic_setting" "backup_vault" {
  count = var.backup_vault.enabled == true && var.backup_vault.config.diagnostic_settings.enabled == true ? 1 : 0

  name                           = "mondiag-${basename(local.backup_vault_diagnostics_workspace_id)}"
  target_resource_id             = azurerm_data_protection_backup_vault.default.0.id
  log_analytics_destination_type = "Dedicated"
  log_analytics_workspace_id     = local.backup_vault_diagnostics_workspace_id

  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.backup_vault.0.log_category_types
    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = data.azurerm_monitor_diagnostic_categories.backup_vault.0.metrics
    content {
      category = metric.value
    }
  }
}


