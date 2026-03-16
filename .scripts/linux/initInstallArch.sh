printf "Já alterou o parallel downloads? (s/n): "
read confirma
if [ "$confirma" = "s" ]; then
  echo "Continuando..."
else
  echo "Abortado."
  exit 1
fi

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

sudo pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si

cd

yay -S zsh zoxide fzf exa bat oh-my-posh neovim zed cargo bun python-pynvim

bun -g install neovim tree-sitter-cli

cargo install fd-find ripgrep

LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh)

zsh
