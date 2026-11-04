#!/usr/bin/env bash
# Faz o ctrl+shift+v colar imagem no Claude Code quando ele roda dentro do tmux.
#
# O Ghostty só cola texto, e o ctrl+v (atalho de imagem do Claude Code) é usado
# pelo tmux para entrar no copy-mode. O fluxo fica assim:
#   1. Ghostty: ctrl+shift+v cola o texto e envia a sequência CSI 9999~
#   2. tmux: reconhece a sequência como User0 e chama este script
#   3. script: se o clipboard só tem imagem e o painel roda o Claude Code,
#      envia ctrl+v direto ao painel, sem passar pelo bind do tmux
#
# Configuração: ~/.config/ghostty/config, ~/.tmux.conf e ~/.zshrc (ignora a
# sequência fora do tmux).
#
# Uso: tmux-paste-image.sh <pane_id>

pane=${1:?uso: tmux-paste-image.sh <pane_id>}

types=$(wl-paste --list-types 2>/dev/null) || exit 0

# Com texto no clipboard, o próprio Ghostty já colou.
grep -qxE 'text/plain.*|UTF8_STRING|STRING|TEXT' <<<"$types" && exit 0
grep -q '^image/' <<<"$types" || exit 0

tty=$(tmux display-message -p -t "$pane" '#{pane_tty}') || exit 0
ps -t "$tty" -o comm= | grep -qx claude || exit 0

tmux send-keys -t "$pane" C-v
