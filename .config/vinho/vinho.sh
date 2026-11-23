#!/usr/bin/env bash
# vinho.sh – tema mínimo: waybar, fuzzel e dunst, sem quickshell. Usado pelo ~/.config/quickshell/tema.sh
# (Super+Shift+T) e pelo hyprland.lua/.conf desta pasta num PC recém-instalado.
#
#   vinho.sh iniciar | parar      sobe | encerra a barra e as notificações deste tema
#   vinho.sh launcher             abre/fecha o launcher
#   vinho.sh energia              menu de energia
#   vinho.sh bloquear             bloqueia a tela
set -u
V="$HOME/.config/vinho"

menu() { fuzzel --config "$V/fuzzel.ini" "$@"; }
parar() {
    pkill -f "^waybar -c $V/"; pkill -f "^dunst -conf $V/"
    for _ in $(seq 40); do pgrep -f "^(waybar -c|dunst -conf) $V/" >/dev/null || return 0; sleep 0.05; done
    pkill -9 -f "^(waybar -c|dunst -conf) $V/"
}

case "${1:-}" in
    iniciar)
        parar
        setsid -f waybar -c "$V/barra.jsonc" -s "$V/barra.css" >/dev/null 2>&1 </dev/null
        setsid -f dunst -conf "$V/dunstrc" >/dev/null 2>&1 </dev/null
        ;;
    parar) parar ;;
    launcher)
        pkill -x fuzzel && exit 0
        if command -v fuzzel >/dev/null; then menu; else exec wofi --show drun; fi
        ;;
    energia)
        pkill -x fuzzel && exit 0
        op=$(printf '%s\n' Bloquear Suspender Sair Reiniciar Desligar | menu --dmenu --lines 5 --width 20) || exit 0
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
    *) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
