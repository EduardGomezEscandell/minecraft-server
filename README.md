# Systemd-managed Minecraft service

This repository contains tools to manage a Minecraft server via systemd.

## Option 1: Running on the hosted machine
To run the Minecraft server on the current machine, just go `cd minecraft-server` and use the Makefile there.
This should do it:
```bash
cd minecraft-server
make dependencies
make install
make start
```

## Option 2: Running on some other machine
This is useful if you have an Azure/AWS/GCP, etc. machine. Obtain your SSH host and user and do:
```bash
SSH_TARGET="user@hostname" ./deploy.sh
```

Alternatively, it is worth adding the host to your `.ssh/config` file. Run the following command
with the proper user and hostname.
```bash
cat << EOF >> .ssh/config
Host minecraft 
    HostName HOSTNAME
    User USER
    Port 22
    IdentityFile ~/.ssh/YOUR_SSH_KEY
```