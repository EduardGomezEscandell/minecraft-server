#!/bin/sh

# Hard-coded variables for Terraform
export TF_VAR_ssh_public_key_path=~/.ssh/id_ed25519.pub

# Dynamically set variables for Terraform
export TF_VAR_subscription_id=$(az account show --query 'id' -o tsv)
export TF_VAR_myIPAddress=$(curl -s ifconfig.me)

# Validation
ping -c 1 "${TF_VAR_myIPAddress}" &> /dev/null || {
    echo "Unable to ping the IP address: $TF_VAR_myIPAddress. Please check your internet connection and try again."
    exit 1
}