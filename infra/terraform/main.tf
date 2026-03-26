locals {
  rg_name   = "rg-${var.prefix}"
  acr_name  = replace("acr${var.prefix}${substr(md5(data.azurerm_subscription.current.id), 0, 8)}", "-", "")
  plan_name = "plan-${var.prefix}"
  app_name  = "app-${var.prefix}-${substr(md5(data.azurerm_subscription.current.id), 0, 8)}"
}

data "azurerm_subscription" "current" {}

# ---------- Resource Group ----------
resource "azurerm_resource_group" "main" {
  name     = local.rg_name
  location = var.location
}

# ---------- Container Registry ----------
resource "azurerm_container_registry" "main" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}

# ---------- App Service Plan ----------
resource "azurerm_service_plan" "main" {
  name                = local.plan_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_service_sku
}

# ---------- App Service ----------
resource "azurerm_linux_web_app" "main" {
  name                = local.app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true

  site_config {
    always_on = true

    application_stack {
      docker_registry_url      = "https://${azurerm_container_registry.main.login_server}"
      docker_image_name        = "bankapi:${var.image_tag}"
      docker_registry_username = azurerm_container_registry.main.admin_username
      docker_registry_password = azurerm_container_registry.main.admin_password
    }
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "WEBSITES_PORT"                       = "8080"
  }
}
