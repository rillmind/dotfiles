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

# fuzzel; sem ele, o wofi com as mesmas cores
menu_apps() {
    if command -v fuzzel >/dev/null; then fuzzel --config "$V/fuzzel.ini"
    else wofi --conf /dev/null --style "$V/wofi.css" --show drun --location center --width 520 --lines 9; fi
}
menu_lista() {
    if command -v fuzzel >/dev/null; then fuzzel --config "$V/fuzzel.ini" --dmenu --lines 5 --width 20
    else wofi --conf /dev/null --style "$V/wofi.css" --dmenu --location center --width 300 --lines 6; fi
}
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
    pkill -f "^waybar -c $V/"; pkill -f "^dunst -conf $V/"
    pkill -f "^waybar -c $B"
    for _ in $(seq 40); do pgrep -f "^(waybar -c|dunst -conf) $V/" >/dev/null || return 0; sleep 0.05; done
    pkill -9 -f "^(waybar -c|dunst -conf) $V/"
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
            Sair) hyprctl dispatch exit 2>/dev/null | grep -qx ok || hyprctl dispatch 'hl.dsp.exit()' ;;
            Reiniciar) systemctl reboot ;;
            Desligar) systemctl poweroff ;;
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
