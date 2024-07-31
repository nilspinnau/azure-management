
variable "location" {
  type        = string
  description = "Determines in which Azure region the resources should be deployed in."
}

variable "resource_group_name" {
  type     = string
  default  = ""
  nullable = false
}

variable "resource_suffix" {
  type    = list(string)
  default = []
}


variable "tags" {
  type        = map(any)
  default     = {}
  description = "Tags to set on the resources."
}

variable "shared_image_gallery" {
  type = object({
    enabled = optional(bool, false)
    config = optional(object({
      sharing = optional(object({
        permission = optional(string, "Private")
        community_gallery = optional(object({
          eula            = string
          prefix          = string
          publisher_email = string
          publisher_uri   = string
        }))
      }))
      description = optional(string, "")
      tags        = optional(map(string))
    }), {})
  })
  default  = {}
  nullable = false
}

variable "bcdr" {
  type = object({
    enabled = optional(bool, false)
    config = optional(object({
      cross_region_restore_enabled  = optional(bool, true)
      public_network_access_enabled = optional(bool, false)
      replication_type              = optional(string, "GeoRedundant")
      diagnostic_settings = optional(object({
        enabled      = optional(bool, false)
        enabled_log  = optional(map(string))
        metric       = optional(map(string))
        workspace_id = optional(string, "")
      }))
      private_endpoints = optional(map(object({
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
      })), {})
    }), {})
  })
  validation {
    condition     = anytrue([var.bcdr.enabled == false, try(contains(["LocallyRedundant", "ZoneRedundant", "GeoRedundant"], var.bcdr.config.replication_type), false)])
    error_message = "Choose between: 'LocallyRedundant', 'ZoneRedundant', 'GeoRedundant'"
  }
  default  = {}
  nullable = false
}

variable "key_vault" {
  type = object({
    enabled = optional(bool, false)
    config = optional(object({
      public_network_access_enabled = optional(bool, false)
      diagnostic_settings = optional(object({
        enabled      = optional(bool, false)
        workspace_id = optional(string, "")
      }))
      network_acls = optional(object({
        bypass                     = optional(string, "None")
        default_action             = optional(string, "Deny")
        ip_rules                   = optional(list(string), [])
        virtual_network_subnet_ids = optional(list(string), [])
      }), {})
      private_endpoints = optional(map(object({
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
      })))
    }), {})
  })
  default  = {}
  nullable = false
}

variable "monitoring" {
  type = object({
    enabled = optional(bool, false)
    config = optional(object({

    }))
  })
  default  = {}
  nullable = false
}

variable "container_registry" {
  type = object({
    enabled = optional(bool, false)
    config = optional(object({
      sku                           = optional(string, "Basic")
      public_network_access_enabled = optional(bool, false)
      georeplications = optional(list(object({
        location                  = string
        regional_endpoint_enabled = optional(bool, false)
        tags                      = optional(map(any), {})
        zone_redundancy_enabled   = optional(bool, true)
      })), [])
      diagnostic_settings = optional(object({
        enabled      = optional(bool, false)
        workspace_id = optional(string, "")
      }), {})
      private_endpoints = optional(map(object({
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
      })))
    }), {})
  })
  default  = {}
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
          tags             = map(any)
        }))
      }))
      diagnostic_settings = optional(object({
        enabled      = optional(bool, false)
        workspace_id = optional(string, "")
      }))
      }), {
      zones = []
    })
  })
  default  = {}
  nullable = false
}