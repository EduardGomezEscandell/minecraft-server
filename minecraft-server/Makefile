INSTALL_LOC ?= /opt/minecraft
SERVICE ?= minecraft
USER=minecraft

.PHONY: help
help: ## Show this help message
	@echo "Minecraft Development Makefile"
	@echo ""
	@echo "COMMANDS"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

dependencies: ## Downloads the dependencies
	mkdir -p bin
	wget -q -O bin/server.jar https://piston-data.mojang.com/v1/objects/97ccd4c0ed3f81bbb7bfacddd1090b0c56f9bc51/server.jar
	sudo apt update
	sudo apt install -y openjdk-25-jre

WHO := $(shell whoami)
.PHONY: install
install: ## Installs the server
# Create Minecraft group and user
	id '$(USER)' || sudo adduser '$(USER)' --no-create-home --disabled-password --gecos ""
	sudo usermod -a -G '$(USER)' '$(WHO)'

# Create working directory owned by Minecraft
# 	mkdir -p '$(INSTALL_LOC)'
# 	cp bin/server.jar '$(INSTALL_LOC)/server.jar'
# 	cp 'server.properties' '$(INSTALL_LOC)/server.properties'
# 	bash -c "echo eula=TRUE > '$(INSTALL_LOC)/eula.txt'"

	sudo chown -R '$(USER)' '$(INSTALL_LOC)'
	sudo chgrp -R '$(USER)' '$(INSTALL_LOC)'
	sudo chmod -R 'g=u,o-rwx' '$(INSTALL_LOC)'

# Install service files
	sudo cp 'services/$(SERVICE).socket' '/etc/systemd/system/$(SERVICE).socket'
	sudo cp 'services/$(SERVICE).service' '/etc/systemd/system/$(SERVICE).service'

# Update systemd
	sudo systemctl daemon-reload
	sudo systemctl enable '$(SERVICE).service'

.PHONY: uninstall
uninstall: ## Uninstalls the server
	sudo systemctl stop '$(SERVICE).service'         || true
	sudo systemctl disable '$(SERVICE).service'      || true
	sudo rm '/etc/systemd/system/$(SERVICE).service' || true
	sudo rm '/etc/systemd/system/$(SERVICE).socket'  || true
	sudo chgrp -R '$(WHO)' '$(INSTALL_LOC)'          || true
	sudo chown -R '$(WHO)' '$(INSTALL_LOC)'          || true
	sudo deluser '$(USER)'                           || true
	sudo delgroup '$(USER)'                          || true

.PHONY: purge
purge: uninstall ## Uninstalls the server and removes saved data
# 	rm -rf bin                   || true
	sudo rm -rf '$(INSTALL_LOC)' || true

start: ## Starts the installed service
	sudo systemctl restart '$(SERVICE).service' || true

stop: ## Stops the installed service
	sudo systemctl stop '$(SERVICE).service' || true

CMD ?= "/help"
command: ## Connect to the server's console
	sudo bash -c "echo $(CMD) > '/run/$(SERVICE).stdin'"
