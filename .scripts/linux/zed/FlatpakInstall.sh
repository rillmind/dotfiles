#!/bin/sh

# Caminho do Zed no Flatpak
ZED_FLATPAK="$HOME/.var/app/dev.zed.Zed/config/zed"
DOTFILES_ZED="$HOME/dotfiles/.config/zed"

if [ -d "$DOTFILES_ZED" ]; then
  echo "Aplicando configurações ao Zed editor (Flatpak)..."
  
  # Garante que a pasta de configuração do sandbox existe
  mkdir -p "$ZED_FLATPAK"

  touch "$ZED_FLATPAK/settings.json"
  touch "$ZED_FLATPAK/keymap.json"
  
  cat "$DOTFILES_ZED/settings.json" > "$ZED_FLATPAK/settings.json"
  cat "$DOTFILES_ZED/keymap.json" > "$ZED_FLATPAK/keymap.json"
  
  sleep 0.5
  echo "Configurações aplicadas!!!"
else
  echo "Erro: Configurações não encontradas em $DOTFILES_ZED"
fi
