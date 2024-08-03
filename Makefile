.PHONY: help
help: ## Show this help message
	@echo "Grocery Price Fetcher Development Makefile"
	@echo ""
	@echo "COMMANDS"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

download: ## Downloads the minecraft server
	mkdir -p bin
	curl https://piston-data.mojang.com/v1/objects/450698d1863ab5180c25d7c804ef0fe6369dd1ba/server.jar > bin/server.jar

WHO := $(shell whoami)
.PHONY: install
install: ## Installs the server
# Create Minecraft group and user
	id minecraft || sudo adduser minecraft --no-create-home --disabled-password --gecos ""
	sudo usermod -a -G minecraft $(WHO)

# Create working directory owned by Minecraft
	sudo mkdir -p /opt/minecraft
	sudo cp bin/server.jar /opt/minecraft/server.jar
	sudo bash -c "echo eula=TRUE > /opt/minecraft/eula.txt"
	sudo chown -R minecraft /opt/minecraft
	sudo chgrp -R minecraft /opt/minecraft

# Install service files
	sudo cp services/minecraft.socket /etc/systemd/system/minecraft.socket
	sudo cp services/minecraft.service /etc/systemd/system/minecraft.service

# Update systemd
	sudo systemctl daemon-reload
	sudo systemctl enable minecraft.service

.PHONY: uninstall
uninstall: ## Uninstalls the server
	sudo systemctl stop minecraft.service
	sudo systemctl disable minecraft.service
	sudo rm /etc/systemd/system/minecraft.service || true
	sudo rm /etc/systemd/system/minecraft.socket  || true
	sudo chgrp -R $(WHO) /opt/minecraft
	sudo chown -R $(WHO) /opt/minecraft
	sudo deluser minecraft                        || true
	sudo delgroup minecraft                       || true

.PHONY: purge
purge: uninstall ## Uninstalls the server and removes saved data
	rm -rf bin                 || true
	sudo rm -rf /opt/minecraft || true

start: ## Starts the installed service
	sudo systemctl restart minecraft.service

stop:
	sudo systemctl stop minecraft.service

CMD ?= "/help"
command: ## Connect to the server's console
	sudo bash -c 'echo $(CMD) > /run/minecraft.stdin'