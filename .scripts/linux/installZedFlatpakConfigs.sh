#!/bin/sh

# Caminho do Zed no Flatpak
ZED_FLATPAK="$HOME/.var/app/dev.zed.Zed/config/zed"
DOTFILES_ZED="$HOME/dotfiles/.config/zed"

if [ -d "$DOTFILES_ZED" ]; then
    echo "Instalando configurações no Zed (Flatpak)..."
    
    # Garante que a pasta de configuração do sandbox existe
    mkdir -p "$ZED_FLATPAK"
    
    cp "$DOTFILES_ZED/settings.json" "$ZED_FLATPAK/"
    cp "$DOTFILES_ZED/keymap.json" "$ZED_FLATPAK/"
    
    sleep 0.5
    echo "Configurações aplicadas ao Flatpak com sucesso!"
else
    echo "Erro: Configurações não encontradas em $DOTFILES_ZED"
fi
