

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.3.0"

  suffix = var.resource_suffix
}


data "azurerm_resource_group" "default" {
  name = var.resource_group_name
}