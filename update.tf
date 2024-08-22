
locals {
  schedule_name = var.patching.enabled == true ? "patch-${join("-", var.resource_suffix)}" : ""
}

resource "azapi_resource" "update_configuration" {
  count = var.patching.enabled == true ? 1 : 0

  type      = "Microsoft.Maintenance/maintenanceConfigurations@2023-04-01"
  name      = local.schedule_name
  parent_id = data.azurerm_resource_group.default.id
  location  = var.location

  body = jsonencode({
    properties = {
      extensionProperties = {
        InGuestPatchMode = "User"
      }
      installPatches = {
        linuxParameters = {
          classificationsToInclude = [
            "Critical",
            "Security"
          ]
          packageNameMasksToExclude = null
          packageNameMasksToInclude = null
        }
        rebootSetting = "RebootIfRequired"
        windowsParameters = {
          classificationsToInclude = [
            "Critical",
            "Security",
            "UpdateRollup"
          ]
          kbNumbersToExclude = null
          kbNumbersToInclude = null
        }
      }
      maintenanceScope = "InGuestPatch"
      maintenanceWindow = {
        duration           = "03:55"
        recurEvery         = "1Month Second Tuesday Offset2"
        startDateTime      = "2024-08-22 00:00"
        timeZone           = "W. Europe Standard Time"
        expirationDateTime = null
      }
    }
  })
}