INSTALL_LOC ?= /opt/minecraft-modded
SERVICE ?= minecraft-modded
USER=minecraftmod
FORGE_VERSION ?= 1.21.1-52.0.4
FERIUM_VERSION ?= v4.7.0
MINECRAFT_VERSION ?= 1.21.1

.PHONY: help
help: ## Show this help message
	@echo "Minecraft Development Makefile"
	@echo ""
	@echo "COMMANDS"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

dependencies: ## Downloads the dependencies
	sudo apt update
	sudo apt install -y openjdk-25-jre unzip wget
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
	id '$(USER)' || sudo adduser '$(USER)' --no-create-home --disabled-password --gecos ""
	sudo usermod -a -G '$(USER)' '$(WHO)'

# Create working directory owned by Minecraft
	sudo mkdir -p '$(INSTALL_LOC)'
	sudo chown '$(WHO):$(WHO)' '$(INSTALL_LOC)'
	cp bin/server.jar '$(INSTALL_LOC)/server.jar'
	cp 'server.properties' '$(INSTALL_LOC)/server.properties'
	cp 'bin/forge-$(FORGE_VERSION)-installer.jar' '$(INSTALL_LOC)/forge-$(FORGE_VERSION)-installer.jar'
	cp bin/ferium '$(INSTALL_LOC)/ferium'
	bash -c "echo eula=TRUE > '$(INSTALL_LOC)/eula.txt'"

# Install forge
	cd '$(INSTALL_LOC)' && java -jar '$(INSTALL_LOC)/forge-$(FORGE_VERSION)-installer.jar' --installServer
	mv '$(INSTALL_LOC)/forge-$(FORGE_VERSION)-shim.jar' '$(INSTALL_LOC)/forge-server.jar'
	cd '$(INSTALL_LOC)' && rm run.sh 'forge-$(FORGE_VERSION)-installer.jar' user_jvm_args.txt

# Set up Ferium
	sudo chmod u+x $(INSTALL_LOC)/ferium

	$(FERIUM) profile create                    \
		--mod-loader forge                      \
		--game-version '$(MINECRAFT_VERSION)'   \
		--name forge                            \
		--output-dir '$(INSTALL_LOC)/mods' || true

	$(FERIUM) add -f $(shell cat mods.json | jq -r ".[]")
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

.PHONY: uninstall
uninstall: ## Uninstalls the server
	sudo systemctl stop '$(SERVICE).service'         || true
	sudo systemctl disable '$(SERVICE).service'      || true
	sudo rm '/etc/systemd/system/$(SERVICE).service' || true
	sudo rm '/etc/systemd/system/$(SERVICE).socket'  || true
	sudo chgrp -R '$(WHO)' '$(INSTALL_LOC)'          || true
	sudo chown -R '$(WHO)' '$(INSTALL_LOC)'          || true
	sudo delgroup '$(USER)'                          || true
	sudo deluser '$(USER)'                           || true

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
