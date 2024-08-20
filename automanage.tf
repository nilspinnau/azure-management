
data "azurerm_resource_group" "default" {
  count = var.automanage.enabled == true ? 1 : 0

  name = var.resource_group_name
}

resource "azapi_resource" "automanage" {
  count = var.automanage.enabled == true ? 1 : 0

  type      = "Microsoft.AutoManage/configurationProfiles@2022-05-04"
  name      = "acm-${join("-", var.resource_suffix)}"
  location  = var.location
  parent_id = data.azurerm_resource_group.default.0.id
  body = jsonencode({
    properties = {
      configuration = {
        "Antimalware/Enable" : var.automanage.config.enable_antimalware,
        "Antimalware/EnableRealTimeProtection" : true,
        "Antimalware/RunScheduledScan" : true,
        "Antimalware/ScanType" : "Quick",
        "Antimalware/ScanDay" : "7",
        "Antimalware/ScanTimeInMinutes" : "120",
        "AzureSecurityBaseline/Enable" : var.automanage.config.enable_baseline_security,
        "AzureSecurityBaseline/AssignmentType" : var.automanage.config.assignment_type,
        "Backup/Enable" : var.automanage.config.enable_backup,
        "Backup/PolicyName" : "dailyBackupPolicy",
        "Backup/TimeZone" : "UTC",
        "Backup/InstantRpRetentionRangeInDays" : "2",
        "Backup/SchedulePolicy/ScheduleRunFrequency" : "Daily",
        "Backup/SchedulePolicy/ScheduleRunTimes" : [
          "2017-01-26T00:00:00Z"
        ],
        "Backup/SchedulePolicy/SchedulePolicyType" : "SimpleSchedulePolicy",
        "Backup/RetentionPolicy/RetentionPolicyType" : "LongTermRetentionPolicy",
        "Backup/RetentionPolicy/DailySchedule/RetentionTimes" : [
          "2017-01-26T00:00:00Z"
        ],
        "Backup/RetentionPolicy/DailySchedule/RetentionDuration/Count" : "180",
        "Backup/RetentionPolicy/DailySchedule/RetentionDuration/DurationType" : "Days",
        "BootDiagnostics/Enable" : var.automanage.config.enable_boot_diagnostics,
        "ChangeTrackingAndInventory/Enable" : var.automanage.config.enable_change_tracking,
        "DefenderForCloud/Enable" : var.automanage.config.enable_defender,
        "LogAnalytics/Enable" : var.automanage.config.enable_log_analytics,
        "LogAnalytics/Reprovision" : false,
        "LogAnalytics/Workspace" : var.automanage.config.custom_log_analytics_workspace == true ? try(azurerm_log_analytics_workspace.default.0.id, null) : null,
        "LogAnalytics/UseAma" : true,
        "UpdateManagement/Enable" : var.automanage.config.enable_updatemanagement,
        "VMInsights/Enable" : var.automanage.config.enable_vminsights,
        "WindowsAdminCenter/Enable" : var.automanage.config.enable_admin_center,
      }
    }
  })

  tags = var.tags
}
