resource "azurerm_maintenance_configuration" "default" {
  count = var.patching.enabled == true ? 1 : 0

  name                = "patch-${var.resource_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  scope      = "InGuestPatch"
  visibility = "Custom"

  in_guest_user_patch_mode = "User"

  window {
    duration             = "04:00"
    recur_every          = "1Month Second Tuesday Offset2"
    start_date_time      = "2024-08-22 00:00"
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

resource "azurerm_maintenance_assignment_dynamic_scope" "example" {
  count = var.patching.enabled == true && var.patching.dynamic_scope != null ? 1 : 0

  name                         = "all"
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