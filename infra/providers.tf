terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }

  # You need to create this storage account and container manually before running terraform init
  # Alternatively, comment out the backend block and keep a local state file.
  backend "azurerm" {
      resource_group_name  = "tfstate"
      storage_account_name = "coleguistfstate"
      container_name       = "tfstate"
      key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}