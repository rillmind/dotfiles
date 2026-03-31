#!/bin/sh

# Caminho do Zed no Flatpak
ZED_FLATPAK="$HOME/.var/app/dev.zed.Zed/config/zed"
BACKUP_DEST="$HOME/dotfiles/.config/zed"

echo "Fazendo backup do Zed (Flatpak)..."

mkdir -p "$BACKUP_DEST"

if [ -d "$ZED_FLATPAK" ]; then
  cat "$ZED_FLATPAK/settings.json" > "$BACKUP_DEST/settings.json"
  cat "$ZED_FLATPAK/keymap.json" > "$BACKUP_DEST/keymap.json"
  
  sleep 0.5
  echo "Backup concluído em $BACKUP_DEST!"
else
  echo "Erro: Pasta do Flatpak não encontrada em $ZED_FLATPAK"
fi
