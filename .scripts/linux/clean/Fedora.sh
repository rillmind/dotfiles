#!/bin/sh

. ~/.scripts/linux/clean/colors.sh

echo -e "${CIANO}=====================================================${NC}"
echo -e "${CIANO}===    Iniciando Script de Limpeza para Fedora    ===${NC}"
echo -e "${CIANO}=====================================================${NC}\n"

# --- Seção 1: Limpeza do DNF ---

bash ~/.scripts/linux/clean/DNF.sh

# --- Seção 2: Limpeza do Flatpak ---

bash ~/.scripts/linux/clean/Flatpak.sh

# --- Seção 3: Limpeza de Caches do Sistema e do Usuário ---

bash ~/.scripts/linux/clean/UserCaches.sh

# --- Seção 4: Limpeza do Docker ---

bash ~/.scripts/linux/clean/Docker.sh

# --- Seção 5: Limpeza do Podman ---

# Linha comentada pois limparia o Distrobox sempre que limpasse o sistema!
bash ~/.scripts/linux/clean/Podman.sh

echo -e "\n${AMARELO}Limpeza de caches diversos concluída!${NC}"
echo -e "${CIANO}-----------------------------------------------------${NC}\n"

echo -e "${CIANO}=====================================================${NC}"
echo -e "${CIANO}===         Limpeza do Sistema Concluída!         ===${NC}"
echo -e "${CIANO}=====================================================${NC}"
