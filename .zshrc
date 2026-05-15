ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

source "${ZINIT_HOME}/zinit.zsh"

# Set up the prompt

autoload -Uz promptinit
promptinit
prompt adam1
autoload -Uz compinit
compinit

# Use emacs keybindings even if our EDITOR is set to vi

bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# Keep 1000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_find_no_dups
setopt hist_ignore_dups
setopt histignorealldups sharehistory

# Use modern completion system

eval "$(/home/linuxbrew/.linuxbrew/bin/oh-my-posh init zsh --config ~/.config/oh-my-posh/oh-my-pure.omp.toml)"
eval "$(dircolors -b)"
eval "$(/home/linuxbrew/.linuxbrew/bin/zoxide init --cmd cd zsh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu no
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

GOPATH=$HOME/go  PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
export PKG_CONFIG_PATH=/usr/lib64/pkgconfig:$PKG_CONFIG_PATH
export GTK_THEME=Adwaita:dark
export PATH=$PATH:/home/raul/.spicetify
export PATH=$HOME/.local/bin:$PATH
export PATH="$PATH:$HOME/go/bin"
export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"
export EDITOR="$HOME/.local/bin/lvim"
export PATH="$HOME/.bun/bin:$PATH"
export PATH="$HOME/.asdf/shims:$PATH"
export PATH="$HOME/../linuxbrew/.linuxbrew/bin/:$PATH"
export BROWSER="distrobox-host-exec google-chrome-canary"
export PATH="$HOME/.local/bin:$PATH"
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH="$PATH:/home/raul/.local/bin"
export PATH="/home/raul/arch/.cache/.bun/bin:$PATH"
export PATH=/home/raul/arch/.opencode/bin:$PATH
export NVM_DIR="$HOME/.nvm"
export PATH=$HOME/.local/share/bob/nvim-bin:$HOME/.bun/bin:$HOME/.local/bin:$HOME/.asdf/shims:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/home/raul/raul/.bun/bin:/home/raul/.cargo/bin:/home/raul/.local/bin:/home/raul/.local/share/zinit/polaris/bin:/usr/local/bin:/usr/bin:/home/raul/.spicetify:/usr/local/go/bin:/home/raul/go/bin:/home/raul/.spicetify:/usr/local/go/bin:/home/raul/go/bin:/home/raul/go/bin
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Comands
nvibrant -v 700 >> ~/nohup.out

# Aliases

gacp() {
  message="$1"
  shift

  git add -A && git commit -m "$message" && git push -u origin main
}

#Tmux Aliases
alias t="tmux"
alias tn="tmux new -s"
alias ta="tmux attach" # -t name
alias tls="tmux ls"
alias tsn="tmux kill-session -t"
alias tsr="tmux kill-server"

#Podman Aliases
alias p="podman"
alias pc="podman-compose"

#VSCodium Aliases
alias codi="flatpak run com.vscodium.codium"

#git Aliases
alias g="git"
alias gs="git status -s"
alias ga="git add"
alias gaa="git add -A"
alias gc="git commit -m"
alias gp="git push"

#asdf Aliases
alias e='asdf exec'

#apt Aliases
alias sapt='sudo apt'
alias apti='sudo apt install'
alias aptu='sudo apt update && sudo apt upgrade'
alias apts='sudo apt search'

#dnf Aliases
alias sdnf='sudo dnf'
alias dnfs='sudo dnf search'
alias dnfi='sudo dnf install'
alias dnfr='sudo dnf remove'
alias dnfu='sudo dnf upgrade && flatpak update && brew upgrade'

#ls Aliases
alias ls='eza --icons --color always'
alias ll='eza --icons --color always -l'
alias lla='eza --icons --color always -la'
alias lsa='eza --icons --color always -a'

#Lunarvim Aliases
alias l='~/.local/bin/lvim'
alias lvim='~/.local/bin/lvim'

#clear Aliases
alias cls='/usr/bin/clear'
alias c='/usr/bin/clear'

#cat Aliases
alias cat='bat --paging=always --color=always'

#fzf Aliases
alias fzf='fzf --preview="bat --color=always {}'

#yay Aliases
alias yay='yay --color always'

#scrot Aliases
alias scrots='scrot -s | xsel -i -b'

#conky Aliases
alias conky='conky -c ~/.config/conky/mocha.conf'

#Zellij Aliases
alias z='zellij options --theme catppuccin-mocha --pane-frames false'

#Zeditor Aliases
alias zed='flatpak run dev.zed.Zed'

#jetbrains-toolbox Aliases
alias toolbox='jetbrains-toolbox'

#distrobox Aliases
alias arch='distrobox-enter -n arch --no-workdir -- /usr/bin/zsh'

#brew Aliases
alias b='brew'
alias bi='brew install'
alias bu='brew update && brew upgrade'

#Helix Aliases
alias helix='flatpak run com.helix_editor.Helix'

#Update all package-managers Aliase
alias update='sudo dnf upgrade && flatpak update && brew upgrade'
alias up='sudo dnf upgrade && flatpak update && brew upgrade'

#Walker Aliases
alias walker="walker --gapplication-service"

#ZSH Aliases
alias zsh="/home/linuxbrew/.linuxbrew/bin/zsh -l"

# sources
# source <(kubectl completion zsh)
source ~/.config/antigen.zsh
[ -s "/home/raul/.bun/_bun" ] && source "/home/raul/.bun/_bun"

/bin/clear
