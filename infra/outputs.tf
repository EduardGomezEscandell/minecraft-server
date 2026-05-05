output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "bastion_host_name" {
  value = azurerm_bastion_host.bastion.name
}

output "compute_ip" {
  value = azurerm_public_ip.compute.ip_address
}