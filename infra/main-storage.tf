resource "azurerm_storage_account" "backups" {
  name                     = "eduminecraftbackups"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  network_rules {
    default_action             = "Allow"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [azurerm_subnet.compute.id]
  }
}

resource "azurerm_role_assignment" "storage_blob_data_contributor_user" {
  scope                = azurerm_storage_account.backups.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "storage_blob_data_owner_user" {
  scope                = azurerm_storage_account.backups.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_storage_container" "saves" {
  name                  = "saves"
  storage_account_name  = azurerm_storage_account.backups.name
  container_access_type = "private"
}
