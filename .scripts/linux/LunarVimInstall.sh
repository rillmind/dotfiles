#!/bin/bash

echo "Instalando dependências do lunarvim!!!"

sudo pipx install pynvim

bun add -g neovim tree-sitter-cli
hash -r

cargo install fd-find ripgrep
hash -r

echo "Instalando LunarVim!!!"

LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh) --no-install-dependencies

echo "Lunarvim instalado!!!"

