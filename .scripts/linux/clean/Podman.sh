#!/bin/sh

. ~/.scripts/linux/clean/colors.sh

echo -e "\n${VERDE}>> Limpando podman (preservando containers do Distrobox)...${NC}"
# Containers do Distrobox têm o label manager=distrobox; os demais são removidos
for id in $(podman ps -aq); do
    [ "$(podman inspect -f '{{index .Config.Labels "manager"}}' "$id")" = "distrobox" ] || podman rm -f "$id"
done
# Remove imagens não usadas por nenhum container restante (as do Distrobox ficam)
podman image prune -a -f
podman system prune -f
