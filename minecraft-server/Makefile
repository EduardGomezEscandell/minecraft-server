SERVICE ?= minecraft
CONTAINER ?= minecraft:latest
SERVER_PORT ?= 25565

.PHONY: build push pull run install uninstall

build:
	docker build --tag $(CONTAINER) .

push:
	docker tag $(CONTAINER) minecraftcoleguisacr.azurecr.io/$(CONTAINER)
	docker push minecraftcoleguisacr.azurecr.io/$(CONTAINER)

pull:
	docker pull minecraftcoleguisacr.azurecr.io/$(CONTAINER)
	docker tag minecraftcoleguisacr.azurecr.io/$(CONTAINER) $(CONTAINER)

run:
	mkdir -p data/world data/logs
	cd data && touch banned-ips.json banned-players.json ops.json usercache.json whitelist.json
	docker run                        \
		--rm -p 127.0.0.1:16002:25565 \
		--name minecraft              \
		--interactive                 \
		--mount "type=bind,src=$(PWD)/data/world,dst=/server/world"                             \
		--mount "type=bind,src=$(PWD)/data/logs,dst=/server/logs"                               \
		--mount "type=bind,src=$(PWD)/data/banned-ips.json,dst=/server/banned-ips.json"         \
		--mount "type=bind,src=$(PWD)/data/banned-players.json,dst=/server/banned-players.json" \
		--mount "type=bind,src=$(PWD)/data/ops.json,dst=/server/ops.json"                       \
		--mount "type=bind,src=$(PWD)/data/usercache.json,dst=/server/usercache.json"           \
		--mount "type=bind,src=$(PWD)/data/whitelist.json,dst=/server/whitelist.json"           \
		$(CONTAINER)

install: pull
# Create data directory
	sudo mkdir -p '/data/$(SERVICE)'
	sudo chmod 1777 '/data/$(SERVICE)'

	cd '/data/$(SERVICE)' && mkdir -p world logs
	cd '/data/$(SERVICE)' && touch banned-ips.json banned-players.json ops.json usercache.json whitelist.json
	sudo chown -R root:root '/data/$(SERVICE)'
	find '/data/$(SERVICE)' -type d -exec sudo chmod 1777 {} \;
	find '/data/$(SERVICE)' -type f -exec sudo chmod 0666 {} \;

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

CMD ?= "/help"
command: ## Connect to the server's console
	sudo bash -c "echo $(CMD) > '/run/$(SERVICE).stdin'"
