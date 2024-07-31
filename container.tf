module "container_registry" {
  count = var.container_registry.enabled == true ? 1 : 0

  source  = "Azure/avm-res-containerregistry-registry/azurerm"
  version = "0.1.0"
  # insert the 2 required variables here

  name                = module.naming.container_registry.name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku             = var.container_registry.config.sku
  georeplications = var.container_registry.config.georeplications

  private_endpoints = var.container_registry.config.private_endpoints

  anonymous_pull_enabled = false
  data_endpoint_enabled  = false

  public_network_access_enabled = var.container_registry.config.public_network_access_enabled

  diagnostic_settings = var.monitoring.enabled == true ? {
    workspace_resource_id = azurerm_log_analytics_workspace.default.0.id
  } : null
}
