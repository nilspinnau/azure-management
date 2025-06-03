
resource "azurerm_log_analytics_workspace" "default" {
  count = var.monitoring.enabled == true ? 1 : 0

  name                = "law-${var.resource_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  local_authentication_disabled = true

  sku               = "PerGB2018"
  retention_in_days = 30

  tags = var.tags
}

# staging storage account
module "monitor_storage" {
  count = var.monitoring.enabled == true && var.monitoring.config.storage_account.enabled == true ? 1 : 0

  source = "github.com/nilspinnau/azure-modules.git/storage-account"

  name                = "stgamon"
  resource_group_name = var.resource_group_name
  resource_suffix     = var.resource_suffix

  location = var.location

  private_endpoints = var.monitoring.config.storage_account.private_endpoints

  private_endpoints_manage_dns_zone_group = true

  public_access = {
    enabled       = var.monitoring.config.storage_account.public_network_access_enabled
    network_rules = var.monitoring.config.storage_account.network_rules
  }

  file_shares     = {}
  containers_list = []

  access_tier              = "Hot"
  account_kind             = "StorageV2"
  account_replication_type = "ZRS"
  account_tier             = "Standard"

  blob_soft_delete_retention_days      = 7
  change_feed_retention_in_days        = 7
  container_soft_delete_retention_days = 7
  enable_change_feed                   = false
  enable_last_access_time              = false
  enable_point_in_time_restore         = false
  enable_versioning                    = false

  enable_advanced_threat_protection = false
  # for perf diagnostics etc
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