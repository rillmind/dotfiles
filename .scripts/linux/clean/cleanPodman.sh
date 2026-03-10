#!/bin/sh

. ~/.scripts/linux/clean/colors.sh

echo -e "\n${VERDE}>> Limpando podman...${NC}"
podman rm --all --force
podman rmi --all --force
podman system prune -a -f
