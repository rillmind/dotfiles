#!/usr/bin/env bash
# vinho.sh – tema mínimo: waybar, fuzzel e dunst, sem quickshell. Usado pelo ~/.config/quickshell/tema.sh
# (Super+Shift+T) e pelo hyprland.lua/.conf desta pasta num PC recém-instalado.
#
#   vinho.sh iniciar | parar      sobe | encerra a barra e as notificações deste tema
#   vinho.sh bandeja              abre/fecha os ícones da bandeja
#   vinho.sh launcher             abre/fecha o launcher
#   vinho.sh energia              menu de energia
#   vinho.sh bloquear             bloqueia a tela
set -u
V="$HOME/.config/vinho"
B="${XDG_RUNTIME_DIR:-/tmp}/vinho-bandeja-"

# Sem o fuzzel, usa o wofi com as mesmas cores, sempre sem diferenciar maiúsculas. O modo drun dele não
# serve: procura também no caminho do arquivo ("local" acha tudo de ~/.local) e lê até .desktop.bak.
wofi_lista() { wofi --conf /dev/null --style "$V/wofi.css" --dmenu --insensitive --location center "$@"; }
# "nome<TAB>arquivo" dos apps visíveis; o mesmo app em ~/.local vale por cima do sistema
listar_apps() {
    local d
    for d in "${XDG_DATA_HOME:-$HOME/.local/share}" "$HOME/.local/share/flatpak/exports/share" \
             /var/lib/flatpak/exports/share /usr/local/share /usr/share; do
        find "$d/applications" -maxdepth 1 -name '*.desktop' 2>/dev/null
    done | awk -F/ '!visto[$NF]++' | xargs -rd '\n' gawk -F= -v l="${LANG%%.*}" '
        BEGINFILE { dentro = x = 0; n = nl = "" }
        /^\[/ { dentro = ($0 == "[Desktop Entry]") }
        !dentro { next }
        $1 == "Name" { n = substr($0, 6) }
        $1 == "Name[" l "]" { nl = substr($0, length($1) + 2) }
        $1 == "Type" && $2 != "Application" { x = 1 }
        ($1 == "NoDisplay" || $1 == "Hidden") && $2 == "true" { x = 1 }
        ENDFILE { if (!x && n != "") print (nl != "" ? nl : n) "\t" FILENAME }' | sort -f |
        awk -F'\t' '{ k = ++v[$1]; print $1 (k > 1 ? " (" k ")" : "") "\t" $2 }'
}
menu_apps() {
    if command -v fuzzel >/dev/null; then fuzzel --config "$V/fuzzel.ini"; return; fi
    local lista nome arq
    lista=$(listar_apps)
    nome=$(cut -f1 <<<"$lista" | wofi_lista --prompt Apps --width 520 --lines 9) || return 0
    # só abre o que está na lista: texto solto não executa nada
    arq=$(awk -F'\t' -v n="$nome" '$1 == n { print $2; exit }' <<<"$lista")
    [ -n "$arq" ] && setsid -f gtk-launch "$(basename "$arq" .desktop)" >/dev/null 2>&1 </dev/null
}
menu_lista() {
    if command -v fuzzel >/dev/null; then fuzzel --config "$V/fuzzel.ini" --dmenu --lines 5 --width 20
    else wofi_lista --prompt Energia --width 300 --lines 6; fi
}
confirmar() { [ "$(printf '%s\n' Cancelar "$1" | menu_lista)" = "$1" ]; }    # Enter sozinho cancela
# se já há um menu aberto, o atalho só o fecha
fechar_menu() { pkill -x 'fuzzel|wofi'; }
# a bandeja é outra waybar, uma por monitor, que fica viva e escondida: se ela fosse fechada, os apps
# perderiam o lugar onde registram os ícones. SIGUSR1 mostra/esconde.
criar_bandeja() {    # monitor
    local margem
    margem=$(hyprctl monitors | awk -v m="$1" '
        /^Monitor/ { eu = ($2 == m) }
        eu && $1 ~ /^[0-9]+x[0-9]+@/ { split($1, r, /[x@]/) }
        eu && $1 == "scale:" { e = $2 }
        eu && $1 == "transform:" { l = int(($2 % 2 ? r[2] : r[1]) / (e ? e : 1)) - 400; print (l > 0 ? l : 0) }')
    sed -e "s/@MONITOR@/$1/" -e "s/@MARGEM@/${margem:-0}/" "$V/bandeja.jsonc" > "$B$1.jsonc"
    setsid -f waybar -c "$B$1.jsonc" -s "$V/bandeja.css" >/dev/null 2>&1 </dev/null
}
parar() {
    pkill -f "^waybar -c $V/"
    pkill -x dunst     # qualquer um: um app que notifica cedo faz o D-Bus subir o dunst sem a nossa config
    pkill -f "^waybar -c $B"
    for _ in $(seq 40); do { pgrep -f "^waybar -c $V/" || pgrep -x dunst; } >/dev/null || return 0; sleep 0.05; done
    pkill -9 -f "^waybar -c $V/"; pkill -9 -x dunst
}

case "${1:-}" in
    iniciar)
        parar
        setsid -f waybar -c "$V/barra.jsonc" -s "$V/barra.css" >/dev/null 2>&1 </dev/null
        for m in $(hyprctl monitors | awk '/^Monitor/ { print $2 }'); do criar_bandeja "$m"; done
        setsid -f dunst -conf "$V/dunstrc" >/dev/null 2>&1 </dev/null
        ;;
    parar) parar ;;
    bandeja)
        m="${WAYBAR_OUTPUT_NAME:-$(hyprctl monitors | awk '/^Monitor/ { m = $2 } /focused: yes/ { print m }')}"
        # monitor ligado depois: a bandeja dele ainda não existe
        pgrep -f "^waybar -c $B$m.jsonc" >/dev/null || { criar_bandeja "$m"; sleep 0.7; }
        pkill -USR1 -f "^waybar -c $B$m.jsonc"
        ;;
    launcher)
        fechar_menu && exit 0
        menu_apps
        ;;
    energia)
        fechar_menu && exit 0
        op=$(printf '%s\n' Bloquear Suspender Sair Reiniciar Desligar | menu_lista) || exit 0
        case "$op" in
            Bloquear) exec "$0" bloquear ;;
            Suspender) systemctl suspend ;;
            Sair) confirmar "Sair" || exit 0; hyprctl dispatch exit 2>/dev/null | grep -qx ok || hyprctl dispatch 'hl.dsp.exit()' ;;
            Reiniciar) confirmar "Reiniciar" || exit 0; systemctl reboot ;;
            Desligar) confirmar "Desligar" || exit 0; systemctl poweroff ;;
        esac
        ;;
    bloquear)
        if [ -x "$HOME/.config/quickshell-bloqueio/bloquear.sh" ] && command -v quickshell >/dev/null; then
            exec "$HOME/.config/quickshell-bloqueio/bloquear.sh"
        fi
        pgrep -x swaylock >/dev/null || exec swaylock -f -C "$V/swaylock.conf"
        ;;
    *) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
