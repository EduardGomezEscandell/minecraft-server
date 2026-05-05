#!/bin/bash

# Manual inputs
RESOURCE_GROUP="minecraft-rg"
BASTION_NAME="minecraft-bastion"
VM_NAME="minecraft-vm"

# Automated inputs
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
AZURE_USERNAME=$(az vm show --resource-group "${RESOURCE_GROUP}" --name "${VM_NAME}" --query "osProfile.adminUsername" -o tsv)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Open a tunnel to the server and deploy the Minecraft server files
az network bastion tunnel \
    --name "${BASTION_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --target-resource-id "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Compute/virtualMachines/${VM_NAME}" \
    --resource-port "22" \
    --port "16001" \
    --output none &

while ! nc -z localhost 16001; do
  sleep 1
done

# Copy the Minecraft server files, install dependencies, and start the server
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

scp -P "16001" -r "${SCRIPT_DIR}/minecraft-server/" "${AZURE_USERNAME}@localhost:/home/${AZURE_USERNAME}/minecraft-server"
scp -P "16001" -r "${SCRIPT_DIR}/website/" "${AZURE_USERNAME}@localhost:/home/${AZURE_USERNAME}/website"

ssh -p 16001 "${AZURE_USERNAME}@localhost" -- "sudo apt update && sudo apt install -y make"

ssh -p 16001 "${AZURE_USERNAME}@localhost" -- "cd minecraft-server && make dependencies && make install && make start"
ssh -p 16001 "${AZURE_USERNAME}@localhost" -- "cd website && make install && make start"

ssh -p 16001 "${AZURE_USERNAME}@localhost" -- "systemctl status minecraft.service"
ssh -p 16001 "${AZURE_USERNAME}@localhost" -- "systemctl status website.service"

ssh -p 16001 "${AZURE_USERNAME}@localhost" -- "rm -rf website"
ssh -p 16001 "${AZURE_USERNAME}@localhost" -- "rm -rf minecraft-server"

# Kill the tunnel process after we're done
kill $(
    ps aux \
    | grep "network bastion tunnel --name ${BASTION_NAME} --resource-group ${RESOURCE_GROUP}" \
    | grep -v grep \
    | awk '{print $2}'
)
