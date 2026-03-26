terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stiacworkshoptfstate"
    container_name       = "tfstate"
    key                  = "iac-workshop.tfstate"
    use_oidc             = true
  }
}
