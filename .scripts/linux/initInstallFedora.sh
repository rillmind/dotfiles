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

sudo dnf install -y git stow vim ghostty google-chrome-canary

echo "Pacotes essenciais instalados!!!"

echo "Instalando dotfiles!!!"

cd ~

sudo rm ~/.bashrc

git clone https://github.com/rillmind/dotfiles

cd dotfiles

stow .

cd ~

echo "Dotfiles instalado!!!"

sudo cat ~/.config/dnf/dnf.conf > /etc/dnf/dnf.conf

echo "Instalando Homebrew!!!"

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew tap oven-sh/bun

brew install gcc rust neovim bun oh-my-posh eza bat zoxide yazi

echo "Homebrew instalado!!!"

echo "Instalando dependências do lunarvim!!!"

curl -fsSL https://bun.sh/install | bash

bun -g install neovim tree-sitter-cli

cargo install fd-find ripgrep

LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh) --no-install-dependencies

echo "Lunarvim instalado!!!"

timedatectl set-local-rtc 1 --adjust-system-clock
timedatectl
sudo timedatectl set-ntp true
sudo timedatectl set-time "YYYY-MM-DD HH:MM:SS"

curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sudo sh

zsh
