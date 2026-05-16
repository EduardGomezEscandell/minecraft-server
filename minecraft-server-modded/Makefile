REGISTRY ?= minecraftcoleguisacr.azurecr.io
SERVICE ?= minecraft-modded
CONTAINER ?= minecraft-modded:latest
BUILD_CONTAINER ?= minecraft-modded-build:latest
SERVER_PORT ?= 25565

FERIUM_VERSION ?= v4.7.1
MINECRAFT_VERSION ?= 26.1.2
FORGE_VERSION ?= 26.1.2.43-beta

.PHONY: build push pull run install uninstall local-install command

build:
	docker build \
		--build-arg FERIUM_VERSION=${FERIUM_VERSION} \
		--build-arg MINECRAFT_VERSION=${MINECRAFT_VERSION} \
		--build-arg FORGE_VERSION=${FORGE_VERSION} \
		--target server \
		--tag $(CONTAINER) \
		.

push:
	docker tag $(CONTAINER) "$(REGISTRY)/$(CONTAINER)"
	docker push "$(REGISTRY)/$(CONTAINER)"

pull:
	docker pull "$(REGISTRY)/$(CONTAINER)"
	docker tag "$(REGISTRY)/$(CONTAINER)" "$(CONTAINER)"

run:
	mkdir -p data/world data/logs
	cd data && touch banned-ips.json banned-players.json ops.json usercache.json whitelist.json
	docker run                        \
		--rm -p 127.0.0.1:16003:25565 \
		--name minecraft-modded       \
		--interactive                 \
		--mount "type=bind,src=$(PWD)/data/world,dst=/server/world"                             \
		--mount "type=bind,src=$(PWD)/data/logs,dst=/server/logs"                               \
		--mount "type=bind,src=$(PWD)/data/banned-ips.json,dst=/server/banned-ips.json"         \
		--mount "type=bind,src=$(PWD)/data/banned-players.json,dst=/server/banned-players.json" \
		--mount "type=bind,src=$(PWD)/data/ops.json,dst=/server/ops.json"                       \
		--mount "type=bind,src=$(PWD)/data/usercache.json,dst=/server/usercache.json"           \
		--mount "type=bind,src=$(PWD)/data/whitelist.json,dst=/server/whitelist.json"           \
		$(CONTAINER)

install:
# Create data directory
	sudo mkdir -p '/data' && sudo chmod 1777 '/data'
	mkdir -p '/data/$(SERVICE)'

# Create persistent data files and directories so they can be mounted with the correct permissions
	cd '/data/$(SERVICE)' && mkdir -p world logs
	cd '/data/$(SERVICE)' && touch banned-ips.json banned-players.json ops.json usercache.json whitelist.json  || true
	
# Align ownership of the data directory with the user running the service
	sudo chown -R 5001:5001 '/data/$(SERVICE)'

# Install service files
	sudo cp 'services/$(SERVICE).socket' '/etc/systemd/system/$(SERVICE).socket'
	sudo cp 'services/$(SERVICE).service' '/etc/systemd/system/$(SERVICE).service'
	sudo sed -i "s|{{server_port}}|${SERVER_PORT}|g" "/etc/systemd/system/$(SERVICE).service"

# Update systemd
	sudo systemctl daemon-reload
	sudo systemctl enable '$(SERVICE).service'
	sudo systemctl restart '$(SERVICE).service'

uninstall:
	sudo systemctl stop '$(SERVICE).service'         || true
	sudo systemctl disable '$(SERVICE).service'      || true
	sudo rm '/etc/systemd/system/$(SERVICE).service' || true
	sudo rm '/etc/systemd/system/$(SERVICE).socket'  || true
	docker rmi "$(CONTAINER)"                        || true
	docker rmi "$(REGISTRY)/$(CONTAINER)"            || true

CMD ?= "/help"
command: ## Connect to the server's console
	sudo bash -c "echo $(CMD) > '/run/$(SERVICE).stdin'"

local-install: ## Install mods in your Minecraft client
	docker build \
		--build-arg FERIUM_VERSION=${FERIUM_VERSION}       \
		--build-arg MINECRAFT_VERSION=${MINECRAFT_VERSION} \
		--build-arg FORGE_VERSION=${FORGE_VERSION}         \
		--target client-builder                            \
		--tag "$(BUILD_CONTAINER)"                         \
		.

	rm -rf mods/

	docker create --name minecraft-mod-installer $(BUILD_CONTAINER) >/dev/null || { docker rm minecraft-mod-installer; exit 1; }
	docker cp minecraft-mod-installer:/builder/mods/. ./mods/                  || { docker rm minecraft-mod-installer; exit 1; }
	docker rm minecraft-mod-installer

# Create a tar.gz archive of the mods for easier sharing
	tar -czvf mods.tar.gz mods/

	@echo "--------------------------------------------------------"
	@echo "Mod folder created in $(PWD)/mods"
	@echo "Next steps:"
	@echo "  1. Install neoforge as explained here: https://docs.neoforged.net/user/docs/client/"
	@echo "  2. Copy the mods from $(PWD)/mods to your Minecraft mods folder"
	@echo "  3. Enjoy playing with the mods!"
	@echo "--------------------------------------------------------"
