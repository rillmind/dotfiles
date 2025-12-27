#!/bin/sh

. ~/.scripts/linux/colors.sh

echo -e "${AMARELO}Passo 3: Limpeza de Caches Diversos${NC}"

echo -e "\n${VERDE}>> Limpando caches de aplicativos do usuário em ~/.cache...${NC}"
# O comando find é mais seguro que 'rm -rf' caso o diretório não exista
find ~/.cache/ -type f -delete
echo "Cache do usuário limpo."

echo -e "\n${VERDE}>> Limpando cache de miniaturas (thumbnails)...${NC}"
rm -rf ~/.cache/thumbnails/*
echo "Cache de miniaturas limpo."

echo -e "\n${VERDE}>> Limpando arquivos temporários do sistema...${NC}"
sudo rm -rf /tmp/* /var/tmp/*
echo "Arquivos temporários do sistema limpos."

echo -e "\n${VERDE}>> Otimizando e limpando os logs do sistema (journald)...${NC}"
echo "Mantendo logs dos últimos 7 dias e limitando o tamanho a 500MB."
sudo journalctl --vacuum-time=7d
sudo journalctl --vacuum-size=500M

echo -e "\n${VERDE}>> Limpando cache de aplicativos...${NC}"
sudo rm -rfv ~/.var/app/*/cache/*
sudo rm -rfv ~/.local/share/zed/node/node*/cache/*

echo -e "\n${VERDE}>> Limpando lixeira do sistema...${NC}"
sudo rm -rfv ~/.local/share/Trash/files/*
