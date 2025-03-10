

resource "random_string" "container_registry" {
  length  = 30
  special = false
  upper   = false
  numeric = false
}

resource "azurerm_container_registry" "default" {
  count = var.container_registry != null ? 1 : 0

  name                = "cr${random_string.container_registry.result}"
  location            = var.location
  resource_group_name = var.resource_group_name

  sku = var.container_registry.sku

  dynamic "georeplications" {
    for_each = var.container_registry.georeplications
    content {
      regional_endpoint_enabled = geo_replications.value.regional_endpoint_enabled
      location                  = geo_replications.value.location
      zone_redundancy_enabled   = geo_replications.value.zone_redundancy_enabled
    }
  }

  public_network_access_enabled = var.container_registry.public_network_access_enabled
  network_rule_bypass_option    = var.container_registry.network_rule_bypass_option

  identity {
    type = "SystemAssigned"
  }

  admin_enabled             = var.container_registry.admin_enabled
  anonymous_pull_enabled    = false
  data_endpoint_enabled     = var.container_registry.data_endpoint_enabled
  export_policy_enabled     = var.container_registry.export_policy_enabled
  quarantine_policy_enabled = var.container_registry.quarantine_policy_enabled

  zone_redundancy_enabled = var.container_registry.zone_redundancy_enabled

  trust_policy = [{
    enabled = false
  }]
  retention_policy = [{
    days    = 30
    enabled = true
  }]

  tags = var.tags
}

resource "azurerm_private_endpoint" "container_registry" {
  for_each = { for k, v in try(var.container_registry.private_endpoints, {}) : k => v }

  location                      = coalesce(each.value.location, var.location)
  name                          = coalesce(each.value.name, "pep-${azurerm_container_registry.default[0].name}")
  resource_group_name           = coalesce(each.value.resource_group_name, var.resource_group_name)
  subnet_id                     = each.value.subnet_resource_id
  custom_network_interface_name = each.value.network_interface_name

  private_service_connection {
    is_manual_connection           = false
    name                           = coalesce(each.value.private_service_connection_name, "pse-${azurerm_container_registry.default[0].name}")
    private_connection_resource_id = azurerm_container_registry.default[0].id
    subresource_names              = ["registry"]
  }
  dynamic "ip_configuration" {
    for_each = each.value.ip_configurations

    content {
      name               = ip_configuration.value.name
      private_ip_address = ip_configuration.value.private_ip_address
      member_name        = "registry"
      subresource_name   = "registry"
    }
  }

  lifecycle {
    ignore_changes = [private_dns_zone_group]
  }

  tags = var.tags
}