#!/bin/sh

. ~/.scripts/linux/clean/colors.sh

echo -e "${AMARELO}Passo 4: Limpeza de Caches de Desenvolvimento${NC}"

if command -v bun &> /dev/null; then
    echo -e "\n${VERDE}>> Limpando cache de pacotes do Bun...${NC}"
    # `bun pm cache rm` exige um package.json no diretório atual, então apaga a pasta direto
    rm -rf "${BUN_INSTALL_CACHE_DIR:-${BUN_INSTALL:-$HOME/.bun}/install/cache}"
    echo "Cache do Bun limpo."
fi

if command -v npm &> /dev/null; then
    echo -e "\n${VERDE}>> Limpando cache do npm...${NC}"
    npm cache clean --force
fi

if command -v go &> /dev/null; then
    echo -e "\n${VERDE}>> Limpando cache de módulos do Go...${NC}"
    go clean -modcache
fi

echo -e "\n${VERDE}>> Limpando caches do Gradle e do registry do Cargo...${NC}"
rm -rf ~/.gradle/caches ~/.cargo/registry/cache ~/.cargo/registry/src
echo "Caches do Gradle e do Cargo limpos."

echo -e "\n${AMARELO}Limpeza de caches de desenvolvimento concluída!${NC}"
echo -e "${CIANO}-----------------------------------------------------${NC}\n"
