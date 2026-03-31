#!/bin/bash

# Define os caminhos utilizados na instalação
ZEN_DIR="/opt/zen-browser"
BIN_LINK="/usr/local/bin/zen-browser"
DESKTOP_ENTRY="/usr/share/applications/zen.desktop"

echo "Iniciando a remoção do Zen Browser..."

# 1. Remover o diretório de instalação
if [ -d "$ZEN_DIR" ]; then
    echo "Removendo arquivos em $ZEN_DIR..."
    sudo rm -rf "$ZEN_DIR"
else
    echo "Diretório $ZEN_DIR não encontrado."
fi

# 2. Remover o link simbólico do binário
if [ -L "$BIN_LINK" ]; then
    echo "Removendo link simbólico em $BIN_LINK..."
    sudo rm "$BIN_LINK"
fi

# 3. Remover a entrada no menu de aplicativos
if [ -f "$DESKTOP_ENTRY" ]; then
    echo "Removendo atalho de menu..."
    sudo rm "$DESKTOP_ENTRY"
fi

# 4. Atualizar o banco de dados de aplicativos (opcional, para o GNOME refletir a mudança)
update-desktop-database ~/.local/share/applications &> /dev/null

echo "----------------------------------------------------"
echo "Zen Browser foi removido com sucesso do sistema."
echo "Nota: Seus dados de perfil (favoritos, senhas e extensões)"
echo "em ~/.zen/ não foram tocados por segurança."
echo "----------------------------------------------------"
