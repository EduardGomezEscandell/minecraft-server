.PHONY: install uninstall start stop

WHO := $(shell whoami)
install:
# Create user
	id webserver || sudo adduser webserver --no-create-home --disabled-password --gecos ""
	sudo usermod -a -G webserver $(WHO)

# Create working directory owned by webserver
	sudo mkdir -p /www/website
	sudo cp -r * /www/website
	sudo rm -rf /www/website/services || true

	sudo chown -R webserver /www/website
	sudo chgrp -R webserver /www/website
	sudo chmod -R 755 /www/website

# Install service files
	sudo cp services/website.service /etc/systemd/system/website.service
	sudo systemctl daemon-reload
	sudo systemctl enable website.service

# Allow webserver to bind to port 80
	sudo iptables -t nat -I PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 3000

localhost:
	sudo python3 -m http.server 80 --directory .

start: ## Starts the installed service
	sudo systemctl restart website.service

stop: ## Stops the installed service
	sudo systemctl stop website.service

uninstall:
	sudo systemctl stop website.service
	sudo systemctl disable website.service
	sudo rm /etc/systemd/system/website.service || true
	sudo rm -rf /www/website || true
	sudo deluser webserver || true
	sudo delgroup webserver || true