terraform {
  required_version = ">=1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.111.0"
    }
    modtm = {
      source  = "azure/modtm"
      version = ">=0.3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">=0.11.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">=2.53.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">=3.6.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">=1.14.0"
    }
    http = {
      source = "hashicorp/http"
    }
  }
}