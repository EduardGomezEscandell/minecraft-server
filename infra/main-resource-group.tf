resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.resource_group_location
}