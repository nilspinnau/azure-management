
resource "azurerm_monitor_action_group" "default" {
  name                = "ag-servicehealth-${var.resource_suffix}"
  location            = var.location
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
  name                = "alert-servicehealth"
  resource_group_name = var.resource_group_name
  location            = var.location

  action {
    action_group_id = azurerm_monitor_action_group.default.id
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