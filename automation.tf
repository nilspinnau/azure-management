

resource "azurerm_automation_account" "default" {
  count = var.automation.enabled == true || var.recovery_vault.config.automation_account.enabled == true ? 1 : 0

  name                = "aa-${var.resource_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  sku_name = "Basic"

  identity {
    type = "SystemAssigned"
  }

  local_authentication_enabled  = false
  public_network_access_enabled = var.automation.public_network_access_enabled

  tags = var.tags
}


resource "azurerm_automation_variable_string" "default" {
  for_each = { for k, v in var.automation.variables : k => v if v.type == "string" }

  automation_account_name = azurerm_automation_account.default.0.name
  resource_group_name     = var.resource_group_name

  name  = each.key
  value = each.value.value
}

resource "azurerm_automation_variable_bool" "default" {
  for_each = { for k, v in var.automation.variables : k => v if v.type == "bool" }

  automation_account_name = azurerm_automation_account.default.0.name
  resource_group_name     = var.resource_group_name

  name  = each.key
  value = each.value.value
}
resource "azurerm_automation_variable_int" "default" {
  for_each = { for k, v in var.automation.variables : k => v if v.type == "int" }

  automation_account_name = azurerm_automation_account.default.0.name
  resource_group_name     = var.resource_group_name

  name  = each.key
  value = each.value.value
}

# automation account for recovery runbooks and automatic extension updates
resource "azurerm_role_assignment" "aa_contributor" {
  count = var.recovery_vault.enabled == true && var.recovery_vault.config.automation_account.enabled == true ? 1 : 0

  scope                = azurerm_automation_account.default.0.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_recovery_services_vault.default.0.identity.0.principal_id
}



resource "azurerm_private_endpoint" "automation" {
  for_each = { for k, v in try(var.automation.private_endpoints, {}) : k => v }

  location                      = coalesce(each.value.location, var.location)
  name                          = coalesce(each.value.name, "pep-${azurerm_automation_account.default.0.name}")
  resource_group_name           = coalesce(each.value.resource_group_name, var.resource_group_name)
  subnet_id                     = each.value.subnet_resource_id
  custom_network_interface_name = each.value.network_interface_name

  private_service_connection {
    is_manual_connection           = false
    name                           = coalesce(each.value.private_service_connection_name, "pse-${azurerm_automation_account.default.0.name}")
    private_connection_resource_id = azurerm_automation_account.default.0.id
    subresource_names              = ["automation"]
  }
  dynamic "ip_configuration" {
    for_each = each.value.ip_configurations

    content {
      name               = ip_configuration.value.name
      private_ip_address = ip_configuration.value.private_ip_address
      subresource_name   = "automation"
    }
  }

  lifecycle {
    ignore_changes = [private_dns_zone_group]
  }

  tags = var.tags
}