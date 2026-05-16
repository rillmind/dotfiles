#!/bin/bash

read -p "Já alterou o parallel downloads? (s/n): " confirm1
if [[ "$confirm1" == "s" || "$confirm1" == "S" ]]; then
  echo "Continuando..."
else
  echo "Abortado."
  exit 1
fi

echo "Instalando pacotes essenciais!!!"

sudo dnf copr enable scottames/ghostty

sudo dnf copr enable sdegler/hyprland

sudo dnf install -y vim ghostty zsh gcc gcc-c++ util-linux-user pipx xdg-desktop-portal-gnome hyprland hyprpaper hyprland-qtutils gammastep sway dbus-devel pkgconf-pkg-config @cosmic-desktop-environment zathura zathura-pdf-mupdf

curl -fsSL https://opencode.ai/install | bash

echo "Pacotes essenciais instalados!!!"

cd ~

echo "Instalando Homebrew!!!"

NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

brew tap oven-sh/bun

brew install gcc
hash -r

brew install bun rust neovim oh-my-posh eza bat zoxide yazi glow gum helix anomalyco/tap/opencode uv

hash -r

echo "Homebrew instalado!!!"

uv tool install nvibrant

cargo install bluetui

hash -r

# bash $HOME/dotfiles/.scripts/linux/LunarVimInstall.sh

timedatectl set-local-rtc 1 --adjust-system-clock > /dev/null 2>&1

sudo timedatectl set-ntp true > /dev/null 2>&1

sudo journalctl --vacuum-time=7d

curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sudo sh

sudo chsh -s $(which zsh)
