resource "random_uuid" "workbook" {
  for_each = { for k, workbook_uri in local.workbook_uris_to_deploy : k => workbook_uri }
}


data "http" "workbook_raw" {
  for_each = { for k, workbook_uri in local.workbook_uris_to_deploy : k => workbook_uri }

  url = each.value
}

resource "azurerm_application_insights_workbook" "vm_management" {
  for_each = { for k, workbook_uri in local.workbook_uris_to_deploy : k => workbook_uri }

  name = random_uuid.workbook[each.key].result

  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = each.key
  data_json           = jsonencode(data.http.workbook_raw[each.key].response_body)
}


locals {
  workbook_uris = {
    "VirtualMachines-VitalSigns" = "https://raw.githubusercontent.com/microsoft/AzureMonitorCommunity/master/Azure%20Services/Virtual%20machines/Workbooks/Virtual%20Machines%20-%20Vital%20Signs.workbook"
    "HighCpuVMs-TopProcesses"    = "https://raw.githubusercontent.com/microsoft/AzureMonitorCommunity/master/Azure%20Services/Virtual%20machines/Workbooks/Top%20processes%20on%20VMs%20with%20High%20CPU.workbook"
    "VM-Uptime"                  = "https://raw.githubusercontent.com/microsoft/AzureMonitorCommunity/master/Azure%20Services/Virtual%20machines/Workbooks/Virtual%20Machine%20Uptime.workbook"
    "Antimalware_Assessment"     = "https://raw.githubusercontent.com/microsoft/AzureMonitorCommunity/master/Azure%20Services/Virtual%20machines/Workbooks/Antimalware%20Assessment.workbook"
    "Update-Assessment"          = "https://raw.githubusercontent.com/microsoft/AzureMonitorCommunity/master/Azure%20Services/Virtual%20machines/Workbooks/Update%20Assessment.workbook"
    "DiskSpace-Trend"            = "https://raw.githubusercontent.com/microsoft/AzureMonitorCommunity/master/Azure%20Services/Virtual%20machines/Workbooks/Disk%20Space%20Report%20with%20Trend.workbook"
    "Windows-Events"             = "https://raw.githubusercontent.com/microsoft/AzureMonitorCommunity/master/Azure%20Services/Virtual%20machines/Workbooks/Windows%20event%20logs.workbook"
    "Linux-Syslog"               = "https://github.com/microsoft/AzureMonitorCommunity/blob/master/Azure%20Services/Virtual%20machines/Workbooks/Syslog.workbook"
  }

  workbook_uris_to_deploy = { for k, v in local.workbook_uris : k => v if contains(var.exclude_workbooks, k) }
}
