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

sudo rpm --import https://dl.google.com/linux/linux_signing_key.pub

sudo tee /etc/yum.repos.d/google-chrome.repo <<EOF
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF

sudo dnf install -y vim ghostty google-chrome-canary zsh gcc

echo "Pacotes essenciais instalados!!!"

cd ~

echo "Instalando Homebrew!!!"

NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

brew tap oven-sh/bun

brew install gcc
hash -r

brew install rust bun neovim oh-my-posh eza bat zoxide yazi
hash -r

echo "Homebrew instalado!!!"

echo "Instalando dependências do lunarvim!!!"

curl -fsSL https://bun.sh/install | bash

bun add -g neovim tree-sitter-cli

cargo install fd-find ripgrep
hash -r

LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh) --no-install-dependencies

echo "Lunarvim instalado!!!"

timedatectl set-local-rtc 1 --adjust-system-clock
timedatectl
sudo timedatectl set-ntp true

curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sudo sh

chsh -s $(which zsh)

clear

zsh
