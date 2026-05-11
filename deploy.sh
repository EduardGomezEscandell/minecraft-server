#!/bin/bash
set -eu

if ! az account show &> /dev/null; then
    echo "Please log in to Azure CLI first using 'az login'"
    exit 1
fi

SKIP_MINECRAFT="${SKIP_MINECRAFT:-}"
SKIP_MINECRAFT_MODDED="${SKIP_MINECRAFT_MODDED:-}"
SKIP_WEBSITE="${SKIP_WEBSITE:-}"
SKIP_BACKUP_MANAGER="${SKIP_BACKUP_MANAGER:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

REMOTE_IP=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw vm_public_ip)
REMOTE_USER=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw vm_username)

VM_OPEN_PORT_1=$(cd "${SCRIPT_DIR}/infra" && terraform output -json vm_open_minecraft_ports | jq -r '.[0][0]')
VM_OPEN_PORT_2=$(cd "${SCRIPT_DIR}/infra" && terraform output -json vm_open_minecraft_ports | jq -r '.[0][1]')

STORAGE_ACCOUNT_NAME=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw storage_account_name)
STORAGE_CONTAINER_NAME=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw storage_container_name)
STORAGE_ACR_NAME=$(cd "${SCRIPT_DIR}/infra" && terraform output -raw acr_name)

echo "REMOTE_IP                  = ${REMOTE_IP}"
echo "REMOTE_USER                = ${REMOTE_USER}"
echo "VM_OPEN_PORT_1             = ${VM_OPEN_PORT_1}"
echo "VM_OPEN_PORT_2             = ${VM_OPEN_PORT_2}"
echo "STORAGE_ACCOUNT_NAME       = ${STORAGE_ACCOUNT_NAME}"
echo "STORAGE_CONTAINER_NAME     = ${STORAGE_CONTAINER_NAME}"
echo "STORAGE_ACR_NAME           = ${STORAGE_ACR_NAME}"
echo "SKIP_MINECRAFT             = ${SKIP_MINECRAFT}"
echo "SKIP_MINECRAFT_MODDED      = ${SKIP_MINECRAFT_MODDED}"
echo "SKIP_WEBSITE               = ${SKIP_WEBSITE}"
echo "SKIP_BACKUP_MANAGER        = ${SKIP_BACKUP_MANAGER}"

ACR_URL="${STORAGE_ACR_NAME}.azurecr.io"
LOCAL_PORT=16001

function create_ssh_tunnel() {
    kill_tunnel
    ssh -L ${LOCAL_PORT}:localhost:22 ${REMOTE_USER}@${REMOTE_IP} -N &

    while ! nc -z localhost "${LOCAL_PORT}"; do
        sleep 1
    done
}

function kill_tunnel() {
    kill $(
        ps aux \
        | grep "ssh -L ${LOCAL_PORT}:localhost:22 ${REMOTE_USER}@${REMOTE_IP} -N" \
        | grep -v grep \
        | awk '{print $2}'
    ) &> /dev/null || true
}

function sshremote() {
    ssh -p "${LOCAL_PORT}" "${REMOTE_USER}@localhost" -- "$@"
}

function scpremote() {
    scp -P "${LOCAL_PORT}" -r "$1" "${REMOTE_USER}@localhost:$2"
}

function setup_packages() {
    sshremote sudo apt update
    sshremote sudo apt install -y make tmux docker.io docker-buildx
    sshremote sudo apt upgrade -y
    sshremote sudo apt autoremove -y
}

function setup_docker() {
    # Local
    az acr login --name "${STORAGE_ACR_NAME}"

    # Remote
    sshremote sudo usermod -aG docker "${REMOTE_USER}"
    sshremote az login --identity --allow-no-subscriptions
	sshremote az acr login --name "${STORAGE_ACR_NAME}"
}

function deploy_minecraft_server() {
    if [ -n "${SKIP_MINECRAFT}" ]; then
        echo "SKIP_MINECRAFT is set, skipping deployment of Minecraft server"
        return
    fi

    MAKE_ARGS="REGISTRY=${ACR_URL} SERVER_PORT=${VM_OPEN_PORT_1}"

    # Build and push the Docker image to the registry
    pushd "${SCRIPT_DIR}/minecraft-server"
    make build ${MAKE_ARGS}
    make push ${MAKE_ARGS}
    popd

    # Install
    sshremote mkdir -p "/home/${REMOTE_USER}/minecraft-server"
    sshremote "rm -rf minecraft-server/*" || true
    scpremote "${SCRIPT_DIR}/minecraft-server/Makefile"  "/home/${REMOTE_USER}/minecraft-server/"
    scpremote "${SCRIPT_DIR}/minecraft-server/services/" "/home/${REMOTE_USER}/minecraft-server/"

    # Install
    sshremote "cd minecraft-server && make pull ${MAKE_ARGS} && make install ${MAKE_ARGS}"

    # Check status
    sshremote "systemctl status minecraft.service"
}

function deploy_minecraft_server_modded() {
    if [ -n "${SKIP_MINECRAFT_MODDED}" ]; then
        echo "SKIP_MINECRAFT_MODDED is set, skipping deployment of Minecraft server"
        return
    fi


    MAKE_ARGS="REGISTRY=${ACR_URL} SERVER_PORT=${VM_OPEN_PORT_2}"

    # Build and push the Docker image to the registry
    pushd "${SCRIPT_DIR}/minecraft-server-modded"
    make build ${MAKE_ARGS}
    make push ${MAKE_ARGS}
    popd

    # Install
    sshremote mkdir -p "/home/${REMOTE_USER}/minecraft-server-modded"
    sshremote "rm -rf minecraft-server-modded/*" || true
    scpremote "${SCRIPT_DIR}/minecraft-server-modded/Makefile"  "/home/${REMOTE_USER}/minecraft-server-modded/"
    scpremote "${SCRIPT_DIR}/minecraft-server-modded/services/" "/home/${REMOTE_USER}/minecraft-server-modded/"

    # Install
    sshremote "cd minecraft-server-modded && make pull ${MAKE_ARGS} && make install ${MAKE_ARGS}"

    # Check status
    sshremote "systemctl status minecraft-modded.service"
}

function deploy_website() {
    if [ -n "${SKIP_WEBSITE}" ]; then
        echo "SKIP_WEBSITE is set, skipping deployment of website"
        return
    fi

    MAKE_ARGS="REGISTRY=${ACR_URL} SERVER_IP=${REMOTE_IP} SERVER_PORT1=${VM_OPEN_PORT_1} SERVER_PORT2=${VM_OPEN_PORT_2}"

    # Build and push the Docker image to the registry
    pushd "${SCRIPT_DIR}/website"
    make build ${MAKE_ARGS}
    make push ${MAKE_ARGS}
    popd

    # Move files over
    sshremote mkdir -p "/home/${REMOTE_USER}/website/services"
    sshremote "rm -rf website/*" || true
    scpremote "${SCRIPT_DIR}/website/Makefile"  "/home/${REMOTE_USER}/website/"
    scpremote "${SCRIPT_DIR}/website/services" "/home/${REMOTE_USER}/website/"

    # Install
    sshremote "cd website  && make pull ${MAKE_ARGS} && make install ${MAKE_ARGS}"

    # Check status
    sshremote systemctl status website.service
}

function deploy_backup_manager() {
    if [ -n "${SKIP_BACKUP_MANAGER}" ]; then
        echo "SKIP_BACKUP_MANAGER is set, skipping deployment of backup manager"
        return
    fi

    MAKE_ARGS="STORAGE_ACCOUNT_NAME=${STORAGE_ACCOUNT_NAME} STORAGE_CONTAINER_NAME=${STORAGE_CONTAINER_NAME}"

    # Copy files over
    sshremote mkdir -p "/home/${REMOTE_USER}/backup-manager"
    sshremote "rm -rf backup-manager/*" || true
    scpremote "${SCRIPT_DIR}/backup-manager" "/home/${REMOTE_USER}/"

    # Install
    sshremote "cd backup-manager && make dependencies ${MAKE_ARGS} && make install ${MAKE_ARGS} && make start ${MAKE_ARGS}"

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

# Install
setup_packages
setup_docker
deploy_tmux_script

# Deploy services
deploy_backup_manager
deploy_minecraft_server
deploy_minecraft_server_modded
deploy_website

# Kill the tunnel process after we're done
kill_tunnel

printf "\n\nDeployment complete! Your resources are available at ${REMOTE_IP}\n"