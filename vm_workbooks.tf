resource "random_uuid" "workbook" {
  for_each = { for k, workbook_uri in local.workbook_uris : k => workbook_uri }
}


data "http" "workbook_raw" {
  for_each = { for k, workbook_uri in local.workbook_uris : k => workbook_uri }

  url = each.value
}

resource "azurerm_application_insights_workbook" "vm_management" {
  for_each = { for k, workbook_uri in local.workbook_uris : k => workbook_uri }

  name = random_uuid.workbook[each.key].result

  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = each.key
  data_json           = jsonencode(data.http.workbook_raw[each.key].response_body)
}


locals {
  workbook_uris = {
    "vmvitalsigns" = "https://raw.githubusercontent.com/microsoft/AzureMonitorCommunity/master/Azure%20Services/Virtual%20machines/Workbooks/Virtual%20Machines%20-%20Vital%20Signs.workbook"
  }
}
