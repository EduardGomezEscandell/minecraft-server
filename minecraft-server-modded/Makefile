INSTALL_LOC ?= /opt/minecraft-modded
SERVICE ?= minecraft-modded
USER=minecraftmod
LOCAL_INSTALL=/mnt/c/Users/edu19/AppData/Roaming/.minecraft
FERIUM_VERSION ?= v4.7.1
MINECRAFT_VERSION ?= 26.1.2
FORGE_VERSION ?= 26.1.2.43-beta
.PHONY: help
help: ## Show this help message
	@echo "Minecraft Development Makefile"
	@echo ""
	@echo "COMMANDS"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

dependencies: ## Downloads the dependencies
	sudo apt install -y openjdk-25-jre unzip wget
	mkdir -p bin
	wget -q -O bin/server.jar 'https://piston-data.mojang.com/v1/objects/97ccd4c0ed3f81bbb7bfacddd1090b0c56f9bc51/server.jar'
	wget -q -O bin/neoforge-$(FORGE_VERSION)-installer.jar 'https://maven.neoforged.net/releases/net/neoforged/neoforge/$(FORGE_VERSION)/neoforge-$(FORGE_VERSION)-installer.jar'
	wget -q -O bin/ferium-linux-nogui.zip 'https://github.com/gorilla-devs/ferium/releases/download/$(FERIUM_VERSION)/ferium-linux-nogui.zip'
	unzip bin/ferium-linux-nogui.zip -d bin
	rm bin/ferium-linux-nogui.zip

WHO := $(shell whoami)
FERIUM := '$(INSTALL_LOC)/ferium' --config-file '$(INSTALL_LOC)/ferium-config.json'
LOCAL_FERIUM := '$(LOCAL_INSTALL)/ferium' --config-file '$(LOCAL_INSTALL)/ferium-config.json'
.PHONY: install
install: ## Installs the server
# Create Minecraft group and user
	id '$(USER)' || sudo adduser '$(USER)' --no-create-home --disabled-password --gecos ""
	sudo usermod -a -G '$(USER)' '$(WHO)'

# Create working directory owned by Minecraft
	sudo mkdir -p '$(INSTALL_LOC)'
	sudo chown '$(WHO):$(WHO)' '$(INSTALL_LOC)'
	sudo cp bin/server.jar '$(INSTALL_LOC)/server.jar'
	sudo cp 'server.properties' '$(INSTALL_LOC)/server.properties'
	sudo cp 'bin/neoforge-$(FORGE_VERSION)-installer.jar' '$(INSTALL_LOC)/neoforge-$(FORGE_VERSION)-installer.jar'
	sudo cp bin/ferium '$(INSTALL_LOC)/ferium'
	sudo bash -c "echo eula=TRUE > '$(INSTALL_LOC)/eula.txt'"

# Install forge
	java -jar '$(INSTALL_LOC)/neoforge-$(FORGE_VERSION)-installer.jar' --installServer '$(INSTALL_LOC)'
	echo "-Xmx12G -Xms12G" | tee '$(INSTALL_LOC)/user_jvm_args.txt'
	rm -rf '$(INSTALL_LOC)/neoforge-$(FORGE_VERSION)-installer.jar'
# Set up Ferium
	sudo chmod u+x $(INSTALL_LOC)/ferium

	$(FERIUM) profile create                    \
		--mod-loader neo-forge                  \
		--game-version '$(MINECRAFT_VERSION)'   \
		--name forge                            \
		--output-dir '$(INSTALL_LOC)/mods' || true

	$(FERIUM) add -f $(shell jq -r ".[].project_id" "mods.json")
	$(FERIUM) upgrade || true

# Update ownership
	sudo chown -R '$(USER)' '$(INSTALL_LOC)'
	sudo chgrp -R '$(USER)' '$(INSTALL_LOC)'
	sudo chmod -R 'g=u,o-rwx' '$(INSTALL_LOC)'

# Install service files
	sudo cp 'services/$(SERVICE).socket' '/etc/systemd/system/$(SERVICE).socket'
	sudo cp 'services/$(SERVICE).service' '/etc/systemd/system/$(SERVICE).service'

# Update systemd
	sudo systemctl daemon-reload
	sudo systemctl enable '$(SERVICE).service'

local-install:
	cp 'bin/neoforge-$(FORGE_VERSION)-installer.jar' '$(LOCAL_INSTALL)/neoforge-$(FORGE_VERSION)-installer.jar'
	cp bin/ferium '$(LOCAL_INSTALL)/ferium'
	java -jar '$(LOCAL_INSTALL)/neoforge-$(FORGE_VERSION)-installer.jar' --install-client $(LOCAL_INSTALL)
	rm -rf '$(LOCAL_INSTALL)/neoforge-$(FORGE_VERSION)-installer.jar'

	$(LOCAL_FERIUM) profile create                    \
		--mod-loader neo-forge                  \
		--game-version '$(MINECRAFT_VERSION)'   \
		--name forge                            \
		--output-dir '$(LOCAL_INSTALL)/mods' || true

	$(LOCAL_FERIUM) add -f $(shell jq -r ".[].project_id" "mods.json")
	$(LOCAL_FERIUM) upgrade || true

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
	sudo rm -rf '$(INSTALL_LOC)/mods' '$(INSTALL_LOC)/ferium-config.json' || true

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
