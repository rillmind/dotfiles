read -p "Já alterou o parallel downloads? (s/n): " confirm1
if [[ "$confirm1" == "s" || "$confirm1" == "S" ]]; then
  echo "Continuando..."
else
  echo "Abortado."
  exit 1
fi

sudo pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si && cd ~
hash -r

yay -S zsh zed python-pynvim xdg-utils perl-file-mimeinfo yazi gcc gcc-c++ xdg-desktop-portal-gnome
hash -r

NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

brew tap oven-sh/bun

brew install gcc
hash -r

brew install bun rust neovim oh-my-posh eza bat zoxide yazi
hash -r

bun add -g neovim tree-sitter-cli

cargo install fd-find ripgrep
hash -r

LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh) --no-install-dependencies

# Corrige problemas em distrobox reconhecer navegadores do sistema original
read -p "É distrobox? (s/n): " confirm2
if [[ "$confirm2" == "s" || "$confirm2" == "S" ]]; then
  sudo pacman -S --noconfirm xdg-utils perl-file-mimeinfo
  sudo ln -sf /usr/bin/distrobox-host-exec /usr/local/bin/xdg-open
  mkdir -p ~/.config
  cat <<EOF > ~/.config/mimeapps.list
[Default Applications]
text/html=browser.desktop
x-scheme-handler/http=browser.desktop
x-scheme-handler/https=browser.desktop
x-scheme-handler/about=browser.desktop
x-scheme-handler/unknown=browser.desktop
EOF

  mkdir -p ~/.local/share/applications
  cat <<EOF > ~/.local/share/applications/browser.desktop
[Desktop Entry]
Type=Application
Name=Host Browser
Exec=distrobox-host-exec google-chrome-canary %u
Icon=google-chrome-canary
Terminal=false
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
EOF

  update-desktop-database ~/.local/share/applications
  echo "Configuração para Distrobox aplicada com sucesso."
else
  echo "Pulando configuração de Distrobox."

  yay -S google-chrome-canary ghostty brave-bin zen-browser-bin

  timedatectl set-local-rtc 1 --adjust-system-clock > /dev/null 2>&1
  sudo timedatectl set-ntp true > /dev/null 2>&1

  curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sudo sh
fi

zsh
