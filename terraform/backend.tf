terraform {
  backend "azurerm" {
    resource_group_name  = "rg-identity-lab"
    storage_account_name = "stegidentitylab1023"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}


