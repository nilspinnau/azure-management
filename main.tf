


resource "azurerm_resource_group" "default" {
  count = var.resource_group_name == "" ? 1 : 0

  name     = module.naming.resource_group.name
  location = var.location
}

locals {
  resource_group_name = var.resource_group_name == "" ? azurerm_resource_group.default.0.name : var.resource_group_name
}


module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.3.0"

  suffix = var.resource_suffix
}