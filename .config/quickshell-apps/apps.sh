#!/usr/bin/env bash
# apps.sh – menu de apps (quickshell-apps). Instância própria, separada dos temas do quickshell.
#
#   apps.sh iniciar   sobe a instância e a reinicia se cair com crash (exec-once do Hyprland)
#   apps.sh toggle    abre/fecha o menu (Super+A); sobe a instância antes, se ela não estiver rodando
set -u

DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# caminho pela ~/.config (é o que aparece no pgrep e no ipc)
CFG="$HOME/.config/quickshell-apps"

rodando() { pgrep -f "^quickshell -p $CFG\$" >/dev/null; }

iniciar() {
    rodando && return 0
    # crash (SIGSEGV/SIGABRT/SIGBUS = 139/134/135): sobe de novo; mais de 5 em 1 min: desiste
    setsid -f bash -c '
        crashes=0; inicio=$(date +%s)
        while :; do
            quickshell -p "$1"; rc=$?
            case $rc in 134|135|139) ;; *) exit 0 ;; esac
            agora=$(date +%s)
            [ $((agora - inicio)) -gt 60 ] && { crashes=0; inicio=$agora; }
            crashes=$((crashes + 1)); [ $crashes -gt 5 ] && exit 1
            sleep 1
        done' _ "$CFG" >/dev/null 2>&1 </dev/null
}

case "${1:-}" in
    iniciar) iniciar ;;
    toggle)
        if ! quickshell -p "$CFG" ipc call apps toggle 2>/dev/null; then
            iniciar
            for _ in $(seq 40); do
                sleep 0.1
                quickshell -p "$CFG" ipc call apps abrir 2>/dev/null && exit 0
            done
            exit 1
        fi
        ;;
    *) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
