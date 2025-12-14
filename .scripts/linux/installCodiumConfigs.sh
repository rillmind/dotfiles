#!/bin/sh

if [ -d ~/.config/VSCodium/ ]; then
  if [ -f ~/.config/VSCodium/User/settings.json ]; then
    echo "Instalando configurações..."

    cat ~/.config/codium/extensions_list.txt | xargs -L 1 codium --install-extension

    cat ~/.config/codium/settings.json > ~/.config/VSCodium/User/settings.json
    cat ~/.config/codium/keybindings.json > ~/.config/VSCodium/User/keybindings.json

    sleep 0.5

    echo "Configurações instaladas!"

  else
    echo "Instalando configurações..."

    cp ~/dotfiles/.config/codium/* ~/.config/VSCodium/User/

    sleep 0.5

    echo "Configurações instaladas!"
  fi

else
  echo "VSCodium não instalado!"
fi
