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
VM_PUBLIC_IP=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw vm_public_ip)
VM_OPEN_PORT_1=$(cd "${SCRIPT_DIR}/infra" && terraform output -json vm_open_minecraft_ports | jq -r '.[0][0]')
VM_OPEN_PORT_2=$(cd "${SCRIPT_DIR}/infra" && terraform output -json vm_open_minecraft_ports | jq -r '.[0][1]')
MANAGED_IDENTITY_CLIENT_ID=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw vm_identity_principal_id)
STORAGE_ACCOUNT_NAME=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw storage_account_name)
STORAGE_CONTAINER_NAME=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw storage_container_name)

echo "SUBSCRIPTION_ID            = ${SUBSCRIPTION_ID}"
echo "RESOURCE_GROUP             = ${RESOURCE_GROUP}"
echo "BASTION_NAME               = ${BASTION_NAME}"
echo "VM_NAME                    = ${VM_NAME}"
echo "VM_USERNAME                = ${VM_USERNAME}"
echo "VM_PUBLIC_IP               = ${VM_PUBLIC_IP}"
echo "VM_OPEN_PORT_1             = ${VM_OPEN_PORT_1}"
echo "VM_OPEN_PORT_2             = ${VM_OPEN_PORT_2}"
echo "MANAGED_IDENTITY_CLIENT_ID = ${MANAGED_IDENTITY_CLIENT_ID}"
echo "STORAGE_ACCOUNT_NAME       = ${STORAGE_ACCOUNT_NAME}"
echo "STORAGE_CONTAINER_NAME     = ${STORAGE_CONTAINER_NAME}"

BASTION_LOCAL_PORT=16001

function sshremote() {
    ssh -p "${BASTION_LOCAL_PORT}" "${VM_USERNAME}@localhost" -- "$@"
}

function kill_bastion() {
    kill $(
        ps aux \
        | grep "network bastion tunnel --name ${BASTION_NAME} --resource-group ${RESOURCE_GROUP}" \
        | grep -v grep \
        | awk '{print $2}'
    ) &> /dev/null || true
}

function remove_old_files() {
    sshremote "rm -rf website" || true
    sshremote "rm -rf minecraft-server" || true
    sshremote "rm -rf minecraft-server-modded" || true
    sshremote "rm -rf backup-manager" || true
}

function upgrade_packages() {
    sshremote "sudo apt update && sudo apt install -y make && sudo apt upgrade -y && sudo apt autoremove -y"
}

function deploy_minecraft_server() {
    # Copy files over
    scp -P "${BASTION_LOCAL_PORT}" -r "${SCRIPT_DIR}/minecraft-server/" "${VM_USERNAME}@localhost:/home/${VM_USERNAME}/minecraft-server"

    # Replace placeholders
    sshremote "sed -i \"s/{{vm_open_port}}/${VM_OPEN_PORT_1}/g\" 'minecraft-server/server.properties'"

    # Install
    sshremote "cd minecraft-server && make dependencies && make install && make start"

    # Check status
    sshremote "systemctl status minecraft.service"
}

function deploy_minecraft_server_modded() {
    # Copy files over
    scp -P "${BASTION_LOCAL_PORT}" -r "${SCRIPT_DIR}/minecraft-server-modded/" "${VM_USERNAME}@localhost:/home/${VM_USERNAME}/minecraft-server-modded"

    # Replace placeholders
    sshremote "sed -i \"s/{{vm_open_port}}/${VM_OPEN_PORT_2}/g\" 'minecraft-server-modded/server.properties'"

    # Install
    sshremote "cd minecraft-server-modded && make dependencies && make install && make start"

    # Check status
    sshremote "systemctl status minecraft-modded.service"
}

function deploy_website() {
    # Copy files over
    scp -P "${BASTION_LOCAL_PORT}" -r "${SCRIPT_DIR}/website/" "${VM_USERNAME}@localhost:/home/${VM_USERNAME}/website"

    # Replace placeholders
    sshremote "sed -i \"s/{{ip_address}}/${VM_PUBLIC_IP}:${VM_OPEN_PORT_1}/g\" 'website/minecraft.html'"
    sshremote "sed -i \"s/{{ip_address}}/${VM_PUBLIC_IP}:${VM_OPEN_PORT_2}/g\" 'website/mods.html'"

    MODLIST=$(jq -r '.[] | "<p><a href=\"" + .url + "\" target=_blank>" + .name + "</a></p>"' minecraft-server-modded/mods.json | tr '\n' ' ')
    sshremote "sed -i \"s|{{modlist}}|${MODLIST}|g\" 'website/mods.html'"

    # Install
    sshremote "cd website && make install && make start"

    # Check status
    sshremote "systemctl status website.service"
}

function deploy_backup_manager() {
    # Copy files over
    scp -P "${BASTION_LOCAL_PORT}" -r "${SCRIPT_DIR}/backup-manager/" "${VM_USERNAME}@localhost:/home/${VM_USERNAME}/backup-manager"

    # Replace placeholders
    for file in backup-create.service backup-purge.service; do
        sshremote "sed -i \"s/{{storage_account_name}}/${STORAGE_ACCOUNT_NAME}/g\"     'backup-manager/services/${file}'"
        sshremote "sed -i \"s/{{storage_container_name}}/${STORAGE_CONTAINER_NAME}/g\" 'backup-manager/services/${file}'"
        sshremote "sed -i \"s/{{identity_client_id}}/${MANAGED_IDENTITY_CLIENT_ID}/g\" 'backup-manager/services/${file}'"
    done

    # Install
    sshremote "cd backup-manager && make dependencies && make install && make start"

    # Check status
    sshremote "systemctl status backup-create.timer"
    sshremote "systemctl status backup-purge.timer"
}

kill_bastion

# Open a tunnel to the server and wait for it to be ready
az network bastion tunnel \
    --name "${BASTION_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --target-resource-id "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Compute/virtualMachines/${VM_NAME}" \
    --resource-port "22" \
    --port "${BASTION_LOCAL_PORT}" \
    --output none &

while ! nc -z localhost "${BASTION_LOCAL_PORT}"; do
  sleep 1
done

# Cache ssh credentials so we don't have to keep entering the password for every command
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

remove_old_files

# Install
upgrade_packages

# Deploy backup-manager before the Minecraft server because it creates a backup right after starting,
# hence making server deployment safer
# deploy_backup_manager
deploy_minecraft_server
deploy_minecraft_server_modded
deploy_website

# Remove temp files
remove_old_files

# Kill the tunnel process after we're done
kill_bastion

printf "\n\nDeployment complete! You can access the website at http://${VM_PUBLIC_IP}\n"