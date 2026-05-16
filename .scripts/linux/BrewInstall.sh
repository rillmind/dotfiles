packages=(
  bun
  rust
  neovim
  oh-my-posh
  eza
  bat
  zoxide
  yazi
  glow
  gum
  helix
  anomalyco/tap/opencode
  uv
)

cd ~

NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

brew tap oven-sh/bun

brew install gcc

hash -r

brew install "${packages[@]}"

hash -r
