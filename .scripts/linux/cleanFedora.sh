#!/bin/sh

. ~/.scripts/colors.sh

echo -e "${CIANO}=====================================================${NC}"
echo -e "${CIANO}===    Iniciando Script de Limpeza para Fedora    ===${NC}"
echo -e "${CIANO}=====================================================${NC}\n"

# --- Seção 1: Limpeza do DNF ---

sh ~/.scripts/cleanDNF.sh

# --- Seção 2: Limpeza do Flatpak ---

sh ~/.scripts/cleanFlatpak.sh

# --- Seção 3: Limpeza de Caches do Sistema e do Usuário ---

sh ~/.scripts/cleanUserCaches.sh

# --- Seção 4: Limpeza do Docker ---

sh ~/.scripts/cleanDocker.sh

# --- Seção 5: Limpeza do Podman ---

sh ~/.scripts/cleanPodman.sh

echo -e "\n${AMARELO}Limpeza de caches diversos concluída!${NC}"
echo -e "${CIANO}-----------------------------------------------------${NC}\n"

echo -e "${CIANO}=====================================================${NC}"
echo -e "${CIANO}===         Limpeza do Sistema Concluída!         ===${NC}"
echo -e "${CIANO}=====================================================${NC}"
