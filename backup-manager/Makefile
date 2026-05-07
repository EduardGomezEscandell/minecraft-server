
RELEASE:=$(shell bash -c 'source /etc/os-release && echo "$$VERSION_ID"')
dependencies:
	curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
	DEBIAN_FRONTEND=noninteractive sudo apt update && sudo apt-get install -y jq

WHO := $(shell whoami)
install:
# Create user. We need a home directory otherwise az cli will fail (see https://github.com/Azure/azure-cli/issues/24397)
	id backup-manager || sudo adduser backup-manager --disabled-password --gecos "" --home /home/backup-manager
	sudo usermod -a -G backup-manager $(WHO)

# Create working directory owned by backup-manager
	sudo mkdir -p /opt/backup-manager/
	sudo cp bin/* /opt/backup-manager/


	sudo chown -R backup-manager /opt/backup-manager
	sudo chgrp -R backup-manager /opt/backup-manager
	sudo chmod -R 'g=u,o-rwx' /opt/backup-manager

# Install service files
	sudo cp services/* /etc/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable backup-create.service backup-create.timer backup-purge.service backup-purge.timer

start: ## Starts the installed service
	sudo systemctl restart backup-create.timer backup-purge.timer

stop: ## Stops the installed service
	sudo systemctl stop backup-create.timer backup-purge.timer

uninstall:
	sudo systemctl stop backup-create.service backup-purge.service
	sudo systemctl disable backup-create.service backup-purge.service
	cd /etc/systemd/system/ && sudo rm -f backup-create.service backup-create.timer backup-purge.service backup-purge.timer || true
	sudo rm -rf /opt/backup-manager || true
	sudo deluser backup-manager || true
	sudo delgroup backup-manager || true
	sudo rm -rf /home/backup-manager || true