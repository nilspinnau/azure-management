

module "dns" {
  for_each = { for dns_zone in var.dns.config.zones : dns_zone.name => dns_zone if var.dns.enabled == true }

  source  = "Azure/avm-res-network-privatednszone/azurerm"
  version = "0.1.2"

  domain_name           = each.value.name
  virtual_network_links = each.value.virtual_network_links

  resource_group_name = local.resource_group_name

  tags = var.tags
}
