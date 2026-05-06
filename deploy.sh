#!/bin/bash
set -eu

if ! az account show &> /dev/null; then
    echo "Please log in to Azure CLI first using 'az login'"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
RESOURCE_GROUP=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw resource_group_name)
BASTION_NAME=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw bastion_name)
VM_NAME=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw vm_name)
VM_USERNAME=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw vm_username)
VM_PUBLIC_IP=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw domain_name)
VM_OPEN_PORT=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw vm_open_minecraft_port)
MANAGED_IDENTITY_CLIENT_ID=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw vm_identity_principal_id)
STORAGE_ACCOUNT_NAME=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw storage_account_name)
STORAGE_CONTAINER_NAME=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw storage_container_name)

echo "SUBSCRIPTION_ID            = ${SUBSCRIPTION_ID}"
echo "RESOURCE_GROUP             = ${RESOURCE_GROUP}"
echo "BASTION_NAME               = ${BASTION_NAME}"
echo "VM_NAME                    = ${VM_NAME}"
echo "VM_USERNAME                = ${VM_USERNAME}"
echo "VM_PUBLIC_IP               = ${VM_PUBLIC_IP}"
echo "VM_OPEN_PORT               = ${VM_OPEN_PORT}"
echo "MANAGED_IDENTITY_CLIENT_ID = ${MANAGED_IDENTITY_CLIENT_ID}"
echo "STORAGE_ACCOUNT_NAME       = ${STORAGE_ACCOUNT_NAME}"
echo "STORAGE_CONTAINER_NAME     = ${STORAGE_CONTAINER_NAME}"

function kill_bastion() {
    kill $(
        ps aux \
        | grep "network bastion tunnel --name ${BASTION_NAME} --resource-group ${RESOURCE_GROUP}" \
        | grep -v grep \
        | awk '{print $2}'
    ) &> /dev/null || true
}

function remove_old_files() {
    ssh -p 16001 "${VM_USERNAME}@localhost" -- "rm -rf website" || true
    ssh -p 16001 "${VM_USERNAME}@localhost" -- "rm -rf minecraft-server" || true
    ssh -p 16001 "${VM_USERNAME}@localhost" -- "rm -rf backup-manager" || true
}

kill_bastion

# Open a tunnel to the server and wait for it to be ready
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

# Cache ssh credentials so we don't have to keep entering the password for every command
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

remove_old_files

# Copy files over
scp -P "16001" -r "${SCRIPT_DIR}/minecraft-server/" "${VM_USERNAME}@localhost:/home/${VM_USERNAME}/minecraft-server"
scp -P "16001" -r "${SCRIPT_DIR}/website/" "${VM_USERNAME}@localhost:/home/${VM_USERNAME}/website"
scp -P "16001" -r "${SCRIPT_DIR}/backup-manager/" "${VM_USERNAME}@localhost:/home/${VM_USERNAME}/backup-manager"

# Replace placeholders
ssh -p 16001 "${VM_USERNAME}@localhost" -- "sed -i \"s/{{vm_open_port}}/${VM_OPEN_PORT}/g\" 'minecraft-server/server.properties'"

ssh -p 16001 "${VM_USERNAME}@localhost" -- "sed -i \"s/{{ip_address}}/${VM_PUBLIC_IP}:${VM_OPEN_PORT}/g\" 'website/minecraft.html'"

for file in backup-create.service backup-purge.service; do
    ssh -p 16001 "${VM_USERNAME}@localhost" -- "sed -i \"s/{{storage_account_name}}/${STORAGE_ACCOUNT_NAME}/g\"     'backup-manager/services/${file}'"
    ssh -p 16001 "${VM_USERNAME}@localhost" -- "sed -i \"s/{{storage_container_name}}/${STORAGE_CONTAINER_NAME}/g\" 'backup-manager/services/${file}'"
    ssh -p 16001 "${VM_USERNAME}@localhost" -- "sed -i \"s/{{identity_client_id}}/${MANAGED_IDENTITY_CLIENT_ID}/g\" 'backup-manager/services/${file}'"
done

# Install
ssh -p 16001 "${VM_USERNAME}@localhost" -- "sudo apt update && sudo apt install -y make"
ssh -p 16001 "${VM_USERNAME}@localhost" -- "cd backup-manager && make dependencies && make install && make start"
ssh -p 16001 "${VM_USERNAME}@localhost" -- "cd minecraft-server && make dependencies && make install && make start"
ssh -p 16001 "${VM_USERNAME}@localhost" -- "cd website && make install && make start"

# Check the status of the services
ssh -p 16001 "${VM_USERNAME}@localhost" -- "systemctl status minecraft.service"
ssh -p 16001 "${VM_USERNAME}@localhost" -- "systemctl status website.service"
ssh -p 16001 "${VM_USERNAME}@localhost" -- "systemctl status backup-create.timer"
ssh -p 16001 "${VM_USERNAME}@localhost" -- "systemctl status backup-purge.timer"

# Remove temp files
remove_old_files

# Kill the tunnel process after we're done
kill_bastion