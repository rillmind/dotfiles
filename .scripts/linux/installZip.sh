#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Uso: $0 <arquivo.zip> <nome_do_executavel>"
    exit 1
fi

ZIP_FILE="$1"
EXEC_NAME="$2"
APP_NAME=$(basename "$ZIP_FILE" .zip)

INSTALL_DIR="$HOME/.local/share/$APP_NAME"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"

# Criar diretórios necessários
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR"

# Extrair o zip
echo "Extraindo $ZIP_FILE..."
unzip -q -o "$ZIP_FILE" -d "$INSTALL_DIR"

# Localizar o executável
EXEC_PATH=$(find "$INSTALL_DIR" -type f -name "$EXEC_NAME" | head -n 1)

if [ -z "$EXEC_PATH" ]; then
    echo "Erro: Executável '$EXEC_NAME' não encontrado dentro do zip."
    # Limpar a pasta se falhar
    rm -rf "$INSTALL_DIR"
    exit 1
fi

# Dar permissão de execução e criar o link em ~/.local/bin
chmod +x "$EXEC_PATH"
ln -sf "$EXEC_PATH" "$BIN_DIR/$EXEC_NAME"

# Procurar um ícone válido (.png ou .svg)
ICON_PATH=$(find "$INSTALL_DIR" -type f \( -name "*.png" -o -name "*.svg" \) | head -n 1)

if [ -z "$ICON_PATH" ]; then
    # Ícone genérico do sistema se não encontrar nenhum
    ICON_PATH="application-x-executable"
fi

# Criar o atalho .desktop
DESKTOP_FILE="$DESKTOP_DIR/$APP_NAME.desktop"

cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Name=$APP_NAME
Exec=$BIN_DIR/$EXEC_NAME
Icon=$ICON_PATH
Type=Application
Terminal=false
EOF

chmod +x "$DESKTOP_FILE"

echo "Instalação concluída!"
echo "Executável: $BIN_DIR/$EXEC_NAME"
echo "Atalho criado: $DESKTOP_FILE"
