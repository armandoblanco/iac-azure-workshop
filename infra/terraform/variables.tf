variable "prefix" {
  description = "Base name prefix for all resources"
  type        = string
  default     = "iacworkshop"
}

variable "location" {
  description = "Azure region for deployment"
  type        = string
  default     = "eastus2"
}

variable "image_tag" {
  description = "Container image tag to deploy"
  type        = string
  default     = "latest"
}

variable "app_service_sku" {
  description = "SKU for the App Service Plan"
  type        = string
  default     = "B1"
}
