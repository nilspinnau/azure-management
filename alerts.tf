
resource "azurerm_monitor_action_group" "default" {
  count = var.service_health.enabled == true ? 1 : 0

  name                = "ag-servicehealth-${var.resource_suffix}"
  location            = "global"
  resource_group_name = var.resource_group_name

  short_name = "svchealth"

  dynamic "email_receiver" {
    for_each = var.service_health.config.email_receivers
    content {
      name          = email_receiver.value.name
      email_address = email_receiver.value.email_address
    }
  }
}

resource "azurerm_monitor_activity_log_alert" "servicehealth" {
  count = var.service_health.enabled == true ? 1 : 0

  name                = "alert-servicehealth"
  resource_group_name = var.resource_group_name
  location            = "global"

  action {
    action_group_id = azurerm_monitor_action_group.default.0.id
  }

  criteria {
    category = "ServiceHealth"
    levels   = ["Informational", "Warning", "Error", "Critical"]
    service_health {
      events = ["Incident", "Maintenance"]
    }
  }

  enabled = true

  scopes = ["/subscriptions/${data.azurerm_client_config.current.subscription_id}"]
}