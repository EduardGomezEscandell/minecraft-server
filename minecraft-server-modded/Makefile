FORGE_VERSION := 1.21.1-52.0.4
FERIUM_VERSION := v4.7.0
MINECRAFT_VERSION := 1.21.1

.PHONY: help
help: ## Show this help message
	@echo "Grocery Price Fetcher Development Makefile"
	@echo ""
	@echo "COMMANDS"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

dependencies: ## Downloads the dependencies
	sudo apt update
	sudo apt install -y default-jre unzip wget
	mkdir -p bin
	wget -q -O bin/server.jar https://piston-data.mojang.com/v1/objects/450698d1863ab5180c25d7c804ef0fe6369dd1ba/server.jar
	wget -q -O bin/forge-$(FORGE_VERSION)-installer.jar https://maven.minecraftforge.net/net/minecraftforge/forge/$(FORGE_VERSION)/forge-$(FORGE_VERSION)-installer.jar
	wget -q -O bin/ferium-linux-nogui.zip https://github.com/gorilla-devs/ferium/releases/download/$(FERIUM_VERSION)/ferium-linux-nogui.zip
	unzip bin/ferium-linux-nogui.zip -d bin
	rm bin/ferium-linux-nogui.zip

WHO := $(shell whoami)
FERIUM := /opt/minecraft/ferium --config-file /opt/minecraft/ferium-config.json
.PHONY: install
install: ## Installs the server
# Create Minecraft group and user
	id minecraft || sudo adduser minecraft --no-create-home --disabled-password --gecos ""
	sudo usermod -a -G minecraft $(WHO)

# Create working directory owned by Minecraft
	sudo mkdir -p /opt/minecraft
	sudo cp bin/server.jar /opt/minecraft/server.jar
	sudo cp "bin/forge-$(FORGE_VERSION)-installer.jar" "/opt/minecraft/forge-$(FORGE_VERSION)-installer.jar"
	sudo cp bin/ferium /opt/minecraft/ferium
	sudo bash -c "echo eula=TRUE > /opt/minecraft/eula.txt"
	sudo chown -R minecraft:minecraft /opt/minecraft
	
# Install forge
	cd /opt/minecraft && sudo -u minecraft -- java -jar "/opt/minecraft/forge-$(FORGE_VERSION)-installer.jar" --installServer
	sudo -u minecraft -- mv "/opt/minecraft/forge-$(FORGE_VERSION)-shim.jar" /opt/minecraft/forge-server.jar
	cd /opt/minecraft/ && sudo rm "run.sh" "forge-$(FORGE_VERSION)-installer.jar" "user_jvm_args.txt"

# Set up Ferium
	sudo chmod 0774 /opt/minecraft/ferium

	sudo -- $(FERIUM) profile create                    \
	            --mod-loader forge                      \
	            --game-version $(MINECRAFT_VERSION)     \
				--name forge                            \
				--output-dir /opt/minecraft/mods || true

	sudo -- $(FERIUM) add -f $(shell cat mods.json | jq -r ".[]")
	sudo -- $(FERIUM) upgrade || true

# Install service files
	sudo cp services/minecraft.socket /etc/systemd/system/minecraft.socket
	sudo cp services/minecraft.service /etc/systemd/system/minecraft.service
	sudo sed -i 's/server.jar/forge-server.jar/' /etc/systemd/system/minecraft.service

# Update systemd
	sudo systemctl daemon-reload
	sudo systemctl enable minecraft.service

.PHONY: uninstall
uninstall: ## Uninstalls the server
	sudo systemctl stop minecraft.service         || true
	sudo systemctl disable minecraft.service      || true
	sudo rm /etc/systemd/system/minecraft.service || true
	sudo rm /etc/systemd/system/minecraft.socket  || true
	sudo chgrp -R $(WHO) /opt/minecraft           || true
	sudo chown -R $(WHO) /opt/minecraft           || true
	sudo deluser minecraft                        || true
	sudo delgroup minecraft                       || true

.PHONY: purge
purge: uninstall ## Uninstalls the server and removes saved data
	rm -rf bin                 || true
	sudo rm -rf /opt/minecraft || true

start: ## Starts the installed service
	sudo systemctl restart minecraft.service || true

stop: ## Stops the installed service
	sudo systemctl stop minecraft.service || true

CMD ?= "/help"
command: ## Connect to the server's console
	sudo bash -c 'echo $(CMD) > /run/minecraft.stdin'
