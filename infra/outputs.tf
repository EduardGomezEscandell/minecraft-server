output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "vm_name" {
  value = azurerm_virtual_machine.minecraft-vm.name
}

output "vm_public_ip" {
  value = azurerm_public_ip.compute.ip_address
}

output "vm_open_minecraft_ports" {
  value = [
    for rule in azurerm_network_security_group.compute.security_rule: rule.destination_port_ranges
    if rule.name == "Allow-Inbound-Minecraft"
  ]
}

output "vm_username" {
  value = [for profile in azurerm_virtual_machine.minecraft-vm.os_profile : profile.admin_username][0]
  sensitive = true
}

output "storage_account_name" {
  value = azurerm_storage_account.backups.name
}

output "storage_container_name" {
  value = azurerm_storage_container.saves.name
}

output "vm_identity_principal_id" {
  value = azurerm_virtual_machine.minecraft-vm.identity[0].principal_id
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}