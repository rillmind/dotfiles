#!/bin/sh

. ~/.scripts/colors.sh

echo -e "${AMARELO}Passo 1: Limpeza do Gerenciador de Pacotes DNF${NC}"

echo -e "\n${VERDE}>> Removendo dependências órfãs (dnf autoremove)...${NC}"
sudo dnf autoremove -y

echo -e "\n${VERDE}>> Limpando todo o cache do dnf (dnf clean all)...${NC}"
sudo dnf clean all

echo -e "\n${AMARELO}Limpeza do DNF concluída!${NC}"
echo -e "${CIANO}-----------------------------------------------------${NC}\n"
