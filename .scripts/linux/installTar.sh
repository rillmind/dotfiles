#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Uso: $0 <arquivo.tar|arquivo.tar.xz> <nome_do_executavel>"
    exit 1
fi

ARCHIVE_FILE="$1"
EXEC_NAME="$2"

# Remove extensões .tar, .tar.xz, .tar.gz, etc., para nomear o app
APP_NAME=$(basename "$ARCHIVE_FILE" | sed -e 's/\.tar\(\.[a-z2]*\)*$//')

INSTALL_DIR="$HOME/.local/share/$APP_NAME"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR"

echo "Extraindo $ARCHIVE_FILE..."
# O comando 'tar -xf' no Linux detecta automaticamente a compressão (.xz, .gz, etc.)
tar -xf "$ARCHIVE_FILE" -C "$INSTALL_DIR"

EXEC_PATH=$(find "$INSTALL_DIR" -type f -name "$EXEC_NAME" | head -n 1)

if [ -z "$EXEC_PATH" ]; then
    echo "Erro: Executável '$EXEC_NAME' não encontrado dentro do arquivo."
    rm -rf "$INSTALL_DIR"
    exit 1
fi

chmod +x "$EXEC_PATH"
ln -sf "$EXEC_PATH" "$BIN_DIR/$EXEC_NAME"

ICON_PATH=$(find "$INSTALL_DIR" -type f \( -name "*.png" -o -name "*.svg" \) | head -n 1)

if [ -z "$ICON_PATH" ]; then
    ICON_PATH="application-x-executable"
fi

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
