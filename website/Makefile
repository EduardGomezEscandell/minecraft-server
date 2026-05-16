.PHONY: build push pull run install uninstall

REGISTRY?=minecraftcoleguisacr.azurecr.io
CONTAINER?=website:latest
SERVICE?=website
SERVER_IP?=localhost
SERVER_PORT1?=16001
SERVER_PORT2?=16002

build:
	cp ../minecraft-server-modded/mods.json ./mods.json
	docker build \
		--tag $(CONTAINER) \
		--build-arg SERVER_IP=${SERVER_IP} \
		--build-arg SERVER_PORT1=${SERVER_PORT1} \
		--build-arg SERVER_PORT2=${SERVER_PORT2} \
		.

push:
	docker tag "$(CONTAINER)" "$(REGISTRY)/$(CONTAINER)"
	docker push "$(REGISTRY)/$(CONTAINER)"

pull:
	docker pull "$(REGISTRY)/$(CONTAINER)"
	docker tag "$(REGISTRY)/$(CONTAINER)" $(CONTAINER)

run:
	docker run --rm -p 127.0.0.1:80:3000 --name website $(CONTAINER)

install:
	sudo mkdir -p /data && sudo chmod 1777 /data
	sudo mkdir -p /data/$(SERVICE) && sudo chmod 1777 '/data/$(SERVICE)'

	[ -f /data/$(SERVICE)/mods.tar.gz ] || install -m 0666 /dev/null /data/$(SERVICE)/mods.tar.gz
	sudo chown -R 5002:5002 /data/$(SERVICE)

	sudo chmod a+r /data/$(SERVICE)/mods.tar.gz
	sudo cp services/website.service /etc/systemd/system/website.service
	sudo systemctl daemon-reload
	sudo systemctl enable website.service
	sudo systemctl restart website.service

uninstall:
	sudo systemctl stop website.service         || true
	sudo systemctl disable website.service      || true
	sudo rm /etc/systemd/system/website.service || true
	sudo systemctl daemon-reload                || true
	docker rmi "$(CONTAINER)"                   || true
	docker rmi "$(REGISTRY)/$(CONTAINER)"       || true