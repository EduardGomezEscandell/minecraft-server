.PHONY: build push pull run install uninstall

SERVER_IP?="localhost"
SERVER_PORT1?="16001"
SERVER_PORT2?="16002"

build:
	cp ../minecraft-server-modded/mods.json ./mods.json
	docker build \
		--tag website:latest \
		--build-arg SERVER_IP=${SERVER_IP} \
		--build-arg SERVER_PORT1=${SERVER_PORT1} \
		--build-arg SERVER_PORT2=${SERVER_PORT2} \
		.

push:
	docker tag website:latest minecraftcoleguisacr.azurecr.io/website:latest
	docker push minecraftcoleguisacr.azurecr.io/website:latest

pull:
	docker pull minecraftcoleguisacr.azurecr.io/website:latest
	docker tag minecraftcoleguisacr.azurecr.io/website:latest website:latest

run:
	docker run --rm -p 127.0.0.1:80:3000 --name website website:latest

install: pull
	sudo cp services/website.service /etc/systemd/system/website.service
	sudo systemctl daemon-reload
	sudo systemctl enable website.service
	sudo systemctl restart website.service

uninstall:
	sudo systemctl stop website.service         || true
	sudo systemctl disable website.service      || true
	sudo rm /etc/systemd/system/website.service || true
	sudo systemctl daemon-reload                || true