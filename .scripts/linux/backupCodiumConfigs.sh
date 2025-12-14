#!/bin/sh

echo "Fazendo backup..."

codium --list-extensions > ~/.config/codium/extensions_list.txt

cat ~/.config/VSCodium/User/settings.json > ~/dotfiles/.config/codium/settings.json
cat ~/.config/VSCodium/User/keybindings.json > ~/dotfiles/.config/codium/keybindings.json

sleep 0.5

echo "Backup concluído!"
