packages=(
  neovim
  oh-my-posh
  eza
  bat
  zoxide
  yazi
)

cd ~

NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

brew install gcc

hash -r

brew install "${packages[@]}"

hash -r
