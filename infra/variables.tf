variable "resource_group_location" {
  type        = string
  default     = "spaincentral"
}

variable "prefix" {
  type        = string
  default     = "minecraft"
}

variable "subscription_id" {
  type = string
}

variable "ssh_public_key_path" {
  type = string
}