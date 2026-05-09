#!/bin/bash
set -eu

if ! az account show &> /dev/null; then
    echo "Please log in to Azure CLI first using 'az login'"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

REMOTE_IP=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw vm_public_ip)
REMOTE_USER=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw vm_username)

VM_OPEN_PORT_1=$(cd "${SCRIPT_DIR}/infra" && terraform output -json vm_open_minecraft_ports | jq -r '.[0][0]')
VM_OPEN_PORT_2=$(cd "${SCRIPT_DIR}/infra" && terraform output -json vm_open_minecraft_ports | jq -r '.[0][1]')

MANAGED_IDENTITY_CLIENT_ID=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw vm_identity_principal_id)
STORAGE_ACCOUNT_NAME=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw storage_account_name)
STORAGE_CONTAINER_NAME=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw storage_container_name)

echo "REMOTE_IP                  = ${REMOTE_IP}"
echo "REMOTE_USER                = ${REMOTE_USER}"
echo "VM_OPEN_PORT_1             = ${VM_OPEN_PORT_1}"
echo "VM_OPEN_PORT_2             = ${VM_OPEN_PORT_2}"
echo "MANAGED_IDENTITY_CLIENT_ID = ${MANAGED_IDENTITY_CLIENT_ID}"
echo "STORAGE_ACCOUNT_NAME       = ${STORAGE_ACCOUNT_NAME}"
echo "STORAGE_CONTAINER_NAME     = ${STORAGE_CONTAINER_NAME}"

LOCAL_PORT=16001

function create_ssh_tunnel() {
    kill_tunnel
    ssh -L ${LOCAL_PORT}:localhost:22 ${REMOTE_USER}@${REMOTE_IP} -N &

    while ! nc -z localhost "${LOCAL_PORT}"; do
        sleep 1
    done
}

function sshremote() {
    ssh -p "${LOCAL_PORT}" "${REMOTE_USER}@localhost" -- "$@"
}

function kill_tunnel() {
    kill $(
        ps aux \
        | grep "ssh -L ${LOCAL_PORT}:localhost:22 ${REMOTE_USER}@${REMOTE_IP} -N" \
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
    sshremote "sudo apt update && sudo apt install -y make tmux && sudo apt upgrade -y && sudo apt autoremove -y"
}

function deploy_minecraft_server() {
    # Copy files over
    scp -P "${LOCAL_PORT}" -r "${SCRIPT_DIR}/minecraft-server/" "${REMOTE_USER}@localhost:/home/${REMOTE_USER}/minecraft-server"

    # Replace placeholders
    sshremote "sed -i \"s/{{vm_open_port}}/${VM_OPEN_PORT_1}/g\" 'minecraft-server/server.properties'"

    # Install
    sshremote "cd minecraft-server && make dependencies && make install && make start"

    # Check status
    sshremote "systemctl status minecraft.service"
}

function deploy_minecraft_server_modded() {
    # Copy files over
    scp -P "${LOCAL_PORT}" -r "${SCRIPT_DIR}/minecraft-server-modded/" "${REMOTE_USER}@localhost:/home/${REMOTE_USER}/minecraft-server-modded"

    # Replace placeholders
    sshremote "sed -i \"s/{{vm_open_port}}/${VM_OPEN_PORT_2}/g\" 'minecraft-server-modded/server.properties'"

    # Install
    sshremote "cd minecraft-server-modded && make dependencies && make install && make start"

    # Check status
    sshremote "systemctl status minecraft-modded.service"
}

function deploy_website() {
    # Copy files over
    scp -P "${LOCAL_PORT}" -r "${SCRIPT_DIR}/website/" "${REMOTE_USER}@localhost:/home/${REMOTE_USER}/website"

    # Replace placeholders
    sshremote "sed -i \"s/{{ip_address}}/${REMOTE_IP}:${VM_OPEN_PORT_1}/g\" 'website/minecraft.html'"
    sshremote "sed -i \"s/{{ip_address}}/${REMOTE_IP}:${VM_OPEN_PORT_2}/g\" 'website/mods.html'"

    MODLIST=$(jq -r '.[] | "<p><a href=\"" + .url + "\" target=_blank>" + .name + "</a></p>"' minecraft-server-modded/mods.json | tr '\n' ' ')
    sshremote "sed -i \"s|{{modlist}}|${MODLIST}|g\" 'website/mods.html'"

    # Install
    sshremote "cd website && make install && make start"

    # Check status
    sshremote "systemctl status website.service"
}

function deploy_backup_manager() {
    # Copy files over
    scp -P "${LOCAL_PORT}" -r "${SCRIPT_DIR}/backup-manager/" "${REMOTE_USER}@localhost:/home/${REMOTE_USER}/backup-manager"

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

function deploy_tmux_script() {
    scp -P "${LOCAL_PORT}" "${SCRIPT_DIR}/tmux.sh" "${REMOTE_USER}@localhost:/home/${REMOTE_USER}/tmux.sh"
    sshremote "chmod +x tmux.sh"
}

# Cache ssh credentials so we don't have to keep entering the password for every command
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

create_ssh_tunnel
remove_old_files

# Install
upgrade_packages
deploy_tmux_script

# Deploy backup-manager before the Minecraft server because it creates a backup right after starting,
# hence making server deployment safer
deploy_backup_manager
deploy_minecraft_server
deploy_minecraft_server_modded
deploy_website

# Remove temp files
remove_old_files

# Kill the tunnel process after we're done
kill_tunnel

printf "\n\nDeployment complete! You can access the website at http://${REMOTE_IP}\n"