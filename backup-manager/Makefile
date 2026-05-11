
STORAGE_ACCOUNT_NAME ?= eduminecraftbackups
STORAGE_CONTAINER_NAME ?= saves

dependencies:
	which az || curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
	which jq || DEBIAN_FRONTEND=noninteractive sudo apt install -y jq

install:
# Create working directory owned by backup-manager
	sudo mkdir -p /opt/backup-manager/
	sudo cp bin/* /opt/backup-manager/

# Replace placeholders
	sudo sed -i "s/{{storage_account_name}}/$(STORAGE_ACCOUNT_NAME)/g"     '/opt/backup-manager/env.conf'
	sudo sed -i "s/{{storage_container_name}}/$(STORAGE_CONTAINER_NAME)/g" '/opt/backup-manager/env.conf'

# Update ownership and permissions
	sudo chown -R root:root /opt/backup-manager
	sudo chmod -R 'g=u-w,o-rwx' /opt/backup-manager

# Install service files
	sudo cp services/* /etc/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable backup-create.service backup-create.timer backup-purge.service backup-purge.timer

start: ## Starts the installed service
	sudo systemctl restart backup-create.timer backup-purge.timer

stop: ## Stops the installed service
	sudo systemctl stop backup-create.timer backup-purge.timer

uninstall:
	sudo systemctl stop backup-create.service backup-purge.service    || true
	sudo systemctl disable backup-create.service backup-purge.service || true
	cd /etc/systemd/system/ && sudo rm -f backup-create.service backup-create.timer backup-purge.service backup-purge.timer || true
	sudo systemctl daemon-reload     || true
	sudo rm -rf /opt/backup-manager  || true
	sudo deluser backup-manager      || true
	sudo delgroup backup-manager     || true
	sudo rm -rf /home/backup-manager || true