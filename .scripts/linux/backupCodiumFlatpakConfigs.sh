#!/bin/sh

FLATPAK_CONFIG="$HOME/.var/app/com.vscodium.codium/config/VSCodium/User"
BACKUP_DEST="$HOME/dotfiles/.config/codium"

echo "Fazendo backup do VSCodium (Flatpak)..."

# Garante que o diretório de destino existe
mkdir -p "$BACKUP_DEST"

# Lista extensões via comando Flatpak
flatpak run com.vscodium.codium --list-extensions > "$BACKUP_DEST/extensions_list.txt"

# Copia arquivos de configuração do sandbox para o destino
if [ -d "$FLATPAK_CONFIG" ]; then
    cp "$FLATPAK_CONFIG/settings.json" "$BACKUP_DEST/settings.json"
    cp "$FLATPAK_CONFIG/keybindings.json" "$BACKUP_DEST/keybindings.json"
    
    sleep 0.5
    echo "Backup concluído em $BACKUP_DEST!"
else
    echo "Erro: Diretório de configuração do Flatpak não encontrado."
fi