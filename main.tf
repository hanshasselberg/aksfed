provider "azurerm" {
    # The "feature" block is required for AzureRM provider 2.x. 
    # If you are using version 1.x, the "features" block is not allowed.
    version = "~>2.0"
    features {}
}

terraform {
    backend "azurerm" {}
}

resource "azurerem_resource_group" "rg"{
  name = "aks-test-hansa"
  location = "US West 2"
}
