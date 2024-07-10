
variable "location" {
  type        = string
  description = "Determines in which Azure region the resources should be deployed in."
}

variable "resource_group_name" {
  type     = string
  nullable = false
  default  = ""
}

variable "resource_group_id" {
  type     = string
  nullable = false
  default  = ""
}

variable "resource_suffix" {
  type = list(string)
}


variable "tags" {
  type        = map(any)
  default     = {}
  description = "Tags to set on the resources."
}

variable "bcdr" {
  type = object({
    enabled = optional(bool, false)
    config = optional(object({
      cross_region_restore_enabled = optional(bool, true)
      replication_type             = optional(string, "GeoRedundant")
      subnet_ids                   = optional(list(string))
    }))
  })
  validation {
    condition     = anytrue([var.bcdr.enabled == false, try(contains(["LocallyRedundant", "ZoneRedundant", "GeoRedundant"], var.bcdr.config.replication_type), false)])
    error_message = "Choose between: 'LocallyRedundant', 'ZoneRedundant', 'GeoRedundant'"
  }
  default = {
    enabled = false
  }
}

variable "key_vault" {
  type = object({
    enabled = optional(bool, false)
    config = optional(object({
      public_network_access_enabled = optional(bool, false)
      network_acls = optional(object({
        bypass                     = optional(string, "None")
        default_action             = optional(string, "Deny")
        ip_rules                   = optional(list(string), [])
        virtual_network_subnet_ids = optional(list(string), [])
      }), {})
      private_endpoints = map(object({
        name                                    = optional(string, null)
        tags                                    = optional(map(string), null)
        subnet_resource_id                      = string
        private_dns_zone_group_name             = optional(string, "default")
        private_dns_zone_resource_ids           = optional(set(string), [])
        application_security_group_associations = optional(map(string), {})
        private_service_connection_name         = optional(string, null)
        network_interface_name                  = optional(string, null)
        location                                = optional(string, null)
        resource_group_name                     = optional(string, null)
        ip_configurations = optional(map(object({
          name               = string
          private_ip_address = string
        })), {})
      }))
    }))
  })
  default = {
    enabled = false
  }
}

variable "automanage" {
  type = object({
    enabled = optional(bool, false)
    config = optional(object({
      name                           = string
      custom_log_analytics_workspace = optional(bool, true)
      enable_antimalware             = optional(bool, true)
      enable_baseline_security       = optional(bool, true)
      assignment_type                = optional(string, "ApplyAndMonitor") # "Audit", "ApplyAndAutoCorrect"
      enable_backup                  = optional(bool, false)
      enable_boot_diagnostics        = optional(bool, true)
      enable_change_tracking         = optional(bool, true)
      enable_defender                = optional(bool, true)
      enable_log_analytics           = optional(bool, true)
      enable_updatemanagement        = optional(bool, true)
      enable_vminsights              = optional(bool, true)
      enable_admin_center            = optional(bool, true)
      }), {
      name                           = "custom"
      custom_log_analytics_workspace = true
      enable_antimalware             = true
      enable_baseline_security       = true
      assignment_type                = "ApplyAndMonitor"
      enable_backup                  = false
      enable_boot_diagnostics        = true
      enable_change_tracking         = true
      enable_defender                = true
      enable_log_analytics           = true
      enable_updatemanagement        = true
      enable_vminsights              = true
      enable_admin_center            = true
    })
  })
  default = {
    enabled = false
  }
}

variable "monitoring" {
  type = object({
    enabled = optional(bool, true)
    config = optional(object({
      private_endpoints = map(object({
        name                                    = optional(string, null)
        tags                                    = optional(map(string), null)
        subnet_resource_id                      = string
        private_dns_zone_group_name             = optional(string, "default")
        private_dns_zone_resource_ids           = optional(set(string), [])
        application_security_group_associations = optional(map(string), {})
        private_service_connection_name         = optional(string, null)
        network_interface_name                  = optional(string, null)
        location                                = optional(string, null)
        resource_group_name                     = optional(string, null)
        ip_configurations = optional(map(object({
          name               = string
          private_ip_address = string
        })), {})
      }))
    }))
  })
  default = {
    enabled = true
  }
  nullable = false
}

variable "container_registry" {
  type = object({
    enabled = optional(bool, true)
    config = optional(object({
      sku                           = optional(string, "Basic")
      public_network_access_enabled = optional(bool, false)
      georeplications = list(object({
        location                  = string
        regional_endpoint_enabled = optional(bool, false)
        tags                      = optional(map(any), {})
        zone_redundancy_enabled   = optional(bool, true)
      }))
      private_endpoints = map(object({
        name                                    = optional(string, null)
        tags                                    = optional(map(string), null)
        subnet_resource_id                      = string
        private_dns_zone_group_name             = optional(string, "default")
        private_dns_zone_resource_ids           = optional(set(string), [])
        application_security_group_associations = optional(map(string), {})
        private_service_connection_name         = optional(string, null)
        network_interface_name                  = optional(string, null)
        location                                = optional(string, null)
        resource_group_name                     = optional(string, null)
        ip_configurations = optional(map(object({
          name               = string
          private_ip_address = string
        })), {})
      }))
    }))
  })
  default = {
    enabled = false
  }
  nullable = false
}

variable "dns" {
  type = object({
    enabled = optional(bool, false)
    config = optional(object({
      zones = list(object({
        name = string
        virtual_network_links = list(object({
          vnetid           = string
          vnetlinkname     = string
          autoregistration = optional(bool, false)
        }))
      }))
    }))
  })
}