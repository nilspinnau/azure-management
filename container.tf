

resource "random_string" "container_registry" {
  length  = 30
  special = false
  upper   = false
  numeric = false
}

module "container_registry" {
  count = var.container_registry.enabled == true ? 1 : 0

  source  = "Azure/avm-res-containerregistry-registry/azurerm"
  version = "0.1.0"
  # insert the 2 required variables here

  name                = "cr${random_string.container_registry.result}"
  location            = var.location
  resource_group_name = var.resource_group_name

  sku             = var.container_registry.config.sku
  georeplications = var.container_registry.config.georeplications

  private_endpoints = var.container_registry.config.private_endpoints

  anonymous_pull_enabled = false
  data_endpoint_enabled  = false

  public_network_access_enabled = var.container_registry.config.public_network_access_enabled

  diagnostic_settings = var.container_registry.config.diagnostic_settings.enabled == true ? {
    workspace_resource_id = try(coalesce(var.container_registry.config.diagnostic_settings.workspace_id, try(azurerm_log_analytics_workspace.default.0.id, null)), null)
  } : null
}
