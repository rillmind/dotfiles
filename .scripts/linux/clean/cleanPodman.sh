#!/bin/sh

. ~/.scripts/linux/clen/colors.sh

echo -e "\n${VERDE}>> Limpando podman...${NC}"
podman rm --all --force
podman rmi --all --force
podman system prune -a -f
