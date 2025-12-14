#!/bin/sh

# ==============================================================================
#   SCRIPT DE LIMPEZA E MANUTENÇÃO PARA UBUNTU
#   Versão: 1.0
#   Este script executa várias tarefas de limpeza para liberar espaço em disco.
#   Execute com 'sudo ./ubuntu-cleanup.sh'
# ==============================================================================

# -- Funções de Cor para Melhor Visualização --
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
NC="\033[0m" # No Color

echo -e "${GREEN}--- Iniciando Faxina Digital no Ubuntu ---${NC}\n"

# --- 1. Limpeza do Gerenciador de Pacotes (APT) ---
echo -e "${YELLOW}==> 1/5: Limpando o cache do APT e removendo pacotes órfãos...${NC}"
apt-get clean
apt-get autoremove --purge -y
echo -e "${GREEN}Cache do APT e dependências órfãs removidos.${NC}\n"

# --- 2. Limpeza dos Logs do Sistema (Journald) ---
echo -e "${YELLOW}==> 2/5: Reduzindo o tamanho dos logs do sistema para no máximo 100MB...${NC}"
journalctl --vacuum-size=100M
echo -e "${GREEN}Logs antigos do sistema limpos.${NC}\n"

# --- 3. Limpeza de Snaps Antigos ---
# Remove revisões de snaps que estão desativadas.
echo -e "${YELLOW}==> 3/5: Removendo revisões antigas de Snaps...${NC}"
# Fecha todos os apps snap para evitar erros (descomente se necessário)
# snap stop $(snap list | awk '!/Nome|Name/{print $1}')
snap list --all | awk '/desativado|disabled/{print $1, $3}' |
    while read snapname revision; do
        snap remove "$snapname" --revision="$revision"
    done
echo -e "${GREEN}Revisões antigas de Snaps removidas.${NC}\n"

# --- 4. Limpeza de Flatpaks Não Utilizados ---
# Verifica se o flatpak está instalado antes de rodar o comando.
if command -v flatpak &> /dev/null
then
    echo -e "${YELLOW}==> 4/5: Removendo runtimes de Flatpak não utilizados...${NC}"
    flatpak uninstall --unused -y
    echo -e "${GREEN}Runtimes de Flatpak não utilizados removidos.${NC}\n"
else
    echo -e "${YELLOW}==> 4/5: Flatpak não encontrado. Pulando etapa.${NC}\n"
fi

# --- 5. Limpeza de Caches do Usuário ---
# Esta seção limpa caches que pertencem ao usuário que executou o sudo.
# O alvo principal é o cache de miniaturas.
echo -e "${YELLOW}==> 5/5: Limpando o cache de miniaturas do usuário...${NC}"
if [ "$SUDO_USER" ]; then
    HOME_DIR=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    THUMBNAIL_DIR="$HOME_DIR/.cache/thumbnails"
    if [ -d "$THUMBNAIL_DIR" ]; then
        rm -rf "$THUMBNAIL_DIR"/*
        echo -e "${GREEN}Cache de miniaturas de '$SUDO_USER' limpo.${NC}"
    else
        echo "Diretório de miniaturas não encontrado para o usuário $SUDO_USER."
    fi
else
    echo "Não foi possível determinar o usuário. Pulando limpeza de cache de miniaturas."
fi

rm -rf ~/.cache/*

# --- Mensagem Final ---
echo -e "\n${GREEN}--- Limpeza Concluída! ---${NC}"
