#!/bin/sh

# Caminhos do Flatpak
FLATPAK_CONFIG="$HOME/.var/app/com.vscodium.codium/config/VSCodium/User"
EXT_LIST="$HOME/.config/codium/extensions_list.txt"

if [ -d "$HOME/.var/app/com.vscodium.codium" ]; then
    echo "Instalando configurações para VSCodium (Flatpak)..."

    # Instalação de extensões via Flatpak
    if [ -f "$EXT_LIST" ]; then
        cat "$EXT_LIST" | xargs -L 1 flatpak run com.vscodium.codium --install-extension
    fi

    # Cria o diretório de destino caso não exista
    mkdir -p "$FLATPAK_CONFIG"

    # Sincronização dos arquivos
    if [ -f "$HOME/.config/codium/settings.json" ]; then
        cp "$HOME/.config/codium/settings.json" "$FLATPAK_CONFIG/settings.json"
        cp "$HOME/.config/codium/keybindings.json" "$FLATPAK_CONFIG/keybindings.json"
    else
        cp ~/dotfiles/.config/codium/* "$FLATPAK_CONFIG/"
    fi

    sleep 0.5
    echo "Configurações instaladas!"
else
    echo "VSCodium Flatpak não encontrado em ~/.var/app/com.vscodium.codium"
fi