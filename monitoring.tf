
resource "azurerm_log_analytics_workspace" "default" {
  count = var.monitoring.enabled == true ? 1 : 0

  name                = module.naming.log_analytics_workspace.name_unique
  resource_group_name = var.resource_group_name
  location            = var.location

  local_authentication_disabled = true

  sku               = "PerGB2018"
  retention_in_days = 30

  tags = var.tags
}

# storage account required for the 
resource "azurerm_storage_account" "monitoring" {
  count = var.monitoring.enabled == true ? 1 : 0

  name                = module.naming.storage_account.name_unique
  location            = var.location
  resource_group_name = var.resource_group_name

  account_kind = "StorageV2"
  account_tier = "Standard"

  access_tier              = "Hot"
  account_replication_type = "LRS"

  cross_tenant_replication_enabled = false
  allow_nested_items_to_be_public  = false

  shared_access_key_enabled = true # IaaSDiagnostics uses key access

  https_traffic_only_enabled        = true
  infrastructure_encryption_enabled = true

  min_tls_version = "TLS1_2"

  public_network_access_enabled = true
  # https://learn.microsoft.com/en-us/azure/network-watcher/network-watcher-nsg-flow-logging-cli
  network_rules {
    bypass                     = ["AzureServices"]
    default_action             = "Deny"
    virtual_network_subnet_ids = []
    ip_rules                   = []
  }

  tags = var.tags
}
