#!/bin/bash
set -eux

WORKING_DIR=$1
SERVER_IP="$2"
SERVER_PORT1="$3"
SERVER_PORT2="$4"

MODLIST=$(jq -r '.[] | select(.client == "required") | "<li><a href=\"" + .url + "\" target=_blank>" + .name + "</a></li>"' mods.json | tr '\n' ' ')
RECOMMENDED=$(jq -r '.[] | select(.client == "recommended") | "<li><a href=\"" + .url + "\" target=_blank>" + .name + "</a></li>"' mods.json | tr '\n' ' ')

[ -z "${MODLIST}" ] && { MODLIST="No mods found." ; exit 2; }

sed -i "s|{{ip_address}}|${SERVER_IP}:${SERVER_PORT1}|g" "${WORKING_DIR}/minecraft.html"
sed -i "s|{{ip_address}}|${SERVER_IP}:${SERVER_PORT2}|g" "${WORKING_DIR}/mods.html"
sed -i "s|{{modlist}}|${MODLIST}|g" "${WORKING_DIR}/mods.html"
sed -i "s|{{recommended_modlist}}|${RECOMMENDED}|g" "${WORKING_DIR}/mods.html"
