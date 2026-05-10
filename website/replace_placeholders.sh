#!/bin/bash
set -eux

SERVER_IP="$2"
SERVER_PORT1="$3"
SERVER_PORT2="$4"

MODLIST=$(jq -r '.[] | "<li><a href=\"" + .url + "\" target=_blank>" + .name + "</a></li>"' mods.json | tr '\n' ' ')

[ -z "${MODLIST}" ] && { MODLIST="No mods found." ; exit 2; }

sed -i "s|{{ip_address}}|${SERVER_IP}:${SERVER_PORT1}|g" "src/minecraft.html"
sed -i "s|{{ip_address}}|${SERVER_IP}:${SERVER_PORT2}|g" "src/mods.html"
sed -i "s|{{modlist}}|${MODLIST}|g" "src/mods.html"