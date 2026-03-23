#!/bin/sh

echo "Instalando dependências do lunarvim!!!"

curl -fsSL https://bun.sh/install | bash

bun -g install neovim tree-sitter-cli

cargo install fd-find ripgrep

LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh) --no-install-dependencies

echo "Lunarvim instalado!!!"
