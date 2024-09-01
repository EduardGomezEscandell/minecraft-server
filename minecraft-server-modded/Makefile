FORGE_VERSION ?= 1.21.1-52.0.4
FERIUM_VERSION ?= v4.7.0
MINECRAFT_VERSION ?= 1.21.1
INSTALL_LOC ?= /opt/minecraft-modded
SERVICE ?= minecraft-modded

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
	wget -q -O bin/server.jar 'https://piston-data.mojang.com/v1/objects/450698d1863ab5180c25d7c804ef0fe6369dd1ba/server.jar'
	wget -q -O bin/forge-$(FORGE_VERSION)-installer.jar 'https://maven.minecraftforge.net/net/minecraftforge/forge/$(FORGE_VERSION)/forge-$(FORGE_VERSION)-installer.jar'
	wget -q -O bin/ferium-linux-nogui.zip 'https://github.com/gorilla-devs/ferium/releases/download/$(FERIUM_VERSION)/ferium-linux-nogui.zip'
	unzip bin/ferium-linux-nogui.zip -d bin
	rm bin/ferium-linux-nogui.zip

WHO := $(shell whoami)
FERIUM := '$(INSTALL_LOC)/ferium' --config-file '$(INSTALL_LOC)/ferium-config.json'
.PHONY: install
install: ## Installs the server
# Create Minecraft group and user
	id minecraft || sudo adduser minecraft --no-create-home --disabled-password --gecos ""
	sudo usermod -a -G minecraft '$(WHO)'

# Create working directory owned by Minecraft
	sudo mkdir -p '$(INSTALL_LOC)'
	sudo cp bin/server.jar '$(INSTALL_LOC)/server.jar'
	sudo cp 'bin/forge-$(FORGE_VERSION)-installer.jar' '$(INSTALL_LOC)/forge-$(FORGE_VERSION)-installer.jar'
	sudo cp bin/ferium '$(INSTALL_LOC)/ferium'
	sudo bash -c "echo eula=TRUE > '$(INSTALL_LOC)/eula.txt'"
	sudo chown -R minecraft:minecraft '$(INSTALL_LOC)'
	
# Install forge
	cd '$(INSTALL_LOC)' && sudo -u minecraft -- java -jar '$(INSTALL_LOC)/forge-$(FORGE_VERSION)-installer.jar' --installServer
	sudo -u minecraft -- mv '$(INSTALL_LOC)/forge-$(FORGE_VERSION)-shim.jar' '$(INSTALL_LOC)/forge-server.jar'
	cd '$(INSTALL_LOC)' && sudo rm run.sh 'forge-$(FORGE_VERSION)-installer.jar' user_jvm_args.txt

# Set up Ferium
	sudo chmod 0774 $(INSTALL_LOC)/ferium

	sudo -- $(FERIUM) profile create                    \
	            --mod-loader forge                      \
	            --game-version '$(MINECRAFT_VERSION)'   \
				--name forge                            \
				--output-dir '$(INSTALL_LOC)/mods' || true

	sudo -- $(FERIUM) add -f $(shell cat mods.json | jq -r ".[]")
	sudo -- $(FERIUM) upgrade || true

# Install service files
	sudo cp 'services/$(SERVICE).socket' '/etc/systemd/system/$(SERVICE).socket'
	sudo cp 'services/$(SERVICE).service' '/etc/systemd/system/$(SERVICE).service'
	sudo sed -i 's/server.jar/forge-server.jar/' '/etc/systemd/system/$(SERVICE).service'

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
	sudo deluser minecraft                           || true
	sudo delgroup minecraft                          || true

.PHONY: purge
purge: uninstall ## Uninstalls the server and removes saved data
	rm -rf bin                   || true
	sudo rm -rf '$(INSTALL_LOC)' || true

start: ## Starts the installed service
	sudo systemctl restart '$(SERVICE).service' || true

stop: ## Stops the installed service
	sudo systemctl stop '$(SERVICE).service' || true

CMD ?= "/help"
command: ## Connect to the server's console
	sudo bash -c "echo $(CMD) > '/run/$(SERVICE).stdin'"
