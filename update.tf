resource "azurerm_maintenance_configuration" "default" {
  count = var.patching.enabled == true ? 1 : 0

  name                = "patch-${var.resource_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  scope      = "InGuestPatch"
  visibility = "Custom"

  in_guest_user_patch_mode = "User"

  window {
    duration             = "01:30"
    recur_every          = "6Hour"            # every 6 hours # "1Month Second Tuesday Offset2" # patch tuesday
    start_date_time      = "2024-08-22 12:00" # "2024-08-22 00:00"
    time_zone            = "W. Europe Standard Time"
    expiration_date_time = null
  }

  install_patches {
    linux {
      classifications_to_include = [
        "Critical",
        "Security",
        "Other"
      ]
      package_names_mask_to_exclude = null
      package_names_mask_to_include = null
    }
    windows {
      classifications_to_include = [
        "Critical",
        "Security",
        "UpdateRollup",
        "FeaturePack",
        "ServicePack",
        "Definition",
        "Tools",
        "Updates"
      ]
      kb_numbers_to_exclude = null
      kb_numbers_to_include = null
    }
    reboot = "IfRequired"
  }

  tags = var.tags
}

resource "azurerm_maintenance_assignment_dynamic_scope" "default" {
  count = var.patching.enabled == true && var.patching.dynamic_scope != null ? 1 : 0

  name                         = "patching-dynamic-scope-${var.resource_suffix}"
  maintenance_configuration_id = azurerm_maintenance_configuration.default.0.id

  filter {
    locations       = var.patching.dynamic_scope.locations
    os_types        = var.patching.dynamic_scope.os_types
    resource_groups = var.patching.dynamic_scope.resource_groups
    resource_types  = var.patching.dynamic_scope.resource_types
    tag_filter      = var.patching.dynamic_scope.tag_filter
    dynamic "tags" {
      for_each = var.patching.dynamic_scope.tags
      content {
        tag    = tags.value.tag
        values = tags.value.values
      }
    }
  }
}

resource "azurerm_eventgrid_system_topic" "update" {
  count = var.patching.enabled == true && var.patching.events.enabled == true ? 1 : 0

  name                = "evhg-patching-event-subscription-${var.resource_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  source_arm_resource_id = azurerm_maintenance_configuration.default.0.id
  topic_type             = "Microsoft.Maintenance.MaintenanceConfigurations"
}

resource "azurerm_eventgrid_system_topic_event_subscription" "update" {
  for_each = {
    for k, v in var.patching.events.event_subscriptions : k => v
    if var.patching.enabled == true &&
    var.patching.events.enabled == true
  }

  name                = each.key
  resource_group_name = var.resource_group_name
  system_topic        = azurerm_eventgrid_system_topic.update.0.id

  event_delivery_schema = "CloudEventSchemaV1_0"

  azure_function_endpoint {
    function_id = "${module.functionapp.0.id}/functions/${each.value.function_name}"
  }

  included_event_types = each.value.included_event_types
}


module "serviceplan" {
  count = var.patching.enabled == true && var.patching.events.enabled == true ? 1 : 0

  source = "github.com/nilspinnau/azure-modules.git/app-service"

  resource_group_name = var.resource_group_name
  resource_suffix     = var.resource_suffix
  location            = var.location

  service_plan = {
    os_type = "Windows"
    sku     = "Y1"
  }

  zone_redundant = false
  tags           = var.tags
}

module "storage" {
  count = var.patching.enabled == true && var.patching.events.enabled == true ? 1 : 0

  source = "github.com/nilspinnau/azure-modules.git/storage-account"

  name                = "stgpatch"
  resource_group_name = var.resource_group_name
  resource_suffix     = var.resource_suffix
  location            = var.location

  account_replication_type = "LRS"
  enable_sas_key           = true
  public_access = {
    enabled = true
  }

  tags = var.tags
}

module "functionapp" {
  count = var.patching.enabled == true && var.patching.events.enabled == true ? 1 : 0

  source = "github.com/nilspinnau/azure-modules.git/functionapp"

  resource_group_name = var.resource_group_name
  resource_suffix     = var.resource_suffix
  location            = var.location

  service_plan_id = module.serviceplan.0.service_plan.id
  os_type         = "Windows"
  storage_account = {
    name       = module.storage.0.name
    id         = module.storage.0.id
    access_key = module.storage.0.primary_access_key
  }

  app_settings = {
    WEBSITE_RUN_FROM_PACKAGE       = 1
    SCM_DO_BUILD_DURING_DEPLOYMENT = true
  }
  site_config = {
    always_on = false
  }

  zip_deploy_file = var.patching.events.zip_deploy_file

  tags = var.tags
}

resource "azurerm_role_assignment" "update" {
  for_each = {
    for k, v in var.patching.events.role_assignments : k => v
    if var.patching.enabled == true &&
    var.patching.events.enabled == true
  }

  role_definition_name = each.value.role_definition_name
  scope                = each.value.scope
  principal_id         = module.functionapp.0.identity.0.principal_id
}