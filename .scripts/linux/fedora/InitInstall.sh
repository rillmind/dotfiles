#!/bin/bash

read -p "Já alterou o parallel downloads? (s/n): " confirm1
if [[ "$confirm1" == "s" || "$confirm1" == "S" ]]; then
  echo "Continuando..."
else
  echo "Abortado."
  exit 1
fi

echo "Instalando pacotes essenciais!!!"

sudo bash $HOME/.scripts/linux/fedora/InstallEssential.sh

echo "Pacotes essenciais instalados!!!"

echo "Instalando Homebrew!!!"

bash $HOME/.scripts/linux/install/Homebrew.sh

echo "Homebrew instalado!!!"

hash -r

echo "Instalando pacotes essenciais do flatpak"

bash $HOME/.scripts/linux/install/FlatpakEssential.sh

echo "Pacotes flatpak instalados!!!"

# bash $HOME/dotfiles/.scripts/linux/LunarVimInstall.sh

# Configurações do sistema

timedatectl set-local-rtc 1 --adjust-system-clock > /dev/null 2>&1

sudo timedatectl set-ntp true > /dev/null 2>&1

sudo journalctl --vacuum-time=7d

curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sudo sh

sudo chsh -s $(which zsh)

bash $HOME/.scripts/linux/install/Rust.sh
