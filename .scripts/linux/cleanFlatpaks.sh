#!/bin/sh

. ~/.scripts/linux/colors.sh

echo -e "${AMARELO}Passo 2: Limpeza do Flatpak${NC}"

if ! command -v flatpak &> /dev/null; then
    echo "Flatpak não encontrado. Pulando esta seção."
else
    echo -e "\n${VERDE}>> Desinstalando runtimes do Flatpak não utilizados...${NC}"
    flatpak uninstall --unused -y

    echo -e "\n${VERDE}>> Limpando o cache de download do Flatpak...${NC}"
    sudo rm -rf /var/tmp/flatpak-cache-*
    echo "Cache do Flatpak limpo."
fi

echo -e "\n${AMARELO}Limpeza do Flatpak concluída!${NC}"
echo -e "${CIANO}-----------------------------------------------------${NC}\n"
