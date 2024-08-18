#!/bin/bash
SSH_TARGET=${SSH_TARGET:-minecraft}

rsync --exclude="bin" --exclude=".git" --recursive ./minecraft-server/ "${SSH_TARGET}:minecraft-server/"
ssh ${SSH_TARGET} -- "sudo apt update && sudo apt install -y make" # All other dependencies are installed by the makefile
ssh ${SSH_TARGET} -- "cd minecraft-server && make dependencies && make install && make start"
ssh ${SSH_TARGET} -- "systemctl status minecraft.service"

