environment=(
  @cosmic-desktop-environment
  zathura
  zathura-pdf-mupdf
  gdu # TUI para analizar armazenamento
  duf # grafico de discos
  udiskie
)

dev=(
  pipx
  vim
  ghostty
  zsh
  gcc
  gcc-c++
  codium
  podman
)

hyprland=(
  util-linux-user
  xdg-desktop-portal-gnome
  hyprland
  hyprpaper
  hyprland-qtutils
  gammastep
  sway
  dbus-devel
  pkgconf-pkg-config
  nwg-dock-hyprland
)

#Importação dos repositórios
sudo tee -a /etc/yum.repos.d/vscodium.repo << 'EOF'
[gitlab.com_paulcarroty_vscodium_repo]
name=gitlab.com_paulcarroty_vscodium_repo
baseurl=https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/rpms/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg
metadata_expire=1h
EOF

# Ainda importação dos repositórios, mas só os CORP
sudo dnf copr enable scottames/ghostty

sudo dnf copr enable sdegler/hyprland

sudo dnf copr enable tofik/nwg-shell

# Instalação dos pacotes do DNF
sudo dnf install -y "${environment[@]}" "${dev[@]}" "${hyprland[@]}"

#Instalção dos pacotes via script de instalação externos
curl -f https://zed.dev/install.sh | sh

curl -fsSL https://bun.com/install | bash

curl -LsSf https://astral.sh/uv/install.sh | sh

uv tool install nvibrant pulsemixer

curl -fsSL https://opencode.ai/install | bash

bash -c "$(curl -sLo- https://superfile.dev/install.sh)"

curl -s https://ohmyposh.dev/install.sh | bash -s
