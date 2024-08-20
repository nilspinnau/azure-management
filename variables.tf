
variable "location" {
  type        = string
  description = "Determines in which Azure region the resources should be deployed in."
}

variable "resource_group_name" {
  type     = string
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
      # enable_sharing = optional(bool, false)
      # sharing = optional(object({
      #   permission = optional(string, "Private")
      #   community_gallery = optional(object({
      #     eula            = string
      #     prefix          = string
      #     publisher_email = string
      #     publisher_uri   = string
      #   }))
      # }), {})
      description = optional(string, "")
      tags        = optional(map(string))
    }), {})
  })
  default  = {}
  nullable = false
}

variable "backup_vault" {
  type = object({
    enabled = optional(bool, false)
    config = optional(object({
      policies = optional(list(object({
        name                            = string
        type                            = optional(string, "disk")
        backup_repeating_time_intervals = optional(list(string), ["R/2021-05-19T00:00:00+00:00/PT1H"])
        default_retention_duration      = optional(string, "P2W")
        time_zone                       = optional(string, "UTC")
        retention_rule = optional(list(object({
          name     = string
          duration = optional(string, "P2W")
          priority = string
          criteria = object({
            absolute_criteria      = optional(string, "FirstOfDay")
            days_of_month          = optional(string)
            days_of_week           = optional(string)
            months_of_year         = optional(string)
            scheduled_backup_times = optional(string)
            weeks_of_month         = optional(list(string))
          })
          life_cycle = optional(object({
            data_store_type = optional(string, "VaultStore")
            duration        = string
            }), {
            data_store_type = "VaultStore"
            duration        = "P2W"
          })
        })), [])
      })), [])
      retention_duration_in_days = optional(number, 14)
      redundancy                 = optional(string, "GeoRedundant")
      datastore_type             = optional(string, "OperationalStore")
      soft_delete                = optional(string, "Off")
      diagnostic_settings = optional(object({
        enabled      = optional(bool, false)
        enabled_log  = optional(map(string))
        metric       = optional(map(string))
        workspace_id = optional(string, "")
      }), {})
    }), {})
  })
  validation {
    condition     = anytrue([var.backup_vault.enabled == false, try(contains(["LocallyRedundant", "ZoneRedundant", "GeoRedundant"], var.backup_vault.config.redundancy), false)])
    error_message = "Choose between: 'LocallyRedundant', 'ZoneRedundant', 'GeoRedundant'"
  }
  default  = {}
  nullable = false
}

variable "recovery_vault" {
  type = object({
    enabled = optional(bool, false)
    config = optional(object({
      policies = optional(list(object({
        resource_group = optional(object({
          suffix = optional(string, null)
          prefix = string
        }))
        name                           = string
        instant_restore_retention_days = number
        time_zone                      = optional(string, "UTC")
        backup = optional(object({
          frequency     = optional(string, "Daily")
          time          = optional(string, "00:00")
          hour_interval = optional(number, 12)
          weekdays      = optional(set(string), ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturyday", "Sunday"])
        }), {})
        retention_daily = optional(object({
          count = optional(number, 7)
        }), {})
        retention_weekly = optional(object({
          count    = number
          weekdays = optional(set(string), ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturyday", "Sunday"])
        }))
        retention_monthly = optional(object({
          count    = number
          weekdays = optional(set(string), ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturyday", "Sunday"])
          weeks    = set(string)
        }))
        retention_yearly = optional(object({
          count    = number
          weekdays = optional(set(string), ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturyday", "Sunday"])
          weeks    = set(string)
          months   = set(string)
        }))
      })), [])
      storage_account = optional(object({
        network_rules = optional(object({
          bypass                     = optional(list(string), [])
          default_action             = optional(string, "Deny")
          ip_rules                   = optional(list(string), [])
          virtual_network_subnet_ids = optional(list(string), [])
        }), null)
        public_network_access_enabled = optional(bool, true)
        other_vault_principal_ids     = optional(list(string), [])
      }), {})
      automation_account = optional(object({
        enabled           = optional(bool, true)
        recovery_runbooks = optional(list(string), [])
      }), {})
      cross_region_restore_enabled  = optional(bool, true)
      public_network_access_enabled = optional(bool, false)
      storage_mode_type             = optional(string, "GeoRedundant")
      soft_delete_enabled           = optional(bool, false)

      disk_encryption = optional(object({
        local_key_vault_enabled = optional(bool, true)
        other_key_vault_ids     = optional(list(string), [])
      }), {})

      diagnostic_settings = optional(object({
        enabled      = optional(bool, false)
        enabled_log  = optional(map(string))
        metric       = optional(map(string))
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
      })), {})
    }), {})
  })
  validation {
    condition     = anytrue([var.recovery_vault.enabled == false, try(contains(["LocallyRedundant", "ZoneRedundant", "GeoRedundant"], var.recovery_vault.config.storage_mode_type), false)])
    error_message = "Choose between: 'LocallyRedundant', 'ZoneRedundant', 'GeoRedundant'"
  }
  default  = {}
  nullable = false
}


variable "key_vault" {
  type = object({
    enabled = optional(bool, false)
    config = optional(object({
      public_network_access_enabled   = optional(bool, false)
      sku_name                        = optional(string, "standard")
      enabled_for_disk_encryption     = optional(bool, true)
      enabled_for_deployment          = optional(bool, false)
      enabled_for_template_deployment = optional(bool, false)
      disk_encryption_set_enabled     = optional(bool, true)
      diagnostic_settings = optional(object({
        enabled      = optional(bool, false)
        workspace_id = optional(string, "")
      }), {})
      keys = optional(map(object({
        name     = string
        key_type = string
        key_opts = optional(list(string), ["sign", "verify"])

        key_size        = optional(number, null)
        curve           = optional(string, null)
        not_before_date = optional(string, null)
        expiration_date = optional(string, null)
        tags            = optional(map(any), null)

        role_assignments = optional(map(object({
          role_definition_id_or_name             = string
          principal_id                           = string
          description                            = optional(string, null)
          skip_service_principal_aad_check       = optional(bool, false)
          condition                              = optional(string, null)
          condition_version                      = optional(string, null)
          delegated_managed_identity_resource_id = optional(string, null)
          principal_type                         = optional(string, null)
        })), {})

        rotation_policy = optional(object({
          automatic = optional(object({
            time_after_creation = optional(string, null)
            time_before_expiry  = optional(string, null)
          }), null)
          expire_after         = optional(string, null)
          notify_before_expiry = optional(string, null)
        }), null)
      })), {})
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
      }), {})
      }), {
      zones = []
    })
  })
  default  = {}
  nullable = false
}


variable "automanage" {
  type = object({
    enabled = optional(bool, false)
    config = optional(object({
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
    }), {})
  })
  default = {
    enabled = false
  }
}