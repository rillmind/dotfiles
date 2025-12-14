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

setopt histignorealldups sharehistory

# Use emacs keybindings even if our EDITOR is set to vi

bindkey -e

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

# Use modern completion system
autoload -Uz compinit
compinit

eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/oh-my-pure.omp.toml)"

eval "$(zoxide init --cmd cd zsh)"

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
alias codi="codium"

#git Aliases
alias g="git"
alias gs="git status -s"
alias ga="git add"
alias gaa="git add -A"
alias gc="git commit -m"
alias gp="git push"

gacp() {
  message="$1"
  shift

  git add -A && git commit -m "$message" && git push -u origin main
}

#docker-lang Aliases
docker-lang() {
  local lang="$1"
  shift

  docker run -it --rm -v "$PWD":/app -w /app "$lang"
}

#tmux Aliases
#alias tmux='tmux new /bin/zsh'

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
alias dnfu='sudo dnf upgrade'

#ls Aliases
alias ls='eza --icons --color always'
alias ll='eza --icons --color always -l'
alias lla='eza --icons --color always -la'
alias lsa='eza --icons --color always -a'

#nvim Aliases
#alias nvim='~/.local/bin/nvim-linux-x86_64/bin/nvim'

#Lunarvim Aliases
alias l='~/.local/bin/lvim'
alias lvim='~/.local/bin/lvim'

#clear Aliases
alias cls='/usr/bin/clear'
alias c='/usr/bin/clear'

#cat Aliases
alias cat='bat --paging=always --color=always'

#Python Aliases
#alias py='python3'

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

#jetbrains-toolbox Aliases
alias toolbox='jetbrains-toolbox'

#ncdu Aliases
#alias ncdu='ncdu --color dark'

zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
eval "$(dircolors -b)"
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

bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

source ~/.config/antigen.zsh

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
[ -s "/home/raul/.bun/_bun" ] && source "/home/raul/.bun/_bun"
GOPATH=$HOME/go  PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
export PATH=$PATH:/home/raul/.spicetify
export PATH=$HOME/.local/bin:$PATH
export PATH="$PATH:$HOME/go/bin"
export PATH=/home/raul/.local/share/bob/nvim-bin:/home/raul/.bun/bin:/home/raul/.local/bin:/home/raul/.asdf/shims:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/home/raul/raul/.bun/bin:/home/raul/.cargo/bin:/home/raul/.local/bin:/home/raul/.local/share/zinit/polaris/bin:/usr/local/bin:/usr/bin:/home/raul/.spicetify:/usr/local/go/bin:/home/raul/go/bin:/home/raul/.spicetify:/usr/local/go/bin:/home/raul/go/bin:/home/raul/go/bin
export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"
export EDITOR="~/.local/bin/lvim"
export PATH="/home/raul/.bun/bin:$PATH"
export PATH="$HOME/.asdf/shims:$PATH"
