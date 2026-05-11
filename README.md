# Systemd-managed Minecraft service

This repository contains tools to manage a Minecraft server via systemd.

## Option 1: Running on the hosted machine
To run the Minecraft server on the current machine, just go `cd minecraft-server` and use the Makefile there.
This should do it:
```bash
cd minecraft-server
make build
make install
```
You can later uninstall with `make uninstall`. This will remove the services and docker images, but not the saved data from
you Minecraft world. That is stored in `/data/minecraft`, which you can choose to remove manually.

For modded servers, the process is the same, you just need to run these steps in directory `minecraft-server-modded`, and the 
data is saved under `data/minecraft-moded`.

## Option 2: Running on some other machine

### Setting up the infrastructure
This repo contains all you need to deploy to Azure.

First, log in to your Azure account with `az login`. You need to visit the portal and create a subscription.
In this subscription, create a resource group. Inside it, create a Storage account, and within it a container named "tfstate".

Then, go to infra/providers.tf and update the resource_group_name and storage_account_name variables under terraform.backend.azurerm,

Once you've got this, you can deploy via:
```bash
make apply
```

If you want to skip the remote state and get started quicker, simply comment out the entire terraform.backend. You can always migrate later.

### Deploying the servers
There is a script that deploys both modded and unmodded servers to your Azure backend.

You need to log in to Azure first:
```
az login
```
Once logged in, you have a choice of what to deploy. All gets deployed by default, but you can use any of these to deploy only part of the stack:
```bash
export SKIP_BACKUP_MANAGER=1
export SKIP_MINECRAFT=1
export SKIP_MINECRAFT_MODDED=1
export SKIP_WEBSITE=1
```

Once you've set any (or none) of these environement variables, you can deploy with:
```
./deploy.sh
```